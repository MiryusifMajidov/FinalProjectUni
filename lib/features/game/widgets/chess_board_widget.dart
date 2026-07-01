import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/board_themes.dart';
import '../engine/chess_engine.dart';

/// Chess board widget.
///
/// Rendering strategy:
///   Layer 1 — [_BoardPainter] (CustomPainter): draws squares, highlights,
///              legal-move dots/rings, and coordinate labels.
///   Layer 2 — Pieces with slide animation: the last-moved piece smoothly
///              glides from its origin square to its destination (Chess.com style).
///   Layer 3 — GestureDetector grid (invisible tap targets).
class ChessBoardWidget extends StatefulWidget {
  final ChessEngine engine;
  final bool flipped;
  final String? selectedSquare;
  final List<String> legalMoveSquares;
  final void Function(String square) onSquareTap;
  final BoardTheme boardTheme;
  final PieceSet pieceSet;
  final bool showCoordinates;
  final bool showLastMoveHighlight;
  final String? premoveFrom;
  final String? premoveTo;
  final Duration animationDuration;

  const ChessBoardWidget({
    super.key,
    required this.engine,
    required this.flipped,
    required this.selectedSquare,
    required this.legalMoveSquares,
    required this.onSquareTap,
    this.boardTheme = BoardTheme.brownWood,
    this.pieceSet = PieceSet.cburnett,
    this.showCoordinates = true,
    this.showLastMoveHighlight = true,
    this.premoveFrom,
    this.premoveTo,
    this.animationDuration = const Duration(milliseconds: 220),
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;

  ({String from, String to})? _animatingMove;
  ({String from, String to})? _lastKnownMove;

  @override
  void initState() {
    super.initState();
    _lastKnownMove = widget.engine.lastMove;
    _slideCtrl = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _slideCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _animatingMove = null);
      }
    });
  }

  @override
  void didUpdateWidget(ChessBoardWidget old) {
    super.didUpdateWidget(old);
    if (old.animationDuration != widget.animationDuration) {
      _slideCtrl.duration = widget.animationDuration;
    }
    final newLast = widget.engine.lastMove;
    if (newLast != null && newLast != _lastKnownMove) {
      _lastKnownMove = newLast;
      _animatingMove = newLast;
      _slideCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final size = constraints.maxWidth;
          final sqSize = size / 8;
          final board = widget.engine.board;
          final lastMove = widget.engine.lastMove;

          final captureSquares = <String>{
            for (final sq in widget.legalMoveSquares)
              if (board.containsKey(sq)) sq,
          };

          return Stack(
            children: [
              // ── Layer 1: Board (CustomPainter) ──────────────────────────────
              CustomPaint(
                size: Size(size, size),
                painter: _BoardPainter(
                  flipped: widget.flipped,
                  selectedSquare: widget.selectedSquare,
                  legalMoveSquares: widget.legalMoveSquares,
                  captureSquares: captureSquares,
                  lastMove: lastMove,
                  showLastMoveHighlight: widget.showLastMoveHighlight,
                  premoveFrom: widget.premoveFrom,
                  premoveTo: widget.premoveTo,
                  checkSquare: widget.engine.kingInCheckSquare,
                  boardTheme: widget.boardTheme,
                  showCoordinates: widget.showCoordinates,
                ),
              ),

              // ── Layer 2: Pieces with slide animation ──────────────────────
              ...board.entries.map((entry) {
                final sq = entry.key;
                final piece = entry.value;
                final pos = _squareOffset(sq, sqSize, widget.flipped);

                Widget pw = _PieceWidget(
                  piece: piece,
                  size: sqSize,
                  pieceSet: widget.pieceSet,
                );

                final isAnimatingTo =
                    _animatingMove != null && sq == _animatingMove!.to && _slideCtrl.isAnimating;

                if (isAnimatingTo) {
                  final fromPos = _squareOffset(
                      _animatingMove!.from, sqSize, widget.flipped);
                  final toPos = pos;
                  final dx = fromPos.dx - toPos.dx;
                  final dy = fromPos.dy - toPos.dy;

                  pw = AnimatedBuilder(
                    animation: _slideCtrl,
                    child: pw,
                    builder: (_, child) {
                      final t = Curves.easeOutCubic.transform(_slideCtrl.value);
                      return Transform.translate(
                        offset: Offset(dx * (1 - t), dy * (1 - t)),
                        child: child,
                      );
                    },
                  );
                }

                return Positioned(
                  key: ValueKey(sq),
                  left: pos.dx,
                  top: pos.dy,
                  width: sqSize,
                  height: sqSize,
                  child: pw,
                );
              }),

              // ── Layer 3: Tap targets ─────────────────────────────────────────
              Positioned.fill(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8),
                  itemCount: 64,
                  itemBuilder: (_, i) {
                    final sq = _indexToSquare(i, widget.flipped);
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => widget.onSquareTap(sq),
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _indexToSquare(int index, bool flipped) {
    final col = flipped ? 7 - (index % 8) : index % 8;
    final row = flipped ? index ~/ 8 : 7 - (index ~/ 8);
    return '${_kFiles[col]}${row + 1}';
  }

  static Offset _squareOffset(String sq, double sqSize, bool flipped) {
    final file = _kFiles.indexOf(sq[0]);
    final rank = int.parse(sq[1]) - 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset(col * sqSize, row * sqSize);
  }

  static const _kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
}

// ── Board CustomPainter ────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final bool flipped;
  final String? selectedSquare;
  final List<String> legalMoveSquares;
  final Set<String> captureSquares;
  final ({String from, String to})? lastMove;
  final bool showLastMoveHighlight;
  final String? premoveFrom;
  final String? premoveTo;
  final String? checkSquare;
  final BoardTheme boardTheme;
  final bool showCoordinates;

  _BoardPainter({
    required this.flipped,
    required this.selectedSquare,
    required this.legalMoveSquares,
    required this.captureSquares,
    required this.lastMove,
    required this.showLastMoveHighlight,
    this.premoveFrom,
    this.premoveTo,
    required this.checkSquare,
    required this.boardTheme,
    required this.showCoordinates,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sq = size.width / 8;

    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final square = _colRowToSq(col, row, flipped);
        final rect = Rect.fromLTWH(col * sq, row * sq, sq, sq);
        final isLight = _isLight(square);

        // ── Base colour ──────────────────────────────────────────────────────
        canvas.drawRect(
          rect,
          Paint()..color = isLight ? boardTheme.lightSquare : boardTheme.darkSquare,
        );

        // ── Last-move tint ───────────────────────────────────────────────────
        if (showLastMoveHighlight &&
            lastMove != null &&
            (square == lastMove!.from || square == lastMove!.to)) {
          canvas.drawRect(rect, Paint()..color = AppColors.moveHighlight);
        }

        // ── Premove highlight (blue tint) ────────────────────────────────────
        if (premoveFrom != null &&
            (square == premoveFrom || square == premoveTo)) {
          canvas.drawRect(
            rect,
            Paint()..color = const Color(0x556699FF),
          );
        }

        // ── Selected-square tint ─────────────────────────────────────────────
        if (square == selectedSquare) {
          canvas.drawRect(rect, Paint()..color = AppColors.selectedSquare);
        }

        // ── Check radial glow ────────────────────────────────────────────────
        if (square == checkSquare) {
          canvas.drawRect(
            rect,
            Paint()
              ..shader = RadialGradient(colors: [
                AppColors.error.withOpacity(0.88),
                AppColors.error.withOpacity(0.0),
              ]).createShader(rect),
          );
        }

        // ── Legal move indicators ────────────────────────────────────────────
        if (legalMoveSquares.contains(square)) {
          final center = Offset(col * sq + sq / 2, row * sq + sq / 2);
          if (captureSquares.contains(square)) {
            canvas.drawCircle(
              center,
              sq * 0.46,
              Paint()
                ..color = AppColors.legalMoveDot.withOpacity(0.55)
                ..style = PaintingStyle.stroke
                ..strokeWidth = sq * 0.09,
            );
          } else {
            canvas.drawCircle(
              center,
              sq * 0.155,
              Paint()..color = AppColors.legalMoveDot,
            );
          }
        }
      }
    }

    if (showCoordinates) _paintCoords(canvas, size, sq);
  }

  void _paintCoords(Canvas canvas, Size size, double sq) {
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    const ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];

    final dFiles = flipped ? files.reversed.toList() : List<String>.from(files);
    final dRanks = flipped ? List<String>.from(ranks) : ranks.reversed.toList();

    final fs = sq * 0.26;

    for (var i = 0; i < 8; i++) {
      final fileIsLight = flipped ? i % 2 == 1 : i % 2 == 0;
      _drawLabel(
        canvas,
        dFiles[i],
        Offset(i * sq + sq * 0.62, size.height - sq * 0.30),
        fs,
        (fileIsLight ? boardTheme.darkSquare : boardTheme.lightSquare)
            .withOpacity(1.0),
      );

      final rankIsLight = flipped ? i % 2 == 0 : i % 2 == 1;
      _drawLabel(
        canvas,
        dRanks[i],
        Offset(sq * 0.05, i * sq + sq * 0.04),
        fs,
        (rankIsLight ? boardTheme.darkSquare : boardTheme.lightSquare)
            .withOpacity(1.0),
      );
    }
  }

  void _drawLabel(
      Canvas canvas, String text, Offset pos, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w700,
              color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(_BoardPainter old) {
    if (old.flipped != flipped) return true;
    if (old.selectedSquare != selectedSquare) return true;
    if (old.lastMove != lastMove) return true;
    if (old.checkSquare != checkSquare) return true;
    if (old.boardTheme != boardTheme) return true;
    if (old.showCoordinates != showCoordinates) return true;
    if (old.legalMoveSquares.length != legalMoveSquares.length) return true;
    for (var i = 0; i < legalMoveSquares.length; i++) {
      if (old.legalMoveSquares[i] != legalMoveSquares[i]) return true;
    }
    return false;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _colRowToSq(int col, int row, bool flipped) {
    final file = flipped ? 7 - col : col;
    final rank = flipped ? row : 7 - row;
    return '${_kFiles[file]}${rank + 1}';
  }

  static bool _isLight(String sq) {
    final f = _kFiles.indexOf(sq[0]);
    final r = int.parse(sq[1]) - 1;
    return (f + r) % 2 != 0;
  }

  static const _kFiles = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
}

// ── Piece Widget ───────────────────────────────────────────────────────────────

class _PieceWidget extends StatelessWidget {
  final PieceInfo piece;
  final double size;
  final PieceSet pieceSet;

  const _PieceWidget({
    required this.piece,
    required this.size,
    required this.pieceSet,
  });

  @override
  Widget build(BuildContext context) {
    final color = piece.isWhite ? 'w' : 'b';
    final type = _typeCode(piece.type);
    final path = 'assets/pieces/${pieceSet.folderName}/$color$type.svg';

    return Center(
      child: SvgPicture.asset(
        path,
        width: size * 0.88,
        height: size * 0.88,
      ),
    );
  }

  static String _typeCode(PieceType t) => switch (t) {
        PieceType.king => 'K',
        PieceType.queen => 'Q',
        PieceType.rook => 'R',
        PieceType.bishop => 'B',
        PieceType.knight => 'N',
        PieceType.pawn => 'P',
      };
}
