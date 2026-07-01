import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/models/game_model.dart';

class TimeControlSelector extends StatelessWidget {
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const TimeControlSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeControlRow(
          label: '⚡ Bullet',
          controls: TimeControls.allBullet,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeControlRow(
          label: '🔥 Blitz',
          controls: TimeControls.allBlitz,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeControlRow(
          label: '⏱ Rapid',
          controls: TimeControls.allRapid,
          selected: selected,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _TimeControlRow extends StatelessWidget {
  final String label;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeControlRow({
    required this.label,
    required this.controls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: AppTextStyles.labelSmall),
        ),
        Expanded(
          child: Row(
            children: controls.map((tc) {
              final isSelected = selected == tc;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(tc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.2)
                          : context.appColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        tc.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class ColorOptionButton extends StatelessWidget {
  final String label;
  final String symbol;
  final bool selected;
  final VoidCallback onTap;

  const ColorOptionButton({
    super.key,
    required this.label,
    required this.symbol,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.15)
                : context.appColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(symbol, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
