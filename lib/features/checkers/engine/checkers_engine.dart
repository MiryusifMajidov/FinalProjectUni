// ── Checkers Engine ─────────────────────────────────────────────────────────
// Supports five variants:
//   • Standard (American 8×8)  – diagonal, forward capture only, single-step
//     kings, promotion ends a capture chain
//   • International (10×10)    – diagonal, backward capture, flying kings,
//     max capture, captured pieces stay on board until the move completes
//   • Turkish (8×8)             – orthogonal movement, flying kings, max
//     capture, captured pieces removed immediately
//   • Brazilian (8×8)           – international rules on an 8×8 board
//   • Russian (8×8)             – backward capture, flying kings, free choice
//     of capture sequence, man promotes mid-chain and continues as a king

import 'dart:math';

// ── Enums ───────────────────────────────────────────────────────────────────

enum CheckersVariant { standard, international, turkish, brazilian, russian }

enum CheckersPiece { empty, white, black, whiteKing, blackKing }

enum CheckersPlayer { white, black }

enum CheckersResult { ongoing, whiteWin, blackWin, draw }

// ── Variant rules config ────────────────────────────────────────────────────

class VariantRules {
  final int boardSize;
  final int piecesPerSide;
  final bool diagonal;             // false → orthogonal (Turkish)
  final bool menCaptureBack;       // men can capture backwards
  final bool flyingKings;          // kings slide multiple squares
  final bool maxCapture;           // must pick longest capture chain
  final bool promotionEndsCapture; // man crowning mid-chain stops the chain
  final bool promoteDuringCapture; // man crowning mid-chain continues as king
  final bool deadPiecesRemain;     // captured pieces stay on board (blockers)
                                   // until the whole move is complete

  const VariantRules({
    required this.boardSize,
    required this.piecesPerSide,
    this.diagonal = true,
    this.menCaptureBack = false,
    this.flyingKings = false,
    this.maxCapture = false,
    this.promotionEndsCapture = false,
    this.promoteDuringCapture = false,
    this.deadPiecesRemain = false,
  });

  static const standard = VariantRules(
    boardSize: 8, piecesPerSide: 12,
    promotionEndsCapture: true,
  );
  static const international = VariantRules(
    boardSize: 10, piecesPerSide: 20,
    menCaptureBack: true, flyingKings: true, maxCapture: true,
    deadPiecesRemain: true,
  );
  static const turkish = VariantRules(
    boardSize: 8, piecesPerSide: 16,
    diagonal: false, menCaptureBack: false, flyingKings: true, maxCapture: true,
    promotionEndsCapture: true,
  );
  static const brazilian = VariantRules(
    boardSize: 8, piecesPerSide: 12,
    menCaptureBack: true, flyingKings: true, maxCapture: true,
    deadPiecesRemain: true,
  );
  static const russian = VariantRules(
    boardSize: 8, piecesPerSide: 12,
    menCaptureBack: true, flyingKings: true, maxCapture: false,
    promoteDuringCapture: true, deadPiecesRemain: true,
  );

  static VariantRules fromVariant(CheckersVariant v) => switch (v) {
    CheckersVariant.standard      => standard,
    CheckersVariant.international => international,
    CheckersVariant.turkish       => turkish,
    CheckersVariant.brazilian     => brazilian,
    CheckersVariant.russian       => russian,
  };
}

// ── Extensions ──────────────────────────────────────────────────────────────

extension CheckersPieceX on CheckersPiece {
  bool get isWhite => this == CheckersPiece.white || this == CheckersPiece.whiteKing;
  bool get isBlack => this == CheckersPiece.black || this == CheckersPiece.blackKing;
  bool get isKing  => this == CheckersPiece.whiteKing || this == CheckersPiece.blackKing;
  bool get isEmpty => this == CheckersPiece.empty;

  bool belongsTo(CheckersPlayer p) =>
      p == CheckersPlayer.white ? isWhite : isBlack;

