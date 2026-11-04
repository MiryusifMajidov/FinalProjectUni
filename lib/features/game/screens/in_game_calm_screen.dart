import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/cache_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../engine/chess_engine.dart';
import '../providers/game_provider.dart';
import '../widgets/captured_pieces.dart';
import '../widgets/chess_board_widget.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/board_themes.dart';
// ── Design tokens ──────────────────────────────────────────────────────────────
const _kBg        = AppColors.background;   // slightly warm near-black
const _kCard      = AppColors.card;
const _kAmber     = AppColors.amber;
const _kAmberGlow = AppColors.amberGlow;
const _kInk       = AppColors.ink;
const _kInkDim    = AppColors.inkDim;
const _kInkMute   = AppColors.inkMute;
const _kBorder    = AppColors.border;
const _kDanger    = AppColors.loss;

/// Calm redesign of the game screen — used for both online multiplayer and
/// bot games.  The mode is read from [GameConfig.mode]; when it is
/// [GameMode.bot] the UI swaps the eval bar for a hint chip and changes the
/// action row to Hint / Undo / Resign.
class InGameCalmScreen extends ConsumerStatefulWidget {
  final String gameId;
  final Map<String, dynamic>? extra;

  const InGameCalmScreen({
    super.key,
    required this.gameId,
    this.extra,
  });

  @override
  ConsumerState<InGameCalmScreen> createState() => _InGameCalmScreenState();
}

class _InGameCalmScreenState extends ConsumerState<InGameCalmScreen> {
  late GameConfig _config;

