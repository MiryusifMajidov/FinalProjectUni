import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameChatMessage {
  final String id;
  final String senderUid;
  final String senderUsername;
  final String text;
  final DateTime createdAt;
  final bool isQuick;

  const GameChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderUsername,
    required this.text,
    required this.createdAt,
    this.isQuick = false,
  });

  factory GameChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return GameChatMessage(
      id: id,
      senderUid: map['senderUid'] as String,
      senderUsername: map['senderUsername'] as String? ?? '',
      text: map['text'] as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isQuick: (map['isQuick'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    'senderUsername': senderUsername,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
    'isQuick': isQuick,
  };
}

class GameChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _chat(String gameId) =>
      _db.collection('games').doc(gameId).collection('chat');

  Future<void> sendMessage({
    required String gameId,
    required String senderUid,
    required String senderUsername,
    required String text,
    bool isQuick = false,
  }) async {
    await _chat(gameId).add({
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isQuick': isQuick,
    });
  }

  Stream<List<GameChatMessage>> watchMessages(String gameId) {
    return _chat(gameId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GameChatMessage.fromMap(d.id, d.data()))
            .toList());
  }
}

final gameChatServiceProvider =
    Provider<GameChatService>((ref) => GameChatService());
