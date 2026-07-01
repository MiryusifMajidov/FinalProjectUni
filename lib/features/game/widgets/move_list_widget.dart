import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class MoveListWidget extends StatelessWidget {
  final List<String> moves;
  /// Verbose move history for long-algebraic notation. When null, long notation
  /// falls back to SAN.
  final List<({String from, String to, String san})>? verboseHistory;
  /// Notation style: 'san' (default), 'long' (e.g. e2e4), 'figurine' (♕ symbols)
  final String notation;
  final int? reviewIndex;
  final VoidCallback onFirst;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLast;

  const MoveListWidget({
    super.key,
    required this.moves,
    this.verboseHistory,
    this.notation = 'san',
    this.reviewIndex,
    required this.onFirst,
    required this.onPrev,
    required this.onNext,
    required this.onLast,
  });

  /// Converts a SAN string to the requested notation.
  String _formatMove(String san, int moveIdx) {
    switch (notation) {
      case 'figurine':
        return san
            .replaceAll('N', '♘')
            .replaceAll('B', '♗')
            .replaceAll('R', '♖')
            .replaceAll('Q', '♕')
            .replaceAll('K', '♔');
      case 'long':
        if (verboseHistory != null && moveIdx < verboseHistory!.length) {
          final v = verboseHistory![moveIdx];
          if (v.from.isNotEmpty && v.to.isNotEmpty) return '${v.from}${v.to}';
        }
        return san;
      default: // 'san'
        return san;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = <(int, String, String?)>[];
    for (var i = 0; i < moves.length; i += 2) {
      pairs.add((i ~/ 2 + 1, moves[i], i + 1 < moves.length ? moves[i + 1] : null));
    }

    return Column(
      children: [
        Expanded(
          child: moves.isEmpty
              ? Center(child: Text('no_moves_yet'.tr(), style: AppTextStyles.bodySmall))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: pairs.length,
                  itemBuilder: (_, i) {
                    final rawPair = pairs[i];
                    final num   = rawPair.$1;
                    final white = _formatMove(rawPair.$2, i * 2);
                    final String? black = rawPair.$3 != null
                        ? _formatMove(rawPair.$3!, i * 2 + 1)
                        : null;

                    // Determine highlighting
                    final isLive = reviewIndex == null;
                    final isLastLive = isLive && i == pairs.length - 1;

                    bool whiteHighlighted = false;
                    bool blackHighlighted = false;
                    if (reviewIndex != null && reviewIndex! > 0) {
                      final moveIdx = reviewIndex! - 1;
                      if (moveIdx ~/ 2 == i) {
                        if (moveIdx % 2 == 0) whiteHighlighted = true;
                        else blackHighlighted = true;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isLastLive ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('$num.', style: AppTextStyles.monoMove.copyWith(color: AppColors.textHint)),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: whiteHighlighted ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(white, style: AppTextStyles.monoMove),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: blackHighlighted ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                black ?? '',
                                style: AppTextStyles.monoMove.copyWith(
                                  color: black == null ? Colors.transparent : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Navigation buttons
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBtn(icon: Icons.first_page_rounded, onTap: onFirst),
              _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
              _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
              _NavBtn(icon: Icons.last_page_rounded, onTap: onLast),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.textSecondary, size: 22),
      onPressed: onTap,
      splashRadius: 20,
    );
  }
}
