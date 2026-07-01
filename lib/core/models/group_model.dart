import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupPrivacy { public, private }

class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String avatarEmoji;
  final GroupPrivacy privacy;
  final String adminId; // original/legacy single admin
  final String adminUsername;
  final List<String> adminIds; // all admins
  final List<String> memberIds;
  final DateTime createdAt;
  final int memberCount;
  final String whoCanSend; // 'everyone' | 'admins'
  final List<String> mutedBy;
  final String? photoUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> lastReadAt;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.avatarEmoji = '\u265b',
    this.photoUrl,
    required this.privacy,
    required this.adminId,
    required this.adminUsername,
    List<String>? adminIds,
    required this.memberIds,
    required this.createdAt,
    this.memberCount = 0,
    this.whoCanSend = 'everyone',
    this.mutedBy = const [],
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
  }) : adminIds = adminIds ?? const [];

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    final rawAdminId = map['adminId'] as String;
    final rawAdminIds = List<String>.from(map['adminIds'] as List? ?? []);
    // Ensure the original adminId is always in adminIds list
    if (rawAdminId.isNotEmpty && !rawAdminIds.contains(rawAdminId)) {
      rawAdminIds.insert(0, rawAdminId);
    }

    return GroupModel(
      id: id,
      name: map['name'] as String,
      description: map['description'] as String?,
      avatarEmoji: map['avatarEmoji'] as String? ?? '\u265b',
      privacy: GroupPrivacy.values.firstWhere(
        (p) => p.name == (map['privacy'] as String? ?? 'public'),
        orElse: () => GroupPrivacy.public,
      ),
      adminId: rawAdminId,
      adminUsername: map['adminUsername'] as String? ?? '',
      adminIds: rawAdminIds,
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      whoCanSend: map['whoCanSend'] as String? ?? 'everyone',
      mutedBy: List<String>.from(map['mutedBy'] as List? ?? []),
      photoUrl: map['photoUrl'] as String?,
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCounts: (map['unreadCounts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      lastReadAt: Map.fromEntries(
        ((map['lastReadAt'] as Map<String, dynamic>?) ?? {})
            .entries
            .where((e) => e.value is Timestamp)
            .map((e) => MapEntry(e.key, (e.value as Timestamp).toDate())),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (description != null) 'description': description,
    'avatarEmoji': avatarEmoji,
    'privacy': privacy.name,
    'adminId': adminId,
    'adminUsername': adminUsername,
    'adminIds': adminIds,
    'memberIds': memberIds,
    'createdAt': FieldValue.serverTimestamp(),
    'memberCount': memberCount,
    'whoCanSend': whoCanSend,
    'mutedBy': mutedBy,
    if (photoUrl != null) 'photoUrl': photoUrl,
    if (lastMessage != null) 'lastMessage': lastMessage,
  };

  // Helper methods
  bool isAdmin(String uid) => adminIds.contains(uid) || uid == adminId;
  bool isMember(String uid) => memberIds.contains(uid);
  bool isMuted(String uid) => mutedBy.contains(uid);
  int unreadFor(String uid) => unreadCounts[uid] ?? 0;
}

class GroupMessage {
  final String id;
  final String senderUid;
  final String senderUsername;
  final String text;
  final DateTime createdAt;

  // Reply fields
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;

  const GroupMessage({
    required this.id,
    required this.senderUid,
    required this.senderUsername,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
  });

  factory GroupMessage.fromMap(String id, Map<String, dynamic> map) =>
      GroupMessage(
        id: id,
        senderUid: map['senderUid'] as String,
        senderUsername: map['senderUsername'] as String? ?? '',
        text: map['text'] as String,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        replyToId: map['replyToId'] as String?,
        replyToText: map['replyToText'] as String?,
        replyToSenderName: map['replyToSenderName'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'senderUsername': senderUsername,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
    if (replyToId != null) 'replyToId': replyToId,
    if (replyToText != null) 'replyToText': replyToText,
    if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
  };

  bool get hasReply => replyToId != null && replyToText != null;
}
