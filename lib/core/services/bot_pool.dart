import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_model.dart';
import '../models/game_type.dart';
import '../models/user_model.dart';
import 'bot_cities.dart';

/// One of the 2500 bots that fill arenas and stand in when matchmaking finds
/// nobody. The list (assets/data/bots.json) is the same one the arena Cloud
/// Functions use (functions/bot_pool.json), so a bot has the same name, flag
/// and ratings everywhere.
///
/// The first 2000 (`bot_0001` … `bot_2000`) play under their names like any
/// player, at a person's pace (HumanPace), with a profile, a place on the
/// player map and a record that grows. The last 500 (`bot_2001` …
/// `bot_2500`) are "labelled": a Bot badge follows their name everywhere.
/// No bot is in the world ranking.
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

  /// Shown with a Bot badge (see [BotPool.isLabelledUid]).
  bool get labelled => BotPool.isLabelledUid(uid);

  int ratingFor(GameType game) => switch (game) {
        GameType.chess => chessRating,
        GameType.checkers => checkersRating,
        GameType.domino => dominoRating,
      };

  int get _n => int.tryParse(uid.replaceFirst('bot_', '')) ?? username.hashCode;

  /// The bot as a player profile, so its page opens like anyone's. Bots have
  /// no users/ document: everything here is derived from the bot's id and
  /// the time, so every phone shows the same profile.
  ///
  /// The bot plays a few games a day of its own, so its record grows day by
  /// day, and the games [mine] (played against it on this phone) are added
  /// on top. Its record fits its strength (stronger bots win more). It is
  /// online now and then, and takes no messages or challenges, settings any
  /// player can choose.
  UserModel toUser({DateTime? now, BotRecord mine = const BotRecord()}) {
    final at = now ?? DateTime.now();
    final rng = Random(_n * 7919 + 17);

    final created = DateTime(2026, 7, 20)
        .add(Duration(days: rng.nextInt(96), hours: rng.nextInt(24)));
    final days = max(0.0, at.difference(created).inMinutes / 1440);

    double perDay(double lo, double span) =>
        lo + pow(rng.nextDouble(), 1.7) * span;

    RatingStats record(int rating, double mean, double spread, double perDay,
        double drawRate, int minGames, (int, int, int) extra) {
      final edge = ((rating - mean) / spread).clamp(-1.6, 1.6);
      final score = (0.5 + edge * 0.09 + (rng.nextDouble() - 0.5) * 0.06)
          .clamp(0.3, 0.72);
      final drawShare = drawRate * (0.6 + rng.nextDouble() * 0.8);
      final winShare = (score - drawShare / 2).clamp(0.0, 1.0 - drawShare);
      final games = minGames + (perDay * days).floor();
      final draws = (games * drawShare).round();
      final wins = min((games * winShare).round(), games - draws);
      return RatingStats(
        rating: rating,
        wins: wins + extra.$1,
        draws: draws + extra.$2,
        losses: games - wins - draws + extra.$3,
      );
    }

    final blitz = chessRating;
    final bullet = chessRating - 35 + rng.nextInt(51);
    final rapid = chessRating - 10 + rng.nextInt(51);
    final level = switch (blitz) {
      < 600 => 'Beginner',
      < 1000 => 'Casual',
      < 1400 => 'Intermediate',
      < 1800 => 'Advanced',
      < 2200 => 'Expert',
      _ => 'Master',
    };
    final blitzStats = record(blitz, 1263, 300, perDay(0.25, 6), 0.07, 8,
        mine.of('blitz'));
    final bulletStats = record(bullet, 1263, 300, perDay(0.03, 2.4), 0.04, 2,
        mine.of('bullet'));
    final rapidStats = record(rapid, 1263, 300, perDay(0.02, 1.0), 0.09, 1,
        mine.of('rapid'));
    final checkersStats = record(checkersRating, 341, 100, perDay(0.05, 2.4),
        0.12, 3, mine.of('checkers'));
    final dominoStats = record(dominoRating, 342, 100, perDay(0.05, 2.4), 0.02,
        3, mine.of('domino'));
    final campaign = rng.nextInt(18);
    final challengePrivacy = rng.nextDouble() < 0.6 ? 'friends' : 'nobody';
    final messagePrivacy = rng.nextDouble() < 0.65 ? 'friends' : 'nobody';

    final h = _hash(_n, at.millisecondsSinceEpoch ~/ _window);
    final justPlayed = mine.lastPlayed != null &&
        at.difference(mine.lastPlayed!).inMinutes < 10;
    final lastSeen = onlineAt(at) || justPlayed
        ? at.subtract(Duration(minutes: h % 4))
        : at.subtract(Duration(minutes: 20 + h % (60 * 48)));

    // A spot in or around one of the bigger cities of its country.
    final place = Random(_n * 31 + 5);
    final cities = kBotCities[countryCode];
    final city = cities == null ? null : cities[place.nextInt(cities.length)];

    return UserModel(
      uid: uid,
      username: username,
      email: '',
      skillLevel: level,
      countryCode: countryCode,
      createdAt: created,
      lastSeen: lastSeen,
      blitzStats: blitzStats,
      bulletStats: bulletStats,
      rapidStats: rapidStats,
      checkersStats: checkersStats,
      dominoStats: dominoStats,
      campaignProgress: campaign,
      showOnMap: !labelled && city != null,
      latitude: city == null ? null : city.$1 + (place.nextDouble() - 0.5) * 0.16,
      longitude:
          city == null ? null : city.$2 + (place.nextDouble() - 0.5) * 0.22,
      challengePrivacy: challengePrivacy,
      messagePrivacy: messagePrivacy,
    );
  }

  /// "Last seen" minutes change in 12-minute windows.
  static const _window = 12 * 60000;

  /// Whether the bot is online at [at], the same on every phone. Like
  /// people, bots are online more in their country's evening and less at
  /// night: about one in four at 9 pm local time, one in twenty-five at
  /// 4 am. Each bot comes and goes on its own clock (sessions of 6–20
  /// minutes from its own starting point), so someone joins or leaves every
  /// few seconds and the online count never sits still.
  bool onlineAt(DateTime at) {
    final utc = at.toUtc();
    final offset = _kUtcOffset[countryCode] ?? 0;
    final local = (utc.hour + utc.minute / 60 + offset) % 24;
    final share = _activity(local);
    final session = (6 + _hash(_n, 7) % 15) * 60000;
    final phase = _hash(_n, 13) % session;
    final slot = (at.millisecondsSinceEpoch + phase) ~/ session;
    return (_hash(_n, slot) % 1000) < share * 1000;
  }

  /// Share of players online by local hour (0–24).
  static double _activity(double hour) {
    const curve = [
      0.12, 0.08, 0.05, 0.04, 0.04, 0.05, 0.07, 0.09, 0.11, 0.12, 0.13, 0.14,
      0.15, 0.15, 0.14, 0.14, 0.15, 0.17, 0.20, 0.23, 0.25, 0.25, 0.22, 0.17,
    ];
    final i = hour.floor() % 24;
    final f = hour - hour.floor();
    return curve[i] + (curve[(i + 1) % 24] - curve[i]) * f;
  }

  static int _hash(int a, int b) {
    var x = (a * 73856093) ^ (b * 19349663);
    x = (x ^ (x >> 13)) * 1274126177;
    return (x ^ (x >> 16)) & 0x7fffffff;
  }
}

