import 'package:flutter/material.dart';
import '../engine/checkers_engine.dart';

/// Renders an N×N checkers board (8×8 or 10×10) with disc-shaped pieces,
/// radial gradient 3-D effect, king markers, legal-move hints, and
/// forced-capture highlights. Board size is derived from the engine's variant.
///
/// Hint sets are computed by the screen (which owns the multi-jump path
/// selection state):
///  • [hintCells]        — quiet-move targets (small dot)
///  • [captureHintCells] — capture targets (red ring)
///  • [forcedCells]      — pieces that MUST capture this turn (accent ring)
class CheckersBoardWidget extends StatelessWidget {
  final CheckersEngine engine;
  final int? selectedCell;
  final Set<int> hintCells;
  final Set<int> captureHintCells;
  final Set<int> forcedCells;

  /// From/to squares of the most recent move ("Highlight last move" setting).
  final Set<int> lastMoveCells;
  final ValueChanged<int>? onCellTap;
  final bool flipped;

  /// Square colours — fed from the board theme picked in Game Settings.
  final Color lightSquareColor;
  final Color darkSquareColor;

  const CheckersBoardWidget({
    super.key,
    required this.engine,
    this.selectedCell,
    this.hintCells = const {},
    this.captureHintCells = const {},
    this.forcedCells = const {},
    this.lastMoveCells = const {},
    this.onCellTap,
    this.flipped = false,
    this.lightSquareColor = _lightSquare,
    this.darkSquareColor = _darkSquare,
  });

  // ── Colours ──────────────────────────────────────────────────────────────
  static const _lightSquare = Color(0xFFE8D8B6);
  static const _darkSquare  = Color(0xFF8B6B3A);
  static const _selectedSquare = Color(0x806FB4E0);
  static const _legalDot = Color(0x606FB4E0);
  static const _captureHint = Color(0x80F07079);
  static const _forcedRing = Color(0xCC6FB4E0);
  static const _lastMoveTint = Color(0x336FB4E0);

  static const _whitePiece = Color(0xFFF5F0E0);
  static const _whitePieceEdge = Color(0xFFD4C5A9);
  static const _blackPiece = Color(0xFF2A2017);
  static const _blackPieceEdge = Color(0xFF1A1410);
  static const _checkerAccent = Color(0xFF6FB4E0);

  @override
  Widget build(BuildContext context) {
    final n = engine.boardSize;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        final cellSize = constraints.maxWidth / n;
        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxWidth),
              painter: _BoardPainter(
                boardSize: n,
                selectedCell: selectedCell,
                lastMoveCells: lastMoveCells,
                flipped: flipped,
                isTurkish: engine.variant == CheckersVariant.turkish,
                light: lightSquareColor,
                dark: darkSquareColor,
              ),
            ),
            for (int r = 0; r < n; r++)
              for (int c = 0; c < n; c++)
                _buildCell(r, c, cellSize, n),
          ],
        );
      }),
    );
  }

  Widget _buildCell(int r, int c, double cellSize, int n) {
    final last = n - 1;
    final displayR = flipped ? last - r : r;
    final displayC = flipped ? last - c : c;
    final cellIdx = displayR * n + displayC;
    final piece = engine.board[cellIdx];

    final isCaptureTarget = captureHintCells.contains(cellIdx);
    final isQuietTarget = !isCaptureTarget && hintCells.contains(cellIdx);
    final isForced = forcedCells.contains(cellIdx) && cellIdx != selectedCell;

    return Positioned(
      left: c * cellSize,
      top: r * cellSize,
      width: cellSize,
      height: cellSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCellTap != null ? () => onCellTap!(cellIdx) : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isQuietTarget && piece.isEmpty)
              Container(
                width: cellSize * 0.28,
                height: cellSize * 0.28,
                decoration: const BoxDecoration(
                  color: _legalDot,
                  shape: BoxShape.circle,
                ),
              ),
            if (isCaptureTarget)
              Container(
                width: cellSize * 0.8,
                height: cellSize * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _captureHint, width: 3),
                ),
              ),
            if (isForced)
              Container(
                width: cellSize * 0.88,
                height: cellSize * 0.88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _forcedRing.withValues(alpha: 0.55),
                    width: 2,
                  ),
                ),
              ),
            if (!piece.isEmpty) _buildPiece(piece, cellSize),
          ],
        ),
      ),
    );
  }

  Widget _buildPiece(CheckersPiece piece, double cellSize) {
    final isWhitePiece = piece.isWhite;
    final isKing = piece.isKing;
    final baseColor = isWhitePiece ? _whitePiece : _blackPiece;
    final edgeColor = isWhitePiece ? _whitePieceEdge : _blackPieceEdge;
    final size = cellSize * 0.75;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: [
            isWhitePiece
                ? const Color(0xFFFFF8ED)
                : const Color(0xFF3A3025),
            baseColor,
            edgeColor,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: isKing
          ? Center(
              child: Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _checkerAccent.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '♛',
                    style: TextStyle(
                      fontSize: size * 0.25,
                      color: _checkerAccent,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _BoardPainter extends CustomPainter {
  final int boardSize;
  final int? selectedCell;
  final Set<int> lastMoveCells;
  final bool flipped;
  final bool isTurkish;
  final Color light;
  final Color dark;

  _BoardPainter({
    required this.boardSize,
    this.selectedCell,
    this.lastMoveCells = const {},
    this.flipped = false,
    this.isTurkish = false,
    this.light = CheckersBoardWidget._lightSquare,
    this.dark = CheckersBoardWidget._darkSquare,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = boardSize;
    final cellW = size.width / n;
    final cellH = size.height / n;
    final last = n - 1;

    final lightPaint = Paint()..color = light;
    final darkPaint  = Paint()..color = dark;
    final selectPaint = Paint()..color = CheckersBoardWidget._selectedSquare;
    final lastMovePaint = Paint()..color = CheckersBoardWidget._lastMoveTint;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final rect = Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH);
        final displayR = flipped ? last - r : r;
        final displayC = flipped ? last - c : c;

        // Turkish uses all squares; others use alternating
        final isDark = isTurkish || (displayR + displayC) % 2 == 1;

        canvas.drawRect(rect, isDark ? darkPaint : lightPaint);

        final cellIdx = displayR * n + displayC;
        if (lastMoveCells.contains(cellIdx)) {
          canvas.drawRect(rect, lastMovePaint);
        }
        if (cellIdx == selectedCell) {
          canvas.drawRect(rect, selectPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.selectedCell != selectedCell ||
      old.lastMoveCells != lastMoveCells ||
      old.flipped != flipped ||
      old.boardSize != boardSize ||
      old.light != light ||
      old.dark != dark;
}
