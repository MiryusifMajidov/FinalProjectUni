import 'dart:math';

/// How long a person takes over a move.
///
/// The stand-in opponents (the matchmaking and arena bots that play under a
/// player name) wait this long before they move, instead of answering every
/// move at once. A person plays the opening from memory, takes a piece back
/// at once and answers a forced move quickly; they slow down in the
/// middlegame, now and then sink into a long think, and hurry when their
/// clock runs low. Every figure is spread around its median, so no two moves
/// take exactly the same time.
class HumanPace {
  HumanPace._();

  /// A log-normal factor with median 1 (sigma 0.45: most values between
  /// about 0.4 and 2.5).
  static double spread(Random rng, [double sigma = 0.45]) {
    final u1 = max(rng.nextDouble(), 1e-9);
    final u2 = rng.nextDouble();
    final z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return exp(z * sigma);
  }

  /// Chess: milliseconds for the stand-in's [moveNumber]-th move (1 = its
  /// first move).
  ///
  /// [clockMs] is the stand-in's time left (0 or less: no clock); the time
  /// control is [baseSeconds] + [incrementSeconds] per move.
  static int chessMs({
    required int moveNumber,
    required int legalMoves,
    required bool inCheck,
    required bool recapture,
    required int piecesOnBoard,
    required int clockMs,
    required int baseSeconds,
    required int incrementSeconds,
    required Random rng,
  }) {
    // A person uses about four fifths of their time over a 40-move game.
    final perMove = baseSeconds > 0
        ? (baseSeconds + 40 * incrementSeconds) * 0.8 / 40 * 1000
        : 6000.0;

    final double phase;
    if (moveNumber <= 2) {
      phase = 0.18; // first moves: from memory
    } else if (moveNumber <= 5) {
      phase = 0.32;
    } else if (moveNumber <= 9) {
      phase = 0.65; // leaving the opening
    } else if (piecesOnBoard <= 10) {
      phase = 0.85; // endgame
    } else {
      phase = 1.15; // middlegame
    }

    double ms;
    if (legalMoves == 1) {
      ms = 450.0 + rng.nextInt(700); // the only move
    } else if (recapture) {
      ms = min(perMove * phase * spread(rng), 600.0 + rng.nextInt(1300));
    } else {
      ms = perMove * phase * spread(rng);
      if (inCheck && legalMoves <= 3) ms *= 0.5;
      if (legalMoves >= 35) ms *= 1.15; // a lot to look at
      // Now and then a long think in the middlegame.
      if (moveNumber > 9 && rng.nextDouble() < 0.08) {
        ms *= 2.2 + rng.nextDouble() * 1.4;
      }
    }

    ms = ms.clamp(350.0, 30000.0);
    if (clockMs > 0) {
      // Never more than a tenth of the time left; a twentieth in a scramble.
      ms = min(ms, clockMs * (clockMs < 20000 ? 0.05 : 0.1));
      ms = max(ms, min(150.0, clockMs * 0.02));
    }
    return ms.round();
  }

  /// Draughts: milliseconds for the stand-in's [moveNumber]-th move, with
  /// [legalMoves] to choose from ([capture]: they are captures). Well inside
  /// the 30-second move limit.
  static int draughtsMs({
    required int moveNumber,
    required int legalMoves,
    required bool capture,
    required Random rng,
  }) {
    if (legalMoves <= 1) return 500 + rng.nextInt(900); // forced
    final base = moveNumber <= 3
        ? 1100.0
        : moveNumber <= 8
            ? 2200.0
            : 3600.0;
    var ms = base * spread(rng);
    if (capture) ms *= 0.8; // a choice between captures is a short one
    if (legalMoves >= 9) ms *= 1.15;
    if (moveNumber > 8 && rng.nextDouble() < 0.07) {
      ms *= 2.2 + rng.nextDouble();
    }
    return ms.clamp(450.0, 14000.0).round();
  }

  /// Dominoes: milliseconds for one turn with [options] playable moves out
  /// of a hand of [handSize] tiles. [draws] tiles taken from the boneyard
  /// first add time of their own.
  static int dominoMs({
    required int options,
    required int handSize,
    int draws = 0,
    required Random rng,
  }) {
    final drawing = draws * (450 + rng.nextInt(350));
    if (options == 0) return drawing + 900 + rng.nextInt(900); // pass
    if (options == 1) return drawing + 700 + rng.nextInt(1000); // nothing to think about
    var ms = (1300.0 + 380 * min(options, 6)) * spread(rng, 0.35);
    if (handSize >= 6) ms *= 1.1; // a full hand takes longer to read
    if (rng.nextDouble() < 0.05) ms *= 2;
    return drawing + ms.clamp(600.0, 9000.0).round();
  }
}
