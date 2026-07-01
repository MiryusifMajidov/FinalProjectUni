import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../engine/domino_engine.dart';

/// Renders a single domino tile with pip dots, matching the design's DominoTile
/// component with felt-style aesthetics.
///
/// Vertical layout (hand): value [a] on top, [b] on bottom.
/// Horizontal layout (chain): value [a] on the LEFT, [b] on the RIGHT — the
/// chain widget pre-orients tiles so neighbouring halves share the same value.
class DominoTileWidget extends StatelessWidget {
  final DominoTile tile;
  final bool horizontal;
  final bool selected;
  final bool faceDown;
  final double size; // height of vertical tile (or width of horizontal tile)
  final VoidCallback? onTap;

  const DominoTileWidget({
    super.key,
    required this.tile,
    this.horizontal = false,
    this.selected = false,
    this.faceDown = false,
    this.size = 80,
    this.onTap,
  });

  static const _boneColor = Color(0xFFF5F0E0);
  static const _boneBorder = Color(0xFFD4C5A9);
  static const _pipColor = Color(0xFF1A1712);
  static const _dividerColor = Color(0xFFD4C5A9);
  static const _selectedBorder = Color(0xFF5FD4A3);
  static const _faceDownColor = Color(0xFF2A2017);

  double get _width => size * 0.5;
  double get _halfHeight => size * 0.48;

  @override
  Widget build(BuildContext context) {
    if (horizontal && !faceDown) return _buildHorizontal();

    final tileWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        width: _width,
        height: size,
        decoration: _boxDecoration(),
        child: faceDown
            ? Center(
                child: Container(
                  width: _width * 0.5,
                  height: size * 0.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  // Top half (a)
                  SizedBox(
                    width: _width,
                    height: _halfHeight,
                    child: _PipLayout(value: tile.a, cellSize: _width),
                  ),
                  // Divider
                  Container(
                    width: _width * 0.7,
                    height: 1.5,
                    color: _dividerColor,
                  ),
                  // Bottom half (b)
                  SizedBox(
                    width: _width,
                    height: _halfHeight,
                    child: _PipLayout(value: tile.b, cellSize: _width),
                  ),
                ],
              ),
      ),
    );

    return tileWidget;
  }

  /// Horizontal tile: [a] on the left, [b] on the right. Rendered with an
  /// explicit Row (no RotatedBox) so the orientation is always correct.
  Widget _buildHorizontal() {
    final w = size;
    final h = size * 0.5;
    final half = h; // each pip cell is roughly square (h × h)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        decoration: _boxDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: half,
              height: h,
              child: _PipLayout(value: tile.a, cellSize: half),
            ),
            Container(
              width: 1.5,
              height: h * 0.7,
              color: _dividerColor,
            ),
            Expanded(
              child: SizedBox(
                height: h,
                child: _PipLayout(value: tile.b, cellSize: half),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: faceDown ? _faceDownColor : _boneColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? _selectedBorder : _boneBorder,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      );
}

/// Lays out pips (dots) for a value 0-6 in the traditional domino pattern.
class _PipLayout extends StatelessWidget {
  final int value;
  final double cellSize;

