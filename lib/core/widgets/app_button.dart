import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_extension.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost, danger }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool expand;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  Color get _bgColor => switch (widget.variant) {
        AppButtonVariant.primary => AppColors.primary,
        AppButtonVariant.secondary => AppColors.secondary,
        AppButtonVariant.outlined => Colors.transparent,
        AppButtonVariant.ghost => Colors.transparent,
        AppButtonVariant.danger => AppColors.error,
      };

  Color get _textColor => switch (widget.variant) {
        AppButtonVariant.primary => const Color(0xFF0A0A0B),  // dark on amber
        AppButtonVariant.outlined => AppColors.ink,
        AppButtonVariant.ghost => AppColors.amber,
        AppButtonVariant.danger => Colors.white,
        _ => const Color(0xFF0A0A0B),
      };

  Border? get _border => switch (widget.variant) {
        AppButtonVariant.outlined =>
          Border.all(color: AppColors.divider, width: 1.5),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height ?? 50,
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? AppColors.textDisabled
                : _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: _border,
            boxShadow: widget.variant == AppButtonVariant.primary &&
                    widget.onTap != null
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:
                widget.expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_textColor),
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: AppTextStyles.buttonLarge.copyWith(
                    color: widget.onTap == null
                        ? AppColors.textSecondary
                        : _textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return widget.expand ? child : child;
  }
}

class AppIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.backgroundColor,
    this.size = 44,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? context.appColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: widget.icon),
        ),
      ),
    );
  }
}
