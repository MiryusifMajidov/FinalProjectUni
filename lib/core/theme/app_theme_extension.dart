import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware color tokens. Access via `context.appColors`.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color background;
  final Color surface;
  final Color card;
  final Color cardElevated;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  const AppThemeExtension({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardElevated,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
  });

  static const dark = AppThemeExtension(
    background: AppColors.background,
    surface: AppColors.surface,
    card: AppColors.card,
    cardElevated: AppColors.cardElevated,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
  );

  static const light = AppThemeExtension(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    card: AppColors.lightCard,
    cardElevated: AppColors.lightCardElevated,
    divider: AppColors.lightDivider,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    textHint: AppColors.lightTextHint,
  );

  @override
  AppThemeExtension copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardElevated,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
  }) =>
      AppThemeExtension(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        card: card ?? this.card,
        cardElevated: cardElevated ?? this.cardElevated,
        divider: divider ?? this.divider,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textHint: textHint ?? this.textHint,
      );

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemeExtension get appColors =>
      Theme.of(this).extension<AppThemeExtension>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppThemeExtension.dark
          : AppThemeExtension.light);
}
