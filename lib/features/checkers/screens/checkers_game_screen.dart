import 'dart:async';
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
import '../../../core/theme/board_themes.dart';
import '../../settings/screens/settings_screen.dart' show settingsProvider;
import '../engine/checkers_engine.dart';
import '../widgets/checkers_board_widget.dart';

/// Checkers game screen — supports bot, local, online & campaign modes.
/// Accepts either direct constructor params (bot setup) or an [extra] map
/// (matchmaking / tournament / invite / campaign).
class CheckersGameScreen extends ConsumerStatefulWidget {
  final String? gameId;
  final Map<String, dynamic> extra;

  const CheckersGameScreen({
    super.key,
    this.gameId,
    this.extra = const {},
  });

  @override
  ConsumerState<CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends ConsumerState<CheckersGameScreen> {
  static const int _turnTimeLimit = 30; // seconds per move (online)
  static const int _abandonGraceSeconds = 30;

  late CheckersEngine _engine;
  int? _selectedCell;
  List<int> _pendingPath = []; // multi-capture path being tapped out
  List<CheckersMove> _legalMoves = [];
  Set<int> _hintCells = {};
  Set<int> _captureHintCells = {};
  Set<int> _forcedCells = {};
  bool _thinking = false;
  bool _gameSaved = false;
  bool _resultShown = false;

  // ── Resolved config from extra map ──────────────────────────────────────
  late final bool _vsBot;
  late final int _botDepth;
  late final bool _playerIsWhite;
  late final String _mode;
  late final String _myUsername;
  late final String _opponentUsername;
  late final bool _isRated;
  late final bool _isFakeBotFallback;
  late String _gameId;
  late final CheckersVariant _variant;
  late final String? _arenaId;
  late final int? _campaignChapter;

  // ── Online sync (ordered action log) ─────────────────────────────────────
  late final bool _isOnline;
  String? _myUid;
  String? _opponentUid;
  StreamSubscription<DatabaseEvent>? _actionSub;
  StreamSubscription<DatabaseEvent>? _gameOverSub;
  StreamSubscription<DatabaseEvent>? _presenceSub;
  int _appliedActions = 0;
  final Map<int, Map<String, dynamic>> _pendingActions = {};

  // ── Online turn timer + presence ─────────────────────────────────────────
  Timer? _turnTimer;
  int _turnSecondsLeft = _turnTimeLimit;
  int _myTimeouts = 0;
  Timer? _abandonTimer;
  bool _opponentSeenOnline = false;

  // Undo snapshots (offline only) — engine state right before each human move.
  final List<CheckersEngine> _undoStack = [];

  CheckersPlayer get _humanPlayer =>
      _playerIsWhite ? CheckersPlayer.white : CheckersPlayer.black;

  int get _mySeat => _playerIsWhite ? 0 : 1;

  /// True when it is the local human's turn to move.
  /// - Local pass-and-play: always true (both sides on one device).
  /// - Bot / online: only when the engine's turn matches the human side.
  bool get _isHumanTurn {
    if (!_vsBot && !_isOnline) return true;
    return _engine.turn == _humanPlayer;
  }

  bool get _isLocalGame => !_vsBot && !_isOnline;

  bool get _flipped => !_playerIsWhite;

  @override
  void initState() {
    super.initState();

    final e = widget.extra;
    _mode = e['mode'] as String? ?? 'bot';
    _vsBot = _mode == 'bot' || _mode == 'campaign';
    _isOnline = _mode == 'online';
    _playerIsWhite = e['playerIsWhite'] as bool? ?? true;
    _myUsername = e['myUsername'] as String? ?? 'You';
    _opponentUsername = e['opponentUsername'] as String? ?? (_vsBot ? 'Bot' : 'Opponent');
    _isRated = e['isRated'] as bool? ?? false;
    _isFakeBotFallback = e['isFakeBotFallback'] as bool? ?? false;
    _arenaId = e['arenaId'] as String?;
    _campaignChapter = e['campaignChapter'] as int?;
    _gameId = widget.gameId ?? e['gameId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Campaign difficulty scales with chapter (1-60 → depth 1-6);
    // otherwise the bot-setup / matchmaking supplied depth applies.
    final chapter = _campaignChapter;
    if (_mode == 'campaign' && chapter != null) {
      _botDepth = (1 + (chapter - 1) ~/ 10).clamp(1, 6);
    } else {
      _botDepth = e['botDepth'] as int? ?? 4;
    }

    // Resolve checkers variant from extra map. Online matchmaking pairs
    // players via a variant-keyed queue, so both clients are guaranteed to
    // carry the same value here — the chosen variant is honoured online too.
    final variantKey = e['checkersVariant'] as String? ?? 'standard';
    _variant = switch (variantKey) {
      'international' => CheckersVariant.international,
      'turkish'       => CheckersVariant.turkish,
      'brazilian'     => CheckersVariant.brazilian,
      'russian'       => CheckersVariant.russian,
      _               => CheckersVariant.standard,
    };

    _engine = CheckersEngine(variant: _variant);
    _refreshMoves();

    // Online: wire up ordered action log + game-over + presence sync.
    if (_isOnline) {
      _myUid = ref.read(authStateProvider).valueOrNull?.uid;
      _opponentUid = e['opponentUid'] as String?;
      final rtdb = ref.read(realtimeGameServiceProvider);

      // The onChildAdded stream replays the full existing log first, which
      // makes reconnect/resume work: every past action (including our own)
      // is re-applied in index order.
      _actionSub = rtdb.watchActions(_gameId).listen(_onActionEvent);
      _gameOverSub = rtdb.watchGameOver(_gameId).listen(_onRemoteGameOver);

      if (_myUid != null) {
        rtdb.goOnline(_gameId, _myUid!);
      }
      if (_opponentUid != null) {
        _presenceSub =
            rtdb.watchPresence(_gameId, _opponentUid!).listen(_onOpponentPresence);
      }

      _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTurnTick());
    }

    // If the opponent (bot) moves first.
    if (_vsBot && !_isHumanTurn) {
      _scheduleBotMove();
    }
  }

  @override
  void dispose() {
    _actionSub?.cancel();
    _gameOverSub?.cancel();
    _presenceSub?.cancel();
    _turnTimer?.cancel();
    _abandonTimer?.cancel();
    if (_isOnline && _myUid != null) {
      final rtdb = ref.read(realtimeGameServiceProvider);
      rtdb.cancelDisconnectHandler(_gameId, _myUid!);
      rtdb.goOffline(_gameId, _myUid!);
    }
    super.dispose();
  }

  void _refreshMoves() {
    _legalMoves = _engine.legalMoves();
    _forcedCells =
        (_legalMoves.isNotEmpty && _legalMoves.first.isCapture && _isHumanTurn)
            ? _legalMoves.map((m) => m.from).toSet()
            : {};
    _recomputeHints();
  }

  void _recomputeHints() {
    _hintCells = {};
    _captureHintCells = {};
    if (_selectedCell == null) return;
    final prefix = _pendingPath.isEmpty ? [_selectedCell!] : _pendingPath;
    for (final m in _legalMoves) {
      if (!_hasPrefix(m.path, prefix)) continue;
      // Next waypoint along the chain
      if (m.path.length > prefix.length) {
        final next = m.path[prefix.length];
        if (m.isCapture) {
          _captureHintCells.add(next);
        } else {
          _hintCells.add(next);
        }
      }
      // Final landing square (lets the user tap the destination directly)
      if (m.isCapture) {
        _captureHintCells.add(m.to);
      } else {
        _hintCells.add(m.to);
      }
    }
  }

  bool _hasPrefix(List<int> path, List<int> prefix) {
    if (prefix.length > path.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  // ── Tap handling ─────────────────────────────────────────────────────────

  void _onCellTap(int cellIdx) {
    if (_engine.result != CheckersResult.ongoing) return;
    if (_thinking) return;
    if (!_isHumanTurn) return;

    final piece = _engine.board[cellIdx];

    // If tapping own piece → select it
    if (piece.belongsTo(_engine.turn)) {
      final movesForPiece =
          _legalMoves.where((m) => m.from == cellIdx).toList();
      if (movesForPiece.isEmpty) {
        // Mandatory capture elsewhere — explain instead of silently ignoring.
        if (_forcedCells.isNotEmpty) {
          _showSnack('Capture is mandatory — highlighted pieces must capture');
        }
        setState(() {
          _selectedCell = null;
          _pendingPath = [];
          _recomputeHints();
        });
        return;
      }
      setState(() {
        _selectedCell = cellIdx;
        _pendingPath = [cellIdx];
        _recomputeHints();
      });
      return;
    }

    // If a piece is selected and tapping a target → resolve against the
    // pending path so multi-jump chains can be picked square by square.
    if (_selectedCell != null) {
      _onTargetTap(cellIdx);
    }
  }

  void _onTargetTap(int t) {
    final prefix = _pendingPath.isEmpty ? [_selectedCell!] : _pendingPath;
    final cands =
        _legalMoves.where((m) => _hasPrefix(m.path, prefix)).toList();

    // 1) Direct destination tap: unique move ending on t → play it.
    final finals = cands.where((m) => m.to == t).toList();
    if (finals.length == 1) {
      _makeMove(finals.first);
      return;
    }

    // 2) Waypoint tap: extend the pending path along matching chains.
    final extended = cands
        .where((m) =>
            m.path.length > prefix.length && m.path[prefix.length] == t)
        .toList();

    if (extended.isEmpty) {
      if (finals.length > 1) {
        _showSnack('Multiple capture routes — tap each square of the route');
        return;
      }
      // Not a valid continuation → clear selection.
      setState(() {
        _selectedCell = null;
        _pendingPath = [];
        _recomputeHints();
      });
      return;
    }

    final newPrefix = [...prefix, t];
    // If the chain is now uniquely determined, play the full move.
    if (extended.length == 1) {
      _makeMove(extended.first);
      return;
    }
    final identical = extended.every((m) => m.samePathAs(extended.first));
    if (identical) {
      _makeMove(extended.first);
      return;
    }
    setState(() {
      _pendingPath = newPrefix;
      _recomputeHints();
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _makeMove(CheckersMove move) {
    // Save an undo snapshot (offline only) before mutating the engine.
    if (!_isOnline) {
      _undoStack.add(_engine.clone());
      if (_undoStack.length > 40) _undoStack.removeAt(0);
    }

    final applied = _engine.makeMove(move);
    if (!applied) return;

    if (_isOnline) _pushAction(move);
    _resetTurnClock();

    setState(() {
      _selectedCell = null;
      _pendingPath = [];
      _refreshMoves();
    });

    if (_engine.result != CheckersResult.ongoing) {
      if (_isOnline) _broadcastGameOver(_engine.result);
      _showResultDialog();
      return;
    }

    if (_vsBot && !_isHumanTurn) {
      _scheduleBotMove();
    }
  }

  // ── Online sync ────────────────────────────────────────────────────────

  void _pushAction(CheckersMove move) {
    final idx = _appliedActions;
    _appliedActions++;
    ref.read(realtimeGameServiceProvider).setAction(_gameId, idx, {
      'uid': _myUid,
      'seat': _mySeat,
      'path': move.path,
      'captured': move.captured,
    });
  }

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
    bool any = false;
    while (_pendingActions.containsKey(_appliedActions)) {
      final map = _pendingActions.remove(_appliedActions)!;
      _appliedActions++;

      if (_engine.result != CheckersResult.ongoing) continue;

      final path =
          (map['path'] as List?)?.map((e) => (e as num).toInt()).toList() ??
              const <int>[];
      final captured =
          (map['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ??
              const <int>[];
      if (path.length < 2) continue;

      final seat = (map['seat'] as num?)?.toInt();
      final expectedSeat = _engine.turn == CheckersPlayer.white ? 0 : 1;
      if (seat != null && seat != expectedSeat) {
        debugPrint('[Checkers] out-of-turn action $seat at ${_appliedActions - 1}');
        continue;
      }

      final ok = _engine.makeMove(CheckersMove(path: path, captured: captured));
      if (!ok) {
        debugPrint('[Checkers] failed to apply action ${_appliedActions - 1}');
        continue;
      }
      any = true;
    }

    if (!any || !mounted) return;
    _resetTurnClock();
    setState(() {
      _selectedCell = null;
      _pendingPath = [];
      _refreshMoves();
    });

    if (_engine.result != CheckersResult.ongoing) {
      _showResultDialog();
    }
  }

  Future<void> _onRemoteGameOver(DatabaseEvent event) async {
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    final resultStr = map['result'] as String?;
    final result = switch (resultStr) {
      'whiteWin' => CheckersResult.whiteWin,
      'blackWin' => CheckersResult.blackWin,
      'draw'     => CheckersResult.draw,
      _          => CheckersResult.ongoing,
    };
    if (result == CheckersResult.ongoing) return;

    // Give the action-log replay a moment to finish (resume case) so the
    // final board state is on screen before the result is forced.
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    if (_engine.result != CheckersResult.ongoing) return; // already ended locally

    _engine.result = result;
    setState(() {});
    _showResultDialog();
  }

  void _broadcastGameOver(CheckersResult result, {String status = 'finished'}) {
    if (!_isOnline) return;
    ref
        .read(realtimeGameServiceProvider)
        .setGameOver(_gameId, result.name, status);
  }

  // ── Online turn timer ────────────────────────────────────────────────────

  void _resetTurnClock() {
    _turnSecondsLeft = _turnTimeLimit;
  }

  void _onTurnTick() {
    if (!_isOnline || !mounted) return;
    if (_engine.result != CheckersResult.ongoing) return;
    if (_engine.moveHistory.isEmpty && _appliedActions == 0) {
      // Don't run the clock before the first move of the game.
      return;
    }

    setState(() => _turnSecondsLeft--);
    if (_turnSecondsLeft > 0) return;

    _resetTurnClock();
    if (!_isHumanTurn) return; // opponent's clock is enforced on their device

    _myTimeouts++;
    if (_myTimeouts >= 3) {
      // Repeated stalling forfeits the game.
      _applyResign();
    } else {
      _showSnack('Time! A move was played automatically (${3 - _myTimeouts} left)');
      if (_legalMoves.isNotEmpty) {
        _makeMove(_legalMoves.first);
      }
    }
  }

  // ── Presence / abandonment ──────────────────────────────────────────────

  void _onOpponentPresence(DatabaseEvent event) {
    final raw = event.snapshot.value;
    final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final online = map?['online'] == true;

    if (online) {
      _opponentSeenOnline = true;
      _abandonTimer?.cancel();
      _abandonTimer = null;
      return;
    }

    // Only an explicit offline record (set by onDisconnect / goOffline)
    // starts the countdown — and only after we've seen them connected.
    if (map == null || !_opponentSeenOnline) return;
    if (_engine.result != CheckersResult.ongoing) return;
    _abandonTimer ??= Timer(const Duration(seconds: _abandonGraceSeconds), () {
      if (!mounted) return;
      if (_engine.result != CheckersResult.ongoing) return;
      final winResult =
          _playerIsWhite ? CheckersResult.whiteWin : CheckersResult.blackWin;
      _engine.result = winResult;
      _broadcastGameOver(winResult, status: 'abandon');
      setState(() {});
      _showResultDialog();
    });
  }

  // ── Undo (offline only) ──────────────────────────────────────────────────

  void _handleUndo() {
    if (_isOnline || _thinking || _undoStack.isEmpty) return;
    setState(() {
      _engine = _undoStack.removeLast();
      _selectedCell = null;
      _pendingPath = [];
      _refreshMoves();
    });
  }

  int get _effectiveDepth {
    // 10×10 international has a much larger branching factor — cap the
    // depth so move times stay reasonable (never raise low difficulties).
    if (_variant == CheckersVariant.international && _botDepth > 5) return 5;
    return _botDepth;
  }

  Future<void> _scheduleBotMove() async {
    setState(() => _thinking = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // The search runs in a background isolate so the UI never janks.
    Map<String, dynamic>? res;
    try {
      res = await compute(checkersBestMoveIsolate, {
        ..._engine.toSearchState(),
        'depth': _effectiveDepth,
      });
    } catch (err) {
      debugPrint('[Checkers] isolate search failed: $err');
      res = null;
    }
    if (!mounted) return;

    if (res != null) {
      final move = CheckersMove(
        path: List<int>.from(res['path'] as List),
        captured: List<int>.from(res['captured'] as List),
      );
      _engine.makeMove(move); // validated against current legal moves
    }
    setState(() {
      _thinking = false;
      _refreshMoves();
    });
    if (_engine.result != CheckersResult.ongoing) {
      _showResultDialog();
    }
  }

  // ── Save game to Firestore ───────────────────────────────────────────────

  Future<void> _saveGame(CheckersResult result) async {
    if (_gameSaved) return;
    _gameSaved = true;

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final myUid = user.uid;
    final oppUid = _opponentUid ?? widget.extra['opponentUid'] as String?;
    final whiteUid = _playerIsWhite ? myUid : oppUid;
    final blackUid = _playerIsWhite ? oppUid : myUid;
    final whiteUsername = _playerIsWhite ? _myUsername : _opponentUsername;
    final blackUsername = _playerIsWhite ? _opponentUsername : _myUsername;

    final gameResult = switch (result) {
      CheckersResult.whiteWin => GameResult.white,
      CheckersResult.blackWin => GameResult.black,
      CheckersResult.draw     => GameResult.draw,
      _                       => GameResult.aborted,
    };

    final won = (_playerIsWhite && result == CheckersResult.whiteWin) ||
        (!_playerIsWhite && result == CheckersResult.blackWin);
    final lost = (_playerIsWhite && result == CheckersResult.blackWin) ||
        (!_playerIsWhite && result == CheckersResult.whiteWin);
    final isDraw = result == CheckersResult.draw;

    try {
      final firestore = ref.read(firestoreServiceProvider);

      // Read the freshest stats so back-to-back rematches don't compound a
      // stale rating snapshot from the cached provider value.
      final freshUser = await firestore.getUser(myUid) ?? user;

      // Compute the point change BEFORE saving the game so my side's
      // before/change is stored on the game doc — the profile rating chart
      // is built from exactly these fields.
      int? myBefore;
      int? myChange;
      Map<String, dynamic>? newStatsMap;
      if (_isRated || _isFakeBotFallback) {
        final stats = freshUser.checkersStats;
        final oppRating = widget.extra['opponentRating'] as int? ?? stats.rating;
        final pointChange = GameType.checkers.calculatePointChange(
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
              draws: stats.draws + (!won && !lost ? 1 : 0),
              rating: stats.rating + pointChange,
            )
            .toMap();
      }

      final game = GameModel(
        id: _gameId,
        mode: _isFakeBotFallback ? GameMode.online : GameMode.values.firstWhere(
          (m) => m.name == _mode,
          orElse: () => GameMode.bot,
        ),
        gameType: 'checkers',
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
        whiteRatingBefore: _playerIsWhite ? myBefore : null,
        blackRatingBefore: _playerIsWhite ? null : myBefore,
        whiteRatingChange: _playerIsWhite ? myChange : null,
        blackRatingChange: _playerIsWhite ? null : myChange,
      );

      await firestore.saveGame(game);
      await firestore.addRecentGameId(myUid, _gameId);

      // Update points for rated games (point-based system)
      if (newStatsMap != null) {
        await firestore.updateUser(myUid, {'checkersStats': newStatsMap});
      }

      // Update campaign progress if player won a campaign game
      if (_mode == 'campaign' && won) {
        final chapter = _campaignChapter ?? 0;
        if (chapter > freshUser.checkersCampaignProgress) {
          await firestore.updateCampaignProgress(myUid, chapter, gameType: 'checkers');
          debugPrint('[Checkers] campaign progress updated → $chapter');
        }
      }

      // Record arena tournament score.
      if (_arenaId != null && !_isLocalGame) {
        await _recordArenaResult(gameResult, won: won, isDraw: isDraw,
            myUid: myUid, oppUid: oppUid);
      }

      debugPrint('[Checkers] saved game $_gameId');
    } catch (e) {
      debugPrint('[Checkers] failed to save game: $e');
    }
  }

  Future<void> _recordArenaResult(GameResult result,
      {required bool won,
      required bool isDraw,
      required String myUid,
      String? oppUid}) async {
    try {
      final tournaments = ref.read(tournamentServiceProvider);
      if (_isOnline && oppUid != null) {
        // Only the white side records to avoid double-counting.
        if (!_playerIsWhite) return;
        final whiteUid = _playerIsWhite ? myUid : oppUid;
        final blackUid = _playerIsWhite ? oppUid : myUid;
        final winnerUid = isDraw
            ? null
            : (result == GameResult.white ? whiteUid : blackUid);
        await tournaments.recordArenaResult(
          tournamentId: _arenaId!,
          whiteUid: whiteUid,
          blackUid: blackUid,
          winnerUid: winnerUid,
          isDraw: isDraw,
        );
      } else {
        // Bot fallback game — only the human has a participant doc.
        await tournaments.recordArenaResultSingle(
          tournamentId: _arenaId!,
          uid: myUid,
          won: won,
          isDraw: isDraw,
        );
      }
      debugPrint('[Checkers] arena result recorded for $_arenaId');
    } catch (e) {
      debugPrint('[Checkers] failed to record arena result: $e');
    }
  }

  // ── Resign ─────────────────────────────────────────────────────────────

  /// In local pass-and-play the side **to move** resigns; in bot/online
  /// games the human resigns.
  CheckersPlayer get _resigningSide =>
      _isLocalGame ? _engine.turn : _humanPlayer;

  Future<void> _handleResign() async {
    final side = _resigningSide;
    final sideName = side == CheckersPlayer.white ? 'White' : 'Black';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardElevated,
        title: Text('Resign', style: GoogleFonts.fraunces(
          fontSize: 20, fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic, color: AppColors.ink,
        )),
        content: Text(
            _isLocalGame
                ? '$sideName resigns — are you sure?'
                : 'Are you sure you want to resign?',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.inkDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Resign', style: GoogleFonts.inter(
              color: AppColors.loss, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _applyResign();
    }
  }

  void _applyResign() {
    final side = _resigningSide;
    final resignResult = side == CheckersPlayer.white
        ? CheckersResult.blackWin
        : CheckersResult.whiteWin;
    _engine.result = resignResult;
    if (_isOnline) _broadcastGameOver(resignResult, status: 'resign');
    setState(() {});
    _showResultDialog();
  }

  // ── Result dialog ────────────────────────────────────────────────────────

  void _showResultDialog() {
    if (_resultShown) return;
    if (_engine.result == CheckersResult.ongoing) return;
    _resultShown = true;

    final result = _engine.result;
    String title;
    Color titleColor;

    // Save game to Firestore
    _saveGame(result);

    if (result == CheckersResult.draw) {
      title = 'Draw';
      titleColor = AppColors.draw;
    } else if (_isLocalGame) {
      // Pass-and-play: announce the winning colour, not "You".
      title = result == CheckersResult.whiteWin ? 'White Won' : 'Black Won';
      titleColor = AppColors.win;
    } else {
      final humanWon =
          (result == CheckersResult.whiteWin && _humanPlayer == CheckersPlayer.white) ||
          (result == CheckersResult.blackWin && _humanPlayer == CheckersPlayer.black);
      title = humanWon ? 'You Won!' : 'You Lost';
      titleColor = humanWon ? AppColors.win : AppColors.loss;
    }

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
              style: GoogleFonts.fraunces(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: titleColor,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'White: ${_engine.countPieces(CheckersPlayer.white)} · '
              'Black: ${_engine.countPieces(CheckersPlayer.black)}',
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
                    child: Text('Exit', style: AppTextStyles.buttonMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (_isOnline) {
                        // Online: go back to matchmaking to find a new opponent.
                        Navigator.pop(context);
                      } else {
                        _resetGame();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6FB4E0),
                      foregroundColor: const Color(0xFF0A0A0B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isOnline ? 'New Game' : 'Rematch',
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
      _engine = CheckersEngine(variant: _variant);
      _selectedCell = null;
      _pendingPath = [];
      _thinking = false;
      _gameSaved = false;
      _resultShown = false;
      _myTimeouts = 0;
      _undoStack.clear();
      _refreshMoves();
    });
    if (_vsBot && !_isHumanTurn) {
      _scheduleBotMove();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final whiteCount = _engine.countPieces(CheckersPlayer.white);
    final blackCount = _engine.countPieces(CheckersPlayer.black);

    // Orientation: when the board is flipped (human plays black), white
    // pieces render at the top — the bars must follow the displayed board.
    final topIsWhite = _flipped;
    final topCount = topIsWhite ? whiteCount : blackCount;
    final bottomCount = topIsWhite ? blackCount : whiteCount;
    final topTurn = _engine.turn ==
        (topIsWhite ? CheckersPlayer.white : CheckersPlayer.black);

    // The opponent (or, in pass-and-play, player 2 from the setup screen)
    // is always shown at the top; the board side is indicated by the disc.
    final topLabel = _opponentUsername;
    final bottomLabel = _myUsername;

    final showClock = _isOnline &&
        _engine.result == CheckersResult.ongoing &&
        (_engine.moveHistory.isNotEmpty || _appliedActions > 0);

    final activeGame = _engine.result == CheckersResult.ongoing &&
        _engine.moveHistory.isNotEmpty;

    return PopScope(
      canPop: !activeGame,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleResign();
      },
      child: Scaffold(
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
            onPressed: () {
              if (activeGame) {
                _handleResign();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⛀ ', style: TextStyle(fontSize: 18)),
              Text(
                switch (_variant) {
                  CheckersVariant.international => 'International',
                  CheckersVariant.turkish       => 'Turkish',
                  CheckersVariant.brazilian     => 'Brazilian',
                  CheckersVariant.russian       => 'Russian',
                  _                             => 'Checkers',
                },
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (_thinking)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6FB4E0),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _PlayerBar(
                label: topLabel,
                count: topCount,
                isWhitePieces: topIsWhite,
                isActive: topTurn,
                secondsLeft: showClock && topTurn ? _turnSecondsLeft : null,
              ),
              // Board
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Builder(builder: (context) {
                      // "Show legal moves" / "Highlight last move" from
                      // Game Settings apply to checkers too.
                      final cache = ref.watch(cacheServiceProvider);
                      final showHints = cache.showLegalMoves;
                      final lastMove = (cache.highlightLastMove &&
                              _engine.moveHistory.isNotEmpty)
                          ? {
                              _engine.moveHistory.last.from,
                              _engine.moveHistory.last.to,
                            }
                          : const <int>{};
                      return CheckersBoardWidget(
                        engine: _engine,
                        selectedCell: _selectedCell,
                        hintCells: showHints ? _hintCells : const {},
                        captureHintCells:
                            showHints ? _captureHintCells : const {},
                        forcedCells: showHints ? _forcedCells : const {},
                        lastMoveCells: lastMove,
                        onCellTap: _onCellTap,
                        flipped: _flipped,
                        lightSquareColor:
                            ref.watch(settingsProvider).boardTheme.lightSquare,
                        darkSquareColor:
                            ref.watch(settingsProvider).boardTheme.darkSquare,
                      );
                    }),
                  ),
                ),
              ),
              _PlayerBar(
                label: bottomLabel,
                count: bottomCount,
                isWhitePieces: !topIsWhite,
                isActive: !topTurn,
                secondsLeft: showClock && !topTurn ? _turnSecondsLeft : null,
              ),
              const SizedBox(height: 12),
              // Action bar
              _ActionBar(
                onUndo: (!_isOnline &&
                        _undoStack.isNotEmpty &&
                        _isHumanTurn &&
                        !_thinking)
                    ? _handleUndo
                    : null,
                onResign: _engine.result == CheckersResult.ongoing
                    ? _handleResign
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Player Bar ──────────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  final String label;
  final int count;
  final bool isWhitePieces;
  final bool isActive;
  final int? secondsLeft;

  const _PlayerBar({
    required this.label,
    required this.count,
    required this.isWhitePieces,
    required this.isActive,
    this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    final lowTime = (secondsLeft ?? 99) <= 10;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF6FB4E0).withValues(alpha: 0.1) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF6FB4E0).withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Piece indicator
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhitePieces ? const Color(0xFFF5F0E0) : const Color(0xFF2A2017),
              border: Border.all(
                color: isWhitePieces ? const Color(0xFFD4C5A9) : const Color(0xFF4A4030),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const Spacer(),
          if (secondsLeft != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (lowTime ? AppColors.loss : const Color(0xFF6FB4E0))
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${secondsLeft}s',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: lowTime ? AppColors.loss : const Color(0xFF6FB4E0),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Piece count
          Text(
            '$count pieces',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.inkDim,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF6FB4E0),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action Bar ──────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final VoidCallback? onUndo;
  final VoidCallback? onResign;

  const _ActionBar({this.onUndo, this.onResign});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionBtn(
            icon: PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.regular),
            label: 'Undo',
            onTap: onUndo,
          ),
          const SizedBox(width: 16),
          _ActionBtn(
            icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
            label: 'Resign',
            onTap: onResign,
            color: AppColors.loss,
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.inkDim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
