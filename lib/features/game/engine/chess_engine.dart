import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

/// Wraps the `chess` package with a clean API for our game screens.
class ChessEngine {
  late ch.Chess _chess;
  final List<String> _moveHistory = []; // SAN strings
  final List<String> _fenHistory = [];
  final List<({String from, String to, String san})> _verboseHistory = [];

  /// Cached board map — invalidated on every move/undo.
  Map<String, PieceInfo>? _boardCache;

  ChessEngine() {
    _chess = ch.Chess();
  }

  ChessEngine.fromFen(String fen) {
    _chess = ch.Chess.fromFEN(fen);
  }

  String get fen => _chess.fen;
  bool get isWhiteTurn => _chess.turn == ch.Color.WHITE;
  bool get isCheck => _chess.in_check;
  bool get isCheckmate => _chess.in_checkmate;
  bool get isStalemate => _chess.in_stalemate;
  bool get isDraw => _chess.in_draw;
  bool get isGameOver => _chess.game_over;
  List<String> get moveHistory => List.unmodifiable(_moveHistory);
  int get moveCount => _moveHistory.length;
  List<({String from, String to, String san})> get verboseHistory =>
      List.unmodifiable(_verboseHistory);

  /// Returns all legal destination squares from a given square.
  List<String> legalMovesFrom(String square) {
    final moves = _chess.moves({'square': square, 'verbose': true});
    return moves
        .map((m) => (m as Map)['to'] as String)
        .toList();
  }

  /// Make a move by from/to squares. Returns true if successful.
  bool makeMove(String from, String to, {String? promotion}) {
    final moveMap = <String, dynamic>{'from': from, 'to': to};
    if (promotion != null) moveMap['promotion'] = promotion;

    // move() returns bool
    if (_chess.move(moveMap) == true) {
      final history = _chess.getHistory({'verbose': true});
      String san = '$from$to';
      if (history.isNotEmpty) {
        final last = history.last as Map;
        san = last['san'] as String? ?? '$from$to';
      }
      _moveHistory.add(san);
      _verboseHistory.add((from: from, to: to, san: san));
      _fenHistory.add(_chess.fen);
      _boardCache = null;
      return true;
    }
    return false;
  }

  /// Make a move from SAN notation.
  bool makeSanMove(String san) {
    if (_chess.move(san) == true) {
      final history = _chess.getHistory({'verbose': true});
      String from = '';
      String to = '';
      if (history.isNotEmpty) {
        final last = history.last as Map;
        from = last['from'] as String? ?? '';
        to   = last['to']   as String? ?? '';
      }
      _moveHistory.add(san);
      _verboseHistory.add((from: from, to: to, san: san));
      _fenHistory.add(_chess.fen);
      _boardCache = null;
      return true;
    }
    return false;
  }

  /// Undo the last move.
  bool undo() {
    final result = _chess.undo();
    if (result != null && _moveHistory.isNotEmpty) {
      _moveHistory.removeLast();
      if (_fenHistory.isNotEmpty) _fenHistory.removeLast();
      if (_verboseHistory.isNotEmpty) _verboseHistory.removeLast();
      _boardCache = null;
      return true;
    }
    return false;
  }

  /// Get the piece at a square. Returns null if empty.
  PieceInfo? pieceAt(String square) {
    final piece = _chess.get(square);
    if (piece == null) return null;
    return PieceInfo(
      type: _pieceType(piece.type),
      isWhite: piece.color == ch.Color.WHITE,
    );
  }

  /// Get king square for the current side in check.
  String? get kingInCheckSquare {
    if (!_chess.in_check) return null;
    final color = _chess.turn;
    // SQUARES maps algebraic name → internal int index
    for (final entry in ch.Chess.SQUARES.entries) {
      final square = entry.key as String;
      final piece = _chess.get(square);
      if (piece != null &&
          piece.type == ch.PieceType.KING &&
          piece.color == color) {
        return square;
      }
    }
    return null;
  }

  /// Get the full board as a map of square → PieceInfo.
  /// Cached — only rebuilt after a move or undo.
  Map<String, PieceInfo> get board {
    if (_boardCache != null) return _boardCache!;
    final result = <String, PieceInfo>{};
    for (final key in ch.Chess.SQUARES.keys) {
      final square = key as String;
      final piece = _chess.get(square);
      if (piece != null) {
        result[square] = PieceInfo(
          type: _pieceType(piece.type),
          isWhite: piece.color == ch.Color.WHITE,
        );
      }
    }
    _boardCache = result;
    return result;
  }

  /// Get the last move's from/to squares.
  /// O(1) — reads from the already-maintained _verboseHistory list instead of
  /// calling getHistory({'verbose': true}) which is O(N) and rebuilds the full
  /// move list every call.
  ({String from, String to})? get lastMove {
    if (_verboseHistory.isEmpty) return null;
    final last = _verboseHistory.last;
    return (from: last.from, to: last.to);
  }

