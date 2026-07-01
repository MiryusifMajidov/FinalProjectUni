import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend_request_model.dart';

class FriendsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Incoming-request document for a (toUid, fromUid) pair.
  /// Path: friendRequests/{toUid}/received/{fromUid}
  ///
  /// This path matches what the Cloud Function `sendFriendRequestNotification`
  /// listens on, so writing here triggers the FCM push automatically.
  DocumentReference<Map<String, dynamic>> _received(
          String toUid, String fromUid) =>
      _db
          .collection('friendRequests')
          .doc(toUid)
          .collection('received')
          .doc(fromUid);

  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  /// Send a friend request. Throws if request already exists or already friends.
  Future<void> sendRequest({
    required String fromUid,
    required String fromUsername,
    required String toUid,
  }) async {
    // Already friends check
    final friendDoc = await _friends(fromUid).doc(toUid).get();
    if (friendDoc.exists) throw Exception('Already friends.');

    // Duplicate request check — path is unique per (from, to) pair
    final existing = await _received(toUid, fromUid).get();
    if (existing.exists) throw Exception('Request already sent.');

    await _received(toUid, fromUid).set({
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept a friend request. Adds both users to each other's friends subcollection.
  Future<void> acceptRequest({
    required String fromUid,
    required String fromUsername,
    required int fromRating,
    required String toUid,
    required String toUsername,
    required int toRating,
    String? fromAvatarId,
    String? fromPhotoUrl,
    String? toAvatarId,
    String? toPhotoUrl,
  }) async {
    final batch = _db.batch();

    // Mark request as accepted
    batch.update(_received(toUid, fromUid), {'status': 'accepted'});

    // Add to both friends subcollections
    final now = Timestamp.now();
    batch.set(_friends(fromUid).doc(toUid), {
      'uid': toUid,
      'username': toUsername,
      if (toAvatarId != null) 'avatarId': toAvatarId,
      if (toPhotoUrl != null) 'photoUrl': toPhotoUrl,
      'rating': toRating,
      'since': now,
    });
    batch.set(_friends(toUid).doc(fromUid), {
      'uid': fromUid,
      'username': fromUsername,
      if (fromAvatarId != null) 'avatarId': fromAvatarId,
      if (fromPhotoUrl != null) 'photoUrl': fromPhotoUrl,
      'rating': fromRating,
      'since': now,
    });

    await batch.commit();
  }

  /// Decline a friend request.
  Future<void> declineRequest(String toUid, String fromUid) =>
      _received(toUid, fromUid).update({'status': 'declined'});

  /// Remove a friend (both sides).
  Future<void> removeFriend(String myUid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_friends(myUid).doc(friendUid));
    batch.delete(_friends(friendUid).doc(myUid));
    await batch.commit();
  }

  /// Stream of incoming pending requests for [uid].
  Stream<List<FriendRequestModel>> watchIncomingRequests(String uid) {
    return _db
        .collection('friendRequests')
        .doc(uid)
        .collection('received')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendRequestModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Stream of friends list for a user.
  Stream<List<FriendModel>> watchFriends(String uid) {
    return _friends(uid).snapshots().map((snap) =>
        snap.docs.map((d) => FriendModel.fromMap(d.data())).toList());
  }

  /// Get friends list once.
  Future<List<FriendModel>> getFriends(String uid) async {
    final snap = await _friends(uid).get();
    return snap.docs.map((d) => FriendModel.fromMap(d.data())).toList();
  }

  /// Check if two users are friends.
  Future<bool> areFriends(String myUid, String otherUid) async {
    final doc = await _friends(myUid).doc(otherUid).get();
    return doc.exists;
  }
}

final friendsServiceProvider =
    Provider<FriendsService>((ref) => FriendsService());
