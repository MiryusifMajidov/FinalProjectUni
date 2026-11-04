import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentStatus { waiting, active, finished }

/// Parse "5+0" → (timeSeconds=300, incrementSeconds=0)
(int timeSeconds, int incrementSeconds) parseTCLabel(String label) {
  final parts = label.split('+');
  final mins = int.tryParse(parts[0]) ?? 5;
  final inc = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return (mins * 60, inc);
}

class TournamentModel {
  final String id;
  final String name;
  final String? description;
  final String gameType; // 'chess', 'checkers', 'domino'

  /// Per-game ruleset chosen by the creator: checkers variant key
  /// ('standard' | 'russian' | …) or domino ruleset ('draw' | 'block').
  /// Null for chess (which uses [timeControlLabel] instead).
  final String? rulesKey;
  final TournamentStatus status;
  final String creatorUid;
  final String creatorUsername;
  final int maxPlayers;
  final String timeControlLabel;
  final int timeSeconds;
  final int incrementSeconds;
  final int durationMinutes;
  final DateTime? endsAt;
  final DateTime createdAt;
  final int participantCount;

  /// One of the server's live arenas rather than a player's own.
  final bool isSystem;

  /// Translation key for server-created arenas ("arena_theme_golden"), so
  /// the name shows in the player's language. [name] is the English fallback.
  final String? nameKey;

  /// When a waiting arena goes live: the slot start for live arenas, two
  /// minutes after creation for a player's arena (both set by the server).
  final DateTime? startsAt;

  /// Set by the server when the arena finishes.
  final String? winnerUid;
  final String? winnerUsername;
  final DateTime? finishedAt;

  /// Closed without being played (nobody stayed in a player's arena).
  final bool cancelled;

  /// Bots that are in the middle of a bot-vs-bot game right now, so a player
  /// is paired with a free one.
  final Set<String> busyBotUids;

  const TournamentModel({
    required this.id,
    required this.name,
    this.description,
    this.gameType = 'chess',
    this.rulesKey,
    required this.status,
    required this.creatorUid,
    required this.creatorUsername,
    required this.maxPlayers,
    required this.timeControlLabel,
    required this.timeSeconds,
    required this.incrementSeconds,
    required this.durationMinutes,
    this.endsAt,
    required this.createdAt,
    this.participantCount = 0,
    this.isSystem = false,
    this.nameKey,
    this.startsAt,
    this.winnerUid,
    this.winnerUsername,
    this.finishedAt,
    this.cancelled = false,
    this.busyBotUids = const {},
  });

  bool get isActive => status == TournamentStatus.active && !hasEnded;
  bool get isWaiting => status == TournamentStatus.waiting;

  /// Finished — or past its end time and waiting for the server to close it
  /// (the server sweeps once a minute; the UI should not show "LIVE 00:00").
  bool get isFinished => status == TournamentStatus.finished || hasEnded;

  bool get hasEnded =>
      status == TournamentStatus.active &&
      endsAt != null &&
      DateTime.now().isAfter(endsAt!);

  /// The status to display, folding [hasEnded] into finished.
  TournamentStatus get effectiveStatus =>
      hasEnded ? TournamentStatus.finished : status;

  bool get isFull => participantCount >= maxPlayers;

  /// Players may join until the arena ends (arena format — late joiners
  /// simply have fewer games), as long as there is room.
  bool get canJoin => !isFinished && !isFull;