/// Standard UTC offsets (hours) of the bot pool's countries, for the hour
/// of day where the bot lives (the main time zone; summer time ignored).
const Map<String, double> _kUtcOffset = {
  'AZ': 4, 'TR': 3, 'RU': 3, 'US': -5, 'IN': 5.5, 'DE': 1, 'ES': 1,
  'BR': -3, 'FR': 1, 'CN': 8, 'UA': 2, 'GB': 0, 'PK': 5, 'IR': 3.5,
  'PL': 1, 'EG': 2, 'IT': 1, 'ID': 7, 'KZ': 5, 'MX': -6, 'NL': 1,
  'AR': -3, 'UZ': 5, 'GE': 4, 'NG': 1, 'CA': -5, 'SA': 3, 'PH': 8,
  'KR': 9, 'JP': 9,
};

/// Games played against one bot on this phone, from the bot's side, per
/// rating ('bullet', 'blitz', 'rapid', 'checkers', 'domino') as
/// (wins, draws, losses).
class BotRecord {
  final Map<String, (int, int, int)> byKind;
  final DateTime? lastPlayed;
  const BotRecord({this.byKind = const {}, this.lastPlayed});

  (int, int, int) of(String kind) => byKind[kind] ?? (0, 0, 0);
}

/// Stores [BotRecord]s on the phone, so a bot's profile counts the games
/// played against it here as soon as they end.
class BotRecords {
  BotRecords._();

  static const _key = 'bot_games_v1';
  static Map<String, dynamic>? _cache;

