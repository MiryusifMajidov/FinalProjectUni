import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_extension.dart';
import '../../../core/models/game_model.dart';

import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:easy_localization/easy_localization.dart';
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
          icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
          color: AppColors.bullet,
          label: 'bullet'.tr(),
          controls: TimeControls.allBullet,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeControlRow(
          icon: PhosphorIcons.fire(PhosphorIconsStyle.fill),
          color: AppColors.blitz,
          label: 'blitz'.tr(),
          controls: TimeControls.allBlitz,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 10),
        _TimeControlRow(
          icon: PhosphorIcons.timer(PhosphorIconsStyle.fill),
          color: AppColors.rapid,
          label: 'rapid'.tr(),
          controls: TimeControls.allRapid,
          selected: selected,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _TimeControlRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final List<TimeControl> controls;
  final TimeControl selected;
  final void Function(TimeControl) onSelect;

  const _TimeControlRow({
    required this.icon,
    required this.color,
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
          width: 78,
          child: Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall),
              ),
            ],
          ),
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