  /// Generate PGN for this game.
  String get pgn => _chess.pgn();

  /// Captured pieces by each side.
  List<PieceInfo> get capturedByWhite => _getCaptured(byWhite: true);
  List<PieceInfo> get capturedByBlack => _getCaptured(byWhite: false);

  List<PieceInfo> _getCaptured({required bool byWhite}) {
    // pieces captured from the enemy (i.e., pieces missing from enemy's set)
    final initial = _initialPieceCount();
    final current = _currentPieceCount();
    final result = <PieceInfo>[];
    final capturedIsWhite = !byWhite; // white captures black pieces

    for (final type in PieceType.values) {
      final key = _typeKey(type, capturedIsWhite);
      final missing = (initial[key] ?? 0) - (current[key] ?? 0);
      for (var i = 0; i < missing; i++) {
        result.add(PieceInfo(type: type, isWhite: capturedIsWhite));
      }
    }
    return result;
  }

  String _typeKey(PieceType type, bool isWhite) =>
      '${isWhite ? 'w' : 'b'}${type.name}';

  Map<String, int> _initialPieceCount() => {
        'wpawn': 8, 'bpawn': 8,
        'wknight': 2, 'bknight': 2,
        'wbishop': 2, 'bbishop': 2,
        'wrook': 2, 'brook': 2,
        'wqueen': 1, 'bqueen': 1,
        'wking': 1, 'bking': 1,
      };

  Map<String, int> _currentPieceCount() {
    final counts = <String, int>{};
    for (final entry in board.entries) {
      final key = _typeKey(entry.value.type, entry.value.isWhite);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// All legal moves in current position as SAN strings.
  List<String> get allLegalMoveSans {
    return _chess.moves().cast<String>();
  }

  /// Does moving from→to require pawn promotion?
  bool needsPromotion(String from, String to) {
    final piece = _chess.get(from);
    if (piece == null || piece.type != ch.PieceType.PAWN) return false;
    return (piece.color == ch.Color.WHITE && to[1] == '8') ||
        (piece.color == ch.Color.BLACK && to[1] == '1');
  }

  PieceType _pieceType(ch.PieceType t) {
    if (t == ch.PieceType.PAWN) return PieceType.pawn;
    if (t == ch.PieceType.KNIGHT) return PieceType.knight;
    if (t == ch.PieceType.BISHOP) return PieceType.bishop;
    if (t == ch.PieceType.ROOK) return PieceType.rook;
    if (t == ch.PieceType.QUEEN) return PieceType.queen;
    if (t == ch.PieceType.KING) return PieceType.king;
    return PieceType.pawn;
  }

  void reset() {
    _chess = ch.Chess();
    _moveHistory.clear();
    _fenHistory.clear();
    _verboseHistory.clear();
  }

  /// Snapshot at review position N.
  /// N=0 → starting position (before any moves)
  /// N=1..moveCount → after N-th move
  ChessEngine snapshotAt(int n) {
    if (n <= 0) return ChessEngine();
    if (n - 1 >= _fenHistory.length) return this;
    return ChessEngine.fromFen(_fenHistory[n - 1]);
  }

  /// Standard piece values: P=1, N=3, B=3, R=5, Q=9, K=0
  static int pieceValue(PieceType type) => switch (type) {
    PieceType.pawn   => 1,
    PieceType.knight => 3,
    PieceType.bishop => 3,
    PieceType.rook   => 5,
    PieceType.queen  => 9,
    PieceType.king   => 0,
  };

  /// Material advantage for [forWhite]. Positive = that side is ahead.
  /// e.g. white captured Q(9), black captured R(5) → forWhite=true → +4
  int materialAdvantageFor(bool forWhite) {
    final myCaptured    = forWhite ? capturedByWhite : capturedByBlack;
    final theirCaptured = forWhite ? capturedByBlack : capturedByWhite;
    return myCaptured.fold(0, (s, p) => s + pieceValue(p.type)) -
           theirCaptured.fold(0, (s, p) => s + pieceValue(p.type));
  }
}

enum PieceType { pawn, knight, bishop, rook, queen, king }

@immutable
class PieceInfo {
  final PieceType type;
  final bool isWhite;
  const PieceInfo({required this.type, required this.isWhite});

  String get symbol => switch (type) {
        PieceType.pawn => isWhite ? '♙' : '♟',
        PieceType.knight => isWhite ? '♘' : '♞',
        PieceType.bishop => isWhite ? '♗' : '♝',
        PieceType.rook => isWhite ? '♖' : '♜',
        PieceType.queen => isWhite ? '♕' : '♛',
        PieceType.king => isWhite ? '♔' : '♚',
      };
}