  const _PipLayout({required this.value, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    final pipSize = cellSize * 0.14;
    final positions = _pipPositions(value);

    return Stack(
      children: positions.map((pos) {
        return Positioned(
          left: pos.dx * cellSize - pipSize / 2,
          top: pos.dy * (cellSize * 0.96) - pipSize / 2,
          child: Container(
            width: pipSize,
            height: pipSize,
            decoration: BoxDecoration(
              color: DominoTileWidget._pipColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 1,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Normalized positions for pips (0.0 to 1.0 coordinate space).
  List<Offset> _pipPositions(int n) {
    const tl = Offset(0.28, 0.22);
    const tr = Offset(0.72, 0.22);
    const ml = Offset(0.28, 0.50);
    const mc = Offset(0.50, 0.50);
    const mr = Offset(0.72, 0.50);
    const bl = Offset(0.28, 0.78);
    const br = Offset(0.72, 0.78);

    switch (n) {
      case 0:  return [];
      case 1:  return [mc];
      case 2:  return [tl, br];
      case 3:  return [tl, mc, br];
      case 4:  return [tl, tr, bl, br];
      case 5:  return [tl, tr, mc, bl, br];
      case 6:  return [tl, tr, ml, mr, bl, br];
      default: return [];
    }
  }
}

// ── Snake board ──────────────────────────────────────────────────────────────

class _SnakePlacement {
  final DominoTile display; // values arranged for the render orientation
  final Rect rect;
  final bool vertical;

  const _SnakePlacement({
    required this.display,
    required this.rect,
    required this.vertical,
  });
}

/// The played chain laid out as a boustrophedon "snake": tiles run across the
/// table, turn 90° at the edge and continue in the opposite direction — the
/// standard look of popular domino apps. Doubles sit crosswise. The whole
/// snake auto-shrinks (BoxFit.scaleDown) so the entire chain is always
/// visible — no scrolling.
///
/// Both open ends expose ghost zones that act as drag-drop targets and as
/// tap targets (when a hand tile is selected, the playable ends glow and the
/// player taps the end directly — no dialogs).
class DominoSnakeBoard extends StatelessWidget {
  final List<DominoTile> chain;
  final int? leftEnd;
  final int? rightEnd;
  final double tileSize; // long side of a tile in virtual units
  final bool leftActive;  // left ghost glows (selected/dragged tile fits)
  final bool rightActive;
  final bool Function(DominoTile tile, DominoEnd end)? canAcceptDrag;
  final void Function(DominoTile tile, DominoEnd end)? onDragAccept;
  final void Function(DominoEnd end)? onEndTap;
  final String emptyHint;

  /// Most recently placed tile — softly outlined ("Highlight last move").
  final DominoTile? highlightTile;

  const DominoSnakeBoard({
    super.key,
    required this.chain,
    this.leftEnd,
    this.rightEnd,
    this.tileSize = 56,
    this.leftActive = false,
    this.rightActive = false,
    this.canAcceptDrag,
    this.onDragAccept,
    this.onEndTap,
    this.emptyHint = 'Place first tile',
    this.highlightTile,
  });

  static const _accent = Color(0xFF5FD4A3);

  /// Walks the chain from the left open end, assigning each tile a concrete
  /// (incoming, outgoing) orientation so consecutive halves line up.
  List<DominoTile> _orientedChain() {
    if (chain.isEmpty) return const [];
    final oriented = <DominoTile>[];
    int current = leftEnd ?? chain.first.a;
    for (final t in chain) {
      int first, second;
      if (t.a == current) {
        first = current;
        second = t.b;
      } else if (t.b == current) {
        first = current;
        second = t.a;
      } else {
        // Fallback (should not happen for a valid chain)
        first = t.a;
        second = t.b;
      }
      oriented.add(DominoTile(first, second));
      current = second;
    }
    return oriented;
  }

  /// Boustrophedon layout. Returns tile placements plus the two ghost-zone
  /// rects (left = snake start, right = snake tail).
  (List<_SnakePlacement>, Rect, Rect) _layout(
      double maxW, List<DominoTile> oriented) {
    final L = tileSize;
    final S = tileSize / 2;
    const g = 3.0;

    final placements = <_SnakePlacement>[];
    double y = 0; // centerline of the current row
    int dir = 1;  // 1 → left-to-right, -1 → right-to-left
    // The left ghost permanently reserves the first slot so the layout
    // doesn't shift when it becomes visible.
    final leftGhost = Rect.fromLTWH(0, -S / 2, L, S);
    double x = L + g;

    for (final t in oriented) {
      final isDouble = t.isDouble;
      final along = isDouble ? S : L;
      final fits = dir == 1 ? (x + along <= maxW) : (x - along >= 0);

      if (!fits) {
        // Elbow: this tile turns the corner, rendered vertically with the
        // incoming half on top (the snake always descends).
        final ex = dir == 1 ? math.min(x, maxW - S) : math.max(x - S, 0.0);
        placements.add(_SnakePlacement(
          display: t,
          rect: Rect.fromLTWH(ex, y - S / 2, S, L),
          vertical: true,
        ));
        y += L + g;
        dir = -dir;
        x = dir == 1 ? ex : ex + S;
        continue;
      }

      if (isDouble) {
        // Crosswise double: perpendicular to the line of play.
        final left = dir == 1 ? x : x - S;
        placements.add(_SnakePlacement(
          display: t,
          rect: Rect.fromLTWH(left, y - L / 2, S, L),
          vertical: true,
        ));
        x += dir * (S + g);
      } else {
        final left = dir == 1 ? x : x - L;
        // Incoming half faces the previous tile: on the screen-left when
        // travelling right, on the screen-right when travelling left.
        final display = dir == 1 ? t : DominoTile(t.b, t.a);
        placements.add(_SnakePlacement(
          display: display,
          rect: Rect.fromLTWH(left, y - S / 2, L, S),
          vertical: false,
        ));
        x += dir * (L + g);
      }
    }

    // Right ghost: one more slot following the same snake rules.
    Rect rightGhost;
    final fitsR = dir == 1 ? (x + L <= maxW) : (x - L >= 0);
    if (oriented.isEmpty) {
      rightGhost = Rect.fromLTWH(x, -S / 2, L, S);
    } else if (fitsR) {
      rightGhost = Rect.fromLTWH(dir == 1 ? x : x - L, y - S / 2, L, S);
    } else {
      final ex = dir == 1 ? math.min(x, maxW - S) : math.max(x - S, 0.0);
      rightGhost = Rect.fromLTWH(ex, y - S / 2, S, L);
    }

    return (placements, leftGhost, rightGhost);
  }

  @override
  Widget build(BuildContext context) {
    if (chain.isEmpty) {
      // Single opening zone in the table centre.
      return Center(
        child: DragTarget<DominoTile>(
          onWillAcceptWithDetails: (d) =>
              canAcceptDrag?.call(d.data, DominoEnd.left) ?? false,
          onAcceptWithDetails: (d) =>
              onDragAccept?.call(d.data, DominoEnd.left),
          builder: (context, candidates, _) {
            final hover = candidates.isNotEmpty;
            return GestureDetector(
              onTap: leftActive ? () => onEndTap?.call(DominoEnd.left) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: hover
                      ? _accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: Border.all(
                    color: _accent.withValues(
                        alpha: hover || leftActive ? 0.7 : 0.3),
                    width: hover ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  emptyHint,
                  style: const TextStyle(color: _accent, fontSize: 14),
                ),
              ),
            );
          },
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = math.max(constraints.maxWidth, tileSize * 3);
      final (placements, leftGhost, rightGhost) =
          _layout(maxW, _orientedChain());

      // Normalize all rects into a tight bounding box.
      final all = [
        ...placements.map((p) => p.rect),
        leftGhost,
        rightGhost,
      ];
      double minX = all.first.left, minY = all.first.top;
      double maxX = all.first.right, maxY = all.first.bottom;
      for (final r in all) {
        minX = math.min(minX, r.left);
        minY = math.min(minY, r.top);
        maxX = math.max(maxX, r.right);
        maxY = math.max(maxY, r.bottom);
      }
      Rect shift(Rect r) => r.translate(-minX, -minY);

      return Center(
        child: FittedBox(
          // Shrinks the whole snake to keep every tile visible; never
          // enlarges a short chain.
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: maxX - minX,
            height: maxY - minY,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final p in placements)
                  Positioned.fromRect(
                    rect: shift(p.rect),
                    child: Container(
                      // Soft outline on the most recently played tile
                      // (every tile is unique in a double-six set).
                      foregroundDecoration:
                          highlightTile != null && p.display == highlightTile
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.85),
                                    width: 2,
                                  ),
                                )
                              : null,
                      child: DominoTileWidget(
                        tile: p.display,
                        horizontal: !p.vertical,
                        size: tileSize,
                      ),
                    ),
                  ),
                _endZone(shift(leftGhost), DominoEnd.left, leftActive, leftEnd),
                _endZone(
                    shift(rightGhost), DominoEnd.right, rightActive, rightEnd),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _endZone(Rect rect, DominoEnd end, bool active, int? endValue) {
    return Positioned.fromRect(
      rect: rect.inflate(2),
      child: DragTarget<DominoTile>(
        onWillAcceptWithDetails: (d) =>
            canAcceptDrag?.call(d.data, end) ?? false,
        onAcceptWithDetails: (d) => onDragAccept?.call(d.data, end),
        builder: (context, candidates, _) {
          final hover = candidates.isNotEmpty;
          final visible = hover || active;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: active ? () => onEndTap?.call(end) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: hover
                    ? _accent.withValues(alpha: 0.30)
                    : active
                        ? _accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: visible
                    ? Border.all(
                        color: _accent.withValues(alpha: hover ? 0.9 : 0.55),
                        width: hover ? 2 : 1.5,
                      )
                    : null,
              ),
              child: visible
                  ? Center(
                      child: Text(
                        '$endValue',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
