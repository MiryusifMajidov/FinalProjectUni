import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> log({
    required String uid,
    required String username,
    required String type,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _db.collection('logs').add({
        'uid': uid,
        'username': username,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      debugPrint('[Log] Failed to write log: $e');
    }
  }
}

final logServiceProvider = Provider<LogService>((_) => LogService());
