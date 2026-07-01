import 'dart:math' as math;
import '../models/user_model.dart';
import '../models/game_model.dart';

/// Elo rating calculation — chess.com / FIDE style.
///
/// K-factor tiers (matches chess.com):
///   K = 40  → first 30 games (provisional)
///   K = 32  → rating < 2000
///   K = 24  → 2000 ≤ rating < 2400
///   K = 16  → rating ≥ 2400
///
/// Expected score formula (standard Elo):
///   E = 1 / (1 + 10 ^ ((opponentRating - myRating) / 400))
///
/// New rating = oldRating + K × (actual − expected)
///   actual: 1.0 = win, 0.5 = draw, 0.0 = loss
class EloService {
  /// K-factor based on current rating and total games played.
  static int _kFactor(int rating, int games) {
    if (games < 30) return 40;    // Provisional
    if (rating >= 2400) return 16;
    if (rating >= 2000) return 24;
    return 32;
  }

  /// Calculate new ratings for both players.
  ///
  /// Returns (whiteNewRating, blackNewRating, whiteDelta, blackDelta).
  static (int, int, int, int) calculate({
    required int whiteRating,
    required int blackRating,
    required GameResult result,
    int whiteGames = 999,
    int blackGames = 999,
  }) {
    // White's actual score
    final double score = switch (result) {
      GameResult.white => 1.0,
      GameResult.black => 0.0,
      GameResult.draw  => 0.5,
      // ongoing / aborted should never reach here; treat as draw to avoid crash
      _ => 0.5,
    };

    // Expected score for white
    final double expected =
        1.0 / (1.0 + math.pow(10, (blackRating - whiteRating) / 400.0));

    final int whiteK = _kFactor(whiteRating, whiteGames);
    final int blackK = _kFactor(blackRating, blackGames);

    // Delta for white; delta for black is the mirror
    final int whiteDelta = (whiteK * (score - expected)).round();
    final int blackDelta = (blackK * ((1.0 - score) - (1.0 - expected))).round();

    return (
      (whiteRating + whiteDelta).clamp(100, 3200),
      (blackRating + blackDelta).clamp(100, 3200),
      whiteDelta,
      blackDelta,
    );
  }

  /// Build updated [RatingStats] after a game.
  static RatingStats updatedStats({
    required RatingStats stats,
    required int newRating,
    required GameResult result,
    required bool isWhite,
  }) {
    final won = (isWhite && result == GameResult.white) ||
        (!isWhite && result == GameResult.black);
    final drew = result == GameResult.draw;

    return stats.copyWith(
      rating: newRating,
      wins:   won             ? stats.wins   + 1 : null,
      draws:  drew            ? stats.draws  + 1 : null,
      losses: (!won && !drew) ? stats.losses + 1 : null,
    );
  }
}
