import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_model.dart';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _groups.doc(groupId).collection('messages');

  Future<String> createGroup({
    required String name,
    String? description,
    String avatarEmoji = '\u265b',
    required GroupPrivacy privacy,
    required String adminId,
    required String adminUsername,
  }) async {
    final ref = _groups.doc();
    await ref.set({
      'name': name,
      if (description != null) 'description': description,
      'avatarEmoji': avatarEmoji,
      'privacy': privacy.name,
      'adminId': adminId,
      'adminUsername': adminUsername,
      'adminIds': [adminId],
      'memberIds': [adminId],
      'createdAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
      'whoCanSend': 'everyone',
      'mutedBy': [],
      'lastMessage': null,
    });
    return ref.id;
  }

  Future<void> joinGroup(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> leaveGroup(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'adminIds': FieldValue.arrayRemove([uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Future<void> sendMessage({
    required String groupId,
    required String senderUid,
    required String senderUsername,
    required String text,
    required List<String> memberIds,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final batch = _db.batch();

    final msgRef = _messages(groupId).doc();
    final msgData = <String, dynamic>{
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (replyToId != null) msgData['replyToId'] = replyToId;
    if (replyToText != null) msgData['replyToText'] = replyToText;
    if (replyToSenderName != null) {
      msgData['replyToSenderName'] = replyToSenderName;
    }
    batch.set(msgRef, msgData);

    // Increment unread count for every member except the sender
    final groupUpdate = <String, dynamic>{
      'lastMessage': text.length > 80 ? '${text.substring(0, 80)}…' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    };
    for (final uid in memberIds) {
      if (uid != senderUid) {
        groupUpdate['unreadCounts.$uid'] = FieldValue.increment(1);
      }
    }
    batch.update(_groups.doc(groupId), groupUpdate);

    await batch.commit();
  }

  /// Resets the unread counter and records read timestamp for [uid].
  Future<void> markGroupRead(String groupId, String uid) =>
      _groups.doc(groupId).update({
        'unreadCounts.$uid': 0,
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
      });

  /// Watch a single group document as a live stream.
  Stream<GroupModel?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GroupModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<GroupModel>> watchPublicGroups() {
    return _groups
        .where('privacy', isEqualTo: 'public')
        .orderBy('memberCount', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => GroupModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<GroupModel>> watchMyGroups(String uid) {
    return _groups
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((s) {
          final groups =
              s.docs.map((d) => GroupModel.fromMap(d.id, d.data())).toList();
          groups.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
              .compareTo(a.lastMessageAt ?? DateTime(0)));
          return groups;
        });
  }

  Stream<List<GroupMessage>> watchMessages(String groupId) {
    return _messages(groupId)
        .orderBy('createdAt', descending: true) // newest first so limit(200) keeps the latest
        .limit(200)
        .snapshots()
        .map((s) {
          // Reverse so the ListView receives messages in chronological order
          final msgs = s.docs.map((d) => GroupMessage.fromMap(d.id, d.data())).toList();
          return msgs.reversed.toList();
        });
  }

  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromMap(doc.id, doc.data()!);
  }

  /// Update the group's photo URL (any member can do this).
  Future<void> updateGroupPhoto(String groupId, String photoUrl) async {
    await _groups.doc(groupId).update({'photoUrl': photoUrl});
  }

  /// Update group info fields (name, avatarEmoji, description).
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? avatarEmoji,
    String? description,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarEmoji != null) updates['avatarEmoji'] = avatarEmoji;
    if (description != null) updates['description'] = description;
    if (updates.isEmpty) return;
    await _groups.doc(groupId).update(updates);
  }

  /// Add [uid] to the adminIds array.
  Future<void> addAdmin(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([uid]),
    });
  }

  /// Remove [uid] from the adminIds array.
  Future<void> removeAdmin(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'adminIds': FieldValue.arrayRemove([uid]),
    });
  }

  /// Set who can send messages: 'everyone' or 'admins'.
  Future<void> setWhoCanSend(String groupId, String who) async {
    await _groups.doc(groupId).update({'whoCanSend': who});
  }

  /// Remove a member from the group (and from adminIds if applicable).
  Future<void> removeMember(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'adminIds': FieldValue.arrayRemove([uid]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  /// Add a member to the group.
  Future<void> addMember(String groupId, String uid) async {
    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
      'memberCount': FieldValue.increment(1),
    });
  }

  /// Delete the group document and its messages subcollection.
  /// Firestore does not cascade-delete subcollections, so we batch-delete them
  /// manually in chunks of 500 before removing the group document.
  Future<void> deleteGroup(String groupId) async {
    const batchSize = 500;
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await _messages(groupId).limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);

    await _groups.doc(groupId).delete();
  }

  /// Mute the group for [myUid].
  Future<void> muteGroup(String groupId, String myUid) async {
    await _groups.doc(groupId).update({
      'mutedBy': FieldValue.arrayUnion([myUid]),
    });
  }

  /// Unmute the group for [myUid].
  Future<void> unmuteGroup(String groupId, String myUid) async {
    await _groups.doc(groupId).update({
      'mutedBy': FieldValue.arrayRemove([myUid]),
    });
  }
}

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());
