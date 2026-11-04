import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/utils/text_case.dart';
import '../../game/widgets/game_chat_panel.dart';
import '../../game/widgets/game_chrome.dart';
import '../engine/domino_engine.dart';
import '../widgets/domino_tile_widget.dart';

/// Domino game screen — supports bot, local, online (2P & 4P) and campaign
/// modes. Match play: rounds are dealt automatically until one side reaches
/// the target score.
class DominoGameScreen extends ConsumerStatefulWidget {
  final String? gameId;
  final Map<String, dynamic> extra;

  const DominoGameScreen({
    super.key,
    this.gameId,
    this.extra = const {},
  });

  @override
  ConsumerState<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends ConsumerState<DominoGameScreen> {
  static const _accent = Color(0xFF5FD4A3);
  static const int _turnTimeLimit = 30; // seconds per move (online)
  static const int _abandonGraceSeconds = 30;

  DominoEngine? _engine;
  DominoTile? _selectedTile;
  DominoTile? _draggingTile;
  bool _thinking = false;

  /// The end the Hint button suggested for [_selectedTile]; only that end
  /// glows until the tile is played or another one is picked.
  DominoEnd? _hintEnd;
  bool _hinting = false;

  /// The boneyard slot the player just tapped, shown face up for a moment
  /// with the tile that came out of it before it goes into the hand.
  int? _revealSlot;
  DominoTile? _revealTile;
  bool _gameSaved = false;
  bool _resultShown = false;
  bool _roomLoading = false;
  String? _roomError;

  // ── Resolved config from extra map ──────────────────────────────────────
  late final bool _vsBot;
  late final String _mode;
  late final bool _playerIsWhite;
  late final String _myUsername;
  late final String _opponentUsername;
  late final bool _isRated;
  late final bool _isFakeBotFallback;
  late String _gameId;
  late int _playerCount;
  late DominoConfig _config;
  late final String? _arenaId;
  late final String? _arenaBotUid;
  late final int? _campaignChapter;

  int _mySeat = 0;
  List<String> _seatNames = [];
  Set<int> _botSeats = {};       // AI-controlled from the start
  Set<int> _resignedSeats = {};  // humans replaced by stand-ins mid-game

  // ── Friends-table waiting room (room status == 'waiting') ────────────────
  bool _roomWaiting = false;
  String? _hostUid;
  Map<String, Map<String, dynamic>> _rawSeats = {};
  StreamSubscription<DatabaseEvent>? _infoSub;
  bool _presenceSubscribed = false;
  bool _starting = false;

  bool get _isTableHost => _hostUid != null && _hostUid == _myUid;

  // ── Online sync (ordered action log) ─────────────────────────────────────
  late final bool _isOnline;
  String? _myUid;
  String? _opponentUid;
  final Map<int, String?> _seatUids = {};
  StreamSubscription<DatabaseEvent>? _actionSub;
  StreamSubscription<DatabaseEvent>? _gameOverSub;
  StreamSubscription<DatabaseEvent>? _resignedSub;
  final List<StreamSubscription<DatabaseEvent>> _presenceSubs = [];
  int _appliedActions = 0;
  final Map<int, Map<String, dynamic>> _pendingActions = {};
  DateTime _lastActionAt = DateTime.now();
  int _botWriteForIndex = -1;

  // ── Online timers / presence ─────────────────────────────────────────────
  Timer? _turnTimer;
  int _turnSecondsLeft = _turnTimeLimit;
  final Map<int, bool> _seatOnline = {};
  final Map<int, DateTime> _seatOfflineSince = {};
  Timer? _abandonTimer; // 2P only
  bool _opponentSeenOnline = false;

  // ── Round flow ───────────────────────────────────────────────────────────
  int _lastShownRound = 0;
  bool _roundSheetOpen = false;

  /// Match outcome (entity index). Mirrors engine.matchWinner but can also be
  /// forced by resign / abandonment in 2-player games.
  int? _finalWinnerEntity;

  bool get _isLocalGame => !_vsBot && !_isOnline;

  /// A stand-in bot game that is shown as an online one (matchmaking found
  /// nobody): no hints there, exactly like online.
  bool get _looksOnline => _isOnline || _isFakeBotFallback;

  int get _myEntity => _engine?.entityOf(_mySeat) ?? 0;

  bool get _isHumanTurn {
    final e = _engine;
    if (e == null) return false;
    if (_isLocalGame) return true;
    return e.turnSeat == _mySeat;
  }

  /// In local pass-and-play the visible hand belongs to whoever's turn it is.
  int get _handSeat => _isLocalGame ? (_engine?.turnSeat ?? 0) : _mySeat;

  /// Deterministic seed from the gameId so all online clients deal identical
  /// hands/boneyard for every round, then only sync actions on top.
  int _seedFromGameId(String id) {
    int h = 0;
    for (final u in id.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    return h;
  }

  @override
  void initState() {
    super.initState();

    final e = widget.extra;
    _mode = e['mode'] as String? ?? 'bot';
    _vsBot = _mode == 'bot' || _mode == 'campaign';
    _isOnline = _mode == 'online';
    _playerIsWhite = e['playerIsWhite'] as bool? ?? true;
    _myUsername = e['myUsername'] as String? ?? 'you'.tr();
    _opponentUsername = e['opponentUsername'] as String? ??
        (_vsBot ? 'bot'.tr() : 'player_n'.tr(args: ['2']));
    _isRated = e['isRated'] as bool? ?? false;
    _isFakeBotFallback = e['isFakeBotFallback'] as bool? ?? false;
    _arenaId = e['arenaId'] as String?;
    _arenaBotUid = e['arenaBotUid'] as String?;
    _campaignChapter = e['campaignChapter'] as int?;
    _gameId = widget.gameId ?? e['gameId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();

    final pcKey = e['dominoPlayerCount'] as String? ?? '2-player';
    _playerCount = pcKey == '4-player' ? 4 : 2;
    final variantKey = e['dominoVariant'] as String? ?? 'draw';
    final variant =
        variantKey == 'block' ? DominoVariant.block : DominoVariant.draw;
    final target = (e['dominoTarget'] as num?)?.toInt() ?? 100;
    final teams = (e['dominoTeams'] as bool? ?? false) && _playerCount == 4;

    if (_isOnline) {
      _myUid = ref.read(authStateProvider).valueOrNull?.uid;
      _opponentUid = e['opponentUid'] as String?;

      if (_playerCount == 4) {
        // Multi-seat room: seat assignments + config come from RTDB.
        _mySeat = (e['seat'] as num?)?.toInt() ?? 0;
        _roomLoading = true;
        _loadRoom();
      } else {
        _mySeat = _playerIsWhite ? 0 : 1;
        _config = DominoConfig(
          playerCount: 2,
          variant: variant,
          targetScore: target,
        );
        _seatNames = _mySeat == 0
            ? [_myUsername, _opponentUsername]
            : [_opponentUsername, _myUsername];
        _seatUids[_mySeat] = _myUid;
        _seatUids[1 - _mySeat] = _opponentUid;
        _startEngineAndSync();
      }
    } else {
      _mySeat = 0;
      _config = DominoConfig(
        playerCount: _playerCount,
        variant: variant,
        targetScore: target,
        teams: teams,
      );
      _botSeats = _vsBot
          ? {for (int i = 1; i < _playerCount; i++) i}
          : {};
      // Seat names for offline play.
      if (_playerCount == 4) {
        final pool = [...GameType.domino.fakeBotNames]..shuffle();
        final botNames = pool.take(3).toList();
        _seatNames = [
          _myUsername,
          for (int i = 0; i < 3; i++)
            _isFakeBotFallback
                ? botNames[i]
                : (_vsBot
                    ? 'bot_n'.tr(args: ['${i + 1}'])
                    : 'player_n'.tr(args: ['${i + 2}'])),
        ];
      } else {
        // Local pass-and-play carries the entered names in the extras.
        _seatNames = [_myUsername, _opponentUsername];
      }
      _engine = DominoEngine(config: _config);
      _afterStateAdvance();
    }
  }

  // ── 4-player online room ──────────────────────────────────────────────────

  Future<void> _loadRoom() async {
    final rtdb = ref.read(realtimeGameServiceProvider);
    Map<String, dynamic>? info;
    for (int attempt = 0; attempt < 20; attempt++) {
      info = await rtdb.getGameInfo(_gameId);
      if (info != null && info['seats'] != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
    if (!mounted) return;
    if (info == null || info['seats'] == null) {
      setState(() {
        _roomLoading = false;
        _roomError = 'room_load_failed'.tr();
      });
      return;
    }

    _applyRoomInfo(info);
    final status = info['status'] as String? ?? 'active';

    if (status == 'active') {
      setState(() => _roomLoading = false);
      _startEngineAndSync();
      return;
    }

    // Friends table still gathering — this screen acts as the waiting room.
    setState(() {
      _roomLoading = false;
      _roomWaiting = true;
    });
    if (_myUid != null) rtdb.goOnline(_gameId, _myUid!);
    _subscribePresence();
    _infoSub = rtdb.watchGameInfo(_gameId).listen(_onRoomInfo);
  }

  /// Parses config + seats (RTDB may deliver dense integer keys as a List).
  void _applyRoomInfo(Map<String, dynamic> info) {
    final rawConfig = info['config'];
    final cfg = rawConfig is Map
        ? Map<String, dynamic>.from(rawConfig)
        : <String, dynamic>{};
    final variantKey = cfg['variant'] as String? ?? 'draw';
    _config = DominoConfig(
      playerCount: 4,
      variant: variantKey == 'block' ? DominoVariant.block : DominoVariant.draw,
      targetScore: (cfg['targetScore'] as num?)?.toInt() ?? 100,
      teams: cfg['teams'] as bool? ?? false,
    );
    _playerCount = 4;
    _hostUid = info['hostUid'] as String?;

    final seats = <int, Map<String, dynamic>>{};
    final rawSeats = info['seats'];
    if (rawSeats is Map) {
      rawSeats.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && v is Map) seats[i] = Map<String, dynamic>.from(v);
      });
    } else if (rawSeats is List) {
      for (int i = 0; i < rawSeats.length; i++) {
        final v = rawSeats[i];
        if (v is Map) seats[i] = Map<String, dynamic>.from(v);
      }
    }

    _rawSeats = {
      for (final e in seats.entries) '${e.key}': e.value,
    };
    _seatNames = List.generate(
        4, (i) => seats[i]?['name'] as String? ?? 'player_n'.tr(args: ['${i + 1}']));
    _botSeats = {
      for (int i = 0; i < 4; i++)
        if (seats[i]?['bot'] == true) i
    };
    for (int i = 0; i < 4; i++) {
      _seatUids[i] = seats[i]?['uid'] as String?;
      if (_seatUids[i] != null && _seatUids[i] == _myUid) _mySeat = i;
    }
  }

  /// Room updates while waiting: seat changes and the host flipping the
  /// status to 'active' (which starts the game on every client).
  void _onRoomInfo(DatabaseEvent event) {
    if (!mounted) return;
    final raw = event.snapshot.value;
    if (raw == null) {
      if (_roomWaiting) {
        setState(() {
          _roomWaiting = false;
          _roomError = 'host_closed_table'.tr();
        });
      }
      return;
    }
    final info = Map<String, dynamic>.from(raw as Map);
    _applyRoomInfo(info);
    final status = info['status'] as String? ?? 'waiting';

    if (status == 'active' && _engine == null) {
      _infoSub?.cancel();
      _infoSub = null;
      setState(() => _roomWaiting = false);
      _startEngineAndSync();
    } else {
      setState(() {});
    }
  }

  /// Host: start the table. Invited friends who never joined are replaced
  /// by AI stand-ins so the game can never stall on an empty chair.
  Future<void> _hostStartTable() async {
    if (_starting || !_isTableHost) return;
    setState(() => _starting = true);

    final pool = [...GameType.domino.fakeBotNames]..shuffle();
    int botIdx = 0;
    final seats = <String, Map<String, dynamic>>{};
    for (int s = 0; s < 4; s++) {
      final raw = _rawSeats['$s'] ?? <String, dynamic>{};
      final isBot = raw['bot'] == true;
      final present = s == _mySeat || _seatOnline[s] == true;
      if (isBot || present) {
        seats['$s'] = Map<String, dynamic>.from(raw);
      } else {
        seats['$s'] = {'uid': null, 'name': pool[botIdx++], 'bot': true};
      }
    }

    try {
      await ref.read(realtimeGameServiceProvider).updateGameRoom(_gameId, {
        'seats': seats,
        'status': 'active',
      });
      // The room-info event flips every client (including this one) to active.
    } catch (e) {
      debugPrint('[DominoTable] start failed: $e');
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Auto-start once every invited friend is online at the table.
  void _maybeAutoStartTable() {
    if (!_roomWaiting || !_isTableHost || _starting) return;
    for (int s = 0; s < _playerCount; s++) {
      if (s == _mySeat || _botSeats.contains(s)) continue;
      if (_seatOnline[s] != true) return;
    }
    _hostStartTable();
  }

  void _startEngineAndSync() {
    _engine = DominoEngine(
      seed: _seedFromGameId(_gameId),
      config: _config,
    );

    final rtdb = ref.read(realtimeGameServiceProvider);
    // The onChildAdded stream replays the existing log first → resume works.
    _actionSub = rtdb.watchActions(_gameId).listen(_onActionEvent);
    _gameOverSub = rtdb.watchGameOver(_gameId).listen(_onRemoteGameOver);
    _resignedSub = rtdb.watchResignedSeats(_gameId).listen(_onResignedSeats);

    if (_myUid != null) {
      rtdb.goOnline(_gameId, _myUid!);
    }
    _subscribePresence();

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTurnTick());
    setState(() {});
    _afterStateAdvance();
  }

  void _subscribePresence() {
    if (_presenceSubscribed) return;
    _presenceSubscribed = true;
    final rtdb = ref.read(realtimeGameServiceProvider);
    for (final entry in _seatUids.entries) {
      final seat = entry.key;
      final uid = entry.value;
      if (uid == null || uid == _myUid) continue;
      _presenceSubs.add(rtdb
          .watchPresence(_gameId, uid)
          .listen((event) => _onSeatPresence(seat, event)));
    }
  }

  @override
  void dispose() {
    _actionSub?.cancel();
    _gameOverSub?.cancel();
    _resignedSub?.cancel();
    _infoSub?.cancel();
    for (final s in _presenceSubs) {
      s.cancel();
    }
    _turnTimer?.cancel();
    _abandonTimer?.cancel();
    if (_isOnline && _myUid != null) {
      final rtdb = ref.read(realtimeGameServiceProvider);
      rtdb.cancelDisconnectHandler(_gameId, _myUid!);
      rtdb.goOffline(_gameId, _myUid!);
      // Host abandoning the waiting room closes the whole table so guests
      // aren't left staring at a lobby that can never start.
      if (_roomWaiting && _isTableHost) {
        rtdb.deleteGame(_gameId);
      }
    }
    super.dispose();
  }

  // ── Seat control helpers ─────────────────────────────────────────────────

  bool _isSeatBotControlled(int seat) =>
      _botSeats.contains(seat) || _resignedSeats.contains(seat);

  /// The lowest-seated connected human drives the AI stand-ins so every
  /// client sees identical bot behaviour without a server.
  bool get _amActingHost {
    if (!_isOnline) return true;
    if (_resignedSeats.contains(_mySeat)) return false;
    for (int s = 0; s < _playerCount; s++) {
      if (_isSeatBotControlled(s)) continue;
      if (s == _mySeat) return true;
      if (_seatOnline[s] == true) return false;
      // Seat not known to be online → skip it as a host candidate.
    }
    return false;
  }

  // ── Action log ───────────────────────────────────────────────────────────

  void _onActionEvent(DatabaseEvent event) {
    final key = event.snapshot.key;
    final index = key == null ? null : int.tryParse(key);
    if (index == null) return;
    if (index < _appliedActions) return; // already applied (incl. own echoes)

    final raw = event.snapshot.value;
    if (raw == null) return;
    _pendingActions[index] = Map<String, dynamic>.from(raw as Map);
    _drainActions();
  }

  void _drainActions() {
    final engine = _engine;
    if (engine == null) return;
    bool any = false;

    while (_pendingActions.containsKey(_appliedActions)) {
      final map = _pendingActions.remove(_appliedActions)!;
      _appliedActions++;

      if (engine.matchOver) continue;

      final seat = (map['seat'] as num?)?.toInt() ?? -1;
      if (seat != engine.turnSeat) {
        debugPrint('[Domino] out-of-turn action seat=$seat at ${_appliedActions - 1}');
        continue;
      }

      switch (map['type'] as String?) {
        case 'play':
          final a = (map['a'] as num?)?.toInt();
          final b = (map['b'] as num?)?.toInt();
          if (a == null || b == null) break;
          final end = (map['end'] as String?) == 'right'
              ? DominoEnd.right
              : DominoEnd.left;
          engine.play(DominoPlay(tile: DominoTile(a, b), end: end));
          break;
        case 'draw':
          engine.drawTile();
          break;
        case 'pass':
          engine.pass();
          break;
      }
      any = true;
    }

    if (!any || !mounted) return;
    _lastActionAt = DateTime.now();
    _resetTurnClock();
    setState(() {
      _selectedTile = null;
      _hintEnd = null;
    });
    _afterStateAdvance();
  }

  void _pushOwnAction(Map<String, dynamic> action) {
    final idx = _appliedActions;
    _appliedActions++;
    _lastActionAt = DateTime.now();
    ref.read(realtimeGameServiceProvider).setAction(_gameId, idx, {
      'uid': _myUid,
      'seat': _mySeat,
      ...action,
    });
  }

  /// Central place that reacts to any engine state change: round summaries,
  /// match end, scheduling the next AI move.
  void _afterStateAdvance() {
    final engine = _engine;
    if (engine == null || !mounted) return;

    // Match over?
    if (engine.matchOver && _finalWinnerEntity == null) {
      _finalWinnerEntity = engine.matchWinner;
    }
    if (_finalWinnerEntity != null) {
      _showResultDialog();
      return;
    }

    // New round finished → show the round summary once.
    final summary = engine.lastRoundSummary;
    if (summary != null && summary.roundNumber > _lastShownRound) {
      _lastShownRound = summary.roundNumber;
      _showRoundSheet(summary);
      return; // bot scheduling resumes when the sheet closes
    }

    _scheduleAiIfNeeded();
  }

  void _scheduleAiIfNeeded() {
    final engine = _engine;
    if (engine == null || engine.matchOver || _roundSheetOpen) return;

    if (_isOnline) {
      _maybeDriveBotSeat();
      return;
    }
    if (_vsBot && _isSeatBotControlled(engine.turnSeat)) {
      _scheduleLocalBotPlay();
    }
  }

  // ── Offline bot (MCTS in isolate) ────────────────────────────────────────

  int get _botSimulations {
    final chapter = _campaignChapter;
    if (_mode == 'campaign' && chapter != null) {
      return (60 + 14 * chapter).clamp(80, 600);
    }
    return 450;
  }

  Future<void> _scheduleLocalBotPlay() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _thinking = true);
    final delay = _playerCount == 4 ? 350 : 550;
    await Future.delayed(Duration(milliseconds: delay));
    if (!mounted) return;

    final e = _engine;
    if (e == null || e.matchOver || !_isSeatBotControlled(e.turnSeat)) {
      setState(() => _thinking = false);
      return;
    }

    // Draw until playable (Draw variant only — canDraw handles the rules).
    while (e.legalPlays().isEmpty && e.canDraw) {
      e.drawTile();
    }

    if (e.legalPlays().isEmpty) {
      e.pass();
      setState(() => _thinking = false);
      _afterStateAdvance();
      return;
    }

    Map<String, dynamic>? res;
    try {
      res = await compute(dominoBestPlayIsolate, {
        'state': e.toState(),
        'simulations': _botSimulations,
      });
    } catch (err) {
      debugPrint('[Domino] isolate search failed: $err');
    }
    if (!mounted) return;

    final e2 = _engine;
    if (e2 == null || e2.matchOver) {
      setState(() => _thinking = false);
      return;
    }

    DominoPlay? play;
    if (res != null) {
      final tile = DominoTile(res['a'] as int, res['b'] as int);
      final end = DominoEnd.values[res['end'] as int];
      play = DominoPlay(tile: tile, end: end);
    }
    play ??= e2.greedyBotPlay(math.Random());

    if (play != null) {
      if (!e2.play(play)) {
        // Engine state moved on (e.g. resign) — fall back gracefully.
        final fallback = e2.greedyBotPlay(math.Random());
        if (fallback != null) e2.play(fallback);
      }
    } else {
      e2.pass();
    }

    setState(() => _thinking = false);
    _afterStateAdvance();
  }

  // ── Online stand-in driver (4P) ──────────────────────────────────────────

  void _maybeDriveBotSeat() {
    final engine = _engine;
    if (engine == null || !_isOnline || engine.matchOver) return;
    final seat = engine.turnSeat;
    if (!_isSeatBotControlled(seat)) return;
    if (!_amActingHost) return;
    if (_botWriteForIndex == _appliedActions) return;
    _botWriteForIndex = _appliedActions;

    final actionIndex = _appliedActions;
    final seed = _seedFromGameId(_gameId) ^ (actionIndex * 2654435761);
    final delayMs = 700 + math.Random(seed).nextInt(1100);

    Future.delayed(Duration(milliseconds: delayMs), () async {
      if (!mounted) return;
      final e = _engine;
      if (e == null || e.matchOver) return;
      if (_appliedActions != actionIndex) return; // someone already acted
      if (!_isSeatBotControlled(e.turnSeat)) return;
      if (!_amActingHost) return;

      final payload = _deterministicBotAction(e, seed);
      if (payload == null) return;
      payload['seat'] = e.turnSeat;
      payload['uid'] = 'bot';
      // Write-if-absent: a host hand-over can never produce a double move.
      await ref
          .read(realtimeGameServiceProvider)
          .setActionIfAbsent(_gameId, actionIndex, payload);
    });
  }

  /// Deterministic action for an AI stand-in: identical on every client.
  Map<String, dynamic>? _deterministicBotAction(DominoEngine e, int seed) {
    if (e.legalPlays().isEmpty) {
      if (e.canDraw) return {'type': 'draw'};
      return {'type': 'pass'};
    }
    final play = e.greedyBotPlay(math.Random(seed));
    if (play == null) return {'type': 'pass'};
    return {
      'type': 'play',
      'a': play.tile.a,
      'b': play.tile.b,
      'end': play.end.name,
    };
  }

  // ── Human actions ────────────────────────────────────────────────────────

  void _onTileTap(DominoTile tile) {
    final engine = _engine;
    if (engine == null || !_isHumanTurn || _thinking) return;
    if (engine.matchOver) return;

    final plays = engine.legalPlays();
    final tilePlays = plays.where((p) => p.tile == tile).toList();

    if (tilePlays.isEmpty) return;
    if (tile != _selectedTile) _hintEnd = null;

    if (tilePlays.length == 1) {
      _executePlay(tilePlays.first);
    } else {
      // Both ends fit — select the tile; the matching ends glow on the
      // table and the player taps the end directly (no dialog).
      setState(() =>
          _selectedTile = _selectedTile == tile ? null : tile);
    }
  }

  /// Tap on a glowing end zone places the selected tile there.
  void _onEndTap(DominoEnd end) {
    final engine = _engine;
    final tile = _selectedTile;
    if (engine == null || tile == null || !_isHumanTurn || _thinking) return;
    final play = engine
        .legalPlays()
        .where((p) => p.tile == tile && p.end == end)
        .toList();
    if (play.isEmpty) return;
    _executePlay(play.first);
  }

  /// Whether an end zone should glow for the currently selected/dragged tile.
  bool _endActive(DominoEnd end, List<DominoPlay> legalPlays) {
    final focus = _draggingTile ?? _selectedTile;
    if (focus == null) return false;
    // After "Hint", only the suggested end glows for the suggested tile.
    final hintEnd = _hintEnd;
    if (_draggingTile == null && hintEnd != null && end != hintEnd) {
      return false;
    }
    return legalPlays.any((p) => p.tile == focus && p.end == end);
  }

  /// Bot games: asks the engine for a good play and selects that tile, with
  /// only the end it should go on lit up.
  Future<void> _handleHint() async {
    final e = _engine;
    if (e == null || _hinting || _thinking || !_isHumanTurn) return;
    if (e.matchOver || e.legalPlays().isEmpty) return;
    setState(() => _hinting = true);
    Map<String, dynamic>? res;
    try {
      res = await compute(dominoBestPlayIsolate, {
        'state': e.toState(),
        'simulations': 300,
      });
    } catch (err) {
      debugPrint('[Domino] hint search failed: $err');
    }
    if (!mounted) return;
    final now = _engine?.legalPlays() ?? const <DominoPlay>[];
    DominoPlay? play;
    if (res != null) {
      final tile = DominoTile(res['a'] as int, res['b'] as int);
      final end = DominoEnd.values[res['end'] as int];
      play = now
          .where((p) => p.tile == tile && p.end == end)
          .firstOrNull;
    }
    play ??= now.firstOrNull;
    setState(() {
      _hinting = false;
      _selectedTile = play?.tile;
      _hintEnd = play?.end;
    });
  }

  void _executePlay(DominoPlay play) {
    final engine = _engine;
    if (engine == null) return;
    final ok = engine.play(play);
    if (!ok) return;
    if (_isOnline) {
      _pushOwnAction({
        'type': 'play',
        'a': play.tile.a,
        'b': play.tile.b,
        'end': play.end.name,
      });
    }
    _resetTurnClock();
    setState(() {
      _selectedTile = null;
      _hintEnd = null;
    });
    _afterStateAdvance();
  }

  void _onDraw() {
    final engine = _engine;
    if (engine == null || !_isHumanTurn || _thinking) return;
    if (!engine.canDraw) return;

    engine.drawTile();
    if (_isOnline) _pushOwnAction({'type': 'draw'});
    _resetTurnClock();
    setState(() {});
  }

  /// The player tapped a face-down tile in the boneyard.
  ///
  /// The tile that comes out is the next one of the shuffled boneyard, not
  /// the one at the tapped position: every face-down tile is equally likely
  /// either way, and online games keep syncing a plain `draw` action, so
  /// they stay in step with players still on the previous version.
  void _drawFromBoneyard(int slot) {
    final engine = _engine;
    if (engine == null || !_isHumanTurn || _thinking) return;
    if (_revealTile != null || !engine.canDraw) return;
    final tile = engine.drawTile();
    if (tile == null) return;
    if (_isOnline) _pushOwnAction({'type': 'draw'});
    _resetTurnClock();
    setState(() {
      _revealSlot = slot;
      _revealTile = tile;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _revealSlot = null;
        _revealTile = null;
        // A tile that fits comes into the hand ready to play.
        final e = _engine;
        if (e != null &&
            _isHumanTurn &&
            e.legalPlays().any((p) => p.tile == tile)) {
          _selectedTile = tile;
          _hintEnd = null;
        }
      });
    });
  }

  void _onPass() {
    final engine = _engine;
    if (engine == null || !_isHumanTurn || _thinking) return;
    if (engine.legalPlays().isNotEmpty) return;
    if (engine.canDraw) return; // must draw before passing (Draw variant)

    engine.pass();
    if (_isOnline) _pushOwnAction({'type': 'pass'});
    _resetTurnClock();
    setState(() {});
    _afterStateAdvance();
  }

  // ── Online turn timer ────────────────────────────────────────────────────

  void _resetTurnClock() {
    _turnSecondsLeft = _turnTimeLimit;
  }

  void _onTurnTick() {
    final engine = _engine;
    if (engine == null || !_isOnline || !mounted) return;
    if (engine.matchOver || _finalWinnerEntity != null) return;

    // Watchdog: re-arm the stand-in driver if a bot seat has stalled
    // (e.g. the previous acting host disconnected mid-write).
    if (_isSeatBotControlled(engine.turnSeat) &&
        DateTime.now().difference(_lastActionAt).inSeconds > 6 &&
        _amActingHost) {
      _botWriteForIndex = -1;
      _maybeDriveBotSeat();
      _lastActionAt = DateTime.now();
    }

    // Presence-based abandonment for 4P seats (acting host responsibility).
    if (_playerCount == 4 && _amActingHost) {
      for (final entry in _seatOfflineSince.entries) {
        if (_isSeatBotControlled(entry.key)) continue;
        if (DateTime.now().difference(entry.value).inSeconds >
            _abandonGraceSeconds) {
          ref
              .read(realtimeGameServiceProvider)
              .setSeatResigned(_gameId, entry.key);
        }
      }
    }

    if (engine.chain.isEmpty && _appliedActions == 0) return; // pre-game

    setState(() => _turnSecondsLeft--);
    if (_turnSecondsLeft > 0) return;

    _resetTurnClock();
    if (!_isHumanTurn) return;

    // Auto-act so a distracted player can't stall the table.
    if (engine.canDraw) {
      _onDraw();
      return;
    }
    final plays = engine.legalPlays();
    if (plays.isEmpty) {
      _onPass();
      return;
    }
    final auto = engine.greedyBotPlay(math.Random()) ?? plays.first;
    _executePlay(auto);
  }

  // ── Presence ─────────────────────────────────────────────────────────────

  void _onSeatPresence(int seat, DatabaseEvent event) {
    final raw = event.snapshot.value;
    final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final online = map?['online'] == true;

    _seatOnline[seat] = online;

    // Waiting room: just refresh the seat list and let the host auto-start
    // once every invited friend has arrived.
    if (_roomWaiting) {
      if (mounted) setState(() {});
      _maybeAutoStartTable();
      return;
    }

    if (online) {
      _opponentSeenOnline = true;
      _seatOfflineSince.remove(seat);
      if (_playerCount == 2) {
        _abandonTimer?.cancel();
        _abandonTimer = null;
      }
      return;
    }

    if (map == null) return; // never connected yet
    _seatOfflineSince[seat] = DateTime.now();

    // 2P: an explicitly-offline opponent forfeits after the grace period.
    if (_playerCount == 2 && _opponentSeenOnline) {
      final engine = _engine;
      if (engine == null || engine.matchOver || _finalWinnerEntity != null) return;
      _abandonTimer ??= Timer(const Duration(seconds: _abandonGraceSeconds), () {
        if (!mounted) return;
        if (_engine?.matchOver == true || _finalWinnerEntity != null) return;
        _finalWinnerEntity = _myEntity;
        _broadcastGameOver(_myEntity, status: 'abandon');
        setState(() {});
        _showResultDialog();
      });
    }
  }

  void _onResignedSeats(DatabaseEvent event) {
    final raw = event.snapshot.value;
    final next = <int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && v == true) next.add(i);
      });
    } else if (raw is List) {
      for (int i = 0; i < raw.length; i++) {
        if (raw[i] == true) next.add(i);
      }
    }
    if (next.length == _resignedSeats.length) return;
    setState(() => _resignedSeats = next);
    _scheduleAiIfNeeded();
  }

  // ── Game over (2P broadcast) ─────────────────────────────────────────────

  void _broadcastGameOver(int winnerEntity, {String status = 'finished'}) {
    if (!_isOnline) return;
    ref
        .read(realtimeGameServiceProvider)
        .setGameOver(_gameId, 'entity:$winnerEntity', status);
  }

  Future<void> _onRemoteGameOver(DatabaseEvent event) async {
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    final resultStr = map['result'] as String? ?? '';
    if (!resultStr.startsWith('entity:')) return;
    final winner = int.tryParse(resultStr.substring(7));
    if (winner == null) return;

    // Let the action replay settle first (resume case).
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    if (_engine?.matchOver == true || _finalWinnerEntity != null) return;

    _finalWinnerEntity = winner;
    setState(() {});
    _showResultDialog();
  }

  // ── Round summary sheet ──────────────────────────────────────────────────

  void _showRoundSheet(DominoRoundSummary summary) {
    if (!mounted) return;
    _roundSheetOpen = true;

    final engine = _engine!;
    final isWash = summary.winnerEntity == null;
    final iWon = summary.winnerEntity == _myEntity;

    Timer? autoClose;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        // Online: auto-dismiss so one player can't hold up the table.
        if (_isOnline) {
          autoClose = Timer(const Duration(seconds: 5), () {
            if (Navigator.canPop(ctx)) Navigator.pop(ctx);
          });
        }
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'round_n'.tr(args: ['${summary.roundNumber}']).toUpperCaseFor(context),
                style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 12, color: AppColors.inkMute, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isWash
                    ? 'round_wash'.tr()
                    : (summary.wasBlocked
                        ? 'round_blocked_win'.tr(args: [_entityName(summary.winnerEntity!)])
                        : 'round_domino'.tr(args: [_seatName(summary.winnerSeat!)])),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: isWash
                      ? AppColors.draw
                      : (iWon ? AppColors.win : _accent),
                ),
              ),
              if (!isWash) ...[
                const SizedBox(height: 4),
                Text(
                  'points_gained'.tr(args: ['${summary.scoreGained}']),
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _accent,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Pip counts per seat
              ...List.generate(_playerCount, (s) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_seatName(s),
                          style: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.inkDim)),
                      Text('pips_n'.tr(args: ['${summary.pipCounts[s]}']),
                          style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 13, color: AppColors.ink)),
                    ],
                  ),
                );
              }),
              const Divider(color: AppColors.border, height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('score'.tr(), style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.inkDim)),
                  Text(
                    _scoreLine(summary.totalScores),
                    style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: const Color(0xFF0A0A0B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'continue_round'.tr(args: ['${engine.roundNumber}']),
                    style: AppTextStyles.buttonMedium
                        .copyWith(color: const Color(0xFF0A0A0B)),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      autoClose?.cancel();
      _roundSheetOpen = false;
      if (!mounted) return;
      setState(() {});
      _afterStateAdvance();
    });
  }

  String _seatName(int seat) => seat < _seatNames.length
      ? _seatNames[seat]
      : 'player_n'.tr(args: ['${seat + 1}']);

  String _entityName(int entity) {
    final engine = _engine!;
    if (!engine.config.teams) return _seatName(entity);
    return (entity == _myEntity ? 'your_team' : 'opponent_team').tr();
  }

  String _scoreLine(List<int> scores) {
    final engine = _engine!;
    if (engine.config.teams) {
      final mine = scores[_myEntity];
      final theirs = scores[1 - _myEntity];
      return '$mine : $theirs';
    }
    return scores.join(' : ');
  }

  // ── Save match to Firestore ──────────────────────────────────────────────

  Future<void> _saveGame(int winnerEntity) async {
    if (_gameSaved) return;
    _gameSaved = true;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final myUid = user.uid;
    final oppUid = _opponentUid ?? widget.extra['opponentUid'] as String?;

    final humanWon = winnerEntity == _myEntity;
    // Match play has no draws: a target score is always reached (resign /
    // abandonment also produce a winner).
    const isDraw = false;

    final whiteUid = _mySeat == 0 ? myUid : oppUid;
    final blackUid = _mySeat == 0 ? oppUid : myUid;
    final whiteUsername = _mySeat == 0 ? _myUsername : _opponentUsername;
    final blackUsername = _mySeat == 0 ? _opponentUsername : _myUsername;

    final gameResult = humanWon
        ? (_mySeat == 0 ? GameResult.white : GameResult.black)
        : (_mySeat == 0 ? GameResult.black : GameResult.white);

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final freshUser = await firestore.getUser(myUid) ?? user;

      // Compute the point change BEFORE saving the game so my side's
      // before/change lands on the game doc — the profile rating chart is
      // built from exactly these fields. Match outcome is binary: the
      // winning entity takes a win, every other seat takes a loss.
      int? myBefore;
      int? myChange;
      Map<String, dynamic>? newStatsMap;
      if (_isRated || _isFakeBotFallback) {
        final won = humanWon;
        final lost = !humanWon;
        final stats = freshUser.dominoStats;
        final oppRating = widget.extra['opponentRating'] as int? ?? stats.rating;
        final pointChange = GameType.domino.calculatePointChange(
          myPoints: stats.rating,
          opponentPoints: oppRating,
          won: won,
          lost: lost,
        );
        myBefore = stats.rating;
        myChange = pointChange;
        newStatsMap = stats
            .copyWith(
              wins: stats.wins + (won ? 1 : 0),
              losses: stats.losses + (lost ? 1 : 0),
              rating: stats.rating + pointChange,
            )
            .toMap();
      }

      final iAmWhiteSeat = _mySeat == 0;
      final game = GameModel(
        id: _gameId,
        mode: _isFakeBotFallback ? GameMode.online : GameMode.values.firstWhere(
          (m) => m.name == _mode,
          orElse: () => GameMode.bot,
        ),
        gameType: 'domino',
        whiteUid: whiteUid,
        blackUid: blackUid,
        whiteUsername: whiteUsername,
        blackUsername: blackUsername,
        timeControl: TimeControls.none,
        result: gameResult,
        createdAt: DateTime.now(),
        endedAt: DateTime.now(),
        campaignChapter: _campaignChapter,
        isRated: _isRated || _isFakeBotFallback,
        whiteRatingBefore: iAmWhiteSeat ? myBefore : null,
        blackRatingBefore: iAmWhiteSeat ? null : myBefore,
        whiteRatingChange: iAmWhiteSeat ? myChange : null,
        blackRatingChange: iAmWhiteSeat ? null : myChange,
      );

      await firestore.saveGame(game);
      await firestore.addRecentGameId(myUid, _gameId);

      // Update points for rated games (point-based system)
      if (newStatsMap != null) {
        await firestore.updateUser(myUid, {'dominoStats': newStatsMap});
      }

      // Update campaign progress if player won a campaign game
      if (_mode == 'campaign' && humanWon) {
        final chapter = _campaignChapter ?? 0;
        if (chapter > freshUser.dominoCampaignProgress) {
          await firestore.updateCampaignProgress(myUid, chapter, gameType: 'domino');
          debugPrint('[Domino] campaign progress updated → $chapter');
        }
      }

      // Arena tournament score.
      if (_arenaId != null && !_isLocalGame) {
        await _recordArenaResult(gameResult,
            won: humanWon, isDraw: isDraw, myUid: myUid, oppUid: oppUid);
      }

      debugPrint('[Domino] saved game $_gameId');
    } catch (e) {
      debugPrint('[Domino] failed to save game: $e');
    }
  }

  /// Reports the arena result to the server, which scores both sides once
  /// per game (and credits the arena bot when the opponent was one).
  Future<void> _recordArenaResult(GameResult result,
      {required bool won,
      required bool isDraw,
      required String myUid,
      String? oppUid}) async {
    try {
      await ref.read(tournamentServiceProvider).reportArenaResult(
            tournamentId: _arenaId!,
            gameId: _gameId,
            outcome: isDraw
                ? ArenaOutcome.draw
                : won
                    ? ArenaOutcome.win
                    : ArenaOutcome.loss,
            opponentUid: _isOnline && _playerCount == 2 ? oppUid : _arenaBotUid,
          );
      debugPrint('[Domino] arena result reported for $_arenaId');
    } catch (e) {
      debugPrint('[Domino] failed to report arena result: $e');
    }
  }

  // ── Resign ─────────────────────────────────────────────────────────────

  Future<void> _handleResign() async {
    final confirmed = await confirmResign(
      context,
      online: _looksOnline,
      message: _playerCount == 4 && _isOnline ? 'leave_table_confirm'.tr() : null,
    );

    if (!confirmed || !mounted) return;

    if (_isOnline && _playerCount == 4) {
      // 4P: the table plays on — my seat is taken over by a stand-in and
      // I record the loss for myself.
      ref.read(realtimeGameServiceProvider).setSeatResigned(_gameId, _mySeat);
      _finalWinnerEntity = (_myEntity + 1) % (_engine?.entityCount ?? 2);
      setState(() {});
      _showResultDialog();
      return;
    }

    // 2P / offline: resigning ends the match — the opponent entity wins.
    final winner = (_myEntity + 1) % (_engine?.entityCount ?? 2);
    _finalWinnerEntity = winner;
    if (_isOnline) _broadcastGameOver(winner, status: 'resign');
    setState(() {});
    _showResultDialog();
  }

  // ── Result ──────────────────────────────────────────────────────────────

  void _showResultDialog() {
    if (_resultShown) return;
    final winner = _finalWinnerEntity;
    if (winner == null) return;
    _resultShown = true;

    _saveGame(winner);

    final engine = _engine;
    final humanWon = winner == _myEntity;
    final String title = (humanWon ? 'you_won' : 'you_lost').tr();
    final Color color = humanWon ? AppColors.win : AppColors.loss;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 32, fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            if (engine != null)
              Text(
                'domino_match_summary'.tr(args: [
                  _scoreLine(engine.scores),
                  '${engine.roundNumber}',
                ]),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.inkDim,
                ),
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('exit'.tr(), style: AppTextStyles.buttonMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (_isOnline) {
                        Navigator.pop(context); // back to matchmaking
                      } else {
                        _resetGame();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0A0A0B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text((_isOnline ? 'new_game' : 'rematch').tr(),
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: const Color(0xFF0A0A0B))),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _gameId = const Uuid().v4(); // fresh id so the rematch is its own record
      _engine = DominoEngine(config: _config);
      _selectedTile = null;
      _thinking = false;
      _gameSaved = false;
      _resultShown = false;
      _lastShownRound = 0;
      _finalWinnerEntity = null;
    });
    _afterStateAdvance();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  // ── Waiting room (friends table, status == 'waiting') ────────────────────

  Widget _buildWaitingRoom() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
            color: AppColors.ink,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '2v2 Table',
          style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isTableHost
                    ? 'waiting_friends_join'.tr()
                    : 'waiting_host_start'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.inkDim),
              ),
              const SizedBox(height: 20),
              for (int s = 0; s < 4; s++) ...[
                _WaitingSeatTile(
                  name: _seatNames.length > s
                      ? _seatNames[s]
                      : 'player_n'.tr(args: ['${s + 1}']),
                  team: (s % 2 == 0 ? 'team_a' : 'team_b').tr().toUpperCaseFor(context),
                  accent: s % 2 == 0 ? _accent : const Color(0xFFF07079),
                  status: s == _mySeat
                      ? 'you'.tr()
                      : _botSeats.contains(s)
                          ? 'AI stand-in'
                          : (_seatOnline[s] == true
                              ? 'seat_joined'.tr()
                              : 'seat_invited'.tr()),
                  joined: s == _mySeat ||
                      _botSeats.contains(s) ||
                      _seatOnline[s] == true,
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              if (_isTableHost) ...[
                Text(
                  'table_bot_fill_note'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMute),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _starting ? null : _hostStartTable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      disabledBackgroundColor: _accent.withValues(alpha: 0.3),
                      foregroundColor: const Color(0xFF0A0A0B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _starting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF0A0A0B)),
                          )
                        : Text(
                            'start_game'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600,
                              color: const Color(0xFF0A0A0B),
                            ),
                          ),
                  ),
                ),
              ] else
                const Center(
                  child: SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;

    if (_roomWaiting) return _buildWaitingRoom();

    if (_roomLoading || engine == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Center(
          child: _roomError != null
              ? Text(_roomError!,
                  style: GoogleFonts.inter(color: AppColors.inkDim))
              : const CircularProgressIndicator(color: _accent, strokeWidth: 2),
        ),
      );
    }

    final legalPlays = _isHumanTurn ? engine.legalPlays() : const <DominoPlay>[];
    final playableTiles = legalPlays.map((p) => p.tile).toSet();

    // Game Settings toggles apply to domino too: "Show legal moves" controls
    // the dimming of unplayable hand tiles, "Highlight last move" outlines
    // the most recently placed tile on the table.
    final cache = ref.watch(cacheServiceProvider);
    final showPlayableHints = cache.showLegalMoves;
    final highlightTile =
        cache.highlightLastMove ? engine.lastPlayedTile : null;
    final hand = [...engine.handOf(_handSeat)]
      ..sort((a, b) {
        final d = b.total.compareTo(a.total);
        if (d != 0) return d;
        return b.maxPip.compareTo(a.maxPip);
      });

    final gameStarted = engine.chain.isNotEmpty ||
        engine.roundNumber > 1 ||
        _appliedActions > 0;
    final activeGame = !engine.matchOver &&
        _finalWinnerEntity == null &&
        gameStarted;

    final showClock = _isOnline && activeGame;

    final mustDraw = engine.canDraw &&
        _isHumanTurn &&
        !_thinking &&
        _finalWinnerEntity == null;

    return PopScope(
      canPop: !activeGame,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleResign();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              GameTopBar(
                modeLabel: _modeLabel(context, engine),
                subLabel: _subLabel(engine),
                onBack: () {
                  if (activeGame) {
                    _handleResign();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),

              // ── Match score header ───────────────────────────────────────
              _ScoreHeader(
                engine: engine,
                mySeat: _mySeat,
                seatName: _seatName,
                accent: _accent,
              ),

              // ── Opponents ────────────────────────────────────────────────
              if (_playerCount == 4)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      for (final s in _otherSeatsInTurnOrder()) ...[
                        if (s != _otherSeatsInTurnOrder().first)
                          const SizedBox(width: 6),
                        Expanded(
                          child: _CompactInfoBar(
                            label: _seatName(s),
                            isPartner: engine.config.teams &&
                                engine.entityOf(s) == _myEntity,
                            tileCount: engine.handOf(s).length,
                            isActive: engine.turnSeat == s,
                            thinking: _thinking && engine.turnSeat == s,
                            accent: _accent,
                            secondsLeft: showClock && engine.turnSeat == s
                                ? _turnSecondsLeft
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                const SizedBox(height: 4),
                _strip(
                  engine,
                  seat: 1 - _mySeat,
                  showClock: showClock,
                ),
                const SizedBox(height: 4),
              ],

              // ── Board: snake chain with tappable/droppable end zones ────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a2a1f), // felt green table
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                    padding: const EdgeInsets.all(12),
                    child: DominoSnakeBoard(
                      chain: engine.chain,
                      leftEnd: engine.leftEnd,
                      rightEnd: engine.rightEnd,
                      tileSize: 56,
                      leftActive: _endActive(DominoEnd.left, legalPlays),
                      rightActive: _endActive(DominoEnd.right, legalPlays),
                      canAcceptDrag: (tile, end) => legalPlays
                          .any((p) => p.tile == tile && p.end == end),
                      onDragAccept: (tile, end) {
                        final play = legalPlays
                            .where((p) => p.tile == tile && p.end == end)
                            .toList();
                        if (play.isNotEmpty) _executePlay(play.first);
                      },
                      onEndTap: _onEndTap,
                      emptyHint: engine.requiredOpeningTile != null
                          ? 'opening_tile_n'.tr(args: ['${engine.requiredOpeningTile}'])
                          : 'place_first_tile'.tr(),
                      highlightTile: highlightTile,
                    ),
                  ),
                      // Nothing in the hand fits: the boneyard comes up face
                      // down and the player picks a tile from it.
                      if (mustDraw || _revealTile != null)
                        Positioned.fill(
                          child: _BoneyardPicker(
                            faceDownCount: engine.boneyardCount,
                            revealSlot: _revealSlot,
                            revealTile: _revealTile,
                            leftEnd: engine.chain.isEmpty ? null : engine.leftEnd,
                            rightEnd: engine.chain.isEmpty ? null : engine.rightEnd,
                            onPick: _drawFromBoneyard,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── My row + hand ────────────────────────────────────────────
              _strip(
                engine,
                seat: _handSeat,
                showClock: showClock,
              ),

              // Player hand (sorted, draggable)
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: hand.map((tile) {
                        final canPlay =
                            playableTiles.contains(tile) && _isHumanTurn;
                        final tileWidget = DominoTileWidget(
                          tile: tile,
                          size: 80,
                          selected: _selectedTile == tile,
                          onTap: canPlay ? () => _onTileTap(tile) : null,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Opacity(
                            opacity: !showPlayableHints ||
                                    canPlay ||
                                    !_isHumanTurn
                                ? 1.0
                                : 0.45,
                            child: canPlay
                                ? Draggable<DominoTile>(
                                    data: tile,
                                    onDragStarted: () => setState(
                                        () => _draggingTile = tile),
                                    onDragEnd: (_) => setState(
                                        () => _draggingTile = null),
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: DominoTileWidget(
                                          tile: tile, size: 92, selected: true),
                                    ),
                                    childWhenDragging: Opacity(
                                        opacity: 0.3, child: tileWidget),
                                    child: tileWidget,
                                  )
                                : tileWidget,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              GameActionRow(
                actions: _actions(engine, legalPlays, activeGame),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Page chrome ──────────────────────────────────────────────────────────

  String _modeLabel(BuildContext context, DominoEngine engine) {
    String up(String key) => key.tr().toUpperCaseFor(context);
    final base = _arenaId != null
        ? up('arena')
        : _looksOnline
            ? '${up('online')} · ${_isRated || _isFakeBotFallback ? up('rated_game') : up('game_casual')}'
            : switch (_mode) {
                'campaign' => up('campaign'),
                'bot' => '${up('vs_bot')} · ${up('game_casual')}',
                _ => up('local_game'),
              };
    if (_playerCount != 4) return base;
    return '$base · ${engine.config.teams ? '2V2' : '4P'}';
  }

  String _subLabel(DominoEngine engine) {
    final round = 'round_n'.tr(args: ['${engine.roundNumber}']);
    if (engine.boneyardCount == 0) return round;
    return '$round · ${'boneyard'.tr()} ${engine.boneyardCount}';
  }

  Widget _strip(DominoEngine engine, {required int seat, required bool showClock}) {
    final active = engine.turnSeat == seat;
    final timer = showClock && active;
    final isOpponent = !_isLocalGame && seat != _mySeat;
    final name = _seatName(seat);
    // Domino has no sides, so the avatar shows who the player is: their
    // photo or first letter (every seat used to show the same tile icon).
    final photoUrl = !_isLocalGame && seat == _mySeat
        ? ref.watch(currentUserProvider).valueOrNull?.photoUrl
        : null;
    return GamePlayerStrip(
      name: name,
      photoUrl: photoUrl,
      isActive: active,
      token: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.inkDim,
        ),
      ),
      details: [
        GamePlayerStrip.detail('${engine.handOf(seat).length} ${'tiles'.tr()}'),
      ],
      trailing: timer
          ? GameClockText(
              GameClockText.seconds(_turnSecondsLeft),
              active: true,
              low: _turnSecondsLeft <= 10,
            )
          : (_thinking && active && isOpponent)
              ? const GameThinkingIndicator()
              : null,
    );
  }

  List<GameAction> _actions(
      DominoEngine engine, List<DominoPlay> legalPlays, bool activeGame) {
    final myTurn = _isHumanTurn &&
        !_thinking &&
        !engine.matchOver &&
        _finalWinnerEntity == null;
    // Drawing happens by picking a face-down tile in the boneyard (it comes
    // up on the table by itself). Passing is only possible once nothing fits
    // and there is nothing left to draw.
    final drawOrPass = GameAction(
      icon: PhosphorIcons.skipForward(PhosphorIconsStyle.regular),
      label: 'pass_turn'.tr(),
      onTap: myTurn && legalPlays.isEmpty && !engine.canDraw ? _onPass : null,
    );
    final resign = GameAction(
      icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
      label: 'resign'.tr(),
      onTap: activeGame ? _handleResign : null,
      danger: true,
    );
    if (_looksOnline) {
      return [
        GameAction(
          icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
          label: 'chat'.tr(),
          onTap: () => showGameChatSheet(context, gameId: _gameId),
        ),
        drawOrPass,
        resign,
      ];
    }
    if (_vsBot && _arenaId == null) {
      return [
        GameAction(
          icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.regular),
          label: 'hint'.tr(),
          onTap: myTurn && !_hinting && legalPlays.isNotEmpty
              ? _handleHint
              : null,
        ),
        drawOrPass,
        resign,
      ];
    }
    return [drawOrPass, resign];
  }

  List<int> _otherSeatsInTurnOrder() =>
      [for (int i = 1; i < _playerCount; i++) (_mySeat + i) % _playerCount];
}

// ── Boneyard picker ──────────────────────────────────────────────────────────

/// The boneyard laid out face down over the table, as at a real table: when
/// nothing in the hand fits, the player taps a tile to draw it. The tile turns
/// over for a moment, then goes into the hand; if it does not fit either,
/// the player picks again.
class _BoneyardPicker extends StatelessWidget {
  final int faceDownCount;
  final int? revealSlot;
  final DominoTile? revealTile;
  final int? leftEnd;
  final int? rightEnd;
  final ValueChanged<int> onPick;

  const _BoneyardPicker({
    required this.faceDownCount,
    required this.revealSlot,
    required this.revealTile,
    required this.leftEnd,
    required this.rightEnd,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final revealing = revealTile != null;
    // While a tile is turning over, its slot stays in place.
    final slots = faceDownCount + (revealing ? 1 : 0);
    final String hint;
    if (leftEnd == null || rightEnd == null) {
      hint = 'boneyard_pick_hint'.tr();
    } else if (leftEnd == rightEnd) {
      hint = 'boneyard_pick_hint_one'.tr(args: ['$leftEnd']);
    } else {
      hint = 'boneyard_pick_hint_two'.tr(args: ['$leftEnd', '$rightEnd']);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF142219),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'boneyard_title'.tr(args: ['$faceDownCount']),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.inkDim,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < slots; i++)
                    _BoneyardSlot(
                      key: ValueKey(i),
                      faceUp: i == revealSlot ? revealTile : null,
                      onTap: revealing ? null : () => onPick(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tile of the boneyard: face down until it is the one just drawn, then
/// it turns over.
class _BoneyardSlot extends StatelessWidget {
  final DominoTile? faceUp;
  final VoidCallback? onTap;

  const _BoneyardSlot({super.key, required this.faceUp, required this.onTap});

  static const double _size = 60;

  @override
  Widget build(BuildContext context) {
    final tile = faceUp;
    return Semantics(
      button: onTap != null,
      label: 'boneyard_tile'.tr(),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          // Squeeze horizontally and back out: the tile turns over.
          transitionBuilder: (child, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (_, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(animation.value, 1, 1),
              child: child,
            ),
          ),
          child: tile == null
              ? const DominoTileWidget(
                  key: ValueKey('back'),
                  tile: DominoTile(0, 0),
                  faceDown: true,
                  size: _size,
                )
              : DominoTileWidget(
                  key: const ValueKey('face'),
                  tile: tile,
                  size: _size,
                  selected: true,
                ),
        ),
      ),
    );
  }
}

// ── Score header ─────────────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  final DominoEngine engine;
  final int mySeat;
  final String Function(int) seatName;
  final Color accent;

  const _ScoreHeader({
    required this.engine,
    required this.mySeat,
    required this.seatName,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final myEntity = engine.entityOf(mySeat);
    final chips = <Widget>[];

    String entityLabel(int e) {
      if (engine.config.teams) return (e == myEntity ? 'your_team' : 'opponents').tr();
      return seatName(e);
    }

    for (int e = 0; e < engine.entityCount; e++) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: e == myEntity
              ? accent.withValues(alpha: 0.14)
              : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: e == myEntity
                ? accent.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Text(
          '${entityLabel(e)} · ${engine.scores[e]}',
          style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
            fontWeight: FontWeight.w600,
            color: e == myEntity ? accent : AppColors.inkDim,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          Text(
            'play_to_n'.tr(args: ['${engine.targetScore}']),
            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11, color: AppColors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}

/// A seat in 4-player games, where three full player rows would not fit.
class _CompactInfoBar extends StatelessWidget {
  final String label;
  final int tileCount;
  final bool isActive;
  final Color accent;
  final int? secondsLeft;

  /// Your teammate in 2v2 (marked with an icon after the name).
  final bool isPartner;

  /// A bot is choosing its play for this seat.
  final bool thinking;

  const _CompactInfoBar({
    required this.label,
    required this.tileCount,
    required this.isActive,
    required this.accent,
    this.secondsLeft,
    this.isPartner = false,
    this.thinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? accent.withValues(alpha: 0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? accent.withValues(alpha: 0.25) : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (thinking)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: accent),
                  ),
                )
              else if (isActive)
                Container(
                  width: 6, height: 6, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isActive ? accent : AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isPartner) ...[
                const SizedBox(width: 4),
                Icon(PhosphorIcons.handshake(PhosphorIconsStyle.regular),
                    size: 12, color: accent),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            secondsLeft != null
                ? '$tileCount ${'tiles'.tr()} · ${GameClockText.seconds(secondsLeft!)}'
                : '$tileCount ${'tiles'.tr()}',
            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11, color: AppColors.inkDim,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Waiting-room seat tile ───────────────────────────────────────────────────

class _WaitingSeatTile extends StatelessWidget {
  final String name;
  final String team;
  final String status;
  final Color accent;
  final bool joined;

  const _WaitingSeatTile({
    required this.name,
    required this.team,
    required this.status,
    required this.accent,
    required this.joined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: joined
              ? accent.withValues(alpha: 0.35)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: joined ? accent : AppColors.inkMute.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.inkMute),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              team,
              style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5, fontWeight: FontWeight.w700,
                color: accent, letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

