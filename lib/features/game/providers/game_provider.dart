import 'dart:async';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/game_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/elo_service.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/realtime_game_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/tournament_service.dart';
import '../engine/chess_engine.dart';
import '../engine/stockfish_service.dart';

enum GameStatus {
  waiting,
  playing,
  paused,
  checkmate,
  stalemate,
  draw,
  resign,
  timeout,
  aborted,
}

enum RematchState { none, inviteSent, inviteReceived, accepted, declined }

@immutable
class GameState {
  final ChessEngine engine;
  final GameStatus status;
  final bool playerIsWhite;
  final int whiteMsLeft;
  final int blackMsLeft;
  final String? selectedSquare;
  final List<String> legalMoveSquares;
  final bool isBotThinking;
  final GameResult? result;
  final int? whiteRatingBefore;
  final int? blackRatingBefore;
  final int? whiteRatingChange;
  final int? blackRatingChange;
  final bool needsPromotion;
  final String? promotionFrom;
  final String? promotionTo;
  final int? reviewIndex;
  final RematchState rematchState;
  final String? rematchNewGameId;
  final bool drawOfferPending;      // opponent offered draw to me
  final bool drawOfferSent;         // I sent a draw offer (waiting for response)
  final bool opponentDisconnected;  // opponent lost connection
  final int disconnectSecondsLeft;  // countdown before forfeit
  final String? pendingMoveFrom;    // confirmMoves: move waiting for user confirmation
  final String? pendingMoveTo;
  final String? premoveFrom;        // premove: queued while it is the opponent's turn
  final String? premoveTo;
  // Campaign objectives: [won, captured, under40moves] — set at game end
  final List<bool> campaignObjectivesDone;

  const GameState({
    required this.engine,
    required this.status,
    required this.playerIsWhite,
    required this.whiteMsLeft,
    required this.blackMsLeft,
    this.selectedSquare,
    this.legalMoveSquares = const [],
    this.isBotThinking = false,
    this.result,
    this.whiteRatingBefore,
    this.blackRatingBefore,
    this.whiteRatingChange,
    this.blackRatingChange,
    this.needsPromotion = false,
    this.promotionFrom,
    this.promotionTo,
    this.reviewIndex,
    this.rematchState = RematchState.none,
    this.rematchNewGameId,
    this.drawOfferPending = false,
    this.drawOfferSent = false,
    this.opponentDisconnected = false,
    this.disconnectSecondsLeft = 0,
    this.pendingMoveFrom,
    this.pendingMoveTo,
    this.premoveFrom,
    this.premoveTo,
    this.campaignObjectivesDone = const [false, false, false],
  });

  bool get isInReview => reviewIndex != null;

  bool get isMyTurn =>
      (playerIsWhite && engine.isWhiteTurn) ||
      (!playerIsWhite && !engine.isWhiteTurn);

