import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A suggested move drawn on a board the way analysis boards show an engine
/// line: a ring on the final square and an arrow through every square of
/// the move (the origin square's tint is painted by the board itself, under
/// the pieces) (one segment for chess, several
/// for a draughts multi-jump). Used by the Hint button on both boards.
///
/// [points] are square centres in board pixels; [cell] is the square size.
/// [progress] (0–1) grows the arrow out of the origin.
class HintArrowPainter extends CustomPainter {
  final List<Offset> points;
  final double cell;
  final double progress;

  HintArrowPainter({
    required this.points,
    required this.cell,
    required this.progress,
  });

  static const _jade = AppColors.hint;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final s = cell;
    final t = progress.clamp(0.0, 1.0);
    final a = points.first;
    final b = points.last;

    canvas.drawCircle(
      b,
      s * 0.40,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.075
        ..color = _jade.withValues(alpha: 0.9 * t),
    );

    // The visible part of the polyline, [progress] of its full length, with
    // the last segment stopping short of the final centre for the head.
    final segs = <(Offset, Offset)>[];
    for (var i = 0; i + 1 < points.length; i++) {
      segs.add((points[i], points[i + 1]));
    }
    final lengths = [for (final (p, q) in segs) (q - p).distance];
    final total = lengths.fold<double>(0, (x, y) => x + y) - s * 0.12;
    if (total <= 0) return;
    var remaining = total * t;

    final shaft = Paint()
      ..color = _jade.withValues(alpha: 0.88)
      ..strokeWidth = s * 0.19
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(a.dx, a.dy);
    Offset tip = a;
    Offset dir = Offset.zero;
    for (var i = 0; i < segs.length && remaining > 0; i++) {
      final (p, q) = segs[i];
      final len = lengths[i];
      final unit = (q - p) / len;
      final step = remaining < len ? remaining : len;
      tip = p + unit * step;
      dir = unit;
      remaining -= step;
    }
    if (dir == Offset.zero) return;

    // Shaft up to the base of the head, starting a little inside the origin.
    final headLen = s * 0.42;
    final headHalf = s * 0.27;
    final base = tip - dir * headLen;
    var drawn = 0.0;
    final shaftLen = (total * t - headLen).clamp(0.0, double.infinity);
    final start = a + (segs.first.$2 - a) / lengths.first * (s * 0.18);
    path.reset();
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < segs.length; i++) {
      final (p, q) = segs[i];
      final len = lengths[i];
      if (drawn + len >= shaftLen) {
        final end = p + (q - p) / len * (shaftLen - drawn);
        path.lineTo(end.dx, end.dy);
        break;
      }
      path.lineTo(q.dx, q.dy);
      drawn += len;
    }
    if (shaftLen > s * 0.18) canvas.drawPath(path, shaft);

    final normal = Offset(-dir.dy, dir.dx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + normal * headHalf).dx, (base + normal * headHalf).dy)
      ..lineTo((base - normal * headHalf).dx, (base - normal * headHalf).dy)
      ..close();
    canvas.drawPath(head, Paint()..color = _jade.withValues(alpha: 0.88));
  }

  @override
  bool shouldRepaint(HintArrowPainter old) =>
      old.progress != progress ||
      old.cell != cell ||
      !_samePoints(old.points, points);

  static bool _samePoints(List<Offset> x, List<Offset> y) {
    if (x.length != y.length) return false;
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }
}

/// Grows a [HintArrowPainter] in over 320 ms whenever [points] change.
class HintArrow extends StatelessWidget {
  final List<Offset> points;
  final double cell;
  const HintArrow({super.key, required this.points, required this.cell});

  @override
  Widget build(BuildContext context) {
    // "Remove animations" in the system settings: draw it at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      return IgnorePointer(
        child: CustomPaint(
          painter: HintArrowPainter(points: points, cell: cell, progress: 1),
        ),
      );
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(points.map((p) => '${p.dx.round()},${p.dy.round()}').join('|')),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, t, __) => CustomPaint(
          painter: HintArrowPainter(points: points, cell: cell, progress: t),
        ),
      ),
    );
  }
}
