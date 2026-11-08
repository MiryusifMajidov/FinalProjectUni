import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// The house signature: controls are moulded catalin tokens.
///
/// A [MouldedBorder] paints a darker band along the bottom of whatever fill
/// the control has — the token's thickness. Pressed, the band goes away and
/// the token reads as pushed in. Because the band is a translucent shade, the
/// same border works on butterscotch, cherry, jade or a plain surface.
class MouldedBorder extends OutlinedBorder {
  final BorderRadius borderRadius;
  final double lip;

  const MouldedBorder({
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.lip = 4,
    super.side = BorderSide.none,
  });

  static const _shade = Color(0x4D000000);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect).deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(borderRadius.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final rrect = borderRadius.toRRect(rect);
    if (lip > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.bottom - lip, rect.right, rect.bottom),
        Paint()..color = _shade,
      );
      canvas.restore();
    }
    if (side.style != BorderStyle.none && side.width > 0) {
      canvas.drawRRect(rrect.deflate(side.width / 2), side.toPaint());
    }
  }

  @override
  MouldedBorder copyWith({BorderSide? side, BorderRadius? borderRadius, double? lip}) =>
      MouldedBorder(
        side: side ?? this.side,
        borderRadius: borderRadius ?? this.borderRadius,
        lip: lip ?? this.lip,
      );

  @override
  ShapeBorder scale(double t) => MouldedBorder(
        side: side.scale(t),
        borderRadius: borderRadius * t,
        lip: lip * t,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is MouldedBorder) {
      return MouldedBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        lip: lerpDouble(a.lip, lip, t)!,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is MouldedBorder) {
      return MouldedBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: BorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        lip: lerpDouble(lip, b.lip, t)!,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is MouldedBorder &&
      other.side == side &&
      other.borderRadius == borderRadius &&
      other.lip == lip;

  @override
  int get hashCode => Object.hash(side, borderRadius, lip);
}

/// Button style for a moulded token: [fill] face, [onFill] label, the lip
/// sinking away while pressed and the face dimming when disabled.
ButtonStyle mouldedStyle({
  required Color fill,
  required Color onFill,
  double radius = 12,
  double lip = 4,
  // Small vertical padding: many call sites pin the height (44–52 dp) and
  // the label must stay centred above the lip inside it.
  EdgeInsetsGeometry padding =
      const EdgeInsets.fromLTRB(18, 8, 18, 10),
  TextStyle? textStyle,
  Size minimumSize = const Size(64, 48),
}) {
  final r = BorderRadius.circular(radius);
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? fill.withValues(alpha: 0.38) : fill),
    foregroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? onFill.withValues(alpha: 0.6) : onFill),
    overlayColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    padding: WidgetStatePropertyAll(padding),
    minimumSize: WidgetStatePropertyAll(minimumSize),
    shape: WidgetStateProperty.resolveWith((s) => MouldedBorder(
          borderRadius: r,
          lip: s.contains(WidgetState.pressed) || s.contains(WidgetState.disabled)
              ? 0
              : lip,
        )),
    textStyle: WidgetStatePropertyAll(textStyle ??
        AppFonts.ui(fontSize: 16, fontWeight: FontWeight.w700)),
    animationDuration: const Duration(milliseconds: 90),
    splashFactory: NoSplash.splashFactory,
  );
}

/// The primary action: a token in [fill] (butterscotch unless given; the
/// app theme passes the selected game's colour).
ButtonStyle mouldedPrimary({double radius = 12, Color fill = AppColors.amber}) =>
    mouldedStyle(
      fill: fill,
      onFill: AppColors.onAmber,
      radius: radius,
    );

/// A secondary action: a raised token of the surface itself.
ButtonStyle mouldedTonal({double radius = 12}) => mouldedStyle(
      fill: AppColors.cardElevated,
      onFill: AppColors.ink,
      radius: radius,
    );

/// A tappable moulded token for custom layouts (tiles, chips, big Play
/// buttons) that are not Material buttons. The face sits [lip] dp above a
/// darker base; pressed, it drops onto the base.
class Moulded extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color? lipColor;
  final double radius;
  final double lip;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final bool selected;

  const Moulded({
    super.key,
    required this.child,
    this.onTap,
    this.color = AppColors.cardElevated,
    this.lipColor,
    this.radius = 12,
    this.lip = 4,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.selected = false,
  });

  /// Darker shade of [c] for its lip.
  static Color shade(Color c) =>
      Color.alphaBlend(Colors.black.withValues(alpha: 0.32), c);

  @override
  State<Moulded> createState() => _MouldedState();
}

class _MouldedState extends State<Moulded> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final lip = widget.lip;
    final sink = _down ? lip : 0.0;
    final face = enabled
        ? widget.color
        : Color.alphaBlend(
            AppColors.background.withValues(alpha: 0.45), widget.color);
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.lipColor ?? Moulded.shade(face),
            borderRadius: r,
          ),
          margin: EdgeInsets.only(top: sink),
          padding: EdgeInsets.only(bottom: lip - sink),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 70),
            padding: widget.padding,
            decoration: BoxDecoration(color: face, borderRadius: r),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