  CheckersPiece promoted() {
    if (this == CheckersPiece.white) return CheckersPiece.whiteKing;
    if (this == CheckersPiece.black) return CheckersPiece.blackKing;
    return this;
  }

  String get symbol {
    switch (this) {
      case CheckersPiece.white:     return 'w';
      case CheckersPiece.black:     return 'b';
      case CheckersPiece.whiteKing: return 'W';
      case CheckersPiece.blackKing: return 'B';
      default: return '.';
    }
  }
}

// ── Move ────────────────────────────────────────────────────────────────────

class CheckersMove {
  final List<int> path;
  final List<int> captured;

  const CheckersMove({required this.path, this.captured = const []});

  int get from => path.first;
  int get to   => path.last;
  bool get isCapture => captured.isNotEmpty;

  bool samePathAs(CheckersMove other) {
    if (path.length != other.path.length) return false;
    if (captured.length != other.captured.length) return false;
    for (int i = 0; i < path.length; i++) {
      if (path[i] != other.path[i]) return false;
    }
    for (int i = 0; i < captured.length; i++) {
      if (captured[i] != other.captured[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      path.join('→') + (captured.isNotEmpty ? ' x${captured.length}' : '');
}

// ── Transposition Table ─────────────────────────────────────────────────────

class _TTEntry {
  final int depth;
  final double score;
  final int flag; // 0=exact, 1=lower, 2=upper

  const _TTEntry(this.depth, this.score, this.flag);
}

// ── Engine ───────────────────────────────────────────────────────────────────

class CheckersEngine {
  late List<CheckersPiece> board;
  final CheckersVariant variant;
  late final VariantRules rules;
  CheckersPlayer turn = CheckersPlayer.white;
  CheckersResult result = CheckersResult.ongoing;
  int halfMoveClock = 0;
  List<CheckersMove> moveHistory = [];

  // Threefold-repetition tracking. Only reversible positions (king moves
  // without capture) are counted; any capture / man move / promotion clears it.
  Map<int, int> _repetition = {};

  // Transposition table + killer moves for bot AI. Search clones share these
  // references so entries written deep in the tree are visible across nodes.
  Map<int, _TTEntry> _tt = {};
  Map<int, List<int>> _killers = {};

  int get boardSize => rules.boardSize;
  int get totalCells => boardSize * boardSize;

  // ── Factories ──────────────────────────────────────────────────────────

  CheckersEngine({this.variant = CheckersVariant.standard}) {
    rules = VariantRules.fromVariant(variant);
    board = _initialBoard();
  }

  CheckersEngine._raw(this.variant, this.rules, this.board, this.turn);

  /// Full clone (undo snapshots). Gets its own TT / history.
  CheckersEngine clone() {
    final e = CheckersEngine._raw(variant, rules, List.of(board), turn);
    e.result = result;
    e.halfMoveClock = halfMoveClock;
    e.moveHistory = List.of(moveHistory);
    e._repetition = Map.of(_repetition);
    return e;
  }

  /// Lightweight clone for search: shares the TT / killer tables and skips
  /// history copies so deep negamax trees stay cheap.
  CheckersEngine _searchClone() {
    final e = CheckersEngine._raw(variant, rules, List.of(board), turn);
    e.result = result;
    e.halfMoveClock = halfMoveClock;
    e._tt = _tt;
    e._killers = _killers;
    return e;
  }

  /// Serializable state for running the bot inside an isolate.
  Map<String, dynamic> toSearchState() => {
        'variant': variant.index,
        'board': board.map((p) => p.index).toList(),
        'turn': turn.index,
        'halfMoveClock': halfMoveClock,
      };

  factory CheckersEngine.fromSearchState(Map<String, dynamic> state) {
    final e = CheckersEngine(
        variant: CheckersVariant.values[state['variant'] as int]);
    e.board = (state['board'] as List)
        .map((i) => CheckersPiece.values[i as int])
        .toList();
    e.turn = CheckersPlayer.values[state['turn'] as int];
    e.halfMoveClock = state['halfMoveClock'] as int? ?? 0;
    return e;
  }

  // ── Initial setup ──────────────────────────────────────────────────────

  List<CheckersPiece> _initialBoard() {
    final n = boardSize;
    final b = List.filled(n * n, CheckersPiece.empty);

    if (rules.diagonal) {
      // Diagonal variants: pieces on dark squares
      final rows = rules.piecesPerSide ~/ (n ~/ 2);
      // Black on top rows
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < n; c++) {
          if ((r + c) % 2 == 1) b[r * n + c] = CheckersPiece.black;
        }
      }
      // White on bottom rows
      for (int r = n - rows; r < n; r++) {
        for (int c = 0; c < n; c++) {
          if ((r + c) % 2 == 1) b[r * n + c] = CheckersPiece.white;
        }
      }
    } else {
      // Turkish: pieces on rows 1-2 (black) and 5-6 (white), all columns
      for (int r = 1; r <= 2; r++) {
        for (int c = 0; c < n; c++) {
          b[r * n + c] = CheckersPiece.black;
        }
      }
      for (int r = 5; r <= 6; r++) {
        for (int c = 0; c < n; c++) {
          b[r * n + c] = CheckersPiece.white;
        }
      }
    }
    return b;
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────

  int idx(int row, int col) => row * boardSize + col;
  int row(int i) => i ~/ boardSize;
  int col(int i) => i % boardSize;
  bool inBounds(int r, int c) => r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  int _promoRow(CheckersPiece piece) => piece.isWhite ? 0 : boardSize - 1;

  // ── Movement directions ────────────────────────────────────────────────

  List<(int, int)> _moveDirections(CheckersPiece piece) {
    if (rules.diagonal) {
      if (piece.isKing) return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
      if (piece.isWhite) return const [(-1, -1), (-1, 1)];
      return const [(1, -1), (1, 1)];
    } else {
      // Turkish: orthogonal
      if (piece.isKing) return const [(-1, 0), (1, 0), (0, -1), (0, 1)];
      if (piece.isWhite) return const [(-1, 0), (0, -1), (0, 1)]; // forward + sideways
      return const [(1, 0), (0, -1), (0, 1)]; // forward + sideways
    }
  }

  List<(int, int)> _captureDirections(CheckersPiece piece) {
    if (rules.diagonal) {
      if (piece.isKing || rules.menCaptureBack) {
        return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
      }
      if (piece.isWhite) return const [(-1, -1), (-1, 1)];
      return const [(1, -1), (1, 1)];
    } else {
      // Turkish: orthogonal capture
      if (piece.isKing) return const [(-1, 0), (1, 0), (0, -1), (0, 1)];
      // Turkish men cannot capture backward
      if (piece.isWhite) return const [(-1, 0), (0, -1), (0, 1)];
      return const [(1, 0), (0, -1), (0, 1)];
    }
  }

  // ── Legal moves ────────────────────────────────────────────────────────

  List<CheckersMove> legalMoves() {
    if (result != CheckersResult.ongoing) return [];

    final captures = <CheckersMove>[];

    for (int i = 0; i < totalCells; i++) {
      if (!board[i].belongsTo(turn)) continue;
      captures.addAll(_captureMovesFrom(i, board, board[i], [i], [], {}));
    }

    if (captures.isNotEmpty) {
      // Max capture rule: must pick longest chain
      if (rules.maxCapture && captures.length > 1) {
        final maxLen = captures.map((m) => m.captured.length).reduce(max);
        captures.removeWhere((m) => m.captured.length < maxLen);
      }
      return captures;
    }

    final steps = <CheckersMove>[];
    for (int i = 0; i < totalCells; i++) {
      if (!board[i].belongsTo(turn)) continue;
      steps.addAll(_stepMovesFrom(i));
    }
    return steps;
  }

  /// Squares of pieces that currently have a mandatory capture.
  Set<int> mustCaptureCells() {
    final moves = legalMoves();
    if (moves.isEmpty || !moves.first.isCapture) return {};
    return moves.map((m) => m.from).toSet();
  }

  List<CheckersMove> _stepMovesFrom(int i) {
    final piece = board[i];
    final r = row(i), c = col(i);
    final dirs = _moveDirections(piece);
    final result = <CheckersMove>[];

    if (piece.isKing && rules.flyingKings) {
      // Flying king: slide along direction until blocked
      for (final (dr, dc) in dirs) {
        int nr = r + dr, nc = c + dc;
        while (inBounds(nr, nc) && board[idx(nr, nc)].isEmpty) {
          result.add(CheckersMove(path: [i, idx(nr, nc)]));
          nr += dr;
          nc += dc;
        }
      }
    } else {
      for (final (dr, dc) in dirs) {
        final nr = r + dr, nc = c + dc;
        if (!inBounds(nr, nc)) continue;
        if (!board[idx(nr, nc)].isEmpty) continue;
        result.add(CheckersMove(path: [i, idx(nr, nc)]));
      }
    }
    return result;
  }

  List<CheckersMove> _captureMovesFrom(
    int from,
    List<CheckersPiece> b,
    CheckersPiece piece,
    List<int> pathSoFar,
    List<int> capturedSoFar,
    Set<int> capturedSet,
  ) {
    final r = row(from), c = col(from);
    final dirs = _captureDirections(piece);
    final branches = <CheckersMove>[];

    if (piece.isKing && rules.flyingKings) {
      // Flying king capture: scan along direction, jump over first enemy,
      // land on any empty square after it.
      for (final (dr, dc) in dirs) {
        int sr = r + dr, sc = c + dc;
        int? enemyIdx;

        while (inBounds(sr, sc)) {
          final si = idx(sr, sc);
          final sp = b[si];

          if (!sp.isEmpty) {
            // A friendly piece, or a piece already captured this move
            // (still on the board under the dead-piece rule), blocks the scan.
            if (sp.belongsTo(turn) || capturedSet.contains(si)) break;
            enemyIdx = si;
            break;
          }
          sr += dr;
          sc += dc;
        }

        if (enemyIdx == null) continue;

        int lr = row(enemyIdx) + dr, lc = col(enemyIdx) + dc;
        while (inBounds(lr, lc)) {
          final li = idx(lr, lc);
          if (!b[li].isEmpty) break;

          _branchJump(
            b, piece, from, enemyIdx, li,
            pathSoFar, capturedSoFar, capturedSet, branches,
          );

          lr += dr;
          lc += dc;
        }
      }
    } else {
      // Short capture: jump exactly 2 squares
      for (final (dr, dc) in dirs) {
        final mr = r + dr, mc = c + dc;
        final lr = r + 2 * dr, lc = c + 2 * dc;
        if (!inBounds(lr, lc)) continue;

        final midIdx = idx(mr, mc);
        final landIdx = idx(lr, lc);

        final midPiece = b[midIdx];
        if (midPiece.isEmpty || midPiece.belongsTo(turn)) continue;
        if (capturedSet.contains(midIdx)) continue;
        if (!b[landIdx].isEmpty) continue;

        _branchJump(
          b, piece, from, midIdx, landIdx,
          pathSoFar, capturedSoFar, capturedSet, branches,
        );
      }
    }
    return branches;
  }

  /// Applies a single jump in simulation and either terminates or recurses,
  /// honouring the per-variant promotion + dead-piece rules.
  void _branchJump(
    List<CheckersPiece> b,
    CheckersPiece piece,
    int from,
    int enemyIdx,
    int landIdx,
    List<int> pathSoFar,
    List<int> capturedSoFar,
    Set<int> capturedSet,
    List<CheckersMove> branches,
  ) {
    final newBoard = List.of(b);
    newBoard[from] = CheckersPiece.empty;
    // Dead-piece rule: captured pieces stay on the board (as blockers that
    // cannot be captured twice) until the move is finished.
    if (!rules.deadPiecesRemain) {
      newBoard[enemyIdx] = CheckersPiece.empty;
    }

    final newPath = [...pathSoFar, landIdx];
    final newCaptured = [...capturedSoFar, enemyIdx];
    final newSet = {...capturedSet, enemyIdx};

    var nextPiece = piece;
    final landedOnPromo = !piece.isKing && row(landIdx) == _promoRow(piece);

    if (landedOnPromo) {
      if (rules.promotionEndsCapture) {
        // American / Turkish: crowning ends the move immediately.
        newBoard[landIdx] = piece;
        branches.add(CheckersMove(path: newPath, captured: newCaptured));
        return;
      }
      if (rules.promoteDuringCapture) {
        // Russian: the man is crowned mid-chain and continues as a king.
        nextPiece = piece.promoted();
      }
      // International / Brazilian: passing through the back row mid-chain
      // does NOT promote — the man continues as a man.
    }

    newBoard[landIdx] = nextPiece;

    final deeper = _captureMovesFrom(
        landIdx, newBoard, nextPiece, newPath, newCaptured, newSet);
    if (deeper.isEmpty) {
      branches.add(CheckersMove(path: newPath, captured: newCaptured));
    } else {
      branches.addAll(deeper);
    }
  }

  // ── Make move ──────────────────────────────────────────────────────────

  /// Final piece state after travelling [path], honouring variant promotion
  /// rules (Russian promotes mid-path; others promote only on the final square,
  /// which for standard/Turkish is also guaranteed to be the chain end).
  CheckersPiece _pieceAfterMove(CheckersPiece piece, List<int> path) {
    if (piece.isKing) return piece;
    final promo = _promoRow(piece);
    if (rules.promoteDuringCapture) {
      for (int i = 1; i < path.length; i++) {
        if (row(path[i]) == promo) return piece.promoted();
      }
      return piece;
    }
    return row(path.last) == promo ? piece.promoted() : piece;
  }

  bool makeMove(CheckersMove move) {
    final legal = legalMoves();

    // Exact match on the full path + captured list (eliminates ambiguity
    // between chains sharing from/to — critical for online sync).
    CheckersMove? m;
    for (final cand in legal) {
      if (cand.samePathAs(move)) {
        m = cand;
        break;
      }
    }
    // Fallback for short-form moves (from/to only) coming from the UI.
    if (m == null) {
      final loose = legal.where((c) =>
          c.from == move.from &&
          c.to == move.to &&
          c.captured.length == move.captured.length);
      if (loose.isEmpty) return false;
      m = loose.first;
    }

    final piece = board[m.from];

    for (final c in m.captured) {
      board[c] = CheckersPiece.empty;
    }

    board[m.from] = CheckersPiece.empty;
    final finalPiece = _pieceAfterMove(piece, m.path);
    board[m.to] = finalPiece;
    final promoted = finalPiece != piece;

    // Irreversibility: any capture, promotion, or man move resets the
    // draw counters; only quiet king moves accumulate.
    if (m.isCapture || promoted || !piece.isKing) {
      halfMoveClock = 0;
      _repetition.clear();
    } else {
      halfMoveClock++;
    }

    moveHistory.add(m);

    turn = turn == CheckersPlayer.white
        ? CheckersPlayer.black
        : CheckersPlayer.white;

    // Threefold repetition (reversible positions only).
    if (halfMoveClock > 0) {
      final h = _boardHash();
      final count = (_repetition[h] ?? 0) + 1;
      _repetition[h] = count;
      if (count >= 3) {
        result = CheckersResult.draw;
        return true;
      }
    }

    _checkResult();
    return true;
  }

  void _checkResult() {
    if (result != CheckersResult.ongoing) return;

    final moves = legalMoves();
    if (moves.isEmpty) {
      result = turn == CheckersPlayer.white
          ? CheckersResult.blackWin
          : CheckersResult.whiteWin;
      return;
    }

    // 25 consecutive king moves per side without capture/man move → draw.
    if (halfMoveClock >= 50) {
      result = CheckersResult.draw;
    }
  }

  // ── Piece counts ───────────────────────────────────────────────────────

  int countPieces(CheckersPlayer p) =>
      board.where((piece) => piece.belongsTo(p)).length;

  // ── Bot AI: Iterative Deepening + Alpha-Beta + Transposition Table ─────

  CheckersMove? bestBotMove({int depth = 4}) {
    final moves = legalMoves();
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;

    _tt.clear();
    _killers.clear();

    _orderMoves(moves, 0);

    CheckersMove? best;
    double bestScore = double.negativeInfinity;

    // Iterative deepening up to requested depth
    for (int d = 1; d <= depth; d++) {
      CheckersMove? depthBest;
      double depthBestScore = double.negativeInfinity;

      for (final m in moves) {
        final sim = _searchClone();
        sim.makeMove(m);
        final score = -sim._negamax(d - 1, double.negativeInfinity, double.infinity, 1);
        if (score > depthBestScore) {
          depthBestScore = score;
          depthBest = m;
        }
      }

      if (depthBest != null) {
        best = depthBest;
        bestScore = depthBestScore;
        // Put best move first for next iteration
        if (best != moves.first) {
          moves.remove(best);
          moves.insert(0, best);
        }
      }

      // Early exit on forced win
      if (bestScore >= 900) break;
    }

    return best;
  }

  double _negamax(int depth, double alpha, double beta, int ply) {
    // Transposition table lookup (table is shared across search clones).
    final hash = _boardHash();
    final ttEntry = _tt[hash];
    if (ttEntry != null && ttEntry.depth >= depth) {
      if (ttEntry.flag == 0) return ttEntry.score; // exact
      if (ttEntry.flag == 1 && ttEntry.score > alpha) alpha = ttEntry.score; // lower bound
      if (ttEntry.flag == 2 && ttEntry.score < beta) beta = ttEntry.score; // upper bound
      if (alpha >= beta) return ttEntry.score;
    }

    if (depth == 0 || result != CheckersResult.ongoing) {
      final score = _evaluate();
      _tt[hash] = _TTEntry(depth, score, 0);
      return score;
    }

    final moves = legalMoves();
    if (moves.isEmpty) return -1000.0 + ply; // lose as late as possible

    _orderMoves(moves, ply);

    double best = double.negativeInfinity;
    int flag = 2; // upper bound

    for (final m in moves) {
      final sim = _searchClone();
      sim.makeMove(m);
      final score = -sim._negamax(depth - 1, -beta, -alpha, ply + 1);

      if (score > best) best = score;
      if (best > alpha) {
        alpha = best;
        flag = 0; // exact
      }
      if (alpha >= beta) {
        // Killer move heuristic
        _killers.putIfAbsent(ply, () => []);
        if (_killers[ply]!.length < 2) _killers[ply]!.add(m.to);
        flag = 1; // lower bound
        break;
      }
    }

    _tt[hash] = _TTEntry(depth, best, flag);
    return best;
  }

  void _orderMoves(List<CheckersMove> moves, int ply) {
    final killerTargets = _killers[ply] ?? [];
    moves.sort((a, b) {
      // Captures first (more captures = higher priority)
      final capDiff = b.captured.length - a.captured.length;
      if (capDiff != 0) return capDiff;
      // Killer moves next
      final aKiller = killerTargets.contains(a.to) ? 1 : 0;
      final bKiller = killerTargets.contains(b.to) ? 1 : 0;
      if (aKiller != bKiller) return bKiller - aKiller;
      // Center moves preferred
      final aCenterDist = _centerDistance(a.to);
      final bCenterDist = _centerDistance(b.to);
      return aCenterDist.compareTo(bCenterDist);
    });
  }

  double _centerDistance(int i) {
    final center = (boardSize - 1) / 2.0;
    final dr = row(i) - center;
    final dc = col(i) - center;
    return dr * dr + dc * dc;
  }

  int _boardHash() {
    int hash = turn == CheckersPlayer.white ? 17 : 31;
    for (int i = 0; i < board.length; i++) {
      hash = (hash * 31 + board[i].index) & 0x3FFFFFFFFFFFFF;
    }
    return hash;
  }

  // ── Evaluation ─────────────────────────────────────────────────────────

  double _evaluate() {
    if (result == CheckersResult.whiteWin) {
      return turn == CheckersPlayer.white ? 1000.0 : -1000.0;
    }
    if (result == CheckersResult.blackWin) {
      return turn == CheckersPlayer.black ? 1000.0 : -1000.0;
    }
    if (result == CheckersResult.draw) return 0;

    double score = 0;
    int myPieces = 0, oppPieces = 0;
    int myKings = 0, oppKings = 0;
    final n = boardSize;
    final center = (n - 1) / 2.0;

    for (int i = 0; i < totalCells; i++) {
      final p = board[i];
      if (p.isEmpty) continue;

      final r = row(i);
      final c = col(i);
      final isMine = p.belongsTo(turn);

      // Material
      double val = p.isKing ? 4.0 : 1.5;

      // Positional bonus: advance toward promotion
      if (!p.isKing) {
        final advance = p.isWhite ? (n - 1 - r) : r;
        val += advance * 0.12;
        // Back row defense bonus
        if ((p.isWhite && r == n - 1) || (p.isBlack && r == 0)) {
          val += 0.3;
        }
      }

      // Center control
      final centerDist = ((r - center).abs() + (c - center).abs()) / n;
      val += (1.0 - centerDist) * 0.2;

      // Edge penalty for kings (they're more useful in center)
      if (p.isKing) {
        if (r == 0 || r == n - 1 || c == 0 || c == n - 1) val -= 0.2;
      }

      if (isMine) {
        score += val;
        myPieces++;
        if (p.isKing) myKings++;
      } else {
        score -= val;
        oppPieces++;
        if (p.isKing) oppKings++;
      }
    }

    // Mobility bonus
    final mobility = legalMoves().length;
    score += mobility * 0.04;

    // Piece advantage bonus (amplify when ahead)
    if (myPieces > oppPieces) {
      score += (myPieces - oppPieces) * 0.5;
    }

    // Endgame: king advantage is critical
    if (myPieces + oppPieces <= 8) {
      score += (myKings - oppKings) * 1.5;
    }

    return score;
  }

  // ── Debug ──────────────────────────────────────────────────────────────

  @override
  String toString() {
    final buf = StringBuffer();
    final n = boardSize;
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        buf.write(board[r * n + c].symbol);
      }
      buf.writeln();
    }
    buf.writeln('Turn: $turn | Result: $result | Variant: $variant');
    return buf.toString();
  }
}

// ── Isolate entry point ──────────────────────────────────────────────────────
// Top-level so it can be used with Flutter's `compute()`. Takes a serialized
// engine state plus search depth, returns the chosen move (path + captured)
// or null when there is no legal move.

Map<String, dynamic>? checkersBestMoveIsolate(Map<String, dynamic> args) {
  final engine = CheckersEngine.fromSearchState(args);
  final move = engine.bestBotMove(depth: args['depth'] as int? ?? 4);
  if (move == null) return null;
  return {
    'path': move.path,
    'captured': move.captured,
  };
}