  factory TournamentModel.fromMap(String id, Map<String, dynamic> map) {
    final label = map['timeControlLabel'] as String? ?? '5+0';
    final (defaultTc, defaultInc) = parseTCLabel(label);
    return TournamentModel(
      id: id,
      name: map['name'] as String? ?? 'Tournament',
      description: map['description'] as String?,
      status: TournamentStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? ''),
        orElse: () => TournamentStatus.waiting,
      ),
      gameType: (map['gameType'] as String?) ?? 'chess',
      rulesKey: map['rulesKey'] as String?,
      creatorUid: map['creatorUid'] as String? ?? '',
      creatorUsername: map['creatorUsername'] as String? ?? '',
      maxPlayers: (map['maxPlayers'] as num?)?.toInt() ?? 32,
      timeControlLabel: label,
      timeSeconds: (map['timeSeconds'] as num?)?.toInt() ?? defaultTc,
      incrementSeconds: (map['incrementSeconds'] as num?)?.toInt() ?? defaultInc,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      endsAt: (map['endsAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      isSystem: (map['isSystem'] as bool?) ?? false,
      nameKey: map['nameKey'] as String?,
      startsAt: (map['startsAt'] as Timestamp?)?.toDate(),
      winnerUid: map['winnerUid'] as String?,
      winnerUsername: map['winnerUsername'] as String?,
      finishedAt: (map['finishedAt'] as Timestamp?)?.toDate(),
      cancelled: (map['cancelled'] as bool?) ?? false,
      busyBotUids: {
        for (final g in (map['botGames'] as List?) ?? const [])
          if (g is Map) ...[
            if (g['a'] is String) g['a'] as String,
            if (g['b'] is String) g['b'] as String,
          ],
      },
    );
  }

  Map<String, dynamic> toMap() {
    final (tc, inc) = parseTCLabel(timeControlLabel);
    return {
      'name': name,
      if (description != null) 'description': description,
      'gameType': gameType,
      if (rulesKey != null) 'rulesKey': rulesKey,
      'format': 'arena',
      'status': status.name,
      'creatorUid': creatorUid,
      'creatorUsername': creatorUsername,
      'maxPlayers': maxPlayers,
      'timeControlLabel': timeControlLabel,
      'timeSeconds': tc,
      'incrementSeconds': inc,
      'durationMinutes': durationMinutes,
      if (endsAt != null) 'endsAt': Timestamp.fromDate(endsAt!),
      'createdAt': FieldValue.serverTimestamp(),
      'participantCount': participantCount,
    };
  }
}

class ArenaParticipant {
  final String uid;
  final String username;
  final int rating;
  final String? countryCode;

  /// Server-run bot that fills the arena (uid starts with `bot_`). Shown
  /// with a BOT badge; bots have no profile and no world ranking.
  final bool isBot;
  final double score;
  final int wins;
  final int draws;
  final int losses;
  final int gamesPlayed;

  /// Wins in a row. From two on the player is [onFire]: the next game scores
  /// double (4 for a win, 2 for a draw) until they fail to win.
  final int streak;
  final bool onFire;

  /// Points per game, oldest first: "w2", "w4", "d1", "d2", "l0".
  final List<String> results;
  final DateTime joinedAt;

  const ArenaParticipant({
    required this.uid,
    required this.username,
    required this.rating,
    this.countryCode,
    this.isBot = false,
    this.score = 0.0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.gamesPlayed = 0,
    this.streak = 0,
    this.onFire = false,
    this.results = const [],
    required this.joinedAt,
  });

  factory ArenaParticipant.fromMap(Map<String, dynamic> map) {
    return ArenaParticipant(
      uid: map['uid'] as String? ?? '',
      username: map['username'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 1200,
      countryCode: map['countryCode'] as String?,
      isBot: (map['isBot'] as bool?) ??
          ((map['uid'] as String?)?.startsWith('bot_') ?? false),
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      onFire: (map['onFire'] as bool?) ?? false,
      results: [
        for (final r in (map['results'] as List?) ?? const [])
          if (r is String) r,
      ],
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Arena order: points, then wins, then fewer games (a better rate).
  static int compare(ArenaParticipant a, ArenaParticipant b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byGames = a.gamesPlayed.compareTo(b.gamesPlayed);
    if (byGames != 0) return byGames;
    return b.rating.compareTo(a.rating);
  }
}
