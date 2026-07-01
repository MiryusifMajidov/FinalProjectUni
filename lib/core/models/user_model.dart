import 'package:cloud_firestore/cloud_firestore.dart';

class RatingStats {
  final int rating;
  final int wins;
  final int draws;
  final int losses;

  const RatingStats({
    this.rating = 1200,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
  });

  int get games => wins + draws + losses;

  Map<String, dynamic> toMap() => {
        'rating': rating,
        'wins': wins,
        'draws': draws,
        'losses': losses,
      };

  factory RatingStats.fromMap(Map<String, dynamic> map) => RatingStats(
        rating: (map['rating'] as num?)?.toInt() ?? 1200,
        wins: (map['wins'] as num?)?.toInt() ?? 0,
        draws: (map['draws'] as num?)?.toInt() ?? 0,
        losses: (map['losses'] as num?)?.toInt() ?? 0,
      );

  RatingStats copyWith({
    int? rating,
    int? wins,
    int? draws,
    int? losses,
  }) =>
      RatingStats(
        rating: rating ?? this.rating,
        wins: wins ?? this.wins,
        draws: draws ?? this.draws,
        losses: losses ?? this.losses,
      );
}

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String? avatarId;
  final String? photoUrl;    // Firebase Storage URL (set after onboarding)
  final String? skillLevel;  // e.g. 'Beginner', 'Casual', 'Intermediate' …
  final String? countryCode; // 2-letter ISO e.g. "US", "AZ"
  final double? latitude;    // For Player Map
  final double? longitude;
  final bool showOnMap;           // Opt-in privacy flag
  final String profileVisibility; // 'Public' | 'Friends' | 'Private'
  final DateTime? lastSeen;       // Updated periodically while app is open
  final DateTime createdAt;
  final RatingStats bulletStats;
  final RatingStats blitzStats;
  final RatingStats rapidStats;
  final RatingStats checkersStats;  // Checkers overall rating
  final RatingStats dominoStats;    // Domino overall rating
  final int campaignProgress;          // chess chapters completed (0–100)
  final int checkersCampaignProgress;  // checkers chapters completed (0–60)
  final int dominoCampaignProgress;    // domino chapters completed (0–40)
  final List<String> recentGameIds;
  final String? currentGameId; // set while in a live online game

  // ── Privacy / security extras ─────────────────────────────────────────────
  final bool twoFactorEnabled;          // 2FA via email OTP on login
  final bool showOnlineStatus;          // show "online" dot to others
  final bool invisibleMode;             // appear offline to everyone
  final String friendRequestPrivacy;    // 'everyone' | 'nobody'
  final String challengePrivacy;        // 'everyone' | 'friends' | 'nobody'
  final String messagePrivacy;          // 'everyone' | 'friends' | 'nobody'
  final List<String> blockedUsers;      // UIDs this user has blocked

  // ── Notification channel prefs (synced to Firestore so Cloud Fns read) ───
  final bool notifGameInvites;
  final bool notifYourTurn;
  final bool notifMessages;
  final bool notifFriendRequests;
  final bool notifTournaments;

  const UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.avatarId,
    this.photoUrl,
    this.skillLevel,
    this.countryCode,
    this.latitude,
    this.longitude,
    this.showOnMap = false,
    this.profileVisibility = 'Public',
    this.lastSeen,
    required this.createdAt,
    this.bulletStats = const RatingStats(),
    this.blitzStats = const RatingStats(),
    this.rapidStats = const RatingStats(),
    this.checkersStats = const RatingStats(rating: 300),
    this.dominoStats = const RatingStats(rating: 300),
    this.campaignProgress = 0,
    this.checkersCampaignProgress = 0,
    this.dominoCampaignProgress = 0,
    this.recentGameIds = const [],
    this.currentGameId,
    this.twoFactorEnabled = false,
    this.showOnlineStatus = true,
    this.invisibleMode = false,
    this.friendRequestPrivacy = 'everyone',
    this.challengePrivacy = 'everyone',
    this.messagePrivacy = 'everyone',
    this.blockedUsers = const [],
    this.notifGameInvites = true,
    this.notifYourTurn = true,
    this.notifMessages = true,
    this.notifFriendRequests = true,
    this.notifTournaments = true,
  });

  /// Average rating across only the game modes the user has actually played.
  /// Falls back to 1200 if no rated games have been played yet.
  int get overallRating {
    final played = <RatingStats>[
      if (bulletStats.games > 0) bulletStats,
      if (blitzStats.games > 0) blitzStats,
      if (rapidStats.games > 0) rapidStats,
    ];
    if (played.isEmpty) return 1200;
    return (played.map((s) => s.rating).reduce((a, b) => a + b) /
            played.length)
        .round();
  }

  /// Returns a flag emoji for a 2-letter ISO country code, e.g. "US" -> "🇺🇸"
  static String flagEmoji(String? code) {
    if (code == null || code.isEmpty) return '🌍'; // no country → international globe
    if (code == 'XX') return '🌍'; // explicitly international
    if (code.length != 2) return '🌍';
    final base = 0x1F1E6 - 0x41;
    final codePoints = code.toUpperCase().codeUnits;
    return String.fromCharCodes([base + codePoints[0], base + codePoints[1]]);
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'email': email,
        'avatarId': avatarId,
        'photoUrl': photoUrl,
        'skillLevel': skillLevel,
        'countryCode': countryCode,
        'latitude': latitude,
        'longitude': longitude,
        'showOnMap': showOnMap,
        'profileVisibility': profileVisibility,
        'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'bulletStats': bulletStats.toMap(),
        'blitzStats': blitzStats.toMap(),
        'rapidStats': rapidStats.toMap(),
        'checkersStats': checkersStats.toMap(),
        'dominoStats': dominoStats.toMap(),
        'campaignProgress': campaignProgress,
        'checkersCampaignProgress': checkersCampaignProgress,
        'dominoCampaignProgress': dominoCampaignProgress,
        'recentGameIds': recentGameIds,
        if (currentGameId != null) 'currentGameId': currentGameId,
        'twoFactorEnabled': twoFactorEnabled,
        'showOnlineStatus': showOnlineStatus,
        'invisibleMode': invisibleMode,
        'friendRequestPrivacy': friendRequestPrivacy,
        'challengePrivacy': challengePrivacy,
        'messagePrivacy': messagePrivacy,
        'blockedUsers': blockedUsers,
        'notifGameInvites': notifGameInvites,
        'notifYourTurn': notifYourTurn,
        'notifMessages': notifMessages,
        'notifFriendRequests': notifFriendRequests,
        'notifTournaments': notifTournaments,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: (map['uid'] as String?) ?? '',
        username: (map['username'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        avatarId: map['avatarId'] as String?,
        photoUrl: map['photoUrl'] as String?,
        skillLevel: map['skillLevel'] as String?,
        countryCode: map['countryCode'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        showOnMap: (map['showOnMap'] as bool?) ?? false,
        profileVisibility: (map['profileVisibility'] as String?) ?? 'Public',
        lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
        createdAt: (map['createdAt'] as Timestamp).toDate(),
        bulletStats: RatingStats.fromMap(
            (map['bulletStats'] as Map<String, dynamic>?) ?? {}),
        blitzStats: RatingStats.fromMap(
            (map['blitzStats'] as Map<String, dynamic>?) ?? {}),
        rapidStats: RatingStats.fromMap(
            (map['rapidStats'] as Map<String, dynamic>?) ?? {}),
        checkersStats: RatingStats.fromMap(
            (map['checkersStats'] as Map<String, dynamic>?) ?? {'rating': 300}),
        dominoStats: RatingStats.fromMap(
            (map['dominoStats'] as Map<String, dynamic>?) ?? {'rating': 300}),
        campaignProgress: (map['campaignProgress'] as num?)?.toInt() ?? 0,
        checkersCampaignProgress: (map['checkersCampaignProgress'] as num?)?.toInt() ?? 0,
        dominoCampaignProgress: (map['dominoCampaignProgress'] as num?)?.toInt() ?? 0,
        recentGameIds:
            (map['recentGameIds'] as List<dynamic>?)?.cast<String>() ?? [],
        currentGameId: map['currentGameId'] as String?,
        twoFactorEnabled: (map['twoFactorEnabled'] as bool?) ?? false,
        showOnlineStatus: (map['showOnlineStatus'] as bool?) ?? true,
        invisibleMode: (map['invisibleMode'] as bool?) ?? false,
        friendRequestPrivacy:
            (map['friendRequestPrivacy'] as String?) ?? 'everyone',
        challengePrivacy:
            (map['challengePrivacy'] as String?) ?? 'everyone',
        messagePrivacy:
            (map['messagePrivacy'] as String?) ?? 'everyone',
        blockedUsers:
            (map['blockedUsers'] as List<dynamic>?)?.cast<String>() ?? [],
        notifGameInvites: (map['notifGameInvites'] as bool?) ?? true,
        notifYourTurn: (map['notifYourTurn'] as bool?) ?? true,
        notifMessages: (map['notifMessages'] as bool?) ?? true,
        notifFriendRequests: (map['notifFriendRequests'] as bool?) ?? true,
        notifTournaments: (map['notifTournaments'] as bool?) ?? true,
      );

  factory UserModel.fromDoc(DocumentSnapshot doc) =>
      UserModel.fromMap(doc.data() as Map<String, dynamic>);

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? avatarId,
    String? photoUrl,
    String? skillLevel,
    Object? countryCode = _sentinel,
    Object? currentGameId = _sentinel,
    double? latitude,
    double? longitude,
    bool? showOnMap,
    String? profileVisibility,
    DateTime? lastSeen,
    DateTime? createdAt,
    RatingStats? bulletStats,
    RatingStats? blitzStats,
    RatingStats? rapidStats,
    RatingStats? checkersStats,
    RatingStats? dominoStats,
    int? campaignProgress,
    int? checkersCampaignProgress,
    int? dominoCampaignProgress,
    List<String>? recentGameIds,
    bool? twoFactorEnabled,
    bool? showOnlineStatus,
    bool? invisibleMode,
    String? friendRequestPrivacy,
    String? challengePrivacy,
    String? messagePrivacy,
    List<String>? blockedUsers,
    bool? notifGameInvites,
    bool? notifYourTurn,
    bool? notifMessages,
    bool? notifFriendRequests,
    bool? notifTournaments,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        username: username ?? this.username,
        email: email ?? this.email,
        avatarId: avatarId ?? this.avatarId,
        photoUrl: photoUrl ?? this.photoUrl,
        skillLevel: skillLevel ?? this.skillLevel,
        countryCode: countryCode == _sentinel ? this.countryCode : countryCode as String?,
        currentGameId: currentGameId == _sentinel ? this.currentGameId : currentGameId as String?,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        showOnMap: showOnMap ?? this.showOnMap,
        profileVisibility: profileVisibility ?? this.profileVisibility,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt ?? this.createdAt,
        bulletStats: bulletStats ?? this.bulletStats,
        blitzStats: blitzStats ?? this.blitzStats,
        rapidStats: rapidStats ?? this.rapidStats,
        checkersStats: checkersStats ?? this.checkersStats,
        dominoStats: dominoStats ?? this.dominoStats,
        campaignProgress: campaignProgress ?? this.campaignProgress,
        checkersCampaignProgress: checkersCampaignProgress ?? this.checkersCampaignProgress,
        dominoCampaignProgress: dominoCampaignProgress ?? this.dominoCampaignProgress,
        recentGameIds: recentGameIds ?? this.recentGameIds,
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
        invisibleMode: invisibleMode ?? this.invisibleMode,
        friendRequestPrivacy: friendRequestPrivacy ?? this.friendRequestPrivacy,
        challengePrivacy: challengePrivacy ?? this.challengePrivacy,
        messagePrivacy: messagePrivacy ?? this.messagePrivacy,
        blockedUsers: blockedUsers ?? this.blockedUsers,
        notifGameInvites: notifGameInvites ?? this.notifGameInvites,
        notifYourTurn: notifYourTurn ?? this.notifYourTurn,
        notifMessages: notifMessages ?? this.notifMessages,
        notifFriendRequests: notifFriendRequests ?? this.notifFriendRequests,
        notifTournaments: notifTournaments ?? this.notifTournaments,
      );
}

const _sentinel = Object();
