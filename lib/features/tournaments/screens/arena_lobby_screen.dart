import 'dart:async';
import 'dart:math';
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
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart'; // currentUserProvider, firestoreServiceProvider
import '../../../core/services/bot_pool.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bot_badge.dart';
import '../../../core/utils/text_case.dart';
import 'tournament_list_screen.dart'
    show tournamentDisplayName, formatCountdown, arenaClockLabel;

const _kDark = Color(0xFF1A1205);

/// Seconds in the ready queue before the arena pairs you with one of its
/// bots. Short on purpose: with few people online, waiting long for a human
/// who never comes is why players gave up on arenas.
const _botFallbackSeconds = 10;

/// What an arena game hands back to the lobby when the player taps "Back to
/// arena": pair me again.
const kArenaContinue = 'arena-continue';

/// Leaves a finished arena game for its lobby, which pairs the player for
/// the next game straight away (as on chess.com and lichess). Used by the
/// chess, checkers and domino game screens.
void returnToArena(BuildContext context, String arenaId) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop(kArenaContinue);
  } else {
    router.go('/home/tournaments/$arenaId?play=1');
  }
}

/// The player's rating for [game] — for chess, the one of the arena's speed.
int arenaRatingFor(UserModel user, GameType game, TimeControl tc) =>
    switch (game) {
      GameType.checkers => user.checkersStats.rating,
      GameType.domino => user.dominoStats.rating,
      GameType.chess => switch (tc.category) {
          TimeControlCategory.bullet => user.bulletStats.rating,
          TimeControlCategory.blitz => user.blitzStats.rating,
          TimeControlCategory.rapid => user.rapidStats.rating,
        },
    };

class ArenaLobbyScreen extends ConsumerStatefulWidget {
  final String tournamentId;

  /// Pair the player as soon as possible (they came back from an arena game).
  final bool autoPlay;

  const ArenaLobbyScreen({
    super.key,
    required this.tournamentId,
    this.autoPlay = false,
  });

  @override
  ConsumerState<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends ConsumerState<ArenaLobbyScreen> {
  // ── Local state ────────────────────────────────────────────────────────────
  TournamentModel? _tournament;
  List<ArenaParticipant> _participants = const [];
  bool _isParticipant = false;
  bool _isReady = false; // in the RTDB ready queue
  bool _isPairing = false; // running the claim transaction
  bool _joining = false;
  bool _starting = false;
  bool _notFound = false;
  bool _inGame = false; // a game screen is open on top of the lobby

  /// Pair me whenever I am free: after Join, after each game and when the
  /// arena starts — until the player pauses (chess.com's arena flow).
  late bool _wantsToPlay = widget.autoPlay;

  // ── Player info ────────────────────────────────────────────────────────────
  String? _myUid;
  String? _myUsername;
  int _myRating = 1200;

  // ── Subscriptions / timers ─────────────────────────────────────────────────
  late final RealtimeGameService _rtdb = ref.read(realtimeGameServiceProvider);
  StreamSubscription<TournamentModel>? _tournamentSub;
  StreamSubscription<List<ArenaParticipant>>? _participantsSub;
  StreamSubscription<DatabaseEvent>? _queueSub;
  StreamSubscription<DatabaseEvent>? _pairingSub;
  Timer? _clockTimer;
  int _queueSeconds = 0;

  GameType get _gameType => GameTypeX.fromString(_tournament?.gameType);

  TimeControl get _timeControl {
    final t = _tournament;
    return TimeControl(
      minutes: (t?.timeSeconds ?? 300) ~/ 60,
      incrementSeconds: t?.incrementSeconds ?? 0,
    );
  }

  /// Per-game rule extras carried into every arena game so both clients
  /// build the identical engine configuration.
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
    // One clock for every countdown on the screen and for the bot fallback.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final t = _tournament;
      if (t != null && t.isFinished && _isReady) _leaveQueue();
      if (_isReady && !_isPairing) {
        _queueSeconds++;
        if (_queueSeconds >= _botFallbackSeconds) _matchWithBot();
      }
      setState(() {});
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
    if (_isReady && _myUid != null) {
      _rtdb.leaveArenaQueue(widget.tournamentId, _myUid!);
    }
    super.dispose();
  }

