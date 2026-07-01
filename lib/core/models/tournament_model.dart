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
  });

  bool get isActive => status == TournamentStatus.active;
  bool get isFinished => status == TournamentStatus.finished;
  bool get isWaiting => status == TournamentStatus.waiting;

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
  final double score;
  final int wins;
  final int draws;
  final int losses;
  final int gamesPlayed;
  final DateTime joinedAt;

  const ArenaParticipant({
    required this.uid,
    required this.username,
    required this.rating,
    this.score = 0.0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.gamesPlayed = 0,
    required this.joinedAt,
  });

  factory ArenaParticipant.fromMap(Map<String, dynamic> map) {
    return ArenaParticipant(
      uid: map['uid'] as String? ?? '',
      username: map['username'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 1200,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'rating': rating,
        'score': score,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'gamesPlayed': gamesPlayed,
        'joinedAt': FieldValue.serverTimestamp(),
      };
}
