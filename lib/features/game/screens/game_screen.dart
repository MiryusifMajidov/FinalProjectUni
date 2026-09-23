import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../engine/chess_engine.dart';
import '../providers/game_provider.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/clock_widget.dart';
import '../widgets/game_chat_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  final Map<String, dynamic>? extra;

  const GameScreen({super.key, required this.gameId, this.extra});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late GameConfig _config;
  UserModel? _opponentUser;
  bool _resultModalShown = false;
  bool _manualFlip = false; // offline view toggle (flip board button)

  // Overlay notification management
  OverlayEntry? _currentNotif;

  @override
  void initState() {
    super.initState();
    final extra = widget.extra ?? {};
    _config = GameConfig(
      mode: GameMode.values.byName(
          extra['mode'] as String? ?? GameMode.bot.name),
      timeControl: extra['timeControl'] != null
          ? TimeControl.fromMap(extra['timeControl'] as Map<String, dynamic>)
          : TimeControls.blitz5,
      playerIsWhite: extra['playerIsWhite'] as bool? ?? true,
      botRating: extra['botRating'] as int?,
      isRated: extra['isRated'] as bool? ?? false,
      gameId: widget.gameId,
      campaignChapter: extra['campaignChapter'] as int?,
      opponentUid: extra['opponentUid'] as String?,
      opponentRating: extra['opponentRating'] as int?,
      opponentCountryCode: extra['opponentCountryCode'] as String?,
      myUsername: extra['myUsername'] as String?,
      opponentUsername: extra['opponentUsername'] as String?,
      arenaId: extra['arenaId'] as String?,
      isFakeBotFallback: extra['isFakeBotFallback'] as bool? ?? false,
      gameType: extra['gameType'] as String? ?? 'chess',
    );

    // Fetch opponent profile for both online AND friend games
    // so we can show their real photo in the player bar.
    if (_config.opponentUid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchOpponent());
    }
  }

  @override
  void dispose() {
    _currentNotif?.remove();
    _currentNotif = null;
    super.dispose();
  }

  Future<void> _fetchOpponent() async {
    if (_config.opponentUid == null) return;
    try {
      final user = await ref
          .read(firestoreServiceProvider)
          .getUser(_config.opponentUid!);
      if (mounted && user != null) {
        setState(() => _opponentUser = user);
      }
    } catch (e) {
      debugPrint('[Game] failed to fetch opponent profile: $e');
    }
  }

  void _showMoreSheet(BuildContext ctx, GameNotifier notifier, GameState gameState) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161412),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 3,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            if (_config.mode == GameMode.online || _isFakeBotFallback) ...[
              _MoreSheetItem(
                icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                label: 'chat'.tr(),
                onTap: () { Navigator.pop(ctx); _openChat(); },
              ),
              const Divider(color: Color(0xFF2A2520), height: 1),
              _MoreSheetItem(
                icon: PhosphorIcons.handshake(PhosphorIconsStyle.regular),
                label: gameState.drawOfferSent ? 'draw_offered'.tr() : 'draw'.tr(),
                disabled: gameState.drawOfferSent,
                onTap: () { Navigator.pop(ctx); notifier.offerDraw(); },
              ),
              const Divider(color: Color(0xFF2A2520), height: 1),
            ],
            _MoreSheetItem(
              icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
              label: 'resign'.tr(),
              color: AppColors.loss,
              onTap: () { Navigator.pop(ctx); _confirmResign(ctx, notifier); },
            ),
          ],
        ),
      ),
    );
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // viewInsets.bottom = keyboard height (0 when closed).
        // Wrapping with this Padding slides the entire sheet above the keyboard
        // so the input field is always visible.
        final keyboardH = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardH),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.6,
            child: GameChatPanel(
              gameId: widget.gameId,
              onClose: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
    );
  }

  void _navigateToRematch(String newGameId) {
    if (!mounted) return;
    final newExtra = Map<String, dynamic>.from(widget.extra ?? {})
      ..['gameId'] = newGameId
      ..['playerIsWhite'] = !_config.playerIsWhite;
    context.pushReplacement('/game/$newGameId', extra: newExtra);
  }

  // ── Overlay notification ───────────────────────────────────────────────────

  void _showGameNotification({
    required String title,
    required String message,
    required String acceptLabel,
    required VoidCallback onAccept,
    required VoidCallback onDismiss,
    int durationSeconds = 3,
  }) {
    // Remove any existing notification first
    _currentNotif?.remove();
    _currentNotif = null;

    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _GameNotificationOverlay(
        title: title,
        message: message,
        acceptLabel: acceptLabel,
        durationSeconds: durationSeconds,
        onAccept: () {
          if (entry.mounted) entry.remove();
          if (_currentNotif == entry) _currentNotif = null;
          onAccept();
        },
        onDismiss: () {
          if (entry.mounted) entry.remove();
          if (_currentNotif == entry) _currentNotif = null;
          onDismiss();
        },
      ),
    );

    _currentNotif = entry;
    overlay.insert(entry);
  }

  // ── Back / leave guard ─────────────────────────────────────────────────────

  void _confirmLeave(BuildContext context, GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text('leave_game'.tr()),
        content: Text('leave_game_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('stay'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.resign();
              // Wait a brief moment for the resign to propagate, then leave
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) context.pop();
              });
            },
            child: Text('resign_and_leave'.tr(),
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider(_config));
    final notifier = ref.read(gameProvider(_config).notifier);
    final cache = ref.watch(cacheServiceProvider);

    // ── Listeners for overlay notifications ───────────────────────────────────
    ref.listen<GameState>(gameProvider(_config), (prev, next) {
      // Draw offer received
      if ((prev?.drawOfferPending ?? false) == false &&
          next.drawOfferPending == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showGameNotification(
            title: 'draw_offered'.tr(),
            message: 'draw_offered_msg'.tr(),
            acceptLabel: 'accept'.tr(),
            onAccept: () => ref
                .read(gameProvider(_config).notifier)
                .acceptDraw(),
            onDismiss: () => ref
                .read(gameProvider(_config).notifier)
                .declineDraw(),
          );
        });
      }

      // Rematch invite received (while result sheet is open)
      if (prev?.rematchState != RematchState.inviteReceived &&
          next.rematchState == RematchState.inviteReceived) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showGameNotification(
            title: 'rematch_invite'.tr(),
            message: 'rematch_invite_msg'.tr(),
            acceptLabel: 'accept'.tr(),
            onAccept: () => ref
                .read(gameProvider(_config).notifier)
                .acceptRematch(),
            onDismiss: () => ref
                .read(gameProvider(_config).notifier)
                .declineRematch(),
          );
        });
      }
    });

    // Show result modal when game ends (once)
    if (gameState.result != null &&
        gameState.status != GameStatus.playing &&
        !_resultModalShown) {
      _resultModalShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResultModal(context, gameState, notifier);
      });
    }

    final isOnlineActive = (_config.mode == GameMode.online || _isFakeBotFallback) &&
        gameState.status == GameStatus.playing;

    // Local pass-and-play: the board stays FIXED (white at the bottom) — it
    // must never auto-rotate after each move when two players share one
    // device across the table. The "flip board" button toggles it manually.
    final baseFlip =
        _config.mode == GameMode.local ? false : !_config.playerIsWhite;
    final isFlipped = _manualFlip ? !baseFlip : baseFlip;

    // ── Material advantage ─────────────────────────────────────────────────────
    final myMaterialAdv =
        gameState.engine.materialAdvantageFor(_config.playerIsWhite);

    // ── Opponent display info ──────────────────────────────────────────────────
    final category = _config.timeControl.category;
    final oppRating = _opponentUser != null
        ? switch (category) {
            TimeControlCategory.bullet => _opponentUser!.bulletStats.rating,
            TimeControlCategory.blitz => _opponentUser!.blitzStats.rating,
            TimeControlCategory.rapid => _opponentUser!.rapidStats.rating,
          }
        : _config.opponentRating;
    final oppCountryCode =
        _opponentUser?.countryCode ?? _config.opponentCountryCode;
    final oppUsername = _opponentUser?.username ?? _opponentName();
    final oppPhotoUrl = _opponentUser?.photoUrl;

    // My photo — read from currentUser stream (updates in real-time)
    final myPhotoUrl = ref.watch(currentUserProvider).valueOrNull?.photoUrl;

    return PopScope(
      // Allow pop only when not in an active online game
      canPop: !isOnlineActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isOnlineActive) {
          _confirmLeave(context, notifier);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0908),
        // Must be false: the game Scaffold must never resize its body when a
        // keyboard opens (including keyboards inside the chat modal-bottom-sheet).
        // Without this the LayoutBuilder's maxHeight shrinks and boardSize
        // formula produces a tiny board.  Keyboard insets for the chat panel
        // are handled manually inside _openChat().
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, outerConstraints) {
              const headerH   = 52.0;
              const stripH    = 56.0;
              const actionH   = 66.0;
              const spacingH  = 8.0;
              // Move history strip is always visible once first move is played.
              final moveListH = gameState.engine.moveHistory.isNotEmpty ? 44.0 : 0.0;
              final disconnH  = gameState.opponentDisconnected ? 50.0 : 0.0;
              final fixedH    = headerH + stripH * 2 + actionH + spacingH + moveListH + disconnH;
              final boardSize = (outerConstraints.maxHeight - fixedH)
                  .clamp(100.0, outerConstraints.maxWidth - 24.0);

              final reviewEngine = gameState.isInReview
                  ? gameState.engine.snapshotAt(gameState.reviewIndex!)
                  : gameState.engine;

              final oppIsActive = gameState.status == GameStatus.playing &&
                  ((_config.playerIsWhite && !gameState.engine.isWhiteTurn) ||
                   (!_config.playerIsWhite && gameState.engine.isWhiteTurn));
              final myIsActive = gameState.status == GameStatus.playing &&
                  ((_config.playerIsWhite && gameState.engine.isWhiteTurn) ||
                   (!_config.playerIsWhite && !gameState.engine.isWhiteTurn));

              return Column(
                children: [
                  // ── Minimal header ───────────────────────────────────────
                  _MinimalHeader(
                    gameMode: _config.mode,
                    timeControl: _config.timeControl,
                    moveCount: gameState.engine.moveHistory.length,
                    isRated: _config.isRated,
                    isFakeBotFallback: _isFakeBotFallback,
                    onBack: isOnlineActive
                        ? () => _confirmLeave(context, notifier)
                        : () => context.pop(),
                    onMore: () => _showMoreSheet(context, notifier, gameState),
                    onMoves: gameState.engine.moveHistory.isNotEmpty
                        ? () => _showMovesSheet(context, cache.moveNotation)
                        : null,
                  ),

                  // ── Opponent strip ───────────────────────────────────────
                  _CalmPlayerStrip(
                    username: oppUsername,
                    photoUrl: oppPhotoUrl,
                    isWhite: !_config.playerIsWhite,
                    milliseconds: _config.playerIsWhite
                        ? gameState.blackMsLeft
                        : gameState.whiteMsLeft,
                    isActive: oppIsActive,
                    capturedPieces: _config.playerIsWhite
                        ? gameState.engine.capturedByBlack
                        : gameState.engine.capturedByWhite,
                    rating: oppRating,
                    countryCode: oppCountryCode,
                    materialAdvantage: (-myMaterialAdv).clamp(0, 99),
                  ),

                  // Disconnect banner
                  if (gameState.opponentDisconnected)
                    _DisconnectBanner(
                      secondsLeft: gameState.disconnectSecondsLeft,
                      opponentName: _opponentName(),
                    ),

                  // ── Board ────────────────────────────────────────────────
                  Center(
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: Stack(
                        children: [
                          ChessBoardWidget(
                            engine: reviewEngine,
                            flipped: isFlipped,
                            selectedSquare: gameState.isInReview
                                ? null
                                : gameState.selectedSquare,
                            legalMoveSquares: gameState.isInReview
                                ? const []
                                : (cache.showLegalMoves
                                    ? gameState.legalMoveSquares
                                    : const []),
                            onSquareTap: gameState.isInReview
                                ? (_) => notifier.exitReview()
                                : notifier.onSquareTapped,
                            boardTheme: ref.watch(settingsProvider).boardTheme,
                            pieceSet: ref.watch(settingsProvider).pieceSet,
                            showCoordinates: cache.showCoordinates,
                            showLastMoveHighlight: cache.highlightLastMove,
                            animationDuration: cache.pieceMoveAnimationDuration,
                            premoveFrom: gameState.premoveFrom,
                            premoveTo: gameState.premoveTo,
                          ),
                          // Confirm-move overlay bar
                          if (gameState.pendingMoveFrom != null)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _ConfirmMoveBar(
                                onConfirm: notifier.confirmPendingMove,
                                onCancel: notifier.cancelPendingMove,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── My strip ─────────────────────────────────────────────
                  _CalmPlayerStrip(
                    username: _myName(),
                    photoUrl: myPhotoUrl,
                    isWhite: _config.playerIsWhite,
                    milliseconds: _config.playerIsWhite
                        ? gameState.whiteMsLeft
                        : gameState.blackMsLeft,
                    isActive: myIsActive,
                    capturedPieces: _config.playerIsWhite
                        ? gameState.engine.capturedByWhite
                        : gameState.engine.capturedByBlack,
                    materialAdvantage: myMaterialAdv.clamp(0, 99),
                  ),

                  // ── Move history strip (always visible after first move) ──
                  // Tapping any move enters review at that position.
                  // Notation (SAN / Long / Figurine) from game settings applies here.
                  if (gameState.engine.moveHistory.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: _MoveHistoryStrip(
                        moves: gameState.engine.moveHistory,
                        verboseHistory: gameState.engine.verboseHistory,
                        notation: cache.moveNotation,
                        reviewIndex: gameState.reviewIndex,
                        isInReview: gameState.isInReview,
                        onMoveTap: (halfIdx) =>
                            notifier.goToReview(halfIdx + 1),
                        onFirst: () => notifier.reviewFirst(),
                        onPrev:  () => notifier.reviewPrev(),
                        onNext:  () => notifier.reviewNext(),
                        onLast:  () => notifier.exitReview(),
                      ),
                    ),

                  // ── Quiet action row ─────────────────────────────────────
                  _QuietActionRow(
                    // Fake-bot fallback looks like online game: no Hint/Undo
                    isOnline: _config.mode == GameMode.online || _isFakeBotFallback,
                    isBot: !_isFakeBotFallback &&
                           (_config.mode == GameMode.bot ||
                            _config.mode == GameMode.campaign),
                    drawOfferSent: gameState.drawOfferSent,
                    onChat: (_config.mode == GameMode.online || _isFakeBotFallback)
                        ? _openChat
                        : null,
                    onDraw: () => notifier.offerDraw(),
                    onResign: () => _confirmResign(context, notifier),
                    onHint: null,
                    onUndo: null,
                    onFlip: () => setState(() => _manualFlip = !_manualFlip),
                  ),
                ],
              );
            },
          ),
        ),
        bottomSheet: gameState.needsPromotion
            ? _PromotionSheet(
                isWhite: gameState.engine.isWhiteTurn,
                onSelect: (piece) =>
                    ref
                        .read(gameProvider(_config).notifier)
                        .selectPromotion(piece),
              )
            : null,
      ),
    );
  }

  String _myName() {
    final extra = widget.extra ?? {};
    return extra['myUsername'] as String? ?? 'You';
  }

  bool get _isFakeBotFallback =>
      (widget.extra ?? {})['isFakeBotFallback'] as bool? ?? false;

  String _opponentName() {
    final extra = widget.extra ?? {};
    // Fake-bot fallback: show the generated human-looking username, not "Bot"
    if (_isFakeBotFallback) {
      return extra['opponentUsername'] as String? ?? 'Opponent';
    }
    if (_config.mode == GameMode.bot || _config.mode == GameMode.campaign) {
      return 'Bot (${_config.botRating ?? 1200})';
    }
    return extra['opponentUsername'] as String? ?? 'Opponent';
  }

  void _confirmResign(BuildContext context, GameNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('resign'.tr()),
        content: Text('leave_game_warning'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.resign();
            },
            child: Text('resign'.tr(),
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showMovesSheet(BuildContext ctx, String notation) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullMovesSheet(
        config: _config,
        notation: notation,
      ),
    );
  }

  void _showResultModal(
    BuildContext context,
    GameState gameState,
    GameNotifier notifier,
  ) {
    if (!mounted) return;
    // Dismiss any lingering notification (draw offer etc.) when game ends
    _currentNotif?.remove();
    _currentNotif = null;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => _GameResultSheet(
        config: _config,
        result: gameState.result!,
        status: gameState.status,
        playerIsWhite: _config.playerIsWhite,
        whiteRatingChange: gameState.whiteRatingChange,
        blackRatingChange: gameState.blackRatingChange,
        campaignChapter: _config.campaignChapter,
        campaignObjectivesDone: gameState.campaignObjectivesDone,
        isOnline: _config.mode == GameMode.online,
        onPlayAgain: () {
          Navigator.pop(context);
          context.pop();
          final gt = GameTypeX.fromString(_config.gameType);
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          context.push(gt.gameRoute(newId), extra: widget.extra);
        },
        onContinue: _config.campaignChapter != null &&
                _config.campaignChapter! < GameTypeX.fromString(_config.gameType).identity.questChapters
            ? () {
                Navigator.pop(context);
                context.pop();
                context.push(
                    '/home/campaign/${_config.campaignChapter! + 1}');
              }
            : null,
        onHome: () {
          Navigator.pop(context);
          context.go('/home');
        },
        onNewOpponent: () {
          Navigator.pop(context);
          context.go('/home/matchmaking');
        },
        onRematchAccepted: (newGameId) {
          Navigator.pop(context);
          _navigateToRematch(newGameId);
        },
        onBackToArena: _config.arenaId != null
            ? () {
                Navigator.pop(context);
                context.go('/home/tournaments/${_config.arenaId}');
              }
            : null,
      ),
    );
  }
}

