import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeControlCategory { bullet, blitz, rapid }

enum GameResult { white, black, draw, ongoing, aborted }

enum GameMode { local, online, bot, campaign }

class TimeControl {
  final int minutes;
  final int incrementSeconds;

  const TimeControl({required this.minutes, required this.incrementSeconds});

  String get label {
    if (minutes == 0 && incrementSeconds == 0) return '—';
    if (incrementSeconds == 0) return '$minutes min';
    return '$minutes+$incrementSeconds';
  }

  TimeControlCategory get category {
    final total = minutes * 60 + incrementSeconds * 40;
    if (total < 180) return TimeControlCategory.bullet;
    if (total < 600) return TimeControlCategory.blitz;
    return TimeControlCategory.rapid;
  }

  int get totalSeconds => minutes * 60 + incrementSeconds;

  Map<String, dynamic> toMap() => {
        'minutes': minutes,
        'incrementSeconds': incrementSeconds,
      };

  factory TimeControl.fromMap(Map<String, dynamic> map) => TimeControl(
        minutes: (map['minutes'] as num).toInt(),
        incrementSeconds: (map['incrementSeconds'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is TimeControl &&
      minutes == other.minutes &&
      incrementSeconds == other.incrementSeconds;

  @override
  int get hashCode => Object.hash(minutes, incrementSeconds);
}

// Standard time controls
class TimeControls {
  /// Untimed game (checkers / domino records — these games use per-move
  /// timers online rather than a chess clock).
  static const none = TimeControl(minutes: 0, incrementSeconds: 0);

  static const bullet1 = TimeControl(minutes: 1, incrementSeconds: 0);
  static const bullet1plus1 = TimeControl(minutes: 1, incrementSeconds: 1);
  static const bullet2plus1 = TimeControl(minutes: 2, incrementSeconds: 1);

  static const blitz3 = TimeControl(minutes: 3, incrementSeconds: 0);
  static const blitz3plus2 = TimeControl(minutes: 3, incrementSeconds: 2);
  static const blitz5 = TimeControl(minutes: 5, incrementSeconds: 0);
  static const blitz5plus3 = TimeControl(minutes: 5, incrementSeconds: 3);

  static const rapid10 = TimeControl(minutes: 10, incrementSeconds: 0);
  static const rapid15plus10 = TimeControl(minutes: 15, incrementSeconds: 10);
  static const rapid30 = TimeControl(minutes: 30, incrementSeconds: 0);

  static const allBullet = [bullet1, bullet1plus1, bullet2plus1];
  static const allBlitz = [blitz3, blitz3plus2, blitz5, blitz5plus3];
  static const allRapid = [rapid10, rapid15plus10, rapid30];
  static const all = [...allBullet, ...allBlitz, ...allRapid];
}

class GameModel {
  final String id;
  final GameMode mode;
  final String gameType; // 'chess', 'checkers', 'domino'
  final String? whiteUid;
  final String? blackUid;
  final String? whiteUsername;
  final String? blackUsername;
  final TimeControl timeControl;
  final String pgn; // full PGN or FEN sequence
  final List<String> moves;
  final GameResult result;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int? whiteRatingBefore;
  final int? blackRatingBefore;
  final int? whiteRatingChange;
  final int? blackRatingChange;
  final int? campaignChapter;
  final bool isRated;

  const GameModel({
    required this.id,
    required this.mode,
    this.gameType = 'chess',
    this.whiteUid,
    this.blackUid,
    this.whiteUsername,
    this.blackUsername,
    required this.timeControl,
    this.pgn = '',
    this.moves = const [],
    this.result = GameResult.ongoing,
    required this.createdAt,
    this.endedAt,
    this.whiteRatingBefore,
    this.blackRatingBefore,
    this.whiteRatingChange,
    this.blackRatingChange,
    this.campaignChapter,
    this.isRated = false,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'mode': mode.name,
      'gameType': gameType,
      'whiteUid': whiteUid,
      'blackUid': blackUid,
      'whiteUsername': whiteUsername,
      'blackUsername': blackUsername,
      'timeControl': timeControl.toMap(),
      'pgn': pgn,
      'moves': moves,
      'result': result.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'campaignChapter': campaignChapter,
      'isRated': isRated,
      'timeControlCategory': timeControl.category.name,
    };
    // Rating fields are written only when non-null.
    // Both players call saveGame independently; each only knows their own
    // rating delta.  Skipping nulls + merge:true ensures neither client
    // overwrites the other player's already-saved rating data.
    if (whiteRatingBefore != null) map['whiteRatingBefore'] = whiteRatingBefore;
    if (blackRatingBefore != null) map['blackRatingBefore'] = blackRatingBefore;
    if (whiteRatingChange != null) map['whiteRatingChange'] = whiteRatingChange;
    if (blackRatingChange != null) map['blackRatingChange'] = blackRatingChange;
    return map;
  }

  factory GameModel.fromMap(Map<String, dynamic> map) => GameModel(
        id: map['id'] as String,
        mode: GameMode.values.byName(map['mode'] as String),
        gameType: (map['gameType'] as String?) ?? 'chess',
        whiteUid: map['whiteUid'] as String?,
        blackUid: map['blackUid'] as String?,
        whiteUsername: map['whiteUsername'] as String?,
        blackUsername: map['blackUsername'] as String?,
        timeControl:
            TimeControl.fromMap(map['timeControl'] as Map<String, dynamic>),
        pgn: map['pgn'] as String? ?? '',
        moves: (map['moves'] as List<dynamic>?)?.cast<String>() ?? [],
        result: GameResult.values.byName(
            (map['result'] as String?) ?? GameResult.ongoing.name),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
        whiteRatingBefore: (map['whiteRatingBefore'] as num?)?.toInt(),
        blackRatingBefore: (map['blackRatingBefore'] as num?)?.toInt(),
        whiteRatingChange: (map['whiteRatingChange'] as num?)?.toInt(),
        blackRatingChange: (map['blackRatingChange'] as num?)?.toInt(),
        campaignChapter: (map['campaignChapter'] as num?)?.toInt(),
        isRated: map['isRated'] as bool? ?? false,
      );

  GameModel copyWith({
    String? pgn,
    List<String>? moves,
    GameResult? result,
    DateTime? endedAt,
    int? whiteRatingChange,
    int? blackRatingChange,
  }) =>
      GameModel(
        id: id,
        mode: mode,
        gameType: gameType,
        whiteUid: whiteUid,
        blackUid: blackUid,
        whiteUsername: whiteUsername,
        blackUsername: blackUsername,
        timeControl: timeControl,
        pgn: pgn ?? this.pgn,
        moves: moves ?? this.moves,
        result: result ?? this.result,
        createdAt: createdAt,
        endedAt: endedAt ?? this.endedAt,
        whiteRatingBefore: whiteRatingBefore,
        blackRatingBefore: blackRatingBefore,
        whiteRatingChange: whiteRatingChange ?? this.whiteRatingChange,
        blackRatingChange: blackRatingChange ?? this.blackRatingChange,
        campaignChapter: campaignChapter,
        isRated: isRated,
      );
}