  static Future<Map<String, dynamic>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      return _cache = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return _cache = <String, dynamic>{};
    }
  }

  static Future<BotRecord> of(String uid) async {
    final entry = (await _load())[uid];
    if (entry is! Map) return const BotRecord();
    final byKind = <String, (int, int, int)>{};
    for (final kind in const ['bullet', 'blitz', 'rapid', 'checkers', 'domino']) {
      final v = entry[kind];
      if (v is List && v.length == 3) {
        byKind[kind] = ((v[0] as num).toInt(), (v[1] as num).toInt(),
            (v[2] as num).toInt());
      }
    }
    final last = entry['last'];
    return BotRecord(
      byKind: byKind,
      lastPlayed:
          last is num ? DateTime.fromMillisecondsSinceEpoch(last.toInt()) : null,
    );
  }

  /// Counts one finished game against bot [uid]. [botResult] is the bot's:
  /// 1 win, 0 draw, -1 loss. Not for labelled bots or non-bot ids.
  static Future<void> add(String uid, String kind, int botResult) async {
    if (!BotPool.isBotUid(uid)) return;
    final all = await _load();
    final entry = Map<String, dynamic>.from((all[uid] as Map?) ?? const {});
    final v = List<int>.from(
        ((entry[kind] as List?) ?? const [0, 0, 0]).map((e) => (e as num).toInt()));
    v[botResult > 0 ? 0 : botResult == 0 ? 1 : 2]++;
    entry[kind] = v;
    entry['last'] = DateTime.now().millisecondsSinceEpoch;
    all[uid] = entry;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(all));
    } catch (_) {}
  }

  /// The record key of a chess game in [tc] ('bullet', 'blitz' or 'rapid').
  static String chessKind(TimeControl tc) => switch (tc.category) {
        TimeControlCategory.bullet => 'bullet',
        TimeControlCategory.rapid => 'rapid',
        _ => 'blitz',
      };
}

class BotPool {
  BotPool._();

  /// Bots `bot_0001` … `bot_2000` play under their names; the ones after
  /// them carry a Bot badge.
  static const unlabelledCount = 2000;

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

  /// Bot ids are `bot_0001` … `bot_2500`; no person's id looks like that.
  static bool isBotUid(String? uid) => uid != null && uid.startsWith('bot_');

  /// A bot shown with a Bot badge (`bot_2001` and after).
  static bool isLabelledUid(String? uid) {
    if (!isBotUid(uid)) return false;
    final n = int.tryParse(uid!.substring(4));
    return n != null && n > unlabelledCount;
  }

  /// The bot named [username], if the pool is already loaded (it is once
  /// any bot game has started). For the Bot badge at a domino table, whose
  /// seats keep only names.
  static BotProfile? loadedByName(String username) {
    for (final b in _bots ?? const <BotProfile>[]) {
      if (b.username == username) return b;
    }
    return null;
  }

  static Future<BotProfile?> byUid(String uid) async {
    final n = int.tryParse(uid.replaceFirst('bot_', ''));
    final bots = await load();
    if (n != null && n >= 1 && n <= bots.length && bots[n - 1].uid == uid) {
      return bots[n - 1];
    }
    for (final b in bots) {
      if (b.uid == uid) return b;
    }
    return null;
  }

  /// Names are unique across the pool (a 4-player domino seat keeps only
  /// the name).
  static Future<BotProfile?> byName(String username) async {
    for (final b in await load()) {
      if (b.username == username) return b;
    }
    return null;
  }

  /// The profile of bot [uid], with the games played against it on this
  /// phone; null if there is no such bot.
  static Future<UserModel?> userFor(String uid) async {
    final bot = await byUid(uid);
    if (bot == null) return null;
    return bot.toUser(mine: await BotRecords.of(uid));
  }

  /// Bots whose name starts with [query] (case-insensitive), for player
  /// search; at most [limit].
  static Future<List<UserModel>> search(String query, {int limit = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    final out = <UserModel>[];
    for (final b in await load()) {
      if (!b.username.toLowerCase().startsWith(q)) continue;
      out.add(b.toUser(mine: await BotRecords.of(b.uid)));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// The bot named exactly [username] (case-insensitive), as a profile.
  static Future<UserModel?> userByName(String username) async {
    final q = username.trim().toLowerCase();
    for (final b in await load()) {
      if (b.username.toLowerCase() == q) {
        return b.toUser(mine: await BotRecords.of(b.uid));
      }
    }
    return null;
  }

  /// How many unlabelled bots are online at [now] (labelled bots are not
  /// counted as players).
  static Future<int> onlineCount({DateTime? now}) async {
    final at = now ?? DateTime.now();
    var n = 0;
    for (final b in await load()) {
      if (!b.labelled && b.onlineAt(at)) n++;
    }
    return n;
  }

  /// Every unlabelled bot as a profile with its place on the map.
  static Future<List<UserModel>> mapUsers() async {
    final now = DateTime.now();
    return [
      for (final b in await load())
        if (!b.labelled) b.toUser(now: now, mine: await BotRecords.of(b.uid)),
    ];
  }

  /// [count] different random bots for [game] (4-player domino seats).
  static Future<List<BotProfile>> some(int count, {Random? random}) async {
    final bots = [...await load()]..shuffle(random ?? Random());
    return bots.take(count).toList();
  }
}
