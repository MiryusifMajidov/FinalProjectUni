import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/game_type.dart';

/// One of the 2000 bots that fill arenas and stand in when matchmaking finds
/// nobody. The list (assets/data/bots.json) is the same one the arena Cloud
/// Functions use (functions/bot_pool.json), so a bot has the same name, flag
/// and ratings everywhere. Bots always carry a BOT badge and are not in the
/// world ranking.
class BotProfile {
  final String uid;
  final String username;
  final String countryCode;
  final int chessRating;
  final int checkersRating;
  final int dominoRating;

  const BotProfile({
    required this.uid,
    required this.username,
    required this.countryCode,
    required this.chessRating,
    required this.checkersRating,
    required this.dominoRating,
  });

  int ratingFor(GameType game) => switch (game) {
        GameType.chess => chessRating,
        GameType.checkers => checkersRating,
        GameType.domino => dominoRating,
      };
}

class BotPool {
  BotPool._();

  static List<BotProfile>? _bots;

  static Future<List<BotProfile>> load() async {
    final cached = _bots;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/bots.json');
    final rows = jsonDecode(raw) as List;
    final bots = <BotProfile>[
      for (var i = 0; i < rows.length; i++)
        BotProfile(
          uid: 'bot_${(i + 1).toString().padLeft(4, '0')}',
          username: rows[i][0] as String,
          countryCode: rows[i][1] as String,
          chessRating: (rows[i][2] as num).toInt(),
          checkersRating: (rows[i][3] as num).toInt(),
          dominoRating: (rows[i][4] as num).toInt(),
        ),
    ];
    return _bots = bots;
  }

  /// A random bot rated close to [rating] in [game] (the window widens until
  /// at least a few bots fit; far outside the pool's range, one of the
  /// closest few), skipping [exclude].
  static Future<BotProfile> near(
    GameType game,
    int rating, {
    Set<String> exclude = const {},
    Random? random,
  }) async {
    final bots = (await load()).where((b) => !exclude.contains(b.uid)).toList();
    final rng = random ?? Random();
    for (final window in const [60, 120, 250, 500]) {
      final fit = bots
          .where((b) => (b.ratingFor(game) - rating).abs() <= window)
          .toList();
      if (fit.length >= 3) return fit[rng.nextInt(fit.length)];
    }
    bots.sort((a, b) => (a.ratingFor(game) - rating)
        .abs()
        .compareTo((b.ratingFor(game) - rating).abs()));
    final closest = bots.take(5).toList();
    return closest[rng.nextInt(closest.length)];
  }

  /// [count] different random bots for [game] (4-player domino seats).
  static Future<List<BotProfile>> some(int count, {Random? random}) async {
    final bots = [...await load()]..shuffle(random ?? Random());
    return bots.take(count).toList();
  }
}
