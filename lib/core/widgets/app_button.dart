import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/moulded.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost, danger }

/// The app's button: a moulded token (see moulded.dart).
///
///   primary   → butterscotch, the one main action on a screen
///   secondary / outlined → a raised token of the surface
///   danger    → coral face for destructive actions
///   ghost     → plain text action, no token
class AppButton extends StatelessWidget {
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

  Color get _face => switch (variant) {
        AppButtonVariant.primary => AppColors.accent,
        AppButtonVariant.danger => AppColors.loss,
        _ => AppColors.cardElevated,
      };

  Color get _ink => switch (variant) {
        AppButtonVariant.primary => AppColors.onAmber,
        AppButtonVariant.danger => AppColors.onAmber,
        AppButtonVariant.ghost => AppColors.accent,
        _ => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !isLoading;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _ink),
          )
        else ...[
          if (icon != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: _ink, size: 20),
              child: icon!,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.buttonLarge.copyWith(
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );

    final h = height ?? 52;

    if (variant == AppButtonVariant.ghost) {
      return SizedBox(
        height: h,
        width: expand ? double.infinity : null,
        child: TextButton(
          onPressed: enabled ? onTap : null,
          child: content,
        ),
      );
    }

    return SizedBox(
      height: h,
      width: expand ? double.infinity : null,
      child: Moulded(
        color: _face,
        radius: 12,
        semanticLabel: label,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: content),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.backgroundColor,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: Moulded(
        color: backgroundColor ?? AppColors.card,
        radius: 12,
        lip: 3,
        semanticLabel: tooltip,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Center(child: icon),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