// ── Minimal Header ────────────────────────────────────────────────────────────

class _MinimalHeader extends StatelessWidget {
  final GameMode gameMode;
  final TimeControl timeControl;
  final int moveCount;
  final bool isRated;
  final bool isFakeBotFallback;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback? onMoves;

  const _MinimalHeader({
    required this.gameMode,
    required this.timeControl,
    required this.moveCount,
    required this.isRated,
    this.isFakeBotFallback = false,
    required this.onBack,
    required this.onMore,
    this.onMoves,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = isFakeBotFallback
        ? '${timeControl.label.toUpperCase()} · RATED'
        : switch (gameMode) {
            GameMode.online   => '${timeControl.label.toUpperCase()} · ${isRated ? 'RATED' : 'CASUAL'}',
            GameMode.bot      => 'VS BOT · CASUAL',
            GameMode.campaign => 'CAMPAIGN',
            GameMode.local    => 'LOCAL GAME',
          };
    final halfMove = (moveCount / 2).ceil();
    final subLabel = moveCount == 0 ? 'Opening' : 'Move $halfMove';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
                color: AppColors.inkDim, size: 18,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  modeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMute,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subLabel,
                  style: GoogleFonts.fraunces(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkDim,
                  ),
                ),
              ],
            ),
          ),
          if (onMoves != null) ...[
            GestureDetector(
              onTap: onMoves,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  PhosphorIcons.listNumbers(PhosphorIconsStyle.regular),
                  color: AppColors.inkDim, size: 18,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: onMore,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: Center(
                child: Text(
                  '⋯',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18, color: AppColors.inkDim,
                    letterSpacing: -2, height: 1.2,
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

// ── More Sheet Item ───────────────────────────────────────────────────────────

class _MoreSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool disabled;

  const _MoreSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = disabled ? AppColors.inkMute : (color ?? AppColors.ink);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w500, color: c,
            )),
          ],
        ),
      ),
    );
  }
}

