import 'package:flutter/material.dart';

/// Centralized responsive breakpoints for the CheckMate app.
///
///  Phone   : shortestSide < 600
///  Tablet  : shortestSide >= 600
///  Large T : shortestSide >= 840
class Responsive {
  Responsive._();

  // ── Breakpoints ─────────────────────────────────────────────────────────────

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 840;

  static bool isPhone(BuildContext context) => !isTablet(context);

  // ── Screen dimensions ────────────────────────────────────────────────────────

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ── Adaptive horizontal padding ──────────────────────────────────────────────
  /// Phone → 20, Tablet → 32, Large tablet → 48
  static double hPadding(BuildContext context) {
    if (isLargeTablet(context)) return 48;
    if (isTablet(context)) return 32;
    return 20;
  }

  // ── Content max width (prevents stretching on very wide tablets) ─────────────
  /// Keeps content readable; phone fills full width.
  static double contentMaxWidth(BuildContext context) {
    if (isLargeTablet(context)) return 1000;
    if (isTablet(context)) return 720;
    return double.infinity;
  }

  // ── Column count for grids ───────────────────────────────────────────────────
  static int gridColumns(BuildContext context) => isTablet(context) ? 3 : 2;

  // ── Value by breakpoint ──────────────────────────────────────────────────────
  static T value<T>(
    BuildContext context, {
    required T phone,
    required T tablet,
    T? largeTablet,
  }) {
    if (isLargeTablet(context)) return largeTablet ?? tablet;
    if (isTablet(context)) return tablet;
    return phone;
  }
}

// ── Extension for concise access ──────────────────────────────────────────────

extension ResponsiveContext on BuildContext {
  bool get isTablet => Responsive.isTablet(this);
  bool get isLargeTablet => Responsive.isLargeTablet(this);
  bool get isPhone => Responsive.isPhone(this);
  double get hPadding => Responsive.hPadding(this);
  double get screenWidth => Responsive.width(this);
  double get screenHeight => Responsive.height(this);
  double get contentMaxWidth => Responsive.contentMaxWidth(this);
}
