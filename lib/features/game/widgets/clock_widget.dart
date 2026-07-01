import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';

class ClockWidget extends StatelessWidget {
  final int milliseconds;
  final bool isActive;
  final bool isWhite;

  const ClockWidget({
    super.key,
    required this.milliseconds,
    required this.isActive,
    required this.isWhite,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    final tenths = (milliseconds % 1000) ~/ 100;

    final isCritical = seconds < 10;
    final timeText = isCritical
        ? '$seconds.$tenths'
        : '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? (isWhite ? Colors.white : context.appColors.cardElevated)
            : context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(
                color: isCritical
                    ? AppColors.error
                    : (isWhite ? AppColors.textPrimary : AppColors.primary),
                width: 2,
              )
            : null,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (isCritical ? AppColors.error : AppColors.primary)
                      .withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Text(
        timeText,
        style: AppTextStyles.ratingSmall.copyWith(
          color: isActive
              ? (isCritical
                  ? AppColors.error
                  : (isWhite ? context.appColors.background : AppColors.textPrimary))
              : AppColors.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
