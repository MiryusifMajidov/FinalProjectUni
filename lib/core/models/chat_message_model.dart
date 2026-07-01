import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderUid;
  final String text;
  final DateTime createdAt;
  final bool read;

  // Reply fields
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;

  const ChatMessageModel({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
    this.read = false,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessageModel(
      id: id,
      senderUid: map['senderUid'] as String,
      text: map['text'] as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: (map['read'] as bool?) ?? false,
      replyToId: map['replyToId'] as String?,
      replyToText: map['replyToText'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
    'read': read,
    if (replyToId != null) 'replyToId': replyToId,
    if (replyToText != null) 'replyToText': replyToText,
    if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
  };

  bool get hasReply => replyToId != null && replyToText != null;
}

class ChatModel {
  final String id; // sorted uid pair: "uid1_uid2"
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount; // uid → count

  // Delivery and read tracking: uid → timestamp
  final Map<String, DateTime?> lastReadAt;
  final Map<String, DateTime?> lastDeliveredAt;

  // Muted by list
  final List<String> mutedBy;

  const ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = const {},
    this.lastReadAt = const {},
    this.lastDeliveredAt = const {},
    this.mutedBy = const [],
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    // Parse lastReadAt map
    final rawLastRead = map['lastReadAt'] as Map<String, dynamic>?;
    final lastReadAt = <String, DateTime?>{};
    rawLastRead?.forEach((k, v) {
      lastReadAt[k] = (v as Timestamp?)?.toDate();
    });

    // Parse lastDeliveredAt map
    final rawLastDelivered = map['lastDeliveredAt'] as Map<String, dynamic>?;
    final lastDeliveredAt = <String, DateTime?>{};
    rawLastDelivered?.forEach((k, v) {
      lastDeliveredAt[k] = (v as Timestamp?)?.toDate();
    });

    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] as List),
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(
        (map['unreadCount'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ?? {},
      ),
      lastReadAt: lastReadAt,
      lastDeliveredAt: lastDeliveredAt,
      mutedBy: List<String>.from(map['mutedBy'] as List? ?? []),
    );
  }

  static String chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  bool isMutedBy(String uid) => mutedBy.contains(uid);
}