// ── Calm Player Strip ─────────────────────────────────────────────────────────

class _CalmPlayerStrip extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final bool isWhite;
  final int milliseconds;
  final bool isActive;
  final List<PieceInfo> capturedPieces;
  final int? rating;
  final String? countryCode;
  final int materialAdvantage;

  const _CalmPlayerStrip({
    required this.username,
    required this.isWhite,
    required this.milliseconds,
    required this.isActive,
    required this.capturedPieces,
    this.photoUrl,
    this.rating,
    this.countryCode,
    this.materialAdvantage = 0,
  });

  @override
  Widget build(BuildContext context) {
    final flag = UserModel.flagEmoji(countryCode);
    final subParts = <String>[
      if (rating != null) '$rating',
      if (flag.isNotEmpty) flag,
    ];

    final mins = milliseconds ~/ 60000;
    final secs = (milliseconds % 60000) ~/ 1000;
    final clockStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        children: [
          // Circle avatar with active amber ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite ? const Color(0xFFF5F3EF) : const Color(0xFF1A1310),
              border: Border.all(
                color: isActive ? AppColors.amber : const Color(0xFF3D3530),
                width: isActive ? 2.0 : 1.5,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: AppColors.amberGlow, blurRadius: 12)]
                  : null,
            ),
            child: photoUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(
                      isWhite ? '♔' : '♚',
                      style: TextStyle(
                        fontSize: 20,
                        color: isWhite ? const Color(0xFF1A1310) : const Color(0xFFF5F3EF),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Name + sub
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: GoogleFonts.fraunces(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: AppColors.ink, letterSpacing: -0.2,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subParts.isNotEmpty || capturedPieces.isNotEmpty)
                  Row(
                    children: [
                      if (subParts.isNotEmpty)
                        Text(
                          subParts.join(' · '),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10, color: AppColors.inkMute,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (capturedPieces.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          capturedPieces.map((p) => p.symbol).join(''),
                          style: const TextStyle(fontSize: 11, height: 1.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (materialAdvantage > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '+$materialAdvantage',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10, color: AppColors.win,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          // Clock — large, amber when active
          Text(
            clockStr,
            style: GoogleFonts.fraunces(
              fontSize: 26, fontWeight: FontWeight.w500,
              color: isActive ? AppColors.amber : AppColors.inkDim,
              letterSpacing: -0.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eval Baseline ─────────────────────────────────────────────────────────────

class _EvalBaseline extends StatelessWidget {
  final double evalScore;
  const _EvalBaseline({required this.evalScore});

  @override
  Widget build(BuildContext context) {
    // Normalize: 0 = fully black, 0.5 = equal, 1.0 = fully white
    // +1.0 = white up 1 pawn, etc. Clamp at ±5
    final clamped = evalScore.clamp(-5.0, 5.0);
    final normalized = (clamped + 5.0) / 10.0; // 0.0 to 1.0, 0.5 = equal
    final label = evalScore == 0.0 ? 'equal'
        : evalScore > 0 ? '+${evalScore.toStringAsFixed(1)}'
        : evalScore.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      child: Row(
        children: [
          Text(
            evalScore == 0.0 ? '0.0' : label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.inkMute, letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 14,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2520),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  // Center line
                  Center(
                    child: Container(
                      width: 1, height: 8,
                      color: const Color(0xFF3D3530),
                    ),
                  ),
                  // Amber dot
                  LayoutBuilder(
                    builder: (_, constraints) {
                      final dotX = normalized * constraints.maxWidth;
                      return Positioned(
                        left: (dotX - 4).clamp(0.0, constraints.maxWidth - 8),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.amber,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.amberGlow,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label == '0.0' ? 'equal' : label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.inkMute, letterSpacing: 0.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quiet Action Row ──────────────────────────────────────────────────────────

class _QuietActionRow extends StatelessWidget {
  final bool isOnline;
  final bool isBot;
  final bool drawOfferSent;
  final VoidCallback? onChat;
  final VoidCallback onDraw;
  final VoidCallback onResign;
  final VoidCallback? onHint;
  final VoidCallback? onUndo;
  final VoidCallback? onFlip;

  const _QuietActionRow({
    required this.isOnline,
    required this.isBot,
    required this.drawOfferSent,
    this.onChat,
    required this.onDraw,
    required this.onResign,
    this.onHint,
    this.onUndo,
    this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    final actions = isBot
        ? [
            (icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.regular),
             label: 'Hint',
             danger: false,
             onTap: onHint ?? () {}),
            (icon: PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.regular),
             label: 'Undo',
             danger: false,
             onTap: onUndo ?? () {}),
            (icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
             label: 'resign'.tr(),
             danger: true,
             onTap: onResign),
          ]
        : isOnline
            ? [
                (icon: PhosphorIcons.chatCircle(PhosphorIconsStyle.regular),
                 label: 'chat'.tr(),
                 danger: false,
                 onTap: onChat ?? () {}),
                (icon: PhosphorIcons.handshake(PhosphorIconsStyle.regular),
                 label: drawOfferSent ? 'draw_offered'.tr() : 'draw'.tr(),
                 danger: false,
                 onTap: drawOfferSent ? () {} : onDraw),
                (icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
                 label: 'resign'.tr(),
                 danger: true,
                 onTap: onResign),
              ]
            : [
                (icon: PhosphorIcons.arrowsLeftRight(PhosphorIconsStyle.regular),
                 label: 'flip_board'.tr(),
                 danger: false,
                 onTap: onFlip ?? () {}),
                (icon: PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.regular),
                 label: 'Undo',
                 danger: false,
                 onTap: onUndo ?? () {}),
                (icon: PhosphorIcons.flag(PhosphorIconsStyle.regular),
                 label: 'resign'.tr(),
                 danger: true,
                 onTap: onResign),
              ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: actions.map((a) => Expanded(
          child: GestureDetector(
            onTap: a.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(
                    a.icon,
                    size: 16,
                    color: a.danger
                        ? AppColors.loss.withValues(alpha: 0.85)
                        : AppColors.inkDim,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.label,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: a.danger
                          ? AppColors.loss.withValues(alpha: 0.85)
                          : AppColors.inkDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

// ── Disconnect Banner ─────────────────────────────────────────────────────────

class _DisconnectBanner extends StatelessWidget {
  final int secondsLeft;
  final String opponentName;

  const _DisconnectBanner({
    required this.secondsLeft,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    // Pulse red as time runs out
    final urgency = secondsLeft <= 5;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: urgency
            ? AppColors.error.withValues(alpha: 0.18)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgency ? AppColors.error : Colors.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: urgency ? AppColors.error : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'opponent_disconnected'.tr(namedArgs: {'name': opponentName}),
              style: TextStyle(
                color: urgency ? AppColors.error : Colors.orange,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Countdown circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: urgency
                  ? AppColors.error.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                '$secondsLeft',
                style: TextStyle(
                  color: urgency ? AppColors.error : Colors.orange,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Promotion Sheet ───────────────────────────────────────────────────────────

class _PromotionSheet extends StatelessWidget {
  final bool isWhite;
  final void Function(String piece) onSelect;

  const _PromotionSheet({required this.isWhite, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final pieces = ['q', 'r', 'b', 'n'];
    final symbols = isWhite
        ? ['♕', '♖', '♗', '♘']
        : ['♛', '♜', '♝', '♞'];

    return Container(
      color: context.appColors.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('promote_pawn'.tr(), style: AppTextStyles.titleMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              return GestureDetector(
                onTap: () => onSelect(pieces[i]),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.appColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Center(
                    child: Text(
                      symbols[i],
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── In-Game Floating Notification Overlay ────────────────────────────────────

/// Slides in from the top of the screen, stays for [durationSeconds],
/// then auto-dismisses (calling [onDismiss]).  The user can tap "Accept"
/// or the ✕ button at any time to dismiss early.
class _GameNotificationOverlay extends StatefulWidget {
  final String title;
  final String message;
  final String acceptLabel;
  final int durationSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _GameNotificationOverlay({
    required this.title,
    required this.message,
    required this.acceptLabel,
    required this.durationSeconds,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  State<_GameNotificationOverlay> createState() =>
      _GameNotificationOverlayState();
}

class _GameNotificationOverlayState extends State<_GameNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  Timer? _autoTimer;
  bool _acted = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..forward();

    _autoTimer = Timer(Duration(seconds: widget.durationSeconds), () {
      if (!_acted && mounted) _handleDismiss();
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _autoTimer?.cancel();
    super.dispose();
  }

  void _handleAccept() {
    if (_acted) return;
    _acted = true;
    _autoTimer?.cancel();
    widget.onAccept();
  }

  void _handleDismiss() {
    if (_acted) return;
    _acted = true;
    _autoTimer?.cancel();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.primary.withOpacity(0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.handshake_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: AppTextStyles.titleSmall),
                          const SizedBox(height: 1),
                          Text(
                            widget.message,
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Accept button
                    TextButton(
                      onPressed: _handleAccept,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppColors.primary.withOpacity(0.15),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(widget.acceptLabel,
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.primary)),
                    ),
                    // Dismiss
                    IconButton(
                      onPressed: _handleDismiss,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 30, minHeight: 30),
                    ),
                  ],
                ),
              ),
              // Countdown progress bar
              AnimatedBuilder(
                animation: _progressCtrl,
                builder: (_, __) => ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  child: LinearProgressIndicator(
                    value: 1.0 - _progressCtrl.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withOpacity(0.6)),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .slideY(
              begin: -1.5,
              end: 0,
              duration: 350.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 200.ms),
      ),
    );
  }
}

// ── Game Result Sheet ─────────────────────────────────────────────────────────

class _GameResultSheet extends ConsumerStatefulWidget {
  final GameConfig config;
  final GameResult result;
  final GameStatus status;
  final bool playerIsWhite;
  final int? whiteRatingChange;
  final int? blackRatingChange;
  final int? campaignChapter;
  final List<bool> campaignObjectivesDone; // [won, captured, under40]
  final bool isOnline;
  final VoidCallback onPlayAgain;
  final VoidCallback? onContinue;
  final VoidCallback onHome;
  final VoidCallback onNewOpponent;
  final void Function(String newGameId) onRematchAccepted;
  final VoidCallback? onBackToArena; // non-null for arena games

  const _GameResultSheet({
    required this.config,
    required this.result,
    required this.status,
    required this.playerIsWhite,
    this.whiteRatingChange,
    this.blackRatingChange,
    this.campaignChapter,
    this.campaignObjectivesDone = const [false, false, false],
    required this.isOnline,
    required this.onPlayAgain,
    this.onContinue,
    required this.onHome,
    required this.onNewOpponent,
    required this.onRematchAccepted,
    this.onBackToArena,
  });

  @override
  ConsumerState<_GameResultSheet> createState() => _GameResultSheetState();
}

class _GameResultSheetState extends ConsumerState<_GameResultSheet> {
  bool _navigating = false;

  bool get _playerWon =>
      (widget.playerIsWhite && widget.result == GameResult.white) ||
      (!widget.playerIsWhite && widget.result == GameResult.black);
  bool get _isDraw => widget.result == GameResult.draw;

  String get _headline {
    if (_isDraw) return 'game_drawn'.tr();
    if (_playerWon) return 'you_won'.tr();
    return 'you_lost'.tr();
  }

  String get _subtext => switch (widget.status) {
        GameStatus.checkmate => 'checkmate'.tr(),
        GameStatus.timeout => 'timeout'.tr(),
        GameStatus.resign => 'resigned'.tr(),
        GameStatus.stalemate => 'stalemate'.tr(),
        GameStatus.draw => 'game_drawn'.tr(),
        _ => '',
      };

  Color get _headlineColor {
    if (_isDraw) return AppColors.warning;
    if (_playerWon) return AppColors.success;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider(widget.config));
    final notifier = ref.read(gameProvider(widget.config).notifier);
    final rematchState = gameState.rematchState;
    final newGameId = gameState.rematchNewGameId;

    // Auto-navigate when rematch is accepted
    if (rematchState == RematchState.accepted &&
        newGameId != null &&
        !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRematchAccepted(newGameId);
      });
    }

    final ratingChange = widget.playerIsWhite
        ? widget.whiteRatingChange
        : widget.blackRatingChange;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Result icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _headlineColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isDraw
                    ? Icons.handshake_outlined
                    : (_playerWon
                        ? Icons.emoji_events_rounded
                        : Icons.sentiment_dissatisfied_rounded),
                size: 40,
                color: _headlineColor,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 12),
            Text(
              _headline,
              style: AppTextStyles.displayMedium
                  .copyWith(color: _headlineColor),
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
            Text(
              _subtext,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ).animate(delay: 300.ms).fadeIn(),

            if (ratingChange != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      (ratingChange >= 0 ? AppColors.success : AppColors.error)
                          .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${ratingChange >= 0 ? '+' : ''}$ratingChange ${'rating'.tr()}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: ratingChange >= 0
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(),
            ],

            // Campaign objectives summary
            if (widget.campaignChapter != null) ...[
              const SizedBox(height: 16),
              _CampaignObjectivesSummary(
                done: widget.campaignObjectivesDone,
              ).animate(delay: 450.ms).fadeIn(),
            ],

            const SizedBox(height: 28),

            // Campaign: Continue / Retry
            if (widget.onContinue != null && _playerWon) ...[
              AppButton(
                label: widget.campaignChapter == GameTypeX.fromString(widget.config.gameType).identity.questChapters
                    ? '🏆 You Completed the Campaign!'
                    : 'Continue → Chapter ${widget.campaignChapter! + 1}',
                onTap: widget.onContinue!,
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 10),
              AppButton(
                label: 'retry'.tr(),
                onTap: widget.onPlayAgain,
                variant: AppButtonVariant.outlined,
              ).animate(delay: 540.ms).fadeIn(),
            ]
            // Arena game: back to arena lobby
            else if (widget.onBackToArena != null) ...[
              AppButton(
                label: 'back_to_arena'.tr(),
                onTap: widget.onBackToArena!,
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),
            ]
            // Online game: Rematch state machine
            else if (widget.isOnline) ...[
              _buildRematchButtons(context, notifier, rematchState),
            ]
            // Bot / local
            else ...[
              AppButton(
                label: 'new_game'.tr(),
                onTap: widget.onPlayAgain,
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),
            ],

            const SizedBox(height: 10),
            AppButton(
              label: 'home'.tr(),
              onTap: widget.onHome,
              variant: AppButtonVariant.outlined,
            ).animate(delay: 580.ms).fadeIn(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRematchButtons(
    BuildContext context,
    GameNotifier notifier,
    RematchState rematchState,
  ) {
    switch (rematchState) {
      case RematchState.none:
        return Column(
          children: [
            AppButton(
              label: 'rematch'.tr(),
              onTap: () => notifier.sendRematch(),
            ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 10),
            AppButton(
              label: 'find_opponent'.tr(),
              onTap: widget.onNewOpponent,
              variant: AppButtonVariant.outlined,
            ).animate(delay: 540.ms).fadeIn(),
          ],
        );

      case RematchState.inviteSent:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'waiting_for_opponent'.tr(),
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'find_opponent'.tr(),
              onTap: widget.onNewOpponent,
              variant: AppButtonVariant.outlined,
            ),
          ],
        );

      case RematchState.inviteReceived:
        // The overlay notification handles this state.
        // But also show it in the sheet as a fallback.
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.3)),
              ),
              child: Text(
                'rematch_invite_msg'.tr(),
                style: AppTextStyles.titleSmall
                    .copyWith(color: AppColors.success),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'accept'.tr(),
              onTap: () => notifier.acceptRematch(),
            ).animate().fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 8),
            AppButton(
              label: 'decline'.tr(),
              onTap: () => notifier.declineRematch(),
              variant: AppButtonVariant.outlined,
            ),
          ],
        );

      case RematchState.accepted:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        );

      case RematchState.declined:
        return Column(
          children: [
            Text(
              'rematch'.tr(),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'find_opponent'.tr(),
              onTap: widget.onNewOpponent,
            ),
          ],
        );
    }
  }
}

// ── Campaign Objectives Summary ───────────────────────────────────────────────

/// Shows 3 campaign objectives with ✓ / ○ completion indicators.
/// [done] = [won, captured, under40moves]
class _CampaignObjectivesSummary extends StatelessWidget {
  final List<bool> done;
  const _CampaignObjectivesSummary({required this.done});

  static const _labels = [
    'Win the game',
    'Make a capture',
    'Complete in under 40 moves',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'OBJECTIVES',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ...List.generate(_labels.length, (i) {
          final completed = i < done.length && done[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Checkmark or empty circle
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed
                        ? AppColors.success.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: completed ? AppColors.success : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: completed
                      ? Icon(Icons.check_rounded,
                          color: AppColors.success, size: 14)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: completed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: completed
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                // +5 XP badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.amber.withValues(alpha: 0.15)
                        : AppColors.divider.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '+5 XP',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: completed
                          ? AppColors.amber
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Confirm-move bar ───────────────────────────────────────────────────────────

class _ConfirmMoveBar extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmMoveBar({
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0A0908),
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: Text('cancel'.tr()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
          ),
          const Text(
            'Confirm move?',
            style: TextStyle(
              color: Color(0xFFB0A898),
              fontSize: 13,
            ),
          ),
          TextButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text('confirm'.tr()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Move History Strip ────────────────────────────────────────────────────────
//
// A compact 44 px horizontal strip that is always visible once the first move
// is played.  Every half-move is a tappable chip; tapping enters review mode
// at that position.  While in review the four navigation buttons appear on the
// right edge.  The notation (SAN / Long / Figurine) is read from CacheService
// and applied here — this is what makes the Notation setting observable.

class _MoveHistoryStrip extends StatefulWidget {
  final List<String> moves;
  final List<({String from, String to, String san})>? verboseHistory;
  final String notation;
  final int? reviewIndex;
  final bool isInReview;
  final void Function(int halfMoveIdx) onMoveTap;
  final VoidCallback onFirst;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const _MoveHistoryStrip({
    required this.moves,
    this.verboseHistory,
    this.notation = 'san',
    this.reviewIndex,
    required this.isInReview,
    required this.onMoveTap,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  @override
  State<_MoveHistoryStrip> createState() => _MoveHistoryStripState();
}

class _MoveHistoryStripState extends State<_MoveHistoryStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MoveHistoryStrip old) {
    super.didUpdateWidget(old);
    // Auto-scroll to end whenever a new move is played (live game).
    if (widget.moves.length != old.moves.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// Format a SAN string according to the selected notation.
  String _fmt(String san, int idx) {
    switch (widget.notation) {
      case 'figurine':
        return san
            .replaceAll('N', '♘')
            .replaceAll('B', '♗')
            .replaceAll('R', '♖')
            .replaceAll('Q', '♕')
            .replaceAll('K', '♔');
      case 'long':
        final vh = widget.verboseHistory;
        if (vh != null && idx < vh.length) {
          final v = vh[idx];
          if (v.from.isNotEmpty && v.to.isNotEmpty) {
            return '${v.from}${v.to}';
          }
        }
        return san;
      default: // 'san'
        return san;
    }
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    // currentHalf: 0-based index of the highlighted half-move.
    // reviewIndex is 1-based (0 = initial position, 1 = after move[0] …).
    final currentHalf = widget.reviewIndex != null
        ? widget.reviewIndex! - 1   // -1 means initial pos → no highlight
        : moves.length - 1;          // live mode → highlight last move

    final pairCount = (moves.length / 2).ceil();

    return Container(
      color: const Color(0xFF0C0B0A),
      child: Row(
        children: [
          // ── Scrollable move chips ───────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: pairCount,
              itemBuilder: (_, pairIdx) {
                final wi = pairIdx * 2;       // white half-move index
                final bi = pairIdx * 2 + 1;   // black half-move index

                final whiteLabel = _fmt(moves[wi], wi);
                final String? blackLabel =
                    bi < moves.length ? _fmt(moves[bi], bi) : null;

                final wHi = currentHalf == wi;
                final bHi = blackLabel != null && currentHalf == bi;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Move number
                    Text(
                      '${pairIdx + 1}.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: const Color(0xFF504840),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    // White's move
                    _MoveChip(
                      label: whiteLabel,
                      highlighted: wHi,
                      onTap: () => widget.onMoveTap(wi),
                    ),
                    const SizedBox(width: 2),
                    // Black's move
                    if (blackLabel != null) ...[
                      _MoveChip(
                        label: blackLabel,
                        highlighted: bHi,
                        onTap: () => widget.onMoveTap(bi),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                );
              },
            ),
          ),

          // ── Navigation buttons (visible only while reviewing) ───────────
          if (widget.isInReview)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFF2A2520), width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StripNavBtn(
                      icon: Icons.first_page_rounded, onTap: widget.onFirst),
                  _StripNavBtn(
                      icon: Icons.chevron_left_rounded, onTap: widget.onPrev),
                  _StripNavBtn(
                      icon: Icons.chevron_right_rounded, onTap: widget.onNext),
                  _StripNavBtn(
                      icon: Icons.last_page_rounded, onTap: widget.onLast),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final VoidCallback onTap;

  const _MoveChip({
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFFE8B960)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: highlighted
                ? const Color(0xFF1A1205)
                : const Color(0xFFD0C8BF),
          ),
        ),
      ),
    );
  }
}

class _StripNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StripNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
        child: Icon(icon, size: 18, color: const Color(0xFF8A7E74)),
      ),
    );
  }
}

// ── Full Move History Sheet ────────────────────────────────────────────────────
//
// Opens as a bottom sheet from the moves icon button in the header.
// Watches the game provider so highlights update live while navigating.

class _FullMovesSheet extends ConsumerStatefulWidget {
  final GameConfig config;
  final String notation;

  const _FullMovesSheet({
    required this.config,
    required this.notation,
  });

  @override
  ConsumerState<_FullMovesSheet> createState() => _FullMovesSheetState();
}

class _FullMovesSheetState extends ConsumerState<_FullMovesSheet> {
  final _scroll = ScrollController();
  int? _prevReviewIndex;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToMove(int halfIdx) {
    if (!_scroll.hasClients) return;
    final pairIdx = halfIdx ~/ 2;
    final target = (pairIdx * 46.0).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  String _fmt(String san, int idx,
      List<({String from, String to, String san})>? vh) {
    switch (widget.notation) {
      case 'figurine':
        return san
            .replaceAll('N', '♘')
            .replaceAll('B', '♗')
            .replaceAll('R', '♖')
            .replaceAll('Q', '♕')
            .replaceAll('K', '♔');
      case 'long':
        if (vh != null && idx < vh.length) {
          final v = vh[idx];
          if (v.from.isNotEmpty && v.to.isNotEmpty) return '${v.from}${v.to}';
        }
        return san;
      default:
        return san;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider(widget.config));
    final notifier  = ref.read(gameProvider(widget.config).notifier);
    final moves     = gameState.engine.moveHistory;
    final vh        = gameState.engine.verboseHistory;
    final reviewIdx = gameState.reviewIndex;
    final isReview  = gameState.isInReview;

    // 0-based index of highlighted half-move
    final currentHalf =
        reviewIdx != null ? reviewIdx - 1 : moves.length - 1;

    // Auto-scroll when the highlighted move changes
    if (_prevReviewIndex != reviewIdx) {
      _prevReviewIndex = reviewIdx;
      if (currentHalf >= 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToMove(currentHalf));
      }
    }

    final pairCount = (moves.length / 2).ceil();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131316),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF504840),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    'move_history'.tr(),
                    style: GoogleFonts.fraunces(
                      fontSize: 20, fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFFF5F3EF),
                    ),
                  ),
                  const Spacer(),
                  if (isReview)
                    GestureDetector(
                      onTap: () => notifier.exitReview(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x24E8B960),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0x66E8B960)),
                        ),
                        child: Text(
                          'Back to live',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: const Color(0xFFE8B960),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF2A2520), height: 1),

            // ── Moves list ────────────────────────────────────────────────
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.46,
              ),
              child: moves.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'no_moves_played_yet'.tr(),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: const Color(0xFF706860)),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: pairCount,
                      itemBuilder: (_, pairIdx) {
                        final wi = pairIdx * 2;
                        final bi = pairIdx * 2 + 1;
                        return _MovePairRow(
                          moveNumber: pairIdx + 1,
                          whiteLabel: _fmt(moves[wi], wi, vh),
                          blackLabel: bi < moves.length
                              ? _fmt(moves[bi], bi, vh)
                              : null,
                          whiteHighlighted: currentHalf == wi,
                          blackHighlighted:
                              bi < moves.length && currentHalf == bi,
                          onWhiteTap: () => notifier.goToReview(wi + 1),
                          onBlackTap: bi < moves.length
                              ? () => notifier.goToReview(bi + 1)
                              : null,
                        );
                      },
                    ),
            ),

            const Divider(color: Color(0xFF2A2520), height: 1),

            // ── Navigation buttons ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SheetNavBtn(
                      icon: Icons.first_page_rounded,
                      onTap: () => notifier.reviewFirst()),
                  _SheetNavBtn(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => notifier.reviewPrev()),
                  _SheetNavBtn(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => notifier.reviewNext()),
                  _SheetNavBtn(
                      icon: Icons.last_page_rounded,
                      onTap: () => notifier.exitReview()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Move Pair Row ─────────────────────────────────────────────────────────────

class _MovePairRow extends StatelessWidget {
  final int moveNumber;
  final String whiteLabel;
  final String? blackLabel;
  final bool whiteHighlighted;
  final bool blackHighlighted;
  final VoidCallback onWhiteTap;
  final VoidCallback? onBlackTap;

  const _MovePairRow({
    required this.moveNumber,
    required this.whiteLabel,
    this.blackLabel,
    required this.whiteHighlighted,
    required this.blackHighlighted,
    required this.onWhiteTap,
    this.onBlackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        children: [
          // Move number
          SizedBox(
            width: 34,
            child: Text(
              '$moveNumber.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: const Color(0xFF504840),
              ),
            ),
          ),
          // White move
          Expanded(
            child: GestureDetector(
              onTap: onWhiteTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: whiteHighlighted
                      ? const Color(0xFFE8B960)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  whiteLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: whiteHighlighted
                        ? const Color(0xFF1A1205)
                        : const Color(0xFFD0C8BF),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Black move
          Expanded(
            child: blackLabel != null
                ? GestureDetector(
                    onTap: onBlackTap,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: blackHighlighted
                            ? const Color(0xFFE8B960)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        blackLabel!,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: blackHighlighted
                              ? const Color(0xFF1A1205)
                              : const Color(0xFFD0C8BF),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ── Sheet Nav Button ──────────────────────────────────────────────────────────

class _SheetNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SheetNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 52, height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF8A7E74)),
      ),
    );
  }
}
