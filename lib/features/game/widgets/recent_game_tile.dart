import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/services/bot_pool.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/models/game_model.dart';
import '../../../core/models/game_type.dart';

import '../../../core/widgets/game_icon.dart';
import '../../../core/theme/app_fonts.dart';
class RecentGameTile extends StatelessWidget {
  final GameModel game;
  final String uid;

  const RecentGameTile({super.key, required this.game, required this.uid});

  bool get _isWhite => game.whiteUid == uid;

  String get _opponent => _isWhite
      ? (game.blackUsername ?? 'opponent'.tr())
      : (game.whiteUsername ?? 'opponent'.tr());

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
    if (game.result == GameResult.draw) return 'draw'.tr();
    final won = _isWhite
        ? game.result == GameResult.white
        : game.result == GameResult.black;
    return (won ? 'result_won' : 'result_lost').tr();
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
          // Game-type icon
          _MiniBoardPreview(type: gt, accent: gt.accent),
          const SizedBox(width: 12),
          // Opponent + time control
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _opponent,
                  style: AppFonts.ui(
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
                  style: AppFonts.ui(
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
                  _resultLabel,
                  style: AppFonts.ui(
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
                  style: AppFonts.ui(fontFeatures: const [FontFeature.tabularFigures()], fontSize: 11,
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

  /// Played against a stand-in (a `bot_…` opponent under a player name).
  bool get _vsStandIn => [game.whiteUid, game.blackUid]
      .any((u) => BotPool.isBotUid(u) && !BotPool.isLabelledUid(u));

  String _modeLabel() => switch (game.mode) {
        GameMode.bot when _vsStandIn => 'online'.tr(),
        GameMode.bot => 'vs_bot'.tr(),
        GameMode.campaign => 'campaign'.tr(),
        GameMode.online => game.isRated ? 'rated_game'.tr() : 'online'.tr(),
        GameMode.local => 'local_game'.tr(),
      };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today'.tr();
    if (diff.inDays == 1) return 'yesterday'.tr();
    if (diff.inDays < 7) return 'days_ago_n'.tr(args: ['${diff.inDays}']);
    return DateFormat.MMMd().format(dt);
  }
}

// Small 4×4 abstract board watermark with the game-type glyph on top
class _MiniBoardPreview extends StatelessWidget {
  final GameType type;
  final Color accent;
  const _MiniBoardPreview({required this.type, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: Center(child: GameIcon(type: type, size: 18, color: accent)),
    );
  }
}

