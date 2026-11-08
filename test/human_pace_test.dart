import 'dart:math';

import 'package:chess_app/core/services/human_pace.dart';
import 'package:flutter_test/flutter_test.dart';

/// Median of [n] samples of [f].
int _median(int Function(Random rng) f, {int n = 400, int seed = 7}) {
  final rng = Random(seed);
  final xs = [for (var i = 0; i < n; i++) f(rng)]..sort();
  return xs[n ~/ 2];
}

int _chess(
  Random rng, {
  int moveNumber = 15,
  int legalMoves = 30,
  bool inCheck = false,
  bool recapture = false,
  int pieces = 24,
  int clockMs = 150000,
  int base = 180,
  int inc = 2,
}) =>
    HumanPace.chessMs(
      moveNumber: moveNumber,
      legalMoves: legalMoves,
      inCheck: inCheck,
      recapture: recapture,
      piecesOnBoard: pieces,
      clockMs: clockMs,
      baseSeconds: base,
      incrementSeconds: inc,
      rng: rng,
    );

void main() {
  group('HumanPace chess', () {
    test('the opening is quick, the middlegame takes longer', () {
      final opening = _median((r) => _chess(r, moveNumber: 1, pieces: 32));
      final middle = _median((r) => _chess(r, moveNumber: 18));
      expect(opening, lessThan(1500));
      expect(middle, greaterThan(opening * 3));
    });

    test('a recapture or the only legal move is fast', () {
      final recapture = _median((r) => _chess(r, recapture: true));
      final forced = _median((r) => _chess(r, legalMoves: 1));
      final normal = _median((r) => _chess(r));
      expect(recapture, lessThan(normal));
      expect(forced, lessThan(1200));
    });

    test('moves are not all the same length', () {
      final rng = Random(3);
      final xs = {for (var i = 0; i < 50; i++) _chess(rng)};
      expect(xs.length, greaterThan(40));
    });

    test('a slower time control means longer thinks', () {
      final blitz = _median((r) => _chess(r, base: 180, inc: 0));
      final rapid = _median((r) => _chess(r, base: 600, inc: 0, clockMs: 500000));
      expect(rapid, greaterThan(blitz * 2));
    });

    test('never spends more than a tenth of the clock, less in a scramble', () {
      final rng = Random(11);
      for (var i = 0; i < 500; i++) {
        expect(_chess(rng, clockMs: 30000), lessThanOrEqualTo(3000));
        expect(_chess(rng, clockMs: 8000), lessThanOrEqualTo(400));
        expect(_chess(rng, clockMs: 1000), lessThan(1000));
      }
    });
  });

  group('HumanPace draughts and dominoes', () {
    test('draughts stays well inside the 30 s move limit', () {
      final rng = Random(5);
      for (var i = 0; i < 500; i++) {
        final ms = HumanPace.draughtsMs(
            moveNumber: 1 + i % 40, legalMoves: 1 + i % 12, capture: i.isOdd, rng: rng);
        expect(ms, inInclusiveRange(450, 14000));
      }
    });

    test('a forced draughts move is quicker than a free choice', () {
      final forced = _median((r) => HumanPace.draughtsMs(
          moveNumber: 12, legalMoves: 1, capture: true, rng: r));
      final free = _median((r) => HumanPace.draughtsMs(
          moveNumber: 12, legalMoves: 8, capture: false, rng: r));
      expect(forced, lessThan(free));
    });

    test('one domino that fits is quick, several take longer, draws add time', () {
      final one = _median((r) => HumanPace.dominoMs(options: 1, handSize: 4, rng: r));
      final many = _median((r) => HumanPace.dominoMs(options: 5, handSize: 4, rng: r));
      final drawing = _median((r) =>
          HumanPace.dominoMs(options: 1, handSize: 4, draws: 3, rng: r));
      expect(one, lessThan(many));
      expect(drawing, greaterThan(one + 1000));
    });
  });
}
