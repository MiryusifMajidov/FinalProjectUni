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
import '../../../core/widgets/user_avatar.dart';
import '../../../core/utils/text_case.dart';
import 'tournament_list_screen.dart' show tournamentDisplayName, formatCountdown;

const _kDark = Color(0xFF1A1205);

/// Seconds in the ready queue before the arena pairs you with one of its
/// bots. Short on purpose: with few people online, waiting 30 s (the old
/// value) for a human who never comes is why players gave up on arenas.
const _botFallbackSeconds = 10;

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
  bool _notFound = false;

  // ── Player info ────────────────────────────────────────────────────────────
  String? _myUid;
  String? _myUsername;
  int _myRating = 1200;

  // ── Subscriptions / timers ─────────────────────────────────────────────────
  StreamSubscription<TournamentModel>? _tournamentSub;
  StreamSubscription<List<ArenaParticipant>>? _participantsSub;
  StreamSubscription<DatabaseEvent>? _queueSub;
  StreamSubscription<DatabaseEvent>? _pairingSub;
  Timer? _clockTimer;
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
    // One clock for every countdown on the screen.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final t = _tournament;
      if (t != null && t.isFinished && _isReady) _leaveQueue();
    });
    _init();
  }

  @override
  void dispose() {
    _tournamentSub?.cancel();
    _participantsSub?.cancel();
    _queueSub?.cancel();
    _pairingSub?.cancel();
    _clockTimer?.cancel();
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
    _myRating = user.overallRating;

    _tournamentSub = ref
        .read(tournamentServiceProvider)
        .watchTournament(widget.tournamentId)
        .listen(_onTournamentUpdate, onError: (_) {
      if (mounted) setState(() => _notFound = true);
    });

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

    _pairingSub = ref
        .read(realtimeGameServiceProvider)
        .watchMyArenaPairing(widget.tournamentId, _myUid!)
        .listen(_onPairingUpdate);
  }

  void _onTournamentUpdate(TournamentModel t) {
    if (!mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    setState(() {
      _tournament = t;
      if (user != null) {
        _myRating = switch (GameTypeX.fromString(t.gameType)) {
          GameType.checkers => user.checkersStats.rating,
          GameType.domino => user.dominoStats.rating,
          GameType.chess => user.overallRating,
        };
      }
    });
    // Arena closed by the server — leave the queue.
    if (t.isFinished && _isReady) _leaveQueue();
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

    // No free human soon → play one of the arena's bots.
    _botFallbackTimer?.cancel();
    _botFallbackTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isReady || !mounted) { t.cancel(); return; }
      setState(() => _queueSeconds++);
      if (_queueSeconds >= _botFallbackSeconds) {
        t.cancel();
        _matchWithBot();
      }
    });
  }

  void _leaveQueue() {
    if (_myUid == null) return;
    _queueSub?.cancel();
    _botFallbackTimer?.cancel();
    if (mounted) setState(() => _isReady = false);
    ref
        .read(realtimeGameServiceProvider)
        .leaveArenaQueue(widget.tournamentId, _myUid!);
  }

  /// The arena bot closest to my rating, so the game is a fair one and the
  /// server credits that bot with the other half of the result.
  ArenaParticipant? _pickBotOpponent() {
    final bots = _participants.where((p) => p.isBot).toList();
    if (bots.isEmpty) return null;
    bots.sort((a, b) =>
        (a.rating - _myRating).abs().compareTo((b.rating - _myRating).abs()));
    // A little variety: one of the three closest.
    final pool = bots.take(3).toList()..shuffle();
    return pool.first;
  }

  void _matchWithBot() {
    if (!_isReady || !mounted) return;
    _leaveQueue();

    final t = _tournament;
    if (t == null || !t.isActive) return;

    final gt = _gameType;
    final gameId = const Uuid().v4();
    final bot = _pickBotOpponent();
    final botName = bot?.username ?? (gt.fakeBotNames.toList()..shuffle()).first;
    final botRating = bot?.rating ?? _myRating;
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
      'opponentRating': botRating,
      'botRating': botRating,
      // Checkers/domino bots take a search depth instead of a rating.
      'botDepth': (1 + (botRating - 150) ~/ 110).clamp(1, 6),
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      if (bot != null) 'arenaBotUid': bot.uid,
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
    _botFallbackTimer?.cancel();
    _queueSub?.cancel();

    // I'm the claimer → I play white.
    await _navigateToGame(gameId: gameId, isWhite: true, opponentUid: opponentUid);
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

    _botFallbackTimer?.cancel();
    _queueSub?.cancel();
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

  // ── Join / Leave / Start ───────────────────────────────────────────────────

  Future<void> _join() async {
    if (_joining) return;
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    setState(() => _joining = true);
    final rating = switch (_gameType) {
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
          SnackBar(content: Text('arena_join_failed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _leave() async {
    if (_myUid == null) return;
    if (_isReady) _leaveQueue();
    try {
      await ref
          .read(tournamentServiceProvider)
          .leaveTournament(widget.tournamentId, _myUid!);
    } catch (_) {}
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
          SnackBar(content: Text('arena_start_failed'.tr())),
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
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  }),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t == null ? 'arena'.tr() : tournamentDisplayName(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (t != null) ...[
                    const SizedBox(width: 10),
                    ArenaStatusBadge(t.effectiveStatus),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _notFound
                  ? Center(
                      child: Text('arena_not_found'.tr(),
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.inkDim)),
                    )
                  : t == null
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: AppColors.amber))
                      : _buildBody(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TournamentModel t) {
    final accent = _gameType.accent;
    final me = _participants.where((p) => p.uid == _myUid).firstOrNull;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CountdownCard(tournament: t, accent: accent),
                const SizedBox(height: 16),

                if (t.isFinished)
                  _WinnerCard(tournament: t, participants: _participants)
                else if (!_isParticipant) ...[
                  if (t.canJoin)
                    _CTAButton(
                      label: 'join_arena'.tr(),
                      icon: PhosphorIcons.trophy(PhosphorIconsStyle.bold),
                      color: accent,
                      loading: _joining,
                      onTap: _join,
                    )
                  else
                    _InfoBox(
                      icon: PhosphorIcons.usersThree(PhosphorIconsStyle.regular),
                      text: 'arena_full'.tr(),
                    ),
                  const SizedBox(height: 10),
                  _HintText(t.isActive
                      ? 'arena_join_late_hint'.tr()
                      : 'arena_how_it_works'.tr()),
                ] else if (t.isWaiting) ...[
                  _JoinedBox(
                    accent: accent,
                    text: t.startsAt != null
                        ? 'arena_starts_auto'.tr()
                        : 'arena_waiting_players'.tr(),
                  ),
                  if (_myUid == t.creatorUid) ...[
                    const SizedBox(height: 10),
                    if (t.participantCount >= 2)
                      _CTAButton(
                        label: 'start_now'.tr(),
                        icon: PhosphorIcons.lightning(PhosphorIconsStyle.bold),
                        color: accent,
                        loading: _starting,
                        onTap: _startTournament,
                      )
                    else
                      _HintText('arena_need_two'.tr()),
                  ],
                  if ((me?.gamesPlayed ?? 0) == 0)
                    Center(
                      child: TextButton(
                        onPressed: _leave,
                        child: Text(
                          'arena_leave'.tr(),
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.inkMute),
                        ),
                      ),
                    ),
                ] else if (t.isActive) ...[
                  _ReadyButton(
                    accent: accent,
                    isReady: _isReady,
                    isPairing: _isPairing,
                    queueSeconds: _queueSeconds,
                    onEnter: _enterQueue,
                    onLeave: _leaveQueue,
                  ),
                  const SizedBox(height: 10),
                  _HintText('arena_how_it_works'.tr()),
                ],

                const SizedBox(height: 24),

                // ── Standings header ───────────────────────────────────
                Row(
                  children: [
                    Text(
                      'standings'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'arena_col_wdl'.tr(),
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMute,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'arena_col_pts'.tr(),
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
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
                  accent: accent,
                  pointBased: _gameType.isPointBased,
                ),
                childCount: _participants.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'back'.tr(),
      child: GestureDetector(
        onTap: onTap,
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
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;
  const _HintText(this.text);

  @override
  Widget build(BuildContext context) {
    // Full width, so the centred text lines up with the buttons around it
    // instead of hugging the left edge of the column.
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          color: AppColors.inkMute,
          height: 1.45,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.inkDim),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkDim)),
          ),
        ],
      ),
    );
  }
}

