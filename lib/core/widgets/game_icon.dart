import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/game_type.dart';

/// Vector icon for a game type: a knight (from the app's own cburnett piece
/// set), a checkers disc or a domino tile.
///
/// These replace the Unicode glyphs ♞ ⛀ 🁫 that were used as icons. Glyphs
/// render with whatever font the phone happens to have — the domino came out
/// as an empty box on many Androids, the checkers disc as a stack of ovals —
/// and never matched the rest of the icon set.
class GameIcon extends StatelessWidget {
  final GameType type;
  final double size;
  final Color color;

  const GameIcon({
    super.key,
    required this.type,
    this.size = 18,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Widget icon = switch (type) {
      GameType.chess => SvgPicture.asset(
          'assets/pieces/cburnett/bN.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      GameType.checkers => CustomPaint(
          size: Size.square(size),
          painter: _DiscPainter(color),
        ),
      GameType.domino => CustomPaint(
          size: Size.square(size),
          painter: _DominoPainter(color),
        ),
    };
    return ExcludeSemantics(child: SizedBox.square(dimension: size, child: icon));
  }
}

/// A chess piece from the app's piece set, e.g. `PieceIcon('wK')`.
///
/// With [color] the piece is drawn as a flat silhouette in that colour (for
/// use as an icon); without it, in the piece set's own black and white.
class PieceIcon extends StatelessWidget {
  /// Colour + piece letter as in the asset names: wK, bQ, wN, bP…
  final String piece;
  final double size;
  final Color? color;

  /// Folder under assets/pieces/ — the board's piece set where it matters.
  final String pieceSet;

  const PieceIcon(this.piece,
      {super.key, this.size = 22, this.color, this.pieceSet = 'cburnett'});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        'assets/pieces/$pieceSet/$piece.svg',
        width: size,
        height: size,
        colorFilter:
            color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
  }
}

/// Top view of a checkers piece: a disc with an inset ring.
class _DiscPainter extends CustomPainter {
  final Color color;
  _DiscPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.42;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(c, r, Paint()..color = color);
    // Cut the ring out of the disc so it shows the background, whatever it is.
    canvas.drawCircle(
      c,
      r * 0.62,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.shortestSide * 0.08).clamp(1.0, 4.0),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.color != color;
}

/// An upright domino tile: outline, centre bar, one pip above and two below.
class _DominoPainter extends CustomPainter {
  final Color color;
  _DominoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = (s * 0.085).clamp(1.2, 4.0);
    final w = s * 0.56;
    final h = s * 0.9;
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect.deflate(stroke / 2), Radius.circular(s * 0.12));
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRRect(rrect, line);
    canvas.drawLine(
      Offset(rect.left + w * 0.22, rect.center.dy),
      Offset(rect.right - w * 0.22, rect.center.dy),
      line,
    );
    final pip = Paint()..color = color;
    final pr = s * 0.065;
    // Top half: one pip in the middle.
    canvas.drawCircle(Offset(rect.center.dx, rect.top + h * 0.25), pr, pip);
    // Bottom half: two pips on the diagonal.
    canvas.drawCircle(Offset(rect.left + w * 0.33, rect.top + h * 0.64), pr, pip);
    canvas.drawCircle(Offset(rect.right - w * 0.33, rect.top + h * 0.86), pr, pip);
  }

  @override
  bool shouldRepaint(_DominoPainter old) => old.color != color;
}

/// One side of a game in "you play as…" pickers: a king on a light or dark
/// disc for chess, a light or dark disc for checkers, a tile for domino.
class SideToken extends StatelessWidget {
  final GameType type;
  final bool light;
  final double size;

  const SideToken({
    super.key,
    required this.type,
    required this.light,
    this.size = 28,
  });

  static const _lightFill = Color(0xFFECECF2);
  static const _darkFill = Color(0xFF2A2A30);

  @override
  Widget build(BuildContext context) {
    if (type == GameType.chess) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: light ? _lightFill : _darkFill,
          border: Border.all(
            color: light ? Colors.transparent : const Color(0x33FFFFFF),
          ),
        ),
        alignment: Alignment.center,
        child: PieceIcon(
          'bK',
          size: size * 0.64,
          color: light ? const Color(0xFF1A1A1E) : _lightFill,
        ),
      );
    }
    return GameIcon(
      type: type,
      size: size,
      color: light ? _lightFill : const Color(0xFF8A847A),
    );
  }
}
