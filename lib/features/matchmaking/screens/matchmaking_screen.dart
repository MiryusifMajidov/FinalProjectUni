import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_game_service.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = AppColors.background;
const _kCard      = AppColors.card;
const _kCardElev  = AppColors.cardElevated;
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorder    = AppColors.border;

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

// Fake usernames are now per-game via GameTypeX.fakeBotNames

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen> {
  TimeControl _timeControl = TimeControls.blitz5;
  bool _searching = false;
  int _searchSeconds = 0;

  Timer? _clockTimer;
  StreamSubscription? _queueSub;
  StreamSubscription? _myEntrySub;
  bool _matched = false;
  bool _matchFound = false;   // brief "Opponent found!" banner state
  String _matchFoundName = '';

  String? _uid;
  int _myRating = 1200;
  late GameType _gameType;

  // Per-game matchmaking options
  String _checkersVariant = 'standard';   // checkers variant key
  String _dominoPlayerCount = '2-player'; // domino player count key
  String _dominoVariant = 'draw';         // domino ruleset key

  bool _claiming4P = false; // 4P domino host claim in progress

  RealtimeGameService? _cachedService;
  Map<String, dynamic>? _lastQueueSnapshot;

  bool get _isDomino4P =>
      _gameType == GameType.domino && _dominoPlayerCount == '4-player';

  /// Queue label used for filtering — different per game type.
  /// Players only match when every rule option is identical.
  String get _queueLabel => switch (_gameType) {
    GameType.chess    => _timeControl.label,
    GameType.checkers => _checkersVariant,
    GameType.domino   => '$_dominoVariant|$_dominoPlayerCount',
  };

  @override
  void initState() {
    super.initState();
    _gameType = ref.read(activeGameProvider);
  }

  @override
  void dispose() {
    _stopSearch(removeFromQueue: true);
    super.dispose();
  }

  // ── Search lifecycle ──────────────────────────────────────────────────────

  Future<void> _startSearch() async {
    if (_searching) return; // re-entry guard: prevents double-tap from starting two searches
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;

    _uid = user.uid;
    _matched = false;
    _claiming4P = false;

    _myRating = switch (_gameType) {
      GameType.checkers => user.checkersStats.rating,
      GameType.domino   => user.dominoStats.rating,
      GameType.chess    => switch (_timeControl.category) {
        TimeControlCategory.bullet => user.bulletStats.rating,
        TimeControlCategory.blitz  => user.blitzStats.rating,
        TimeControlCategory.rapid  => user.rapidStats.rating,
      },
    };

    final service = ref.read(realtimeGameServiceProvider);
    _cachedService = service;
    await service.joinQueue(user.uid, _myRating, _queueLabel,
        gameType: _gameType.name, username: user.username);

    setState(() {
      _searching = true;
      _searchSeconds = 0;
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _searchSeconds++);
      if (_searchSeconds % 2 == 0) {
        final snapshot = _lastQueueSnapshot;
        if (snapshot != null) _tryMatch(snapshot);
      }
      if (_isDomino4P) {
        // 4P domino: at the 30 s deadline the host starts the table with
        // however many real players showed up — empty seats get AI
        // stand-ins disguised as players. If nobody claimed us by 40 s
        // (e.g. a stale host entry), fall back to a solo disguised table.
        if (_searchSeconds == 30 && !_matched) {
          _try4PHostClaim(force: true);
        }
        if (_searchSeconds == 40 && !_matched) {
          _matchWithBot();
        }
      } else {
        // After 30 s with no real match, silently pair with a bot
        if (_searchSeconds == 30 && !_matched) {
          _matchWithBot();
        }
      }
    });

    _queueSub = service.watchQueue(_queueLabel).listen(_onQueueSnapshot);
    _myEntrySub = service.watchQueueEntry(user.uid).listen(_onMyEntryUpdated);
  }

  Future<void> _onQueueSnapshot(dynamic event) async {
    if (!_searching || _matched) return;
    final snapshot = (event as dynamic).snapshot;
    final raw = snapshot.value;
    if (raw == null) return;
    final queue = Map<String, dynamic>.from(raw as Map);
    _lastQueueSnapshot = queue;
    await _tryMatch(queue);
  }

  Future<void> _tryMatch(Map<String, dynamic> queue) async {
    if (!_searching || _matched) return;
    final myEntry = queue[_uid];
    if (myEntry == null) return;

    final existingGameId = myEntry['gameId'];
    if (existingGameId != null) {
      final entryData = Map<String, dynamic>.from(myEntry as Map);
      _handleMatched(
        existingGameId as String,
        entryData['isWhite'] as bool? ?? true,
        opponentUid: entryData['opponentUid'] as String?,
        seat: (entryData['seat'] as num?)?.toInt(),
      );
      return;
    }

    // 4-player domino uses a host-claims-table flow instead of pairing.
    if (_isDomino4P) {
      await _try4PHostClaim(force: false);
      return;
    }

    final eloRange = _currentEloRange;
    for (final entry in queue.entries) {
      if (_matched) return;
      if (entry.key == _uid) continue;
      final oppData = Map<String, dynamic>.from(entry.value as Map);
      if (oppData['gameId'] != null) continue;
      if (oppData['timeControl'] != _queueLabel) continue;
      // Only match with players searching for the same game type
      final oppGameType = oppData['gameType'] as String? ?? 'chess';
      if (oppGameType != _gameType.name) continue;
      final oppRating = (oppData['rating'] as num).toInt();
      // For non-chess games, skip ELO range filter — match anyone available
      if (_gameType == GameType.chess && (_myRating - oppRating).abs() > eloRange) continue;

      final gameId = const Uuid().v4();
      final service = _cachedService;
      if (service == null) return;
      final claimed = await service.tryClaimMatch(
        myUid: _uid!,
        opponentUid: entry.key,
        gameId: gameId,
        timeControlLabel: _timeControl.label,
      );

      if (claimed) {
        _handleMatched(gameId, true, opponentUid: entry.key, opponentRating: oppRating);
        return;
      }
    }
  }

  void _onMyEntryUpdated(dynamic event) {
    if (!_searching || _matched) return;
    final snapshot = (event as dynamic).snapshot;
    final raw = snapshot.value;
    if (raw == null) return;
    final data = Map<String, dynamic>.from(raw as Map);
    final gameId = data['gameId'];
    if (gameId != null) {
      final isWhite = data['isWhite'] as bool? ?? false;
      _handleMatched(
        gameId as String, isWhite,
        opponentUid: data['opponentUid'] as String?,
        seat: (data['seat'] as num?)?.toInt(),
      );
    }
  }

  int get _currentEloRange {
    if (_searchSeconds < 5) return 200;
    if (_searchSeconds < 10) return 400;
    if (_searchSeconds < 20) return 800;
    return 9999;
  }

  void _handleMatched(String gameId, bool isWhite, {
    String? opponentUid, int? opponentRating, int? seat,
  }) {
    if (_matched) return;
    _matched = true;
    _stopSearch(removeFromQueue: false);
    if (!mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    context.pushReplacement(_gameType.gameRoute(gameId), extra: {
      'mode': GameMode.online.name,
      'gameType': _gameType.name,
      'timeControl': _timeControl.toMap(),
      'playerIsWhite': isWhite,
      'isRated': true,
      'gameId': gameId,
      'myUsername': user?.username ?? 'You',
      'opponentUsername': 'Opponent',
      if (opponentUid != null) 'opponentUid': opponentUid,
      if (opponentRating != null) 'opponentRating': opponentRating,
      if (seat != null) 'seat': seat,
      if (_gameType == GameType.checkers) 'checkersVariant': _checkersVariant,
      if (_gameType == GameType.domino) ...{
        'dominoPlayerCount': _dominoPlayerCount,
        'dominoVariant': _dominoVariant,
        'dominoTarget': 100,
      },
    });
  }

  // ── 4-player domino: host claims the table ─────────────────────────────────
  //
  // The lowest-uid waiting player acts as host. They wait until either four
  // compatible players are queued, or the 30 s deadline passes — then they
  // atomically claim up to three opponents, write the room (seat list +
  // config) and fill the remaining seats with disguised AI stand-ins.
  Future<void> _try4PHostClaim({required bool force}) async {
    if (!_searching || _matched || _claiming4P) return;
    final queue = _lastQueueSnapshot;
    final myUid = _uid;
    if (queue == null || myUid == null) return;

    // Compatible waiting entries (same label + game type, unclaimed).
    final waiting = <String, Map<String, dynamic>>{};
    for (final entry in queue.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      if (data['gameId'] != null) continue;
      if (data['timeControl'] != _queueLabel) continue;
      if ((data['gameType'] as String? ?? 'chess') != _gameType.name) continue;
      waiting[entry.key] = data;
    }
    if (!waiting.containsKey(myUid)) return;

    // Host convention: only the smallest uid claims (avoids races).
    final hostUid = waiting.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    if (hostUid != myUid) return;
    if (!force && waiting.length < 4) return;

    _claiming4P = true;
    final service = _cachedService;
    if (service == null) {
      _claiming4P = false;
      return;
    }

    try {
      final gameId = const Uuid().v4();
      final user = ref.read(currentUserProvider).valueOrNull;
      final myName = user?.username ?? 'You';

      // Claim up to three opponents, oldest joiners first.
      final targets = waiting.entries.where((e) => e.key != myUid).toList()
        ..sort((a, b) => ((a.value['joinedAt'] as num?) ?? 0)
            .compareTo((b.value['joinedAt'] as num?) ?? 0));

      final claimed = <(String uid, String name)>[];
      for (final t in targets) {
        if (claimed.length >= 3) break;
        final data = await service.tryClaimSeat(
          myUid: myUid,
          opponentUid: t.key,
          gameId: gameId,
          seat: claimed.length + 1,
        );
        if (data != null) {
          claimed.add((t.key, data['username'] as String? ?? 'Player'));
        }
      }

      if (claimed.isEmpty && !force) {
        _claiming4P = false;
        return; // everyone got claimed elsewhere — keep waiting
      }

      // Fill the empty seats with AI stand-ins disguised as players.
      final botNames = ([...GameType.domino.fakeBotNames]..shuffle())
          .take(3 - claimed.length)
          .toList();

      final seats = <String, Map<String, dynamic>>{
        '0': {'uid': myUid, 'name': myName, 'bot': false},
      };
      for (int i = 0; i < claimed.length; i++) {
        seats['${i + 1}'] = {
          'uid': claimed[i].$1,
          'name': claimed[i].$2,
          'bot': false,
        };
      }
      for (int i = 0; i < botNames.length; i++) {
        seats['${claimed.length + 1 + i}'] = {
          'uid': null,
          'name': botNames[i],
          'bot': true,
        };
      }

      await service.createGameRoom(gameId, {
        'gameType': 'domino',
        'status': 'active',
        'config': {
          'playerCount': 4,
          'variant': _dominoVariant,
          'targetScore': 100,
          // Classic table dominoes: 4 players always play in partnerships —
          // seats 0&2 vs 1&3 (you partner the player across the table).
          'teams': true,
        },
        'seats': seats,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await service.stampOwnQueueEntry(myUid, gameId, 0);

      _handleMatched(gameId, true, seat: 0);
    } catch (e) {
      debugPrint('[Matchmaking] 4P claim failed: $e');
      _claiming4P = false;
    }
  }

  // ── Bot fallback after 30 s ───────────────────────────────────────────────

  void _matchWithBot() {
    if (_matched) return;
    _matched = true;
    _stopSearch(removeFromQueue: true);
    if (!mounted) return;

    final rng   = math.Random();
    final names  = _gameType.fakeBotNames;
    final fakeName   = names[rng.nextInt(names.length)];
    // Score within ±50 of the user — indistinguishable from a real opponent
    final clampLo = _gameType.isPointBased ? 100 : 400;
    final clampHi = _gameType.isPointBased ? 2000 : 3000;
    final fakeRating = (_myRating + rng.nextInt(101) - 50).clamp(clampLo, clampHi);
    final gameId     = const Uuid().v4();
    final isWhite    = rng.nextBool();
    final user       = ref.read(currentUserProvider).valueOrNull;

    // Brief "Opponent found!" flash before navigating
    setState(() {
      _matchFound     = true;
      _matchFoundName = fakeName;
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      context.pushReplacement(_gameType.gameRoute(gameId), extra: {
        'mode'             : GameMode.bot.name,
        'gameType'         : _gameType.name,
        'timeControl'      : _timeControl.toMap(),
        'playerIsWhite'    : isWhite,
        'isRated'          : true,           // rated → real score change applies
        'gameId'           : gameId,
        'myUsername'       : user?.username ?? 'You',
        'opponentUsername' : fakeName,
        'botRating'        : fakeRating,
        'opponentRating'   : fakeRating,     // used by _processRatingChange
        'isFakeBotFallback': true,           // hides "Bot" label, shows fake name
        if (_gameType == GameType.checkers) 'checkersVariant': _checkersVariant,
        if (_gameType == GameType.domino) ...{
          'dominoPlayerCount': _dominoPlayerCount,
          'dominoVariant': _dominoVariant,
          'dominoTarget': 100,
          'dominoTeams': false,
        },
      });
    });
  }

  void _cancelSearch() => _stopSearch(removeFromQueue: true);

  void _stopSearch({required bool removeFromQueue}) {
    _clockTimer?.cancel(); _clockTimer = null;
    _queueSub?.cancel(); _queueSub = null;
    _myEntrySub?.cancel(); _myEntrySub = null;
    _lastQueueSnapshot = null;
    if (removeFromQueue && _uid != null) {
      _cachedService?.leaveQueue(_uid!);
    }
    _cachedService = null;
    if (mounted) setState(() => _searching = false);
  }

  String get _waitLabel {
    if (_gameType.isPointBased) {
      // Non-chess: simple search, no ELO range expansion
      if (_searchSeconds < 30) return 'Searching for opponent…';
      return 'Matching…';
    }
    if (_searchSeconds < 5)  return 'Searching ±200 ELO…';
    if (_searchSeconds < 10) return 'Expanding to ±400 ELO…';
    if (_searchSeconds < 20) return 'Expanding to ±800 ELO…';
    if (_searchSeconds < 30) return 'Searching any rating…';
    return 'Matching…';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                            color: _kInkDim, size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'find_opponent'.tr(),
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: _kInk,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ──────────────────────────────────────────────────
                Expanded(
                  child: _searching
                      ? _SearchingView(
                          seconds: _searchSeconds,
                          label: _waitLabel,
                          myRating: _myRating,
                          queueLabel: _queueLabel,
                          eloRange: _currentEloRange,
                          queueCount: _lastQueueSnapshot?.length ?? 0,
                          onCancel: _cancelSearch,
                          gameType: _gameType,
                        )
                      : _SetupView(
                          timeControl: _timeControl,
                          onTimeSelect: (tc) => setState(() => _timeControl = tc),
                          checkersVariant: _checkersVariant,
                          onCheckersVariantSelect: (v) => setState(() => _checkersVariant = v),
                          dominoPlayerCount: _dominoPlayerCount,
                          onDominoPlayerCountSelect: (v) => setState(() => _dominoPlayerCount = v),
                          dominoVariant: _dominoVariant,
                          onDominoVariantSelect: (v) => setState(() => _dominoVariant = v),
                          onSearch: _startSearch,
                          myRating: _myRating,
                          gameType: _gameType,
                        ),
                ),
              ],
            ),
          ),

          // ── "Opponent found!" overlay ────────────────────────────────────
          if (_matchFound)
            _MatchFoundOverlay(opponentName: _matchFoundName, gameType: _gameType),
        ],
      ),
    );
  }
}