class _JoinedBox extends StatelessWidget {
  final Color accent;
  final String text;
  const _JoinedBox({required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
              size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'arena_joined'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.inkDim,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────────

class ArenaStatusBadge extends StatelessWidget {
  final TournamentStatus status;
  const ArenaStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TournamentStatus.waiting  => ('arena_status_waiting'.tr(), AppColors.amber),
      TournamentStatus.active   => ('arena_status_live'.tr(), AppColors.live),
      TournamentStatus.finished => ('arena_status_finished'.tr(), AppColors.inkMute),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
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
                boxShadow: [BoxShadow(color: AppColors.live, blurRadius: 6)],
              ),
            ),
          ],
          Text(
            label.toUpperCaseFor(context),
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
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
  final Color accent;

  const _CountdownCard({required this.tournament, required this.accent});

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final now = DateTime.now();
    final total = Duration(minutes: t.durationMinutes);

    final String caption;
    final String value;
    double progress = 0;
    if (t.isFinished) {
      caption = 'arena_status_finished'.tr();
      value = '00:00';
    } else if (t.isActive && t.endsAt != null) {
      final left = t.endsAt!.difference(now);
      caption = 'arena_time_remaining'.tr();
      value = formatCountdown(left);
      progress = total.inSeconds > 0
          ? (left.inSeconds / total.inSeconds).clamp(0.0, 1.0)
          : 0;
    } else if (t.startsAt != null) {
      caption = 'arena_starts_in'.tr();
      final left = t.startsAt!.difference(now);
      value = left.isNegative ? '00:00' : formatCountdown(left);
    } else {
      caption = 'arena_starts_in'.tr();
      value = '—';
    }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.toUpperCaseFor(context),
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tabular digits so the countdown doesn't jitter.
                    Text(
                      value,
                      style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: t.isFinished ? AppColors.inkMute : accent,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (t.gameType == 'chess'
                            ? 'arena_time_control'.tr()
                            : 'arena_rules'.tr())
                        .toUpperCase(),
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMute,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.timeControlLabel,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'arena_duration_min'
                        .tr(namedArgs: {'minutes': '${t.durationMinutes}'}),
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
                      color: AppColors.inkMute,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                PhosphorIcons.users(PhosphorIconsStyle.regular),
                size: 13,
                color: AppColors.inkMute,
              ),
              const SizedBox(width: 5),
              Text(
                'arena_players_count'.tr(namedArgs: {
                  'count': '${t.participantCount}',
                  'max': '${t.maxPlayers}',
                }),
                style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11.5,
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

// ── Winner Card ───────────────────────────────────────────────────────────────

class _WinnerCard extends StatelessWidget {
  final TournamentModel tournament;
  final List<ArenaParticipant> participants;
  const _WinnerCard({required this.tournament, required this.participants});

  @override
  Widget build(BuildContext context) {
    final top = participants.where((p) => p.score > 0).take(3).toList();
    if (top.isEmpty) {
      return _InfoBox(
        icon: PhosphorIcons.flagCheckered(PhosphorIconsStyle.regular),
        text: 'arena_no_winner'.tr(),
      );
    }
    // Gold / silver / bronze rank discs (were 🥇🥈🥉 emoji).
    const medalColors = [Color(0xFFE8B960), Color(0xFFC0C4CC), Color(0xFFC98A5A)];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amberGlow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'arena_finished_title'.tr(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medalColors[i].withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: medalColors[i], width: 1.5),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: medalColors[i],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      top[i].username,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmtPts(top[i].score)} ${'arena_col_pts'.tr().toLowerCase()}',
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _fmtPts(double pts) =>
    pts == pts.truncateToDouble() ? pts.toInt().toString() : pts.toStringAsFixed(1);

// ── CTA Button ────────────────────────────────────────────────────────────────

class _CTAButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _CTAButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: double.infinity,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
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
                        strokeWidth: 2, color: _kDark),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: _kDark),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Ready Button ──────────────────────────────────────────────────────────────

class _ReadyButton extends StatelessWidget {
  final Color accent;
  final bool isReady;
  final bool isPairing;
  final int queueSeconds;
  final VoidCallback onEnter;
  final VoidCallback onLeave;

  const _ReadyButton({
    required this.accent,
    required this.isReady,
    required this.isPairing,
    required this.queueSeconds,
    required this.onEnter,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    if (isPairing || isReady) {
      return Semantics(
        button: true,
        label: 'cancel'.tr(),
        child: GestureDetector(
          onTap: isPairing ? null : onLeave,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPairing ? 'arena_pairing'.tr() : 'searching_opponent'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      if (!isPairing)
                        Text(
                          'arena_cancel_search'.tr(),
                          style: GoogleFonts.inter(
                              fontSize: 11.5, color: AppColors.inkMute),
                        ),
                    ],
                  ),
                ),
                Text(
                  '0:${queueSeconds.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 13, color: AppColors.inkDim),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _CTAButton(
      label: 'arena_ready_cta'.tr(),
      icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
      color: accent,
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
  final Color accent;
  final bool pointBased;

  const _ParticipantRow({
    required this.participant,
    required this.rank,
    required this.isMe,
    required this.accent,
    required this.pointBased,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1
        ? AppColors.amber
        : rank <= 3
            ? AppColors.ink
            : AppColors.inkMute;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? accent.withValues(alpha: 0.12) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isMe ? accent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rankColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          UserAvatar(username: participant.username, size: 34),
          const SizedBox(width: 10),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isMe ? accent : AppColors.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Text(
                        '· ${'arena_you'.tr()}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  pointBased
                      ? '${participant.rating} ${'points_short'.tr()}'
                      : '${participant.rating} ELO',
                  style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${participant.wins}',
                  style: const TextStyle(color: AppColors.win)),
              const TextSpan(text: ' · '),
              TextSpan(text: '${participant.draws}'),
              const TextSpan(text: ' · '),
              TextSpan(
                  text: '${participant.losses}',
                  style: const TextStyle(color: AppColors.loss)),
            ]),
            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMute,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 30,
            child: Text(
              _fmtPts(participant.score),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isMe ? accent : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
