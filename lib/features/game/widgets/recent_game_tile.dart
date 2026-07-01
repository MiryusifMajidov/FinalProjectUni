import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';

class RecentGameTile extends StatelessWidget {
  final GameModel game;
  final String uid;

  const RecentGameTile({super.key, required this.game, required this.uid});

  bool get _isWhite => game.whiteUid == uid;

  String get _opponent => _isWhite
      ? (game.blackUsername ?? 'Opponent')
      : (game.whiteUsername ?? 'Opponent');

  // result color trio: (foreground, background, left-bar)
  (Color, Color, Color) get _resultColors {
    final drew = game.result == GameResult.draw;
    if (drew) return (AppColors.draw, AppColors.drawSoft, AppColors.draw);
    final won = _isWhite
        ? game.result == GameResult.white
        : game.result == GameResult.black;
    return won
        ? (AppColors.win, AppColors.winSoft, AppColors.win)
        : (AppColors.loss, AppColors.lossSoft, AppColors.loss);
  }

  String get _resultLabel {
    if (game.result == GameResult.draw) return 'Draw';
    final won = _isWhite
        ? game.result == GameResult.white
        : game.result == GameResult.black;
    return won ? 'Won' : 'Lost';
  }

  int? get _ratingChange =>
      _isWhite ? game.whiteRatingChange : game.blackRatingChange;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, bar) = _resultColors;
    // For online games show ELO change even if null (treat as 0 — rating may
    // not have been stored for older games or fake-bot fallback edge cases).
    final rawChange = _ratingChange;
    final change = (game.mode == GameMode.online) ? (rawChange ?? 0) : rawChange;

    final gt = GameTypeX.fromString(game.gameType);
    // Chess entries show the clock; checkers/domino show the game name
    // (those records are untimed — '—' would be meaningless here).
    final detail =
        gt == GameType.chess ? game.timeControl.label : gt.identity.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Left color bar
          Container(
            width: 3,
            height: 44,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          // Mini board preview with the game-type glyph (♞ / ⛀ / 🁫)
          _MiniBoardPreview(glyph: gt.glyph, accent: gt.accent),
          const SizedBox(width: 12),
          // Opponent + time control
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _opponent,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$detail · ${_modeLabel()} · ${_formatDate(game.createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.inkMute,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Result + rating change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _resultLabel.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (change != null) ...[
                const SizedBox(height: 4),
                Text(
                  change >= 0 ? '+$change' : '$change',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: change > 0
                        ? AppColors.win
                        : change < 0
                            ? AppColors.loss
                            : AppColors.inkDim,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel() => switch (game.mode) {
        GameMode.bot => 'vs Bot',
        GameMode.campaign => 'Campaign',
        GameMode.online => 'Rated',
        GameMode.local => 'Local',
      };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// Small 4×4 abstract board watermark with the game-type glyph on top
class _MiniBoardPreview extends StatelessWidget {
  final String glyph;
  final Color accent;
  const _MiniBoardPreview({required this.glyph, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CheckerboardPainter()),
            // Dim wash so the glyph stays readable on the checker pattern
            Container(color: Colors.black.withValues(alpha: 0.35)),
            Center(
              child: Text(
                glyph,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.0,
                  color: Color(0xFFF5F3EF),
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  static const _dark  = Color(0xFF3d2e1e);
  static const _light = Color(0xFFd9c4a0);

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint  = Paint()..color = _dark;
    final lightPaint = Paint()..color = _light;
    final cellW = size.width  / 4;
    final cellH = size.height / 4;

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        final isDark = (row + col).isOdd;
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH),
          isDark ? darkPaint : lightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter old) => false;
}