// ── Setup View ────────────────────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  final TimeControl timeControl;
  final void Function(TimeControl) onTimeSelect;
  final String checkersVariant;
  final void Function(String) onCheckersVariantSelect;
  final String dominoPlayerCount;
  final void Function(String) onDominoPlayerCountSelect;
  final String dominoVariant;
  final void Function(String) onDominoVariantSelect;
  final VoidCallback onSearch;
  final int myRating;
  final GameType gameType;

  const _SetupView({
    required this.timeControl,
    required this.onTimeSelect,
    required this.checkersVariant,
    required this.onCheckersVariantSelect,
    required this.dominoPlayerCount,
    required this.onDominoPlayerCountSelect,
    required this.dominoVariant,
    required this.onDominoVariantSelect,
    required this.onSearch,
    required this.myRating,
    required this.gameType,
  });

  @override
  Widget build(BuildContext context) {
    final accent = gameType.accent;
    final accentDeep = Color.lerp(accent, Colors.black, 0.25)!;
    final scoreLabel = gameType.scoreLabel.toUpperCase();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero card (per-game aware) ─────────────────────────────
                _HeroCard(myRating: myRating, gameType: gameType),

                const SizedBox(height: 24),

                // ── Per-game option selection ──────────────────────────────
                if (gameType == GameType.chess) ...[
                  Text(
                    'TIME CONTROL',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kInkMute,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TimeSection(
                    icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                    iconColor: const Color(0xFFFF6B6B),
                    label: 'bullet'.tr(),
                    controls: TimeControls.allBullet,
                    selected: timeControl,
                    onSelect: onTimeSelect,
                  ),
                  const SizedBox(height: 14),
                  _TimeSection(
                    icon: PhosphorIcons.flame(PhosphorIconsStyle.fill),
                    iconColor: const Color(0xFFFF9F43),
                    label: 'blitz'.tr(),
                    controls: TimeControls.allBlitz,
                    selected: timeControl,
                    onSelect: onTimeSelect,
                  ),
                  const SizedBox(height: 14),
                  _TimeSection(
                    icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
                    iconColor: const Color(0xFF54A0FF),
                    label: 'rapid'.tr(),
                    controls: TimeControls.allRapid,
                    selected: timeControl,
                    onSelect: onTimeSelect,
                  ),
                ] else if (gameType == GameType.checkers) ...[
                  Text(
                    'GAME VARIANT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kInkMute,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OptionChips(
                    options: GameTypeX.checkersVariants,
                    selected: checkersVariant,
                    accent: accent,
                    onSelect: onCheckersVariantSelect,
                  ),
                ] else if (gameType == GameType.domino) ...[
                  Text(
                    'PLAYER COUNT',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kInkMute,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OptionChips(
                    options: GameTypeX.dominoPlayerCounts,
                    selected: dominoPlayerCount,
                    accent: accent,
                    onSelect: onDominoPlayerCountSelect,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'RULESET',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kInkMute,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OptionChips(
                    options: GameTypeX.dominoVariants,
                    selected: dominoVariant,
                    accent: accent,
                    onSelect: onDominoVariantSelect,
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Sticky bottom CTA ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: _kBg,
            border: Border(top: BorderSide(color: _kBorder.withOpacity(0.5))),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: onSearch,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accentDeep],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.sword(PhosphorIconsStyle.fill),
                          size: 18,
                          color: const Color(0xFF1A1205),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'find_opponent'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1205),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                gameType.isPointBased
                    ? '$scoreLabel will change after the game'
                    : 'Rating will change after the game',
                style: GoogleFonts.inter(fontSize: 12, color: _kInkMute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Option Chips (for checkers variants / domino player count) ───────────────

class _OptionChips extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Color accent;
  final void Function(String) onSelect;

  const _OptionChips({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSel = opt.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSel ? accent.withOpacity(0.15) : _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? accent : _kBorder,
                width: isSel ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.$2,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                color: isSel ? accent : _kInkDim,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final int myRating;
  final GameType gameType;
  const _HeroCard({required this.myRating, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final accent = gameType.accent;
    final isPoints = gameType.isPointBased;
    final glowColor = accent.withOpacity(0.08);
    final scoreName = gameType.scoreLabel;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCardElev, _kCard],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Accent glow top-right
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: glowColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: glowColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'RATED · ONLINE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kInkMute,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Heading
                  Text(
                    'Find a match',
                    style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: _kInk,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtitle — per game
                  Text(
                    isPoints
                        ? "We'll pair you with an available opponent.\n$scoreName change after the game."
                        : "We'll pair you with an opponent near your ELO.\nRating changes after the game.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _kInkMute,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Score row
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPoints ? 'YOUR POINTS' : 'YOUR ELO',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _kInkMute,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$myRating',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!isPoints)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withOpacity(0.4)),
                          ),
                          child: Text(
                            '±200',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0, duration: 250.ms);
  }
}

// ── Time section ──────────────────────────────────────────────────────────────

class _TimeSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header row
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: iconColor,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor.withOpacity(0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        // Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controls.map((tc) {
            final isSel = tc == selected;
            return GestureDetector(
              onTap: () => onSelect(tc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel ? iconColor.withOpacity(0.15) : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? iconColor : _kBorder,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tc.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                    color: isSel ? iconColor : _kInkDim,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Searching View ────────────────────────────────────────────────────────────

class _SearchingView extends StatelessWidget {
  final int seconds;
  final String label;
  final int myRating;
  final String queueLabel;
  final int eloRange;
  final int queueCount;
  final VoidCallback onCancel;
  final GameType gameType;

  const _SearchingView({
    required this.seconds,
    required this.label,
    required this.myRating,
    required this.queueLabel,
    required this.eloRange,
    required this.queueCount,
    required this.onCancel,
    required this.gameType,
  });

  /// Rough avg-wait estimate based on queue depth.
  String get _avgWait {
    if (queueCount > 100) return '~5s';
    if (queueCount > 40)  return '~10s';
    if (queueCount > 10)  return '~20s';
    return '~40s';
  }

  String get _statusPillLabel {
    if (gameType.isPointBased) {
      return '${queueLabel.toUpperCase()} · RATED';
    }
    final rangeStr = eloRange >= 9999 ? 'ELO ANY' : 'ELO ${myRating - eloRange} – ${myRating + eloRange}';
    return '$rangeStr · ${queueLabel.toUpperCase()} · RATED';
  }

  @override
  Widget build(BuildContext context) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final accent = gameType.accent;
    final isPoints = gameType.isPointBased;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic status label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _kInkMute,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 20),

          // ── Pulsing orb ─────────────────────────────────────────────────
          _PulsingOrb(accent: accent, emoji: gameType.searchEmoji),

          const SizedBox(height: 28),

          // Large timer
          Text(
            timeStr,
            style: GoogleFonts.fraunces(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: accent,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 14),

          // Status pill
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_statusPillLabel),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                _statusPillLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _kInkDim,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatItem(
                label: isPoints ? 'Your Points' : 'Your ELO',
                value: '$myRating',
                valueColor: accent,
              ),
              _StatDivider(),
              _StatItem(label: 'In queue',  value: queueCount > 0 ? '$queueCount' : '—', valueColor: _kInk),
              _StatDivider(),
              _StatItem(label: 'Avg wait',  value: queueCount > 0 ? _avgWait : '—',     valueColor: _kInk),
            ],
          ),

          const SizedBox(height: 48),

          // Cancel button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                child: Center(
                  child: Text(
                    'cancel'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kInkDim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _kInkMute,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: _kBorder,
    );
  }
}

// ── Match-found overlay ───────────────────────────────────────────────────────
// Shown for ~1.8 s after the bot fallback kicks in to simulate a real match.

class _MatchFoundOverlay extends StatelessWidget {
  final String opponentName;
  final GameType gameType;
  const _MatchFoundOverlay({required this.opponentName, required this.gameType});

  @override
  Widget build(BuildContext context) {
    final accent = gameType.accent;
    final accentDeep = Color.lerp(accent, Colors.black, 0.25)!;
    return Container(
      color: _kBg.withOpacity(0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing accent circle
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accentDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.45),
                    blurRadius: 32,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(gameType.searchEmoji, style: const TextStyle(fontSize: 42)),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 700.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 28),

            Text(
              'Opponent found!',
              style: GoogleFonts.fraunces(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: _kInk,
                letterSpacing: -0.5,
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.1, end: 0, duration: 300.ms),

            const SizedBox(height: 10),

            Text(
              opponentName,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: accent,
                letterSpacing: 0.5,
              ),
            )
                .animate(delay: 150.ms)
                .fadeIn(duration: 250.ms),

            const SizedBox(height: 8),

            Text(
              'Get ready…',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _kInkMute,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 250.ms),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing orb (game-aware) ────────────────────────────────────────────────

class _PulsingOrb extends StatelessWidget {
  final Color accent;
  final String emoji;
  const _PulsingOrb({required this.accent, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final accentDeep = Color.lerp(accent, Colors.black, 0.25)!;
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.15), width: 1.5),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.1, 1.1), duration: 1400.ms, curve: Curves.easeInOut)
              .then()
              .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.85, 0.85), duration: 1400.ms),
          Container(
            width: 116, height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.08, 1.08), duration: 1100.ms, curve: Curves.easeInOut)
              .then()
              .scale(begin: const Offset(1.08, 1.08), end: const Offset(0.9, 0.9), duration: 1100.ms),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [accent, accentDeep],
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 6))],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 36))),
          ),
        ],
      ),
    );
  }
}
