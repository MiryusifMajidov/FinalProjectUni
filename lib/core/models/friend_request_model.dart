import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequestModel {
  final String id;
  final String fromUid;
  final String fromUsername;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUid,
    required this.fromUsername,
    required this.toUid,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequestModel(
      id: id,
      fromUid: map['fromUid'] as String,
      fromUsername: map['fromUsername'] as String,
      toUid: map['toUid'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String),
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'fromUid': fromUid,
    'fromUsername': fromUsername,
    'toUid': toUid,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class FriendModel {
  final String uid;
  final String username;
  final String? avatarId;
  final String? photoUrl;
  final int rating;
  final DateTime? lastSeen;

  const FriendModel({
    required this.uid,
    required this.username,
    this.avatarId,
    this.photoUrl,
    required this.rating,
    this.lastSeen,
  });

  factory FriendModel.fromMap(Map<String, dynamic> map) {
    return FriendModel(
      uid: map['uid'] as String,
      username: map['username'] as String,
      avatarId: map['avatarId'] as String?,
      photoUrl: map['photoUrl'] as String?,
      rating: (map['rating'] as num?)?.toInt() ?? 1200,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'username': username,
    if (avatarId != null) 'avatarId': avatarId,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'rating': rating,
    if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
  };

  bool get isOnline =>
      lastSeen != null && DateTime.now().difference(lastSeen!).inMinutes < 5;
}
