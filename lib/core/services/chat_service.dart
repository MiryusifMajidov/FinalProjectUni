import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Shown in place of a deleted message's text — UI-neutral marker.
  static const String deletedMarker = '🗑 This message was deleted';

  /// Maximum allowed message length in characters.
  static const int maxMessageLength = 2000;

  /// Tracks in-flight send calls to prevent duplicate messages on rapid taps.
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _chats.doc(chatId).collection('messages');

  /// Send a message. Creates the chat document if it doesn't exist.
  /// Accepts optional reply parameters.
  Future<void> sendMessage({
    required String myUid,
    required String otherUid,
    required String text,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    // ── Input validation ───────────────────────────────────────────────────
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw Exception('Message cannot be empty.');
    if (trimmed.length > maxMessageLength) {
      throw Exception('Message is too long (max $maxMessageLength characters).');
    }

    // ── Duplicate-send guard ───────────────────────────────────────────────
    // Throw instead of silently returning: the caller's catch block will show
    // a snackbar and restore the input text so the message is not lost.
    if (_sending) throw Exception('Please wait — your previous message is still sending.');
    _sending = true;
    try {
    // Check target user's messagePrivacy
    final targetDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    if (targetDoc.exists) {
      final privacy =
          targetDoc.data()?['messagePrivacy'] as String? ?? 'everyone';
      if (privacy == 'nobody') {
        throw Exception('This user is not accepting messages.');
      }
      if (privacy == 'friends') {
        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUid)
            .collection('friends')
            .doc(myUid)
            .get();
        if (!friendDoc.exists) {
          throw Exception('This user only accepts messages from friends.');
        }
      }
    }

    final chatId = ChatModel.chatId(myUid, otherUid);
    final chatRef = _chats.doc(chatId);

    final batch = _db.batch();

    // Upsert chat metadata.
    // SetOptions.mergeFields with FieldPath is used so that the nested
    // unreadCount field is written as a proper path (not a literal dot-key).
    batch.set(
      chatRef,
      {
        'participants': [myUid, otherUid],
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {otherUid: FieldValue.increment(1)},
      },
      SetOptions(mergeFields: [
        'participants',
        'lastMessage',
        'lastMessageAt',
        FieldPath(['unreadCount', otherUid]),
      ]),
    );

    // Add message
    final msgRef = _messages(chatId).doc();
    final msgData = <String, dynamic>{
      'senderUid': myUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };
    if (replyToId != null) msgData['replyToId'] = replyToId;
    if (replyToText != null) msgData['replyToText'] = replyToText;
    if (replyToSenderName != null) {
      msgData['replyToSenderName'] = replyToSenderName;
    }
    batch.set(msgRef, msgData);

    await batch.commit();
    } finally {
      _sending = false;
    }
  }

  /// Mark all messages in a chat as read for a user.
  /// Also updates lastReadAt timestamp.
  Future<void> markAsRead(String chatId, String myUid) async {
    await _chats.doc(chatId).update({
      'unreadCount.$myUid': 0,
      'lastReadAt.$myUid': FieldValue.serverTimestamp(),
    });
  }

  /// Mark that messages have been delivered to [myUid].
  Future<void> markDelivered(String chatId, String myUid) async {
    await _chats.doc(chatId).update({
      'lastDeliveredAt.$myUid': FieldValue.serverTimestamp(),
    });
  }

  /// Mute this chat for [myUid] — adds uid to mutedBy array.
  Future<void> muteChat(String chatId, String myUid) async {
    await _chats.doc(chatId).set(
      {
        'mutedBy': FieldValue.arrayUnion([myUid]),
      },
      SetOptions(merge: true),
    );
  }

  /// Unmute this chat for [myUid] — removes uid from mutedBy array.
  Future<void> unmuteChat(String chatId, String myUid) async {
    await _chats.doc(chatId).set(
      {
        'mutedBy': FieldValue.arrayRemove([myUid]),
      },
      SetOptions(merge: true),
    );
  }

  /// Stream of whether [myUid] has muted this chat.
  Stream<bool> watchMuted(String chatId, String myUid) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final mutedBy = doc.data()?['mutedBy'] as List<dynamic>?;
      return mutedBy?.contains(myUid) ?? false;
    });
  }

  /// Stream of the 30 most-recent messages, ordered newest first.
  /// Combine with [fetchOlderMessages] to implement infinite scroll.
  Stream<List<ChatMessageModel>> watchMessages(String chatId) {
    return _messages(chatId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessageModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Cursor-based fetch for messages older than [before].
  /// Returns up to [limit] messages ordered newest-first (for easy prepending).
  /// Pass the [createdAt] of the oldest already-loaded message as [before].
  Future<List<ChatMessageModel>> fetchOlderMessages(
    String chatId, {
    required DateTime before,
    int limit = 30,
  }) async {
    final snap = await _messages(chatId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => ChatMessageModel.fromMap(d.id, d.data()))
        .toList();
  }

  /// Stream of chat list for a user (sorted by most recent message).
  /// Limited to 50 most recent chats to avoid memory bloat.
  ///
  /// NOTE: No server-side orderBy — that would require a composite index
  /// (participants array-contains + lastMessageAt desc) which may not exist.
  /// We sort client-side instead; the single-field array index is automatic.
  Stream<List<ChatModel>> watchChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .limit(50)
        .snapshots()
        .map((snap) {
          final chats = snap.docs
              .map((d) => ChatModel.fromMap(d.id, d.data()))
              .toList();
          // Sort newest-first on the client so no composite index is needed.
          chats.sort((a, b) {
            if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
            if (a.lastMessageAt == null) return 1;
            if (b.lastMessageAt == null) return -1;
            return b.lastMessageAt!.compareTo(a.lastMessageAt!);
          });
          return chats;
        });
  }

  /// Get unread count for a user across all chats.
  Stream<int> watchTotalUnread(String uid) {
    return _chats.where('participants', arrayContains: uid).snapshots().map(
      (snap) {
        int total = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final unread = data['unreadCount'] as Map<String, dynamic>?;
          total += (unread?[uid] as num?)?.toInt() ?? 0;
        }
        return total;
      },
    );
  }

  /// Set typing status for a user in a chat.
  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    await _chats.doc(chatId).set(
      {'typing.$uid': isTyping},
      SetOptions(merge: true),
    );
  }

  /// Watch whether [otherUid] is currently typing in [chatId].
  Stream<bool> watchTyping(String chatId, String otherUid) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final typing = doc.data()?['typing'] as Map<String, dynamic>?;
      return (typing?[otherUid] as bool?) ?? false;
    });
  }

  /// Watch chat metadata (for read receipts, delivery status, mute, etc.)
  Stream<ChatModel?> watchChatMeta(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Delete a single message (sets text to deleted marker).
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _messages(chatId).doc(messageId).update({
      'text': deletedMarker,
      'deleted': true,
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());