  @override
  void initState() {
    super.initState();
    final e = widget.extra ?? {};
    _config = GameConfig(
      mode: GameMode.values.byName(
          e['mode'] as String? ?? GameMode.online.name),
      timeControl: e['timeControl'] != null
          ? TimeControl.fromMap(e['timeControl'] as Map<String, dynamic>)
          : TimeControls.rapid10,
      playerIsWhite: e['playerIsWhite'] as bool? ?? true,
      botRating: e['botRating'] as int?,
      isRated: e['isRated'] as bool? ?? false,
      gameId: widget.gameId,
      campaignChapter: e['campaignChapter'] as int?,
      opponentUid: e['opponentUid'] as String?,
      opponentRating: e['opponentRating'] as int?,
      opponentCountryCode: e['opponentCountryCode'] as String?,
      myUsername: e['myUsername'] as String?,
      opponentUsername: e['opponentUsername'] as String?,
      arenaId: e['arenaId'] as String?,
      arenaBotUid: e['arenaBotUid'] as String?,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _tcBadge(TimeControl tc, bool isBot, bool isRated) {
    if (isBot) return 'VS BOT · ${isRated ? 'RATED' : 'CASUAL'}';
    final category = switch (tc.category) {
      TimeControlCategory.bullet => 'BULLET',
      TimeControlCategory.blitz  => 'BLITZ',
      TimeControlCategory.rapid  => 'RAPID',
    };
    return '$category · ${tc.minutes} MIN · ${isRated ? 'RATED' : 'CASUAL'}';
  }

  String _sub(int? rating, String? countryCode) {
    final r = rating != null ? _fmtRating(rating) : '—';
    final flag = countryCode != null ? UserModel.flagEmoji(countryCode) : '';
    return flag.isNotEmpty ? '$r · $flag' : r;
  }

  String _fmtRating(int r) {
    if (r >= 1000) return '${r ~/ 1000},${(r % 1000).toString().padLeft(3, '0')}';
    return r.toString();
  }

  // ── Resign modal ─────────────────────────────────────────────────────────────

  void _showResign(BuildContext ctx, GameNotifier notifier) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kDanger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIcons.flag(PhosphorIconsStyle.fill),
                color: _kDanger,
                size: 20,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'resign'.tr(),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'leave_game_warning'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _kInkMute,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  notifier.resign();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDanger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'resign'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: _kInkDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs       = ref.watch(gameProvider(_config));
    final notifier = ref.read(gameProvider(_config).notifier);
    final settings = ref.watch(settingsProvider);
    final cache    = ref.watch(cacheServiceProvider);
    final userAsync = ref.watch(currentUserProvider);
    final myUser   = userAsync.valueOrNull;

    final isBot   = _config.mode == GameMode.bot;
    final engine  = gs.engine;
    final move    = (engine.moveCount / 2).ceil();

    // Player display info
    final myName  = _config.myUsername ?? myUser?.username ?? 'You';
    final oppName = _config.opponentUsername
        ?? (isBot ? 'Stockfish' : 'Opponent');

    // Clocks (ms)
    final myMs  = gs.playerIsWhite ? gs.whiteMsLeft : gs.blackMsLeft;
    final oppMs = gs.playerIsWhite ? gs.blackMsLeft : gs.whiteMsLeft;

    // Captured pieces
    final myCapt  = gs.playerIsWhite
        ? engine.capturedByWhite
        : engine.capturedByBlack;
    final oppCapt = gs.playerIsWhite
        ? engine.capturedByBlack
        : engine.capturedByWhite;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => context.pop(),
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Minimal header ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(
                            PhosphorIcons.caretLeft(
                                PhosphorIconsStyle.regular),
                            color: _kInkDim,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _tcBadge(
                                _config.timeControl, isBot, _config.isRated),
                            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 10.5,
                              color: _kInkMute,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBot
                                ? (gs.isMyTurn ? 'Your turn' : 'Thinking…')
                                : 'Move $move',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13,
                              color: _kInkDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Icon(
                          PhosphorIcons.dotsThree(PhosphorIconsStyle.bold),
                          size: 18,
                          color: _kInkDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Opponent strip ───────────────────────────────────────────
              _CalmStrip(
                name: oppName,
                sub: isBot
                    ? 'LV. 3 · ${_config.opponentRating ?? 800} ELO'
                    : _sub(_config.opponentRating, _config.opponentCountryCode),
                msLeft: oppMs,
                active: !gs.isMyTurn &&
                    gs.status == GameStatus.playing,
                captured: oppCapt,
                pieceSet: settings.pieceSet.folderName,
                isTop: true,
              ),

              // ── Chess board ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: LayoutBuilder(
                  builder: (_, box) {
                    final size = box.maxWidth;
                    return SizedBox(
                      width: size,
                      height: size,
                      child: ChessBoardWidget(
                        engine: engine,
                        flipped: !gs.playerIsWhite,
                        selectedSquare: gs.selectedSquare,
                        legalMoveSquares: cache.showLegalMoves
                            ? gs.legalMoveSquares
                            : const [],
                        onSquareTap: notifier.onSquareTapped,
                        boardTheme: settings.boardTheme,
                        pieceSet: settings.pieceSet,
                        showCoordinates: cache.showCoordinates,
                        showLastMoveHighlight: cache.highlightLastMove,
                        animationDuration: cache.pieceMoveAnimationDuration,
                        premoveFrom: gs.premoveFrom,
                        premoveTo: gs.premoveTo,
                      ),
                    );
                  },
                ),
              ),

              // ── Eval bar (online) OR hint chip (bot) ─────────────────────
              if (!isBot)
                const _EvalBar()
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _kAmberGlow,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: _kAmber.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.robot(PhosphorIconsStyle.regular),
                            size: 14,
                            color: _kAmber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            gs.isMyTurn
                                ? 'Your turn — find the best move'
                                : 'Stockfish is thinking…',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _kAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── My strip ─────────────────────────────────────────────────
              _CalmStrip(
                name: myName,
                sub: _sub(myUser?.overallRating, myUser?.countryCode),
                msLeft: myMs,
                active: gs.isMyTurn &&
                    gs.status == GameStatus.playing,
                captured: myCapt,
                pieceSet: settings.pieceSet.folderName,
                isTop: false,
              ),

              // ── Action row ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                child: Row(
                  children: isBot
                      ? [
                          _ActionBtn(
                            icon: PhosphorIcons.lightbulb(
                                PhosphorIconsStyle.regular),
                            label: 'Hint',
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          _ActionBtn(
                            icon: PhosphorIcons.arrowCounterClockwise(
                                PhosphorIconsStyle.regular),
                            label: 'Undo',
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          _ActionBtn(
                            icon: PhosphorIcons.flag(
                                PhosphorIconsStyle.regular),
                            label: 'Resign',
                            isDanger: true,
                            onTap: () => _showResign(context, notifier),
                          ),
                        ]
                      : [
                          _ActionBtn(
                            icon: PhosphorIcons.chatCircle(
                                PhosphorIconsStyle.regular),
                            label: 'Chat',
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          _ActionBtn(
                            icon: PhosphorIcons.handshake(
                                PhosphorIconsStyle.regular),
                            label: 'Draw',
                            onTap: () => notifier.offerDraw(),
                          ),
                          const SizedBox(width: 10),
                          _ActionBtn(
                            icon: PhosphorIcons.flag(
                                PhosphorIconsStyle.regular),
                            label: 'Resign',
                            isDanger: true,
                            onTap: () => _showResign(context, notifier),
                          ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CalmStrip ─────────────────────────────────────────────────────────────────

class _CalmStrip extends StatelessWidget {
  final String name;
  final String sub;
  final int msLeft;
  final bool active;
  final List<PieceInfo> captured;
  final String pieceSet;
  final bool isTop;

  const _CalmStrip({
    required this.name,
    required this.sub,
    required this.msLeft,
    required this.active,
    required this.captured,
    required this.pieceSet,
    required this.isTop,
  });

  String _formatClock(int ms) {
    final total = (ms / 1000).ceil().clamp(0, 59940);
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final clock   = msLeft <= 0 ? '00:00' : _formatClock(msLeft);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: active
          ? BoxDecoration(
              border: Border(
                top: isTop
                    ? BorderSide(
                        color: _kAmber.withValues(alpha: 0.15), width: 1)
                    : BorderSide.none,
                bottom: !isTop
                    ? BorderSide(
                        color: _kAmber.withValues(alpha: 0.15), width: 1)
                    : BorderSide.none,
              ),
            )
          : null,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _kAmberGlow : const Color(0xFF1A1A1E),
              border: Border.all(
                color: active
                    ? _kAmber.withValues(alpha: 0.5)
                    : const Color(0xFF2A2520),
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? _kAmber : _kInkDim,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + sub + captures
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? _kInk : _kInkDim,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      sub,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _kInkMute,
                      ),
                    ),
                    if (captured.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: CapturedPieces(
                            pieces: captured,
                            pieceSet: pieceSet,
                            color: _kInkMute,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Clock
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? _kAmber : const Color(0xFF1A1A1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              clock,
              style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 16,
                fontWeight: FontWeight.w700,
                color: active ? const Color(0xFF1A1205) : _kInkMute,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Eval bar ──────────────────────────────────────────────────────────────────

class _EvalBar extends StatelessWidget {
  const _EvalBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
      child: Row(
        children: [
          Text(
            '+0.4',
            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
              color: _kInkMute,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => SizedBox(
                height: 10,
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
                    // Center tick
                    Center(
                      child: Container(
                        width: 1,
                        height: 10,
                        color: const Color(0xFF3D3530),
                      ),
                    ),
                    // Amber glowing dot (slight white advantage)
                    Positioned(
                      left: box.maxWidth * 0.54 - 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kAmber,
                          boxShadow: [
                            BoxShadow(
                              color: _kAmber.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'slight edge',
            style: GoogleFonts.inter(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
              color: _kInkMute,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? _kDanger.withValues(alpha: 0.85)
        : _kInkDim;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
