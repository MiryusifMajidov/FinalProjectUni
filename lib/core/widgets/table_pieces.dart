import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The three games laid on the table: a corner of a chessboard with a knight,
/// a cherry draughtsman and a domino. Drawn from the app's own assets and
/// shapes — this is what the app is, shown instead of described.
class TablePieces extends StatelessWidget {
  final double height;
  const TablePieces({super.key, this.height = 168});

  @override
  Widget build(BuildContext context) {
    final s = height / 168; // design scale
    return Semantics(
      image: true,
      label: 'Chess, draughts and dominoes',
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Board corner, slightly turned, knight on it.
            Positioned(
              left: 0,
              top: 8 * s,
              child: Transform.rotate(
                angle: -4 * math.pi / 180,
                child: _BoardCorner(square: 36 * s),
              ),
            ),
            // Draughtsman, resting against the board's edge.
            Positioned(
              left: 138 * s,
              top: 86 * s,
              child: Draughtsman(size: 62 * s),
            ),
            // Domino, leaning the other way.
            Positioned(
              left: 214 * s,
              top: 18 * s,
              child: Transform.rotate(
                angle: 9 * math.pi / 180,
                child: DominoBone(width: 54 * s, top: 5, bottom: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCorner extends StatelessWidget {
  final double square;
  const _BoardCorner({required this.square});

  @override
  Widget build(BuildContext context) {
    const cols = 4, rows = 4;
    return Container(
      padding: EdgeInsets.all(square * 0.14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4A2E), // the board's wooden frame
        borderRadius: BorderRadius.circular(square * 0.16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(square * 0.06),
        child: SizedBox(
          width: square * cols,
          height: square * rows,
          child: Stack(
            children: [
              Column(
                children: [
                  for (int r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (int c = 0; c < cols; c++)
                          Container(
                            width: square,
                            height: square,
                            color: (r + c).isEven
                                ? AppColors.boardBrown1
                                : AppColors.boardBrown2,
                          ),
                      ],
                    ),
                ],
              ),
              Positioned(
                left: square * 1,
                top: square * 1,
                child: SvgPicture.asset(
                  'assets/pieces/cburnett/wN.svg',
                  width: square,
                  height: square,
                ),
              ),
              Positioned(
                left: square * 2,
                top: square * 3,
                child: SvgPicture.asset(
                  'assets/pieces/cburnett/bP.svg',
                  width: square,
                  height: square,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cherry draughtsman seen from above: rim, groove and crown.
class Draughtsman extends StatelessWidget {
  final double size;
  final Color color;
  const Draughtsman({super.key, required this.size, this.color = AppColors.checkers});

  @override
  Widget build(BuildContext context) {
    final rim = Color.alphaBlend(Colors.black.withValues(alpha: 0.28), color);
    return SizedBox(
      width: size,
      height: size + size * 0.1,
      child: Stack(
        children: [
          // thickness
          Positioned(
            top: size * 0.1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: rim, shape: BoxShape.circle),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: size * 0.66,
              height: size * 0.66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rim, width: size * 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An ivory domino with black pips and a brass pin.
class DominoBone extends StatelessWidget {
  final double width;
  final int top;
  final int bottom;
  const DominoBone({
    super.key,
    required this.width,
    required this.top,
    required this.bottom,
  });

  static const _ivory = Color(0xFFF1EBDD);
  static const _edge = Color(0xFFC9C0AC);

  @override
  Widget build(BuildContext context) {
    final h = width * 2;
    final r = width * 0.14;
    return Container(
      width: width,
      height: h + width * 0.08,
      decoration: BoxDecoration(
        color: _edge,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.topCenter,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: _ivory,
          borderRadius: BorderRadius.circular(r),
        ),
        child: Column(
          children: [
            Expanded(child: _Pips(top, width)),
            Container(
              height: width * 0.04,
              margin: EdgeInsets.symmetric(horizontal: width * 0.16),
              color: const Color(0xFF2B2A26),
            ),
            Expanded(child: _Pips(bottom, width)),
          ],
        ),
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  final int n;
  final double w;
  const _Pips(this.n, this.w);

  // Pip positions on a 3×3 grid, as on a real tile.
  static const _layouts = <int, List<int>>{
    0: [],
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final cell = w * 0.26;
    final dot = w * 0.15;
    final on = _layouts[n] ?? const [];
    return Center(
      child: SizedBox(
        width: cell * 3,
        height: cell * 3,
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (int i = 0; i < 9; i++)
              Center(
                child: on.contains(i)
                    ? Container(
                        width: dot,
                        height: dot,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E1D1A),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// A small but real board of a game, as it looks when a game starts: the
/// chess start position, draughts men on the dark squares, a short line of
/// dominoes. Sits beside the rating on the Play tab.
class GamePreview extends StatelessWidget {
  final String game; // 'chess' | 'checkers' | 'domino'
  final double size;

  /// Chess only: the position to show (FEN). Null shows the start position.
  final String? fen;
  const GamePreview(
      {super.key, required this.game, this.size = 104, this.fen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: switch (game) {
        'domino' => _DominoLine(size: size),
        _ => _MiniBoard8(size: size, chess: game != 'checkers', fen: fen),
      },
    );
  }
}

class _MiniBoard8 extends StatelessWidget {
  final double size;
  final bool chess;
  final String? fen;
  const _MiniBoard8({required this.size, required this.chess, this.fen});

  static const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';

  /// (code, col, row) for every piece in the FEN's placement field.
  static List<(String, int, int)> _pieces(String fen) {
    final out = <(String, int, int)>[];
    final rows = fen.split(' ').first.split('/');
    for (var r = 0; r < rows.length && r < 8; r++) {
      var c = 0;
      for (final ch in rows[r].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          c += n;
          continue;
        }
        final white = ch == ch.toUpperCase();
        out.add(('${white ? 'w' : 'b'}${ch.toUpperCase()}', c, r));
        c++;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final frame = size * 0.04;
    final sq = (size - frame * 2) / 8;
    return Container(
      padding: EdgeInsets.all(frame),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4A2E),
        borderRadius: BorderRadius.circular(size * 0.06),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.02),
        child: Stack(
          children: [
            for (int r = 0; r < 8; r++)
              for (int c = 0; c < 8; c++)
                Positioned(
                  left: c * sq,
                  top: r * sq,
                  width: sq,
                  height: sq,
                  child: ColoredBox(
                    color: (r + c).isEven
                        ? AppColors.boardBrown1
                        : AppColors.boardBrown2,
                  ),
                ),
            if (chess)
              for (final (code, c, r) in _pieces(fen ?? _start))
                _piece(code, c, r, sq)
            else
              for (int r = 0; r < 8; r++)
                for (int c = 0; c < 8; c++)
                  if ((r + c).isOdd && (r < 3 || r > 4))
                    Positioned(
                      left: c * sq + sq * 0.12,
                      top: r * sq + sq * 0.12,
                      width: sq * 0.76,
                      height: sq * 0.76,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: r < 3
                              ? const Color(0xFF2A2017)
                              : const Color(0xFFF5F0E0),
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _piece(String code, int c, int r, double sq) => Positioned(
        left: c * sq,
        top: r * sq,
        width: sq,
        height: sq,
        child: SvgPicture.asset('assets/pieces/cburnett/$code.svg'),
      );
}

class _DominoLine extends StatelessWidget {
  final double size;
  const _DominoLine({required this.size});

  @override
  Widget build(BuildContext context) {
    final w = size * 0.27;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DominoBone(width: w, top: 6, bottom: 3),
          SizedBox(width: size * 0.05),
          DominoBone(width: w, top: 3, bottom: 5),
          SizedBox(width: size * 0.05),
          DominoBone(width: w, top: 5, bottom: 5),
        ],
      ),
    );
  }
}
