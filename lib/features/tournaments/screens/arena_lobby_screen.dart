import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/tournament_model.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart'; // firestoreServiceProvider
import '../../../core/services/tournament_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/widgets/user_avatar.dart';

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  const ArenaLobbyScreen({super.key, required this.tournamentId});

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> {
  // ── Local state ────────────────────────────────────────────────────────────
  TournamentModel? _tournament;
  List<ArenaParticipant> _participants = [];
  bool _isParticipant = false;
  bool _isReady = false;      // currently in the RTDB ready queue
  bool _isPairing = false;    // currently running claim transaction
  bool _joining = false;      // joining the Firestore tournament
  bool _starting = false;     // creator starting the tournament
  Duration _timeRemaining = Duration.zero;

  // ── Player info ────────────────────────────────────────────────────────────
  String? _myUid;
  String? _myUsername;
  int _myRating = 1200;

  // ── Subscriptions / timers ─────────────────────────────────────────────────
  StreamSubscription<TournamentModel>? _tournamentSub;
  StreamSubscription<List<ArenaParticipant>>? _participantsSub;
  StreamSubscription<DatabaseEvent>? _queueSub;
  StreamSubscription<DatabaseEvent>? _pairingSub;
  Timer? _uiTimer;
  Timer? _endTimer;
  Timer? _botFallbackTimer;
  int _queueSeconds = 0;

  GameType get _gameType =>
      GameTypeX.fromString(_tournament?.gameType);

  /// Per-game rule extras carried into every arena game so both clients
  /// build the identical engine configuration (variant chosen at creation).
  Map<String, dynamic> get _rulesExtras {
    final key = _tournament?.rulesKey;
    return switch (_gameType) {
      GameType.checkers => {'checkersVariant': key ?? 'standard'},
      GameType.domino => {
          'dominoVariant': key ?? 'draw',
          'dominoTarget': 100,
          'dominoPlayerCount': '2-player',
        },
      GameType.chess => const {},
    };
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tournamentSub?.cancel();
    _participantsSub?.cancel();
    _queueSub?.cancel();
    _pairingSub?.cancel();
    _uiTimer?.cancel();
    _endTimer?.cancel();
    _botFallbackTimer?.cancel();
    // Leave queue cleanly
    if (_isReady && _myUid != null) {
      ref
          .read(realtimeGameServiceProvider)
          .leaveArenaQueue(widget.tournamentId, _myUid!);
    }
    super.dispose();
  }

  Future<void> _init() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    _myUid = user.uid;
    _myUsername = user.username;
    // Rating will be updated once tournament loads and gameType is known
    _myRating = user.overallRating;

    // Watch tournament document
    _tournamentSub = ref
        .read(tournamentServiceProvider)
        .watchTournament(widget.tournamentId)
        .listen(_onTournamentUpdate, onError: (_) {});

    // Watch leaderboard
    _participantsSub = ref
        .read(tournamentServiceProvider)
        .watchParticipants(widget.tournamentId)
        .listen((ps) {
      if (!mounted) return;
      setState(() {
        _participants = ps;
        _isParticipant = ps.any((p) => p.uid == _myUid);
      });
    }, onError: (_) {});

    // Watch my pairing result
    _pairingSub = ref
        .read(realtimeGameServiceProvider)
        .watchMyArenaPairing(widget.tournamentId, _myUid!)
        .listen(_onPairingUpdate);
  }

  void _onTournamentUpdate(TournamentModel t) {
    if (!mounted) return;
    setState(() => _tournament = t);

    if (t.isActive && t.endsAt != null) {
      _setupCountdown(t);
    }

    // Tournament just ended — leave queue if needed
    if (t.isFinished && _isReady) {
      _leaveQueue();
    }
  }

  void _setupCountdown(TournamentModel t) {
    _uiTimer?.cancel();
    _endTimer?.cancel();

    final endsAt = t.endsAt!;
    final remaining = endsAt.difference(DateTime.now());

    if (remaining.isNegative) {
      _checkAndFinish(t);
      return;
    }

    // Update remaining time every second
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rem = endsAt.difference(DateTime.now());
      setState(() => _timeRemaining = rem.isNegative ? Duration.zero : rem);
      if (rem.isNegative && _tournament?.isActive == true) {
        _uiTimer?.cancel();
        _checkAndFinish(_tournament!);
      }
    });

    // One-shot timer at exact end
    _endTimer = Timer(remaining, () => _checkAndFinish(t));

    setState(() => _timeRemaining = remaining);
  }

  Future<void> _checkAndFinish(TournamentModel t) async {
    if (t.isFinished) return;
    if (_isReady) _leaveQueue();
    try {
      await ref
          .read(tournamentServiceProvider)
          .finishArena(widget.tournamentId);
    } catch (_) {}
  }

  // ── Queue management ───────────────────────────────────────────────────────

  void _enterQueue() {
    if (_myUid == null || _myUsername == null) return;
    setState(() {
      _isReady = true;
      _queueSeconds = 0;
    });

    ref.read(realtimeGameServiceProvider).joinArenaQueue(
          tournamentId: widget.tournamentId,
          uid: _myUid!,
          username: _myUsername!,
          rating: _myRating,
        );

    _queueSub?.cancel();
    _queueSub = ref
        .read(realtimeGameServiceProvider)
        .watchArenaQueue(widget.tournamentId)
        .listen(_onQueueUpdate);

    // Bot fallback: if no real opponent found in 30 s, pair with a bot
    _botFallbackTimer?.cancel();
    _botFallbackTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isReady || !mounted) { t.cancel(); return; }
      _queueSeconds++;
      if (_queueSeconds >= 30) {
        t.cancel();
        _matchWithBot();
      }
    });
  }

  void _leaveQueue() {
    if (_myUid == null) return;
    _queueSub?.cancel();
    _botFallbackTimer?.cancel();
    setState(() => _isReady = false);
    ref
        .read(realtimeGameServiceProvider)
        .leaveArenaQueue(widget.tournamentId, _myUid!);
  }

  void _matchWithBot() {
    if (!_isReady || !mounted) return;
    _leaveQueue();

    final t = _tournament;
    if (t == null || !t.isActive) return;

    final gt = _gameType;
    final gameId = const Uuid().v4();
    final botName = (gt.fakeBotNames.toList()..shuffle()).first;
    final tc = TimeControl(
      minutes: t.timeSeconds ~/ 60,
      incrementSeconds: t.incrementSeconds,
    );

    context.push(gt.gameRoute(gameId), extra: {
      'mode': GameMode.bot.name,
      'gameType': gt.name,
      'timeControl': tc.toMap(),
      'playerIsWhite': DateTime.now().millisecondsSinceEpoch % 2 == 0,
      'isRated': false,
      'gameId': gameId,
      'opponentUsername': botName,
      'opponentRating': _myRating + (50 - (DateTime.now().second % 100)),
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      ..._rulesExtras,
    });
  }

  void _onQueueUpdate(DatabaseEvent event) {
    if (!_isReady || _isPairing) return;
    final raw = event.snapshot.value;
    if (raw == null) return;

    final queue = Map<String, dynamic>.from(raw as Map);

    // UID-comparison convention: only the SMALLER uid initiates the claim.
    // This eliminates symmetric race conditions.
    for (final opponentUid in queue.keys) {
      if (opponentUid == _myUid) continue;
      if (_myUid!.compareTo(opponentUid) >= 0) continue; // not my turn
      _tryPair(opponentUid);
      return;
    }
  }

  Future<void> _tryPair(String opponentUid) async {
    if (!_isReady || _isPairing) return;
    setState(() => _isPairing = true);

    final t = _tournament;
    if (t == null || !t.isActive) {
      setState(() => _isPairing = false);
      return;
    }

    final gameId = const Uuid().v4();

    final ok = await ref.read(realtimeGameServiceProvider).tryClaimArenaPairing(
          tournamentId: widget.tournamentId,
          myUid: _myUid!,
          myUsername: _myUsername!,
          myRating: _myRating,
          opponentUid: opponentUid,
          gameId: gameId,
          timeControlLabel: t.timeControlLabel,
        );

    if (!mounted) return;
    setState(() {
      _isPairing = false;
      if (ok) _isReady = false;
    });

    if (!ok) return; // Opponent was already claimed; stay in queue

    // I'm the claimer → I play white. Navigate to game.
    final gt = _gameType;
    final tc = TimeControl(
      minutes: t.timeSeconds ~/ 60,
      incrementSeconds: t.incrementSeconds,
    );

    final opponent =
        await ref.read(firestoreServiceProvider).getUser(opponentUid);
    if (!mounted) return;

    context.push(gt.gameRoute(gameId), extra: {
      'mode': GameMode.online.name,
      'gameType': gt.name,
      'timeControl': tc.toMap(),
      'playerIsWhite': true,
      'isRated': true,
      'gameId': gameId,
      'opponentUid': opponentUid,
      'opponentUsername': opponent?.username ?? 'Opponent',
      'opponentRating': opponent?.overallRating ?? 1200,
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      ..._rulesExtras,
    });
  }

  void _onPairingUpdate(DatabaseEvent event) {
    // If we already navigated (via _tryPair), ignore this echo
    if (!_isReady) return;
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);

    final gameId = map['gameId'] as String?;
    final isWhite = map['isWhite'] as bool? ?? false;
    final opponentUid = map['opponentUid'] as String?;
    if (gameId == null || opponentUid == null) return;

    // Clear pairing node so it doesn't fire again
    ref
        .read(realtimeGameServiceProvider)
        .clearArenaPairing(widget.tournamentId, _myUid!);

    setState(() => _isReady = false);
    _navigateToGame(gameId: gameId, isWhite: isWhite, opponentUid: opponentUid);
  }

  Future<void> _navigateToGame({
    required String gameId,
    required bool isWhite,
    required String opponentUid,
  }) async {
    final t = _tournament;
    if (t == null) return;

    final gt = _gameType;
    final tc = TimeControl(
      minutes: t.timeSeconds ~/ 60,
      incrementSeconds: t.incrementSeconds,
    );

    final opponent =
        await ref.read(firestoreServiceProvider).getUser(opponentUid);
    if (!mounted) return;

    context.push(gt.gameRoute(gameId), extra: {
      'mode': GameMode.online.name,
      'gameType': gt.name,
      'timeControl': tc.toMap(),
      'playerIsWhite': isWhite,
      'isRated': true,
      'gameId': gameId,
      'opponentUid': opponentUid,
      'opponentUsername': opponent?.username ?? 'Opponent',
      'opponentRating': opponent?.overallRating ?? 1200,
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      ..._rulesExtras,
    });
  }

  // ── Join / Start ───────────────────────────────────────────────────────────

  Future<void> _join() async {
    if (_joining) return;
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    setState(() => _joining = true);
    final gt = _gameType;
    final rating = switch (gt) {
      GameType.checkers => user.checkersStats.rating,
      GameType.domino   => user.dominoStats.rating,
      GameType.chess    => user.overallRating,
    };
    try {
      await ref.read(tournamentServiceProvider).joinTournament(
            tournamentId: widget.tournamentId,
            uid: user.uid,
            username: user.username,
            rating: rating,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join tournament.')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _startTournament() async {
    final t = _tournament;
    if (t == null || _starting) return;
    setState(() => _starting = true);
    try {
      await ref
          .read(tournamentServiceProvider)
          .startArena(widget.tournamentId, t.durationMinutes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start tournament.')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _tournament;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                        color: AppColors.inkDim,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t?.name ?? 'arena'.tr(),
                      style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (t != null) _StatusBadge(t.status),
                ],
              ),
            ),
            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: t == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.amber))
                  : _buildBody(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TournamentModel t) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Countdown / info card ──────────────────────────────
                _CountdownCard(
                  tournament: t,
                  timeRemaining: _timeRemaining,
                ),

                const SizedBox(height: 16),

                // ── Waiting: join / start section ─────────────────────
                if (t.isWaiting) ...[
                  if (!_isParticipant)
                    _AmberCTAButton(
                      label: 'join_arena'.tr(),
                      icon: PhosphorIcons.trophy(PhosphorIconsStyle.bold),
                      trailingIcon:
                          PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                      loading: _joining,
                      onTap: _join,
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.amberGlow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.checkCircle(
                                PhosphorIconsStyle.fill),
                            size: 18,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You have joined',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Waiting for creator to start
                  if (_isParticipant && _myUid != t.creatorUid) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.inkMute,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.inkMute,
                                ),
                                children: [
                                  const TextSpan(text: 'Waiting for '),
                                  TextSpan(
                                    text: t.creatorUsername,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                      text: ' to start the tournament…'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Start button (creator only)
                  if (_myUid == t.creatorUid && t.participantCount >= 2) ...[
                    const SizedBox(height: 10),
                    _AmberCTAButton(
                      label: 'start_tournament'.tr(),
                      icon:
                          PhosphorIcons.lightning(PhosphorIconsStyle.bold),
                      trailingIcon:
                          PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
                      loading: _starting,
                      onTap: _startTournament,
                    ),
                  ] else if (_myUid == t.creatorUid &&
                      t.participantCount < 2) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Need at least 2 players to start',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.inkMute,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],

                // ── Active: Ready to Play / queue button ───────────────
                if (t.isActive && _isParticipant) ...[
                  const SizedBox(height: 4),
                  _ReadyButton(
                    isReady: _isReady,
                    isPairing: _isPairing,
                    onEnter: _enterQueue,
                    onLeave: _leaveQueue,
                  ),
                ],

                const SizedBox(height: 24),

                // ── Standings header ───────────────────────────────────
                Row(
                  children: [
                    Text(
                      'standings'.tr(),
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'W  ·  D  ·  L',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMute,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'PTS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),

        // ── Standings list ─────────────────────────────────────────────────
        if (_participants.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'no_players_yet'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.inkMute,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ParticipantRow(
                  participant: _participants[i],
                  rank: i + 1,
                  isMe: _participants[i].uid == _myUid,
                ),
                childCount: _participants.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final TournamentStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      TournamentStatus.waiting  => (
          'WAITING',
          AppColors.amber,
          AppColors.amberGlow,
        ),
      TournamentStatus.active   => (
          'LIVE',
          AppColors.live,
          const Color(0x24FF6B6B),
        ),
      TournamentStatus.finished => (
          'FINISHED',
          AppColors.inkMute,
          const Color(0x24706B62),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TournamentStatus.active) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.live, blurRadius: 6),
                ],
              ),
            ),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Countdown Card ────────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  final TournamentModel tournament;
  final Duration timeRemaining;

  const _CountdownCard({
    required this.tournament,
    required this.timeRemaining,
  });

  String _fmtCountdown(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = tournament.isActive;
    final total = Duration(minutes: tournament.durationMinutes);
    final progress = isActive && total.inSeconds > 0
        ? (timeRemaining.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardElevated, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: countdown or status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIME REMAINING',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isActive
                          ? _fmtCountdown(timeRemaining)
                          : tournament.isWaiting
                              ? '--:--'
                              : '00:00',
                      style: GoogleFonts.fraunces(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: AppColors.amber,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: time control info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TIME CONTROL',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tournament.timeControlLabel,
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tournament.durationMinutes} min arena',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: AppColors.inkMute,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar (amber gradient)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: AppColors.surface,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.toDouble(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.amber, AppColors.amberDeep],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Player count
          Row(
            children: [
              Icon(
                PhosphorIcons.users(PhosphorIconsStyle.regular),
                size: 12,
                color: AppColors.inkMute,
              ),
              const SizedBox(width: 5),
              Text(
                '${tournament.participantCount}/${tournament.maxPlayers} players',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.inkMute,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Amber CTA Button ──────────────────────────────────────────────────────────

class _AmberCTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData trailingIcon;
  final bool loading;
  final VoidCallback onTap;

  const _AmberCTAButton({
    required this.label,
    required this.icon,
    required this.trailingIcon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.amber,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.amberGlow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A1205),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF1A1205)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1205),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Icon(trailingIcon,
                      size: 16, color: const Color(0xFF1A1205)),
                ],
              ),
      ),
    );
  }
}

// ── Ready Button ──────────────────────────────────────────────────────────────

class _ReadyButton extends StatelessWidget {
  final bool isReady;
  final bool isPairing;
  final VoidCallback onEnter;
  final VoidCallback onLeave;

  const _ReadyButton({
    required this.isReady,
    required this.isPairing,
    required this.onEnter,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (isPairing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.amberGlow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Pairing…',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
      );
    }

    if (isReady) {
      return GestureDetector(
        onTap: onLeave,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.amberGlow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amber.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'searching_opponent'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: queue me in button
    return _AmberCTAButton(
      label: "I'M READY — queue me in",
      icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
      trailingIcon: PhosphorIcons.arrowRight(PhosphorIconsStyle.bold),
      loading: false,
      onTap: onEnter,
    );
  }
}

// ── Participant Row ───────────────────────────────────────────────────────────

class _ParticipantRow extends StatelessWidget {
  final ArenaParticipant participant;
  final int rank;
  final bool isMe;

  const _ParticipantRow({
    required this.participant,
    required this.rank,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? AppColors.amber
        : rank <= 3
            ? AppColors.ink
            : AppColors.inkMute;

    final pts = participant.score;
    final ptsStr = pts == pts.truncateToDouble()
        ? pts.toInt().toString()
        : pts.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.amberGlow : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: AppColors.amber.withOpacity(0.4))
            : Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.fraunces(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontStyle: rank == 1 ? FontStyle.italic : FontStyle.normal,
                color: rankColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),

          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: UserAvatar(
              username: participant.username,
              size: 34,
            ),
          ),
          const SizedBox(width: 10),

          // Username + ELO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.username,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isMe ? AppColors.amber : AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Text(
                        '· you',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${participant.rating} ELO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),

          // W · D · L
          Row(
            children: [
              _WDLItem(count: participant.wins, color: AppColors.win),
              const SizedBox(width: 4),
              Text('·',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.inkMute)),
              const SizedBox(width: 4),
              _WDLItem(
                  count: participant.draws,
                  color: AppColors.inkMute),
              const SizedBox(width: 4),
              Text('·',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.inkMute)),
              const SizedBox(width: 4),
              _WDLItem(count: participant.losses, color: AppColors.loss),
            ],
          ),

          const SizedBox(width: 12),

          // Points
          Text(
            ptsStr,
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: isMe ? AppColors.amber : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _WDLItem extends StatelessWidget {
  final int count;
  final Color color;
  const _WDLItem({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