  GameState copyWith({
    GameStatus? status,
    bool? playerIsWhite,
    int? whiteMsLeft,
    int? blackMsLeft,
    String? selectedSquare,
    List<String>? legalMoveSquares,
    bool? isBotThinking,
    GameResult? result,
    int? whiteRatingBefore,
    int? blackRatingBefore,
    int? whiteRatingChange,
    int? blackRatingChange,
    bool? needsPromotion,
    String? promotionFrom,
    String? promotionTo,
    bool clearSelection = false,
    int? reviewIndex,
    bool clearReview = false,
    RematchState? rematchState,
    String? rematchNewGameId,
    bool? drawOfferPending,
    bool? drawOfferSent,
    bool? opponentDisconnected,
    int? disconnectSecondsLeft,
    String? pendingMoveFrom,
    String? pendingMoveTo,
    bool clearPendingMove = false,
    String? premoveFrom,
    String? premoveTo,
    bool clearPremove = false,
    List<bool>? campaignObjectivesDone,
  }) {
    return GameState(
      engine: engine,
      status: status ?? this.status,
      playerIsWhite: playerIsWhite ?? this.playerIsWhite,
      whiteMsLeft: whiteMsLeft ?? this.whiteMsLeft,
      blackMsLeft: blackMsLeft ?? this.blackMsLeft,
      selectedSquare:
          clearSelection ? null : (selectedSquare ?? this.selectedSquare),
      legalMoveSquares:
          clearSelection ? [] : (legalMoveSquares ?? this.legalMoveSquares),
      isBotThinking: isBotThinking ?? this.isBotThinking,
      result: result ?? this.result,
      whiteRatingBefore: whiteRatingBefore ?? this.whiteRatingBefore,
      blackRatingBefore: blackRatingBefore ?? this.blackRatingBefore,
      whiteRatingChange: whiteRatingChange ?? this.whiteRatingChange,
      blackRatingChange: blackRatingChange ?? this.blackRatingChange,
      needsPromotion: needsPromotion ?? this.needsPromotion,
      promotionFrom: promotionFrom ?? this.promotionFrom,
      promotionTo: promotionTo ?? this.promotionTo,
      reviewIndex: clearReview ? null : (reviewIndex ?? this.reviewIndex),
      rematchState: rematchState ?? this.rematchState,
      rematchNewGameId: rematchNewGameId ?? this.rematchNewGameId,
      drawOfferPending: drawOfferPending ?? this.drawOfferPending,
      drawOfferSent: drawOfferSent ?? this.drawOfferSent,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
      disconnectSecondsLeft:
          disconnectSecondsLeft ?? this.disconnectSecondsLeft,
      pendingMoveFrom:
          clearPendingMove ? null : (pendingMoveFrom ?? this.pendingMoveFrom),
      pendingMoveTo:
          clearPendingMove ? null : (pendingMoveTo ?? this.pendingMoveTo),
      premoveFrom: clearPremove ? null : (premoveFrom ?? this.premoveFrom),
      premoveTo:   clearPremove ? null : (premoveTo   ?? this.premoveTo),
      campaignObjectivesDone: campaignObjectivesDone ?? this.campaignObjectivesDone,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final GameMode mode;
  final TimeControl timeControl;
  final bool playerIsWhite;
  final int? botRating;
  final bool isRated;
  final String? gameId;
  final int? campaignChapter;
  final String? opponentUid;
  final int? opponentRating;
  final String? myUsername;
  final String? opponentUsername;
  final String? arenaId; // non-null when this is an arena tournament game
  final bool isFakeBotFallback; // true → disguise bot game as online
  final String gameType; // 'chess', 'checkers', 'domino'
  final Ref _ref;

  Timer? _clockTimer;
  // Internal ms trackers — updated every 100ms tick, but state only emits on
  // second-boundary changes to avoid 10 rebuilds/sec.
  int _internalWhiteMs = 0;
  int _internalBlackMs = 0;
  final _stockfish = StockfishService();
  late final String _gameId;

  // ── Campaign objective tracking ───────────────────────────────────────────
  bool _hadCapture = false; // true once the player captures any piece

  // ── Online-only ────────────────────────────────────────────────────────────
  String? _myUid;
  StreamSubscription<DatabaseEvent>? _moveSub;
  StreamSubscription<DatabaseEvent>? _gameOverSub;
  StreamSubscription<DatabaseEvent>? _rematchSub;
  StreamSubscription<DatabaseEvent>? _drawOfferSub;
  StreamSubscription<DatabaseEvent>? _presenceSub;
  Timer? _disconnectTimer;
  final _seenMoveKeys = <String>{};

  GameNotifier({
    required this.mode,
    required this.timeControl,
    required this.playerIsWhite,
    this.botRating,
    this.isRated = false,
    this.gameId,
    this.campaignChapter,
    this.opponentUid,
    this.opponentRating,
    this.myUsername,
    this.opponentUsername,
    this.arenaId,
    this.isFakeBotFallback = false,
    this.gameType = 'chess',
    required Ref ref,
  })  : _ref = ref,
        super(GameState(
          engine: ChessEngine(),
          status: GameStatus.playing,
          playerIsWhite: playerIsWhite,
          whiteMsLeft: timeControl.totalSeconds * 1000,
          blackMsLeft: timeControl.totalSeconds * 1000,
        )) {
    _gameId = gameId ?? const Uuid().v4();
    _internalWhiteMs = timeControl.totalSeconds * 1000;
    _internalBlackMs = timeControl.totalSeconds * 1000;

    if (mode == GameMode.online) {
      // H-5: Don't start the clock until _checkStaleGameOver() completes.
      // If we started it in the constructor, the clock would tick briefly even
      // for games that already ended while the player was offline.
      _initOnline();
    } else {
      _startClock();
    }

    if ((mode == GameMode.bot || mode == GameMode.campaign) && !playerIsWhite) {
      _requestBotMove();
    }
  }

  // ── Online sync ────────────────────────────────────────────────────────────

  void _initOnline() {
    final auth = _ref.read(authStateProvider).valueOrNull;
    _myUid = auth?.uid;

    final rtdb = _ref.read(realtimeGameServiceProvider);
    _moveSub = rtdb.watchMoves(_gameId).listen(_onRemoteMove);
    _gameOverSub = rtdb.watchGameOver(_gameId).listen(_onRemoteGameOver);
    _rematchSub = rtdb.watchRematch(_gameId).listen(_onRematchUpdate);
    _drawOfferSub = rtdb.watchDrawOffer(_gameId).listen(_onDrawOfferUpdate);

    // Mark user as in-game for spectator feature
    if (_myUid != null) {
      _ref.read(firestoreServiceProvider).setCurrentGame(_myUid!, _gameId);
      // Go online + register onDisconnect handler
      rtdb.goOnline(_gameId, _myUid!);

      // Log game_start
      _ref.read(logServiceProvider).log(
        uid: _myUid!,
        username: myUsername ?? 'unknown',
        type: 'game_start',
        metadata: {
          'gameId': _gameId,
          'opponentUid': opponentUid ?? '',
          'opponentUsername': opponentUsername ?? '',
          'timeControl': timeControl.label,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'other',
        },
      );
    }

    // Watch opponent's presence (disconnect detection)
    if (opponentUid != null) {
      _presenceSub = rtdb
          .watchPresence(_gameId, opponentUid!)
          .listen(_onOpponentPresence);
    }

    debugPrint('[Online] watching $_gameId as '
        '${playerIsWhite ? "white" : "black"} (uid: $_myUid)');

    // Check if the game already ended while this client was offline.
    // Start the clock only after the check completes — avoids ticking on a
    // game that's already over (H-5).
    _checkStaleGameOver().then((_) {
      if (mounted && state.status == GameStatus.playing) _startClock();
    });
  }

  /// One-shot read of the gameOver RTDB node on session start.
  /// Handles the case where the opponent wrote the result while this player
  /// was offline (or the app was backgrounded / killed mid-game).
  Future<void> _checkStaleGameOver() async {
    try {
      final rtdb = _ref.read(realtimeGameServiceProvider);
      final data = await rtdb.getGameOver(_gameId);
      if (data == null) return;
      if (state.status != GameStatus.playing) return; // already resolved locally

      final resultStr = data['result'] as String?;
      final statusStr = data['status'] as String?;
      if (resultStr == null) return;

      final result = GameResult.values.firstWhere(
        (r) => r.name == resultStr,
        orElse: () => GameResult.draw,
      );
      final status = GameStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => GameStatus.checkmate,
      );

      debugPrint('[Online] stale game-over found: $resultStr / $statusStr');
      _clockTimer?.cancel();
      state = state.copyWith(status: status, result: result);

      // Save first: the rating Cloud Function reads games/{gameId}.
      await _saveGame(result);
      if ((isRated && mode == GameMode.online) || isFakeBotFallback) {
        await _processRatingChange(result);
      }
      if (arenaId != null && playerIsWhite) await _recordArenaResult(result);
    } catch (e) {
      debugPrint('[Online] stale game-over check failed: $e');
    }
  }

  /// Grace period in seconds based on time control.
  int get _gracePeriodSeconds {
    final totalSec = timeControl.totalSeconds;
    if (totalSec <= 180) return 15;  // bullet  (≤ 3 min)
    if (totalSec <= 600) return 30;  // blitz   (≤ 10 min)
    return 60;                        // rapid   (> 10 min)
  }

  void _onOpponentPresence(DatabaseEvent event) {
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    final isOnline = map['online'] as bool? ?? true;

    if (!isOnline && state.status == GameStatus.playing) {
      _startDisconnectCountdown();
    } else if (isOnline && state.opponentDisconnected) {
      _cancelDisconnectCountdown();
    }
  }

  void _startDisconnectCountdown() {
    if (state.opponentDisconnected) return; // already counting
    final grace = _gracePeriodSeconds;
    state = state.copyWith(
      opponentDisconnected: true,
      disconnectSecondsLeft: grace,
    );
    // Pause the running clock while opponent is offline
    _clockTimer?.cancel();

    _disconnectTimer?.cancel();
    _disconnectTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.disconnectSecondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        // Grace period expired → opponent forfeits
        _onOpponentForfeit();
      } else {
        state = state.copyWith(disconnectSecondsLeft: left);
      }
    });

    debugPrint('[Online] opponent disconnected — ${grace}s grace period');
  }

  void _cancelDisconnectCountdown() {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    state = state.copyWith(
      opponentDisconnected: false,
      disconnectSecondsLeft: 0,
    );
    // M-13: Only resume the clock if the game is still in progress.
    // Previously _startClock() was called unconditionally, which restarted the
    // timer even after checkmate/stalemate/timeout had already ended the game.
    if (state.status == GameStatus.playing) {
      _startClock();
      debugPrint('[Online] opponent reconnected — clock resumed');
    }
  }

  void _onOpponentForfeit() {
    if (state.status != GameStatus.playing) return;
    debugPrint('[Online] opponent did not reconnect — they forfeit');
    final iWin = playerIsWhite ? GameResult.white : GameResult.black;
    _endGame(iWin, GameStatus.timeout);
  }

  void _onDrawOfferUpdate(DatabaseEvent event) {
    final raw = event.snapshot.value;
    if (raw == null) {
      // Offer was cleared (accepted / declined / game ended)
      if (state.drawOfferPending || state.drawOfferSent) {
        state = state.copyWith(drawOfferPending: false, drawOfferSent: false);
      }
      return;
    }
    final map = Map<String, dynamic>.from(raw as Map);
    final fromUid = map['fromUid'] as String?;
    if (fromUid == _myUid) {
      // My own offer echoed back — confirm sent state
      state = state.copyWith(drawOfferSent: true, drawOfferPending: false);
    } else {
      // Opponent sent an offer
      state = state.copyWith(drawOfferPending: true, drawOfferSent: false);
    }
  }

  void _onRemoteMove(DatabaseEvent event) {
    final key = event.snapshot.key;
    if (key == null) return;
    if (_seenMoveKeys.contains(key)) return;
    _seenMoveKeys.add(key);

    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);

    if (map['uid'] == _myUid) return; // my own move, already applied
    if (state.status != GameStatus.playing) return;

    final from = map['from'] as String? ?? '';
    final to = map['to'] as String? ?? '';
    final promotion = map['promotion'] as String?;
    if (from.isEmpty || to.isEmpty) return;

    debugPrint('[Online] remote move $from→$to');
    _applyOpponentMove(from, to, promotion: promotion);
  }

  Future<void> _onRemoteGameOver(DatabaseEvent event) async {
    if (state.status != GameStatus.playing) return;
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);

    final resultStr = map['result'] as String?;
    final statusStr = map['status'] as String?;
    if (resultStr == null) return;

    final result = GameResult.values.firstWhere(
      (r) => r.name == resultStr,
      orElse: () => GameResult.draw,
    );
    final status = GameStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => GameStatus.checkmate,
    );

    debugPrint('[Online] remote game over: $resultStr / $statusStr');
    _clockTimer?.cancel();
    state = state.copyWith(status: status, result: result);

    // The game document MUST exist before the rating Cloud Function runs —
    // it reads games/{gameId} to validate the result server-side.
    await _saveGame(result);
    if (isRated) await _processRatingChange(result);
    // White always records arena score (prevents double-counting)
    if (arenaId != null && playerIsWhite) await _recordArenaResult(result);
  }

  void _onRematchUpdate(DatabaseEvent event) {
    if (state.rematchState == RematchState.accepted) return;
    final raw = event.snapshot.value;
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);

    final requestedBy = map['requestedBy'] as String?;
    final newGameId = map['newGameId'] as String?;
    final status = map['status'] as String?;

    if (status == 'accepted') {
      state = state.copyWith(
        rematchState: RematchState.accepted,
        rematchNewGameId: newGameId,
      );
    } else if (status == 'pending' && requestedBy != _myUid) {
      // Opponent sent us a rematch invite
      state = state.copyWith(
        rematchState: RematchState.inviteReceived,
        rematchNewGameId: newGameId,
      );
    } else if (status == 'declined') {
      state = state.copyWith(rematchState: RematchState.none);
    }
  }

  void _applyOpponentMove(String from, String to, {String? promotion}) {
    if (state.status != GameStatus.playing) return;
    final isCapture = state.engine.pieceAt(to) != null;
    final success = state.engine.makeMove(from, to, promotion: promotion);
    if (!success) {
      debugPrint('[Online] Failed to apply remote move $from→$to');
      return;
    }
    _applyIncrementIfNeeded();
    state = state.copyWith(clearSelection: true);
    _playMoveSound(isCapture: isCapture);
    _checkGameOver();

    // Execute queued premove now that it is our turn
    if (state.status == GameStatus.playing) {
      _executePremoveIfQueued();
    }
  }

  /// Executes the queued premove if one is set and it is now our turn.
  void _executePremoveIfQueued() {
    final premFrom = state.premoveFrom;
    final premTo   = state.premoveTo;
    if (premFrom == null || premTo == null) return;
    if (!state.isMyTurn) return;

    // Clear premove state before executing to prevent re-entrancy
    state = state.copyWith(clearPremove: true);

    // Verify the premove is still legal in the current position
    final legal = state.engine.legalMovesFrom(premFrom);
    if (!legal.contains(premTo)) {
      debugPrint('[Premove] $premFrom→$premTo became illegal — discarded');
      return;
    }
    _attemptMove(premFrom, premTo);
  }

  void _pushMoveToRtdb(String from, String to, {String? promotion}) {
    final rtdb = _ref.read(realtimeGameServiceProvider);
    rtdb.pushMove(_gameId, {
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
      'uid': _myUid ?? '',
    });
  }

  // ── Rematch ────────────────────────────────────────────────────────────────

  Future<void> sendRematch() async {
    if (state.rematchState != RematchState.none) return;
    final newGameId = const Uuid().v4();

    // Colors swap in rematch
    final iWillBeWhite = !playerIsWhite;
    final opponentWillBeWhite = playerIsWhite;

    state = state.copyWith(
      rematchState: RematchState.inviteSent,
      rematchNewGameId: newGameId,
    );

    try {
      final rtdb = _ref.read(realtimeGameServiceProvider);
      await rtdb.sendRematchInvite(
        originalGameId: _gameId,
        newGameId: newGameId,
        fromUid: _myUid ?? '',
        whiteUidInNew:
            iWillBeWhite ? (_myUid ?? '') : (opponentUid ?? ''),
        blackUidInNew:
            opponentWillBeWhite ? (_myUid ?? '') : (opponentUid ?? ''),
        timeControlLabel: timeControl.label,
      );
    } catch (e) {
      debugPrint('[Rematch] failed to send invite: $e');
      state = state.copyWith(rematchState: RematchState.none);
    }
  }

  Future<void> acceptRematch() async {
    if (state.rematchState != RematchState.inviteReceived) return;
    try {
      final rtdb = _ref.read(realtimeGameServiceProvider);
      await rtdb.acceptRematch(_gameId);
      state = state.copyWith(rematchState: RematchState.accepted);
    } catch (e) {
      debugPrint('[Rematch] failed to accept: $e');
    }
  }

  void declineRematch() {
    if (state.rematchState != RematchState.inviteReceived) return;
    final rtdb = _ref.read(realtimeGameServiceProvider);
    rtdb.declineRematch(_gameId);
    state = state.copyWith(rematchState: RematchState.none);
  }

  // ── Clock ──────────────────────────────────────────────────────────────────

  // Track the last second boundary for low-time ticking
  int _lastTickSecond = -1;

  void _startClock() {
    _clockTimer?.cancel();
    _lastTickSecond = -1;
    // Sync internal trackers with current state.
    _internalWhiteMs = state.whiteMsLeft;
    _internalBlackMs = state.blackMsLeft;

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.status != GameStatus.playing) {
        _clockTimer?.cancel();
        return;
      }
      if (state.engine.isWhiteTurn) {
        final newMs = _internalWhiteMs - 100;
        if (newMs <= 0) {
          _endGame(GameResult.black, GameStatus.timeout);
          return;
        }
        _internalWhiteMs = newMs;
        // Only push state when the displayed second changes (1 rebuild/sec)
        // or under 10 s remaining (10 rebuilds/sec for smooth countdown).
        final oldSec = state.whiteMsLeft ~/ 1000;
        final newSec = newMs ~/ 1000;
        if (oldSec != newSec || newMs <= 10000) {
          state = state.copyWith(whiteMsLeft: newMs);
        }
        _maybePlayLowTimeTick(isMyTurn: playerIsWhite, msLeft: newMs);
      } else {
        final newMs = _internalBlackMs - 100;
        if (newMs <= 0) {
          _endGame(GameResult.white, GameStatus.timeout);
          return;
        }
        _internalBlackMs = newMs;
        final oldSec = state.blackMsLeft ~/ 1000;
        final newSec = newMs ~/ 1000;
        if (oldSec != newSec || newMs <= 10000) {
          state = state.copyWith(blackMsLeft: newMs);
        }
        _maybePlayLowTimeTick(isMyTurn: !playerIsWhite, msLeft: newMs);
      }
    });
  }

  /// Plays a tick sound once per second when it is my turn and ≤10 s remain.
  void _maybePlayLowTimeTick({required bool isMyTurn, required int msLeft}) {
    if (!isMyTurn) return;
    if (msLeft > 10000) return; // only in last 10 seconds
    final cache = _ref.read(cacheServiceProvider);
    if (!cache.soundEnabled || !cache.soundLowTimeTick) return;
    final currentSecond = msLeft ~/ 1000;
    if (currentSecond != _lastTickSecond) {
      _lastTickSecond = currentSecond;
      _ref.read(soundServiceProvider).play(ChessSound.move); // short tap
    }
  }

  // ── Review ─────────────────────────────────────────────────────────────────

  void goToReview(int index) {
    final count = state.engine.moveCount;
    if (count == 0) return;
    state = state.copyWith(reviewIndex: index.clamp(0, count));
  }

  void reviewFirst() => goToReview(0);
  void reviewPrev() => goToReview((state.reviewIndex ?? state.engine.moveCount) - 1);
  void reviewNext() => goToReview((state.reviewIndex ?? state.engine.moveCount) + 1);
  void exitReview() => state = state.copyWith(clearReview: true);

  // ── Move handling ──────────────────────────────────────────────────────────

  void onSquareTapped(String square) {
    if (state.status != GameStatus.playing) return;
    if (state.isInReview) { exitReview(); return; }
    if (state.needsPromotion) return;
    if (state.isBotThinking) return;

    // ── Premove: queue a move while waiting for opponent ─────────────────────
    if (mode == GameMode.online && !state.isMyTurn) {
      final cache = _ref.read(cacheServiceProvider);
      if (!cache.premove) return;

      if (state.premoveFrom == null) {
        // Pick piece to premove
        final piece = state.engine.pieceAt(square);
        if (piece == null) return;
        final isMyPiece = (playerIsWhite && piece.isWhite) ||
            (!playerIsWhite && !piece.isWhite);
        if (!isMyPiece) return;
        state = state.copyWith(premoveFrom: square, clearSelection: true);
      } else if (state.premoveFrom == square) {
        // Tap same square → cancel premove selection
        state = state.copyWith(clearPremove: true);
      } else {
        // Set premove destination (any target square)
        state = state.copyWith(premoveTo: square);
      }
      return;
    }

    if (mode != GameMode.local && !state.isMyTurn) return;

    final selected = state.selectedSquare;

    if (selected == null) {
      final piece = state.engine.pieceAt(square);
      if (piece == null) return;
      final isCorrectColor = (state.engine.isWhiteTurn && piece.isWhite) ||
          (!state.engine.isWhiteTurn && !piece.isWhite);
      if (!isCorrectColor) return;
      state = state.copyWith(
        selectedSquare: square,
        legalMoveSquares: state.engine.legalMovesFrom(square),
      );
    } else if (selected == square) {
      state = state.copyWith(clearSelection: true);
    } else if (state.legalMoveSquares.contains(square)) {
      _attemptMove(selected, square);
    } else {
      final piece = state.engine.pieceAt(square);
      if (piece != null) {
        final isCorrectColor = (state.engine.isWhiteTurn && piece.isWhite) ||
            (!state.engine.isWhiteTurn && !piece.isWhite);
        if (isCorrectColor) {
          state = state.copyWith(
            selectedSquare: square,
            legalMoveSquares: state.engine.legalMovesFrom(square),
          );
          return;
        }
      }
      state = state.copyWith(clearSelection: true);
    }
  }

  void _attemptMove(String from, String to) {
    final cache = _ref.read(cacheServiceProvider);
    if (state.engine.needsPromotion(from, to)) {
      // Auto-queen: skip the promotion sheet
      if (cache.autoQueen) {
        _executeMove(from, to, promotion: 'q');
        return;
      }
      state = state.copyWith(
        needsPromotion: true,
        promotionFrom: from,
        promotionTo: to,
        clearSelection: true,
      );
      return;
    }
    // Confirm-moves: stage the move and wait for explicit confirmation
    if (cache.confirmMoves) {
      state = state.copyWith(
        pendingMoveFrom: from,
        pendingMoveTo: to,
        clearSelection: true,
      );
      return;
    }
    _executeMove(from, to);
  }

  /// Confirms the pending move (called from UI confirm button).
  void confirmPendingMove() {
    final from = state.pendingMoveFrom;
    final to   = state.pendingMoveTo;
    if (from == null || to == null) return;
    state = state.copyWith(clearPendingMove: true);
    _executeMove(from, to);
  }

  /// Cancels the pending move (called from UI cancel button).
  void cancelPendingMove() {
    state = state.copyWith(clearPendingMove: true);
  }

  /// Cancels any queued premove.
  void cancelPremove() {
    state = state.copyWith(clearPremove: true);
  }

  void selectPromotion(String piece) {
    if (!state.needsPromotion) return;
    final from = state.promotionFrom!;
    final to   = state.promotionTo!;
    // M-7: Clear the promotion flag BEFORE executing the move.
    // If we cleared it after, a checkmate on the promotion move would end the
    // game first, leaving needsPromotion=true and the sheet visible indefinitely.
    state = state.copyWith(needsPromotion: false);
    _executeMove(from, to, promotion: piece);
  }

  void _executeMove(String from, String to, {String? promotion}) {
    final isCapture = state.engine.pieceAt(to) != null;
    // Track player captures for campaign objective "Make a capture"
    if (isCapture && mode == GameMode.campaign) {
      final isPlayerTurn = state.engine.isWhiteTurn == playerIsWhite;
      if (isPlayerTurn) _hadCapture = true;
    }
    final success = state.engine.makeMove(from, to, promotion: promotion);
    if (!success) return;

    _applyIncrementIfNeeded();
    state = state.copyWith(clearSelection: true);

    if (mode == GameMode.online) {
      _pushMoveToRtdb(from, to, promotion: promotion);
    }

    _playMoveSound(isCapture: isCapture);
    _checkGameOver();
    if (state.status == GameStatus.playing &&
        (mode == GameMode.bot || mode == GameMode.campaign)) {
      _requestBotMove();
    }
  }

  void _playMoveSound({bool isCapture = false}) {
    final cache = _ref.read(cacheServiceProvider);
    if (!cache.soundEnabled) return;
    final sound = _ref.read(soundServiceProvider);
    if (state.engine.isCheck) {
      // Re-use the "check" sound for in-check moves; gated by soundCheckMate toggle
      if (cache.soundCheckMate) sound.play(ChessSound.check);
    } else if (isCapture) {
      if (cache.soundCaptures) sound.play(ChessSound.capture);
    } else {
      if (cache.soundPieceMoves) sound.play(ChessSound.move);
    }
  }

  void _applyIncrementIfNeeded() {
    if (timeControl.incrementSeconds == 0) return;
    final inc = timeControl.incrementSeconds * 1000;
    if (state.engine.isWhiteTurn) {
      _internalBlackMs += inc;
      state = state.copyWith(blackMsLeft: _internalBlackMs);
    } else {
      _internalWhiteMs += inc;
      state = state.copyWith(whiteMsLeft: _internalWhiteMs);
    }
  }

  void _checkGameOver() {
    final engine = state.engine;
    if (engine.isCheckmate) {
      _endGame(
        engine.isWhiteTurn ? GameResult.black : GameResult.white,
        GameStatus.checkmate,
      );
    } else if (engine.isStalemate) {
      _endGame(GameResult.draw, GameStatus.stalemate);
    } else if (engine.isDraw) {
      _endGame(GameResult.draw, GameStatus.draw);
    }
  }

  // ── Bot ────────────────────────────────────────────────────────────────────

  Future<void> _requestBotMove() async {
    if (state.status != GameStatus.playing) return;
    if (state.engine.isWhiteTurn == playerIsWhite) return;

    final moves = state.engine.allLegalMoveSans;
    if (moves.isEmpty) return;
    final randomMove = moves[Random().nextInt(moves.length)];

    state = state.copyWith(isBotThinking: true);

    int? overrideDepth;
    int? overrideDelayMs;
    if (mode == GameMode.campaign && campaignChapter != null) {
      // overrideDelayMs must be > 350 so getBestMove uses the Stockfish API
      // (which has built-in repetition detection) instead of the local minimax
      // (which only counts material and can oscillate on repeated positions).
      if (campaignChapter! <= 30) { overrideDepth = 2; overrideDelayMs = 400; }
      else if (campaignChapter! <= 70) { overrideDepth = 4; overrideDelayMs = 500; }
      else { overrideDepth = 7; overrideDelayMs = 600; }
    }
    // Regular bot: no overrideDelayMs (let _thinkingMs apply a natural delay)
    // and no overrideDepth (let _depthForElo pick based on rating).

    // Timeout must be large enough for the Stockfish API to respond at depth 15.
    // API call takes up to 4 s + visual thinking delay (up to 1.2 s) = allow 7 s.
    const apiTimeoutSec = 7;

    String bestMove;
    try {
      final result = await _stockfish.getBestMove(
        fen: state.engine.fen,
        botRating: botRating ?? 1200,
        moves: moves,
        overrideDepth: overrideDepth,
        overrideDelayMs: overrideDelayMs,
      ).timeout(const Duration(seconds: apiTimeoutSec), onTimeout: () => randomMove);
      bestMove = result ?? randomMove;
    } catch (e) {
      bestMove = randomMove;
    }

    if (!mounted) return;
    if (state.engine.isWhiteTurn == playerIsWhite) return;

    state = state.copyWith(isBotThinking: false);
    if (state.status != GameStatus.playing) return;
    if (state.reviewIndex != null) state = state.copyWith(clearReview: true);

    if (bestMove.length >= 4 &&
        bestMove[0].compareTo('a') >= 0 &&
        bestMove[0].compareTo('h') <= 0) {
      final from = bestMove.substring(0, 2);
      final to = bestMove.substring(2, 4);
      final promo = bestMove.length == 5 ? bestMove[4] : null;
      _executeMove(from, to, promotion: promo);
    } else {
      // M-11: SAN fallback — also play move sound (was missing before).
      final ok = state.engine.makeSanMove(bestMove);
      if (!ok) state.engine.makeSanMove(randomMove);
      _applyIncrementIfNeeded();
      state = state.copyWith(clearSelection: true);
      _playMoveSound(isCapture: false);
      _checkGameOver();
    }
  }

  // ── Game control ───────────────────────────────────────────────────────────

  void resign() {
    final winner = playerIsWhite ? GameResult.black : GameResult.white;
    _endGame(winner, GameStatus.resign);
  }

  void offerDraw() {
    if (mode != GameMode.online && !isFakeBotFallback) return;
    if (state.status != GameStatus.playing) return;
    if (state.drawOfferSent || state.drawOfferPending) return;

    // Fake-bot: simulate opponent responding after a short delay
    if (isFakeBotFallback) {
      _fakeBotRespondToDraw();
      return;
    }

    final rtdb = _ref.read(realtimeGameServiceProvider);
    rtdb.sendDrawOffer(_gameId, _myUid ?? '');
    // drawOfferSent will be set true via the RTDB echo in _onDrawOfferUpdate
  }

  /// Simulates the fake opponent reacting to a draw offer.
  /// Bot accepts ~25 % of the time after 1.5-3 s, otherwise silently declines.
  void _fakeBotRespondToDraw() {
    state = state.copyWith(drawOfferSent: true);
    final delayMs = 1500 + Random().nextInt(1500);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (state.status != GameStatus.playing) return;
      state = state.copyWith(drawOfferSent: false);
      if (Random().nextDouble() < 0.25) {
        // Bot accepts → end as draw
        _endGame(GameResult.draw, GameStatus.draw);
      }
      // Otherwise decline silently — button re-enables automatically
    });
  }

  Future<void> acceptDraw() async {
    if (!state.drawOfferPending) return;
    try {
      // Clear offer node first so opponent doesn't see it again
      await _ref.read(realtimeGameServiceProvider).clearDrawOffer(_gameId);
    } catch (_) {}
    _endGame(GameResult.draw, GameStatus.draw);
  }

  void declineDraw() {
    if (!state.drawOfferPending) return;
    _ref.read(realtimeGameServiceProvider).clearDrawOffer(_gameId);
    state = state.copyWith(drawOfferPending: false);
  }

  Future<void> _endGame(GameResult result, GameStatus status) async {
    if (state.status != GameStatus.playing) return;
    _clockTimer?.cancel();
    state = state.copyWith(
      status: status,
      result: result,
      drawOfferPending: false,
      drawOfferSent: false,
    );

    // Play win/lose/draw sound (respects per-effect cache toggles)
    final cache = _ref.read(cacheServiceProvider);
    final sound = _ref.read(soundServiceProvider);
    if (cache.soundEnabled) {
      if (result == GameResult.draw) {
        if (cache.soundPieceMoves) sound.play(ChessSound.move);
      } else {
        final iWon = (playerIsWhite && result == GameResult.white) ||
            (!playerIsWhite && result == GameResult.black);
        if (cache.soundVictoryFanfare) {
          sound.play(iWon ? ChessSound.win : ChessSound.lose);
        }
      }
    }

    // Broadcast to opponent via RTDB
    if (mode == GameMode.online) {
      try {
        final rtdb = _ref.read(realtimeGameServiceProvider);
        await rtdb.setGameOver(_gameId, result.name, status.name);
        // Clean up draw offer node if one was pending
        await rtdb.clearDrawOffer(_gameId);
      } catch (e) {
        debugPrint('[Online] failed to write game-over: $e');
      }
    }

    // The game document MUST be saved BEFORE the rating Cloud Function runs:
    // processGameRating reads games/{gameId} to validate the result, and the
    // doc is only created here. (Calling the CF first made it fail with
    // not-found every time; the local fallback write was then rejected by the
    // Firestore rules, which is why the ELO briefly flashed and reverted.)
    await _saveGame(result);

    // Real rated online games AND fake-bot fallback both get full ELO processing.
    // For fake-bot games opponentRating is already set to the generated fakeRating.
    if ((isRated && mode == GameMode.online) || isFakeBotFallback) {
      try {
        await _processRatingChange(result);
      } catch (e) {
        debugPrint('[Rating] _processRatingChange threw: $e');
      }
      // H-6: Guard against post-dispose state writes. The notifier may be
      // disposed while awaiting the Cloud Function / Firestore calls above.
      if (!mounted) return;
      // Fallback: ratingChange must never stay null for rated/fake-bot games.
      // This ensures the game always appears in the profile chart and tile ELO row.
      if (playerIsWhite && state.whiteRatingChange == null) {
        state = state.copyWith(whiteRatingChange: 0);
      } else if (!playerIsWhite && state.blackRatingChange == null) {
        state = state.copyWith(blackRatingChange: 0);
      }
    }

    // Record arena score — only white side to prevent double-counting
    if (arenaId != null && playerIsWhite && mode == GameMode.online) {
      await _recordArenaResult(result);
    }

    if (mode == GameMode.campaign && campaignChapter != null) {
      final playerWon = (playerIsWhite && result == GameResult.white) ||
          (!playerIsWhite && result == GameResult.black);
      // "under 40 moves" → total half-moves (plies) < 80
      final under40 = state.engine.moveCount < 80;
      if (!mounted) return; // H-6: guard after previous awaits
      state = state.copyWith(
        campaignObjectivesDone: [playerWon, _hadCapture, under40],
      );
      if (playerWon) await _unlockNextCampaignChapter();
    }

    // Clear in-game flag so spectators know game ended
    if (mode == GameMode.online && _myUid != null) {
      _ref.read(firestoreServiceProvider).clearCurrentGame(_myUid!);
    }

    // Log game_end
    if (_myUid != null) {
      final totalMs = timeControl.totalSeconds * 1000;
      final myMsLeft = playerIsWhite ? state.whiteMsLeft : state.blackMsLeft;
      final durationSec = ((totalMs - myMsLeft) / 1000).round();
      _ref.read(logServiceProvider).log(
        uid: _myUid!,
        username: myUsername ?? 'unknown',
        type: 'game_end',
        metadata: {
          'gameId': _gameId,
          'opponentUid': opponentUid ?? '',
          'opponentUsername': opponentUsername ?? '',
          'result': result.name,
          'durationSeconds': durationSec,
          'timeControl': timeControl.label,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'other',
        },
      );
    }
  }

  Future<void> _unlockNextCampaignChapter() async {
    try {
      final user = await _ref.read(currentUserProvider.future);
      if (user == null) return;
      final completed = campaignChapter!;
      final gt = gameType;
      final currentProgress = switch (gt) {
        'checkers' => user.checkersCampaignProgress,
        'domino'   => user.dominoCampaignProgress,
        _          => user.campaignProgress,
      };
      if (completed > currentProgress) {
        await _ref
            .read(firestoreServiceProvider)
            .updateCampaignProgress(user.uid, completed, gameType: gt);
        debugPrint('[Campaign] $gt progress updated → $completed');
      }
    } catch (e) {
      debugPrint('[Campaign] failed to update progress: $e');
    }
  }

  /// Records the arena score (win=2, draw=1, loss=0) for both players.
  /// Only called by the white-side player to avoid double-counting.
  Future<void> _recordArenaResult(GameResult result) async {
    if (arenaId == null) return;
    try {
      final myUid = _myUid ?? '';
      final oppUid = opponentUid ?? '';
      final whiteUid = playerIsWhite ? myUid : oppUid;
      final blackUid = playerIsWhite ? oppUid : myUid;
      final isDraw = result == GameResult.draw;
      final winnerUid = isDraw
          ? null
          : (result == GameResult.white ? whiteUid : blackUid);
      await _ref.read(tournamentServiceProvider).recordArenaResult(
            tournamentId: arenaId!,
            whiteUid: whiteUid,
            blackUid: blackUid,
            winnerUid: winnerUid,
            isDraw: isDraw,
          );
      debugPrint('[Arena] result recorded for $arenaId');
    } catch (e) {
      debugPrint('[Arena] failed to record result: $e');
    }
  }

  /// Delegates ELO calculation and Firestore update to the Cloud Function.
  ///
  /// The CF validates the game result server-side, recalculates ELO, and
  /// writes the updated rating stats — preventing client-side manipulation.
  ///
  /// Falls back to the local EloService if the CF call fails (e.g. offline),
  /// so gameplay is never blocked by a network issue.
  Future<void> _processRatingChange(GameResult result) async {
    // ── Primary path: server-side via Cloud Function ──────────────────────────
    // The CF is idempotent (ratingProcessed guard keyed by gameId), so it is
    // safe to retry on transient failures — a brief network blip right after
    // the game must not cost the player their ELO update.
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final callable = FirebaseFunctions.instance
            .httpsCallable('processGameRating');
        final response = await callable.call({'gameId': _gameId});
        final data = response.data as Map<dynamic, dynamic>;

        final myDelta     = (data['myDelta']     as num?)?.toInt() ?? 0;
        final myNewRating = (data['myNewRating'] as num?)?.toInt();

        // Derive ratingBefore from newRating - delta
        final myBefore = myNewRating != null ? myNewRating - myDelta : null;

        if (!mounted) return;
        if (playerIsWhite) {
          state = state.copyWith(
            whiteRatingBefore: myBefore,
            whiteRatingChange: myDelta,
          );
        } else {
          state = state.copyWith(
            blackRatingBefore: myBefore,
            blackRatingChange: myDelta,
          );
        }
        debugPrint('[Rating] CF processed: delta=$myDelta newRating=$myNewRating');
        return;
      } catch (e) {
        debugPrint('[Rating] CF attempt $attempt/3 failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    // ── Fallback: local estimate for the result dialog ─────────────────────────
    // The Firestore rules deliberately block clients from writing
    // bullet/blitz/rapid stats (anti-cheat — only the CF may), so no direct
    // write is attempted here: it would only be applied locally by latency
    // compensation and then rolled back when the server rejects it (the
    // "rating flashed and disappeared" bug). The estimate below feeds the
    // result dialog; the authoritative update happens when the CF is
    // reachable again (retried on game-screen reopen via the stale
    // game-over check).
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) return;

    final category = timeControl.category;
    final myStats = switch (category) {
      TimeControlCategory.bullet => user.bulletStats,
      TimeControlCategory.blitz  => user.blitzStats,
      TimeControlCategory.rapid  => user.rapidStats,
    };

    int oppRating = opponentRating ?? 1200;
    if (opponentUid != null) {
      try {
        final opp =
            await _ref.read(firestoreServiceProvider).getUser(opponentUid!);
        if (opp != null) {
          oppRating = switch (category) {
            TimeControlCategory.bullet => opp.bulletStats.rating,
            TimeControlCategory.blitz  => opp.blitzStats.rating,
            TimeControlCategory.rapid  => opp.rapidStats.rating,
          };
        }
      } catch (_) {}
    }

    final (whiteNew, blackNew, whiteDelta, blackDelta) = EloService.calculate(
      whiteRating: playerIsWhite ? myStats.rating : oppRating,
      blackRating: playerIsWhite ? oppRating       : myStats.rating,
      result:      result,
      whiteGames:  playerIsWhite ? myStats.games : 999,
      blackGames:  playerIsWhite ? 999           : myStats.games,
    );

    final myDelta = playerIsWhite ? whiteDelta : blackDelta;
    debugPrint('[Rating] CF unreachable — showing estimated delta $myDelta '
        '(authoritative update deferred to the next CF retry)');

    if (!mounted) return; // H-6: guard after awaits above
    if (playerIsWhite) {
      state = state.copyWith(
        whiteRatingBefore: myStats.rating,
        whiteRatingChange: myDelta,
      );
    } else {
      state = state.copyWith(
        blackRatingBefore: myStats.rating,
        blackRatingChange: myDelta,
      );
    }
  }


  Future<void> _saveGame(GameResult result) async {
    final firestore = _ref.read(firestoreServiceProvider);
    final auth = _ref.read(authStateProvider).valueOrNull;
    if (auth == null) return;

    final myUid = _myUid ?? auth.uid;
    final oppUid = opponentUid;

    final whiteUid = playerIsWhite ? myUid : oppUid;
    final blackUid = playerIsWhite ? oppUid : myUid;

    final myName = myUsername ?? auth.email?.split('@').first ?? 'Player';
    final oppName = opponentUsername ?? 'Opponent';
    final whiteUsername = playerIsWhite ? myName : oppName;
    final blackUsername = playerIsWhite ? oppName : myName;

    final game = GameModel(
      id: _gameId,
      // Fake-bot games are saved as online so they appear in online history
      mode: isFakeBotFallback ? GameMode.online : mode,
      gameType: gameType,
      whiteUid: whiteUid,
      blackUid: blackUid,
      whiteUsername: whiteUsername,
      blackUsername: blackUsername,
      timeControl: timeControl,
      pgn: state.engine.pgn,
      moves: state.engine.moveHistory,
      result: result,
      createdAt: DateTime.now(),
      endedAt: DateTime.now(),
      whiteRatingBefore: state.whiteRatingBefore,
      blackRatingBefore: state.blackRatingBefore,
      whiteRatingChange: state.whiteRatingChange,
      blackRatingChange: state.blackRatingChange,
      isRated: isRated,
    );

    try {
      await firestore.saveGame(game);
      await firestore.addRecentGameId(myUid, _gameId);
      debugPrint('[Game] saved $_gameId (mode: ${mode.name})');
    } catch (e) {
      debugPrint('[Game] failed to save game: $e');
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _disconnectTimer?.cancel();
    _moveSub?.cancel();
    _gameOverSub?.cancel();
    _rematchSub?.cancel();
    _drawOfferSub?.cancel();
    _presenceSub?.cancel();

    if (_myUid != null && mode == GameMode.online) {
      final rtdb = _ref.read(realtimeGameServiceProvider);
      if (state.status == GameStatus.playing) {
        // App was killed / crashed mid-game — write offline immediately so the
        // opponent's disconnect-detection fires.  Do NOT cancel the
        // onDisconnect handler here: Firebase's own handler will also fire and
        // that's fine (both writes set online=false).
        rtdb.goOffline(_gameId, _myUid!);
      } else {
        // Game ended cleanly before dispose — cancel the onDisconnect handler
        // so it doesn't emit a spurious offline event in the next session.
        rtdb.cancelDisconnectHandler(_gameId, _myUid!);
      }
    }

    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final gameProvider = StateNotifierProvider.autoDispose
    .family<GameNotifier, GameState, GameConfig>((ref, config) {
  return GameNotifier(
    mode: config.mode,
    timeControl: config.timeControl,
    playerIsWhite: config.playerIsWhite,
    botRating: config.botRating,
    isRated: config.isRated,
    gameId: config.gameId,
    campaignChapter: config.campaignChapter,
    opponentUid: config.opponentUid,
    opponentRating: config.opponentRating,
    myUsername: config.myUsername,
    opponentUsername: config.opponentUsername,
    arenaId: config.arenaId,
    isFakeBotFallback: config.isFakeBotFallback,
    gameType: config.gameType,
    ref: ref,
  );
});

@immutable
class GameConfig {
  final GameMode mode;
  final TimeControl timeControl;
  final bool playerIsWhite;
  final int? botRating;
  final bool isRated;
  final String? gameId;
  final int? campaignChapter;
  final String? opponentUid;
  final int? opponentRating;
  final String? opponentCountryCode;
  final String? myUsername;
  final String? opponentUsername;
  final String? arenaId;
  final bool isFakeBotFallback;
  final String gameType; // 'chess', 'checkers', 'domino'

  const GameConfig({
    required this.mode,
    required this.timeControl,
    required this.playerIsWhite,
    this.botRating,
    this.isRated = false,
    this.gameId,
    this.campaignChapter,
    this.opponentUid,
    this.opponentRating,
    this.opponentCountryCode,
    this.myUsername,
    this.opponentUsername,
    this.arenaId,
    this.isFakeBotFallback = false,
    this.gameType = 'chess',
  });

  @override
  bool operator ==(Object other) =>
      other is GameConfig &&
      mode == other.mode &&
      timeControl == other.timeControl &&
      playerIsWhite == other.playerIsWhite &&
      botRating == other.botRating &&
      isRated == other.isRated &&
      gameId == other.gameId &&
      campaignChapter == other.campaignChapter &&
      opponentUid == other.opponentUid &&
      opponentRating == other.opponentRating &&
      opponentCountryCode == other.opponentCountryCode &&
      myUsername == other.myUsername &&
      opponentUsername == other.opponentUsername &&
      arenaId == other.arenaId &&
      isFakeBotFallback == other.isFakeBotFallback;

  @override
  int get hashCode => Object.hash(mode, timeControl, playerIsWhite, botRating,
      isRated, gameId, campaignChapter, opponentUid, opponentRating,
      opponentCountryCode, myUsername, opponentUsername, arenaId,
      isFakeBotFallback);
}
