import 'package:flutter/material.dart';

import '../../../core/widgets/game_icon.dart';
import '../engine/chess_engine.dart';

/// The pieces a player has taken, as small silhouettes from the board's own
/// piece set, grouped by kind with the copies of one kind packed together —
/// the way chess sites show material.
///
/// This replaces a string of Unicode chess symbols (♟♞♝…). Those were drawn
/// in whatever font the phone had, at a different weight from the rest of the
/// player strip, and the black pawn came out as a colour emoji on many
/// devices.
class CapturedPieces extends StatelessWidget {
  final List<PieceInfo> pieces;

  /// Folder under assets/pieces/, so the icons match the board.
  final String pieceSet;
  final double size;
  final Color color;

  const CapturedPieces({
    super.key,
    required this.pieces,
    required this.color,
    this.pieceSet = 'cburnett',
    this.size = 14,
  });

  static const _order = [
    PieceType.pawn,
    PieceType.knight,
    PieceType.bishop,
    PieceType.rook,
    PieceType.queen,
  ];

  static String _code(PieceType type) => switch (type) {
        PieceType.pawn => 'P',
        PieceType.knight => 'N',
        PieceType.bishop => 'B',
        PieceType.rook => 'R',
        PieceType.queen => 'Q',
        PieceType.king => 'K',
      };

  @override
  Widget build(BuildContext context) {
    // Copies of one kind sit closer together than different kinds, but not
    // so close that the flat silhouettes run into each other.
    final step = size * 0.7;
    final groups = <Widget>[];
    for (final type in _order) {
      final count = pieces.where((p) => p.type == type).length;
      if (count == 0) continue;
      groups.add(SizedBox(
        width: size + (count - 1) * step,
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                left: i * step,
                top: 0,
                child: PieceIcon(
                  'b${_code(type)}',
                  size: size,
                  color: color,
                  pieceSet: pieceSet,
                ),
              ),
          ],
        ),
      ));
    }
    if (groups.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(width: size * 0.3),
          groups[i],
        ],
      ],
    );
  }
}