  Future<void> _init() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;

    _myUid = user.uid;
    _myUsername = user.username;
    _myRating = user.overallRating;

    final service = ref.read(tournamentServiceProvider);
    _tournamentSub = service
        .watchTournament(widget.tournamentId)
        .listen(_onTournamentUpdate, onError: (_) {
      if (mounted) setState(() => _notFound = true);
    });

    _participantsSub =
        service.watchParticipants(widget.tournamentId).listen((ps) {
      if (!mounted) return;
      setState(() {
        _participants = ps;
        _isParticipant = ps.any((p) => p.uid == _myUid);
      });
      _maybeEnterQueue();
    }, onError: (_) {});

    _pairingSub = _rtdb
        .watchMyArenaPairing(widget.tournamentId, _myUid!)
        .listen(_onPairingUpdate);
  }

  void _onTournamentUpdate(TournamentModel t) {
    if (!mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    setState(() {
      _tournament = t;
      if (user != null) {
        _myRating = arenaRatingFor(user, _gameType, _timeControl);
      }
    });
    // Closed by the server — leave the queue. Just started — pair me.
    if (t.isFinished && _isReady) _leaveQueue();
    _maybeEnterQueue();
  }

  // ── Queue management ───────────────────────────────────────────────────────

  void _maybeEnterQueue() {
    final t = _tournament;
    if (!_wantsToPlay || _isReady || _isPairing || _inGame) return;
    if (t == null || !t.isActive || !_isParticipant) return;
    _enterQueue();
  }

  void _enterQueue() {
    if (_myUid == null || _myUsername == null || _isReady) return;
    setState(() {
      _isReady = true;
      _queueSeconds = 0;
    });

    _rtdb.joinArenaQueue(
      tournamentId: widget.tournamentId,
      uid: _myUid!,
      username: _myUsername!,
      rating: _myRating,
    );

    _queueSub?.cancel();
    _queueSub =
        _rtdb.watchArenaQueue(widget.tournamentId).listen(_onQueueUpdate);
  }

  void _leaveQueue() {
    _queueSub?.cancel();
    _queueSub = null;
    if (mounted) setState(() => _isReady = false);
    if (_myUid != null) _rtdb.leaveArenaQueue(widget.tournamentId, _myUid!);
  }

  void _play() {
    setState(() => _wantsToPlay = true);
    _maybeEnterQueue();
  }

  void _pause() {
    setState(() => _wantsToPlay = false);
    _leaveQueue();
  }

  /// A free arena bot close to my rating, so the game is a fair one and the
  /// server credits that bot with the other half of the result.
  ArenaParticipant? _pickBotOpponent(TournamentModel t) {
    final bots = _participants
        .where((p) => p.isBot && !t.busyBotUids.contains(p.uid))
        .toList();
    if (bots.isEmpty) return null;
    bots.sort((a, b) =>
        (a.rating - _myRating).abs().compareTo((b.rating - _myRating).abs()));
    // A little variety: one of the three closest.
    return (bots.take(3).toList()..shuffle()).first;
  }

  Future<void> _matchWithBot() async {
    if (!_isReady || _isPairing || !mounted) return;
    final t = _tournament;
    if (t == null || !t.isActive) return;
    _leaveQueue();

    final gt = _gameType;
    final arenaBot = _pickBotOpponent(t);
    final String name;
    final int rating;
    final String? country;
    if (arenaBot != null) {
      name = arenaBot.username;
      rating = arenaBot.rating;
      country = arenaBot.countryCode;
    } else {
      final bot = await BotPool.near(gt, _myRating);
      name = bot.username;
      rating = bot.ratingFor(gt);
      country = bot.countryCode;
    }
    if (!mounted) return;

    final gameId = const Uuid().v4();
    await _openGame(gt.gameRoute(gameId), {
      'mode': GameMode.bot.name,
      'gameType': gt.name,
      'timeControl': _timeControl.toMap(),
      'playerIsWhite': Random().nextBool(),
      'isRated': false,
      'gameId': gameId,
      'opponentUsername': name,
      'opponentRating': rating,
      if (country != null) 'opponentCountryCode': country,
      'opponentIsBot': true,
      'botRating': rating,
      // Checkers/domino bots take a search depth instead of a rating.
      'botDepth': (1 + (rating - 150) ~/ 110).clamp(1, 6),
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      if (arenaBot != null) 'arenaBotUid': arenaBot.uid,
      ..._rulesExtras,
    });
  }

  void _onQueueUpdate(DatabaseEvent event) {
    if (!_isReady || _isPairing) return;
    final raw = event.snapshot.value;
    if (raw == null) return;
    final queue = Map<String, dynamic>.from(raw as Map);

    // UID-comparison convention: only the SMALLER uid initiates the claim,
    // which rules out symmetric races.
    for (final opponentUid in queue.keys) {
      if (opponentUid == _myUid) continue;
      if (_myUid!.compareTo(opponentUid) >= 0) continue; // not my turn
      _tryPair(opponentUid);
      return;
    }
  }

  Future<void> _tryPair(String opponentUid) async {
    if (!_isReady || _isPairing) return;
    final t = _tournament;
    if (t == null || !t.isActive) return;
    setState(() => _isPairing = true);

    final gameId = const Uuid().v4();
    final ok = await _rtdb.tryClaimArenaPairing(
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
    if (!ok) return; // opponent was claimed by someone else; stay in queue
    _queueSub?.cancel();

    // I'm the claimer → I play white.
    await _navigateToGame(
        gameId: gameId, isWhite: true, opponentUid: opponentUid);
  }

  void _onPairingUpdate(DatabaseEvent event) {
    // Already navigated via _tryPair — ignore this echo.
    if (!_isReady) return;
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);

    final gameId = map['gameId'] as String?;
    final isWhite = map['isWhite'] as bool? ?? false;
    final opponentUid = map['opponentUid'] as String?;
    if (gameId == null || opponentUid == null) return;

    // Clear the pairing node so it doesn't fire again.
    _rtdb.clearArenaPairing(widget.tournamentId, _myUid!);
    _queueSub?.cancel();
    setState(() => _isReady = false);
    _navigateToGame(gameId: gameId, isWhite: isWhite, opponentUid: opponentUid);
  }

  Future<void> _navigateToGame({
    required String gameId,
    required bool isWhite,
    required String opponentUid,
  }) async {
    if (_tournament == null) return;
    final gt = _gameType;
    final opponent =
        await ref.read(firestoreServiceProvider).getUser(opponentUid);
    if (!mounted) return;

    await _openGame(gt.gameRoute(gameId), {
      'mode': GameMode.online.name,
      'gameType': gt.name,
      'timeControl': _timeControl.toMap(),
      'playerIsWhite': isWhite,
      'isRated': true,
      'gameId': gameId,
      'opponentUid': opponentUid,
      'opponentUsername': opponent?.username ?? 'Opponent',
      'opponentRating': opponent == null
          ? 1200
          : arenaRatingFor(opponent, gt, _timeControl),
      if (opponent?.countryCode != null)
        'opponentCountryCode': opponent!.countryCode,
      'myUsername': _myUsername,
      'arenaId': widget.tournamentId,
      ..._rulesExtras,
    });
  }

  /// Opens a game on top of the lobby and, when the player comes back with
  /// "Back to arena", pairs them again.
  Future<void> _openGame(String route, Map<String, dynamic> extra) async {
    setState(() => _inGame = true);
    final result = await context.push<Object?>(route, extra: extra);
    if (!mounted) return;
    setState(() {
      _inGame = false;
      _wantsToPlay = result == kArenaContinue;
    });
    _maybeEnterQueue();
  }

  // ── Join / Leave / Start ───────────────────────────────────────────────────

  Future<void> _join() async {
    if (_joining) return;
    final user = await ref.read(currentUserProvider.future);
    if (user == null || !mounted) return;
    setState(() => _joining = true);
    try {
      await ref.read(tournamentServiceProvider).joinTournament(
            tournamentId: widget.tournamentId,
            uid: user.uid,
            username: user.username,
            rating: arenaRatingFor(user, _gameType, _timeControl),
            countryCode: user.countryCode,
          );
      // Joining a live arena pairs you at once; a waiting one, at its start.
      _wantsToPlay = true;
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
    _pause();
    try {
      await ref
          .read(tournamentServiceProvider)
          .leaveTournament(widget.tournamentId, _myUid!);
    } catch (_) {}
  }

  Future<void> _startNow() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await ref
          .read(tournamentServiceProvider)
          .startArenaNow(widget.tournamentId);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home/tournaments');
                    }
                  }),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t == null ? 'arena'.tr() : tournamentDisplayName(t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (t != null)
                          Text(
                            arenaClockLabel(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _gameType.accent,
                            ),
                          ),
                      ],
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
    final myIndex = _participants.indexWhere((p) => p.uid == _myUid);
    final me = myIndex >= 0 ? _participants[myIndex] : null;

    return LayoutBuilder(builder: (context, constraints) {
      // As many result boxes as fit beside the names (newest on the right).
      final chips =
          ((constraints.maxWidth - 230) / 19).floor().clamp(3, 12).toInt();
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CountdownCard(tournament: t, accent: accent),
                  const SizedBox(height: 14),
                  ..._actionArea(t, me, myIndex + 1, accent),
                  const SizedBox(height: 22),
                  _StandingsHeader(accent: accent),
                  const SizedBox(height: 8),
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
                        fontSize: 14, color: AppColors.inkMute),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _StandingsRow(
                    participant: _participants[i],
                    rank: i + 1,
                    isMe: _participants[i].uid == _myUid,
                    accent: accent,
                    pointBased: _gameType.isPointBased,
                    chips: chips,
                  ),
                  childCount: _participants.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: _HintText('arena_bots_note'.tr()),
            ),
          ),
        ],
      );
    });
  }

  /// The buttons and status between the clock and the standings.
  List<Widget> _actionArea(
      TournamentModel t, ArenaParticipant? me, int myRank, Color accent) {
    if (t.isFinished) {
      return [
        if (t.cancelled)
          _InfoBox(
            icon: PhosphorIcons.flagCheckered(PhosphorIconsStyle.regular),
            text: 'arena_cancelled'.tr(),
          )
        else
          _WinnerCard(participants: _participants),
        if (me != null && me.gamesPlayed > 0) ...[
          const SizedBox(height: 10),
          _MyStatusCard(
            me: me,
            rank: myRank,
            total: _participants.length,
            accent: accent,
            finished: true,
          ),
        ],
      ];
    }

    if (!_isParticipant) {
      return [
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
            : t.isSystem
                ? 'arena_how_it_works'.tr()
                : 'arena_user_wait_hint'.tr()),
      ];
    }

    if (t.isWaiting) {
      return [
        _JoinedBox(
          accent: accent,
          text: t.isSystem
              ? 'arena_starts_auto'.tr()
              : 'arena_user_wait_hint'.tr(),
        ),
        if (!t.isSystem && _myUid == t.creatorUid) ...[
          const SizedBox(height: 10),
          _CTAButton(
            label: 'start_now'.tr(),
            icon: PhosphorIcons.lightning(PhosphorIconsStyle.bold),
            color: accent,
            loading: _starting,
            onTap: _startNow,
          ),
        ],
        if ((me?.gamesPlayed ?? 0) == 0)
          Center(
            child: TextButton(
              onPressed: _leave,
              child: Text(
                'arena_leave'.tr(),
                style:
                    GoogleFonts.inter(fontSize: 13, color: AppColors.inkMute),
              ),
            ),
          ),
      ];
    }

    // Live and I'm in.
    return [
      if (me != null) ...[
        _MyStatusCard(
          me: me,
          rank: myRank,
          total: _participants.length,
          accent: accent,
        ),
        const SizedBox(height: 10),
      ],
      if (_isReady || _isPairing || _inGame)
        _SearchingRow(
          accent: accent,
          isPairing: _isPairing || _inGame,
          queueSeconds: _queueSeconds,
          onPause: _pause,
        )
      else
        _CTAButton(
          label: 'arena_ready_cta'.tr(),
          icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
          color: accent,
          loading: false,
          onTap: _play,
        ),
      const SizedBox(height: 10),
      _HintText('arena_how_it_works'.tr()),
    ];
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
      excludeSemantics: true,
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
      TournamentStatus.waiting => ('arena_status_waiting'.tr(), AppColors.amber),
      TournamentStatus.active => ('arena_status_live'.tr(), AppColors.live),
      TournamentStatus.finished =>
        ('arena_status_finished'.tr(), AppColors.inkMute),
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
          if (status == TournamentStatus.active)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.live, blurRadius: 6)],
              ),
            ),
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
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tabular digits so the countdown doesn't jitter.
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 34,
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
                        .toUpperCaseFor(context),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
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
                    style: GoogleFonts.inter(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 11,
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
                t.isSystem
                    ? 'arena_players_n'
                        .tr(namedArgs: {'count': '${t.participantCount}'})
                    : 'arena_players_count'.tr(namedArgs: {
                        'count': '${t.participantCount}',
                        'max': '${t.maxPlayers}',
                      }),
                style: GoogleFonts.inter(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 11.5,
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

// ── My place ─────────────────────────────────────────────────────────────────

/// "#5 · 5th of 23 · 12 pts", the streak and my latest results.
class _MyStatusCard extends StatelessWidget {
  final ArenaParticipant me;
  final int rank;
  final int total;
  final Color accent;
  final bool finished;

  const _MyStatusCard({
    required this.me,
    required this.rank,
    required this.total,
    required this.accent,
    this.finished = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$rank',
                style: GoogleFonts.inter(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (finished ? 'arena_my_final' : 'arena_my_place').tr(
                      namedArgs: {'rank': '$rank', 'count': '$total'}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.inkDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_fmtPts(me.score)} ${'points_short'.tr()}',
                style: GoogleFonts.inter(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          if (me.results.isNotEmpty || me.onFire) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _ResultChips(results: me.results, max: 12),
                  ),
                ),
                if (me.onFire && !finished) ...[
                  const SizedBox(width: 8),
                  Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill),
                      size: 14, color: AppColors.bullet),
                  const SizedBox(width: 4),
                  Text(
                    'arena_on_fire'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.bullet,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Searching ────────────────────────────────────────────────────────────────

class _SearchingRow extends StatelessWidget {
  final Color accent;
  final bool isPairing;
  final int queueSeconds;
  final VoidCallback onPause;

  const _SearchingRow({
    required this.accent,
    required this.isPairing,
    required this.queueSeconds,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
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
            child: Text(
              isPairing ? 'arena_pairing'.tr() : 'searching_opponent'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          if (!isPairing)
            Text(
              '0:${queueSeconds.clamp(0, 59).toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 13,
                color: AppColors.inkDim,
              ),
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: isPairing ? null : onPause,
            icon: Icon(PhosphorIcons.pause(PhosphorIconsStyle.fill),
                size: 14, color: AppColors.inkDim),
            label: Text(
              'arena_pause'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkDim,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standings ────────────────────────────────────────────────────────────────

class _StandingsHeader extends StatelessWidget {
  final Color accent;
  const _StandingsHeader({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          'arena_col_pts'.tr(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// One row of the table: rank, flag, name (BOT badge), rating, the points of
/// the latest games and the total — with a flame while on a winning streak.
class _StandingsRow extends StatelessWidget {
  final ArenaParticipant participant;
  final int rank;
  final bool isMe;
  final Color accent;
  final bool pointBased;
  final int chips;

  const _StandingsRow({
    required this.participant,
    required this.rank,
    required this.isMe,
    required this.accent,
    required this.pointBased,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    final p = participant;
    final rankColor = rank == 1
        ? AppColors.amber
        : rank <= 3
            ? AppColors.ink
            : AppColors.inkMute;
    final flag = UserModel.flagEmoji(p.countryCode);

    final row = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? accent.withValues(alpha: 0.12) : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isMe ? accent.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (flag.isNotEmpty) ...[
                      Text(flag, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        p.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isMe ? accent : AppColors.ink,
                        ),
                      ),
                    ),
                    if (p.isBot) ...[
                      const SizedBox(width: 5),
                      const BotBadge(),
                    ],
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
                const SizedBox(height: 1),
                Text(
                  pointBased
                      ? '${p.rating} ${'points_short'.tr()}'
                      : '${p.rating}',
                  style: GoogleFonts.inter(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 10.5,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _ResultChips(results: p.results, max: chips),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (p.onFire) ...[
                  Icon(PhosphorIcons.fire(PhosphorIconsStyle.fill),
                      size: 12, color: AppColors.bullet),
                  const SizedBox(width: 2),
                ],
                Text(
                  _fmtPts(p.score),
                  style: GoogleFonts.inter(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isMe ? accent : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // People open their profile; bots have none.
    if (p.isBot || isMe) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/home/profile/${p.uid}'),
      child: row,
    );
  }
}

/// The points of the latest games as small boxes, newest on the right:
/// green wins, orange double-point wins, grey draws, red losses.
class _ResultChips extends StatelessWidget {
  final List<String> results;
  final int max;
  const _ResultChips({required this.results, required this.max});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    final shown =
        results.length > max ? results.sublist(results.length - max) : results;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          _chip(shown[i]),
        ],
      ],
    );
  }

  Widget _chip(String code) {
    final kind = code.isEmpty ? 'l' : code[0];
    final points = code.length > 1 ? code.substring(1) : '0';
    final color = switch (kind) {
      'w' when points == '4' => AppColors.bullet,
      'w' => AppColors.win,
      'd' => AppColors.draw,
      _ => AppColors.loss,
    };
    return Container(
      width: 16,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: kind == 'l' ? 0.12 : 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        points,
        style: GoogleFonts.inter(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Winner Card ───────────────────────────────────────────────────────────────

class _WinnerCard extends StatelessWidget {
  final List<ArenaParticipant> participants;
  const _WinnerCard({required this.participants});

  @override
  Widget build(BuildContext context) {
    final top = participants.where((p) => p.score > 0).take(3).toList();
    if (top.isEmpty) {
      return _InfoBox(
        icon: PhosphorIcons.flagCheckered(PhosphorIconsStyle.regular),
        text: 'arena_no_winner'.tr(),
      );
    }
    const medalColors = [
      Color(0xFFE8B960),
      Color(0xFFC0C4CC),
      Color(0xFFC98A5A),
    ];
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
                  Flexible(
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
                  if (top[i].isBot) ...[
                    const SizedBox(width: 6),
                    const BotBadge(),
                  ],
                  const Spacer(),
                  Text(
                    '${_fmtPts(top[i].score)} ${'points_short'.tr()}',
                    style: GoogleFonts.inter(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 12,
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

String _fmtPts(double pts) => pts == pts.truncateToDouble()
    ? pts.toInt().toString()
    : pts.toStringAsFixed(1);

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
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: _kDark),
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
