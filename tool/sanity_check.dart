// Standalone sanity check for the checkers + domino engines.
// Run with: dart run tool/sanity_check.dart
// Plays full games with random/greedy policies across every variant and
// asserts the core rule invariants hold.

import 'dart:math';

import '../lib/features/checkers/engine/checkers_engine.dart';
import '../lib/features/domino/engine/domino_engine.dart';

int failures = 0;

void check(bool cond, String label) {
  if (!cond) {
    failures++;
    print('  ✗ FAIL: $label');
  }
}

void main() {
  print('── Checkers ──');
  for (final variant in CheckersVariant.values) {
    final rng = Random(42);
    int finished = 0;
    for (int game = 0; game < 20; game++) {
      final e = CheckersEngine(variant: variant);
      int plies = 0;
      while (e.result == CheckersResult.ongoing && plies < 400) {
        final moves = e.legalMoves();
        check(moves.isNotEmpty, '$variant: ongoing game must have moves');
        if (moves.isEmpty) break;
        // Forced capture invariant: if any capture exists, ALL moves capture.
        final anyCapture = moves.any((m) => m.isCapture);
        if (anyCapture) {
          check(moves.every((m) => m.isCapture),
              '$variant: captures must be exclusive when available');
        }
        final m = moves[rng.nextInt(moves.length)];
        final ok = e.makeMove(m);
        check(ok, '$variant: legal move must apply');
        plies++;
      }
      if (e.result != CheckersResult.ongoing) finished++;
    }
    print('  $variant: $finished/20 games reached a result');
  }

  // Exact-path matching: a move with a wrong captured list must be rejected
  // when an exact legal twin exists with different captures.
  {
    final e = CheckersEngine();
    final mv = e.legalMoves().first;
    final fake = CheckersMove(path: [...mv.path], captured: const [99]);
    check(!e.makeMove(fake), 'standard: bogus captured list rejected');
    check(e.makeMove(mv), 'standard: exact move accepted');
  }

  // Bot move (shared TT) must return a legal move; serialization roundtrip.
  {
    final e = CheckersEngine(variant: CheckersVariant.russian);
    final bot = e.bestBotMove(depth: 3);
    check(bot != null, 'russian: bot returns a move');
    if (bot != null) {
      check(e.legalMoves().any((m) => m.samePathAs(bot)),
          'russian: bot move is legal');
    }
    final iso = checkersBestMoveIsolate({...e.toSearchState(), 'depth': 2});
    check(iso != null, 'russian: isolate entry returns a move');
  }

  // Standard rule: a capture chain must STOP on the promotion row.
  {
    final e = CheckersEngine();
    // White man at row2; black men placed so a jump lands on row0 and a
    // further capture would exist if the chain (illegally) continued.
    e.board = List.filled(64, CheckersPiece.empty);
    e.board[e.idx(2, 3)] = CheckersPiece.white;
    e.board[e.idx(1, 4)] = CheckersPiece.black;
    e.board[e.idx(1, 6)] = CheckersPiece.black; // would chain via row0
    e.board[e.idx(7, 0)] = CheckersPiece.black; // keep black alive
    e.turn = CheckersPlayer.white;
    final moves = e.legalMoves();
    final cap = moves.where((m) => m.isCapture).toList();
    check(cap.isNotEmpty, 'standard: capture exists');
    check(cap.every((m) => m.captured.length == 1),
        'standard: chain ends on crowning (no continuation past row 0)');
    if (cap.isNotEmpty) {
      e.makeMove(cap.first);
      check(e.board[cap.first.to] == CheckersPiece.whiteKing,
          'standard: crowned on arrival');
    }
  }

  // Russian rule: man promotes mid-chain and continues as a flying king.
  // White man (2,5) jumps black (1,4) → lands (0,3) on the crowning row →
  // becomes a king mid-move and must continue: flying capture of (2,1).
  {
    final e = CheckersEngine(variant: CheckersVariant.russian);
    e.board = List.filled(64, CheckersPiece.empty);
    e.board[e.idx(2, 5)] = CheckersPiece.white;
    e.board[e.idx(1, 4)] = CheckersPiece.black;
    e.board[e.idx(2, 1)] = CheckersPiece.black;
    e.board[e.idx(7, 7)] = CheckersPiece.black; // keep black alive
    e.turn = CheckersPlayer.white;
    final moves = e.legalMoves().where((m) => m.isCapture).toList();
    check(moves.isNotEmpty, 'russian: capture exists');
    final multi = moves.where((m) => m.captured.length >= 2).toList();
    check(multi.isNotEmpty,
        'russian: man promotes mid-chain and continues as a king');
    if (multi.isNotEmpty) {
      e.makeMove(multi.first);
      check(e.board[multi.first.to] == CheckersPiece.whiteKing,
          'russian: piece is a king after the mid-chain promotion');
    }
  }

  print('── Domino ──');
  final configs = [
    const DominoConfig(playerCount: 2, variant: DominoVariant.draw, targetScore: 100),
    const DominoConfig(playerCount: 2, variant: DominoVariant.block, targetScore: 100),
    const DominoConfig(playerCount: 4, variant: DominoVariant.draw, targetScore: 100),
    const DominoConfig(playerCount: 4, variant: DominoVariant.block, teams: true, targetScore: 150),
  ];

  for (final cfg in configs) {
    final rng = Random(7);
    int matchesDone = 0;
    for (int game = 0; game < 10; game++) {
      final e = DominoEngine(seed: game * 100 + 1, config: cfg);

      // Opening rule: round 1 must offer exactly the required tile.
      final req = e.requiredOpeningTile;
      check(req != null, 'domino: round-1 opening tile designated');
      final opening = e.legalPlays();
      check(opening.length == 1 && opening.first.tile == req,
          'domino: only the designated tile may open');

      int steps = 0;
      while (!e.matchOver && steps < 4000) {
        final plays = e.legalPlays();
        if (plays.isNotEmpty) {
          final p = e.greedyBotPlay(rng) ?? plays[rng.nextInt(plays.length)];
          check(e.play(p), 'domino: legal play applies');
        } else if (e.canDraw) {
          check(e.drawTile() != null, 'domino: draw succeeds when canDraw');
        } else {
          check(e.pass(), 'domino: pass succeeds when stuck');
        }
        steps++;
      }
      if (e.matchOver) {
        matchesDone++;
        final w = e.matchWinner!;
        check(e.scores[w] >= cfg.targetScore,
            'domino: winner reached the target');
        // Guards after match end:
        check(!e.play(DominoPlay(tile: const DominoTile(0, 0), end: DominoEnd.left)),
            'domino: play rejected after match end');
        check(!e.pass(), 'domino: pass rejected after match end');
        check(e.drawTile() == null, 'domino: draw rejected after match end');
      }
    }
    print('  ${cfg.playerCount}P ${cfg.variant.name}'
        '${cfg.teams ? " teams" : ""}: $matchesDone/10 matches completed');
  }

  // Block variant must never allow drawing.
  {
    final e = DominoEngine(
        seed: 5,
        config: const DominoConfig(playerCount: 2, variant: DominoVariant.block));
    check(!e.canDraw, 'block: canDraw always false');
    check(e.drawTile() == null, 'block: drawTile refused');
  }

  // Serialization roundtrip + isolate entry + MCTS legality.
  {
    final e = DominoEngine(seed: 9, config: const DominoConfig());
    e.play(e.legalPlays().first);
    final restored = DominoEngine.fromState(e.toState());
    check(restored.turnSeat == e.turnSeat, 'domino: state roundtrip turn');
    check(restored.chain.length == e.chain.length, 'domino: state roundtrip chain');
    final best = e.bestBotPlay(simulations: 120);
    if (best != null) {
      check(e.legalPlays().any((p) => p.tile == best.tile && p.end == best.end),
          'domino: MCTS move is legal');
    }
    final iso = dominoBestPlayIsolate({'state': e.toState(), 'simulations': 60});
    check(iso == null || iso.containsKey('a'), 'domino: isolate entry works');
  }

  // Deterministic greedy: same state + same seed → same move.
  {
    final a = DominoEngine(seed: 33, config: const DominoConfig());
    final b = DominoEngine(seed: 33, config: const DominoConfig());
    final pa = a.greedyBotPlay(Random(1));
    final pb = b.greedyBotPlay(Random(1));
    check(pa.toString() == pb.toString(), 'domino: greedy is deterministic');
  }

  print(failures == 0 ? '\nALL CHECKS PASSED' : '\n$failures CHECK(S) FAILED');
}
