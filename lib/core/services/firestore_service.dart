import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/game_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  // User operations
  Future<bool> usernameExists(String username) async {
    final doc = await _usernames.doc(username.toLowerCase()).get();
    return doc.exists;
  }

  Future<void> createUser(UserModel user) async {
    final batch = _db.batch();
    batch.set(_users.doc(user.uid), user.toMap());
    batch.set(_usernames.doc(user.username.toLowerCase()), {'uid': user.uid});
    await batch.commit();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final usernameDoc =
        await _usernames.doc(username.toLowerCase()).get();
    if (!usernameDoc.exists) return null;
    final uid = usernameDoc.data()!['uid'] as String;
    return getUser(uid);
  }

  /// Prefix-search for users whose lowercase username starts with [query].
  /// Pass [excludeUid] to remove the current user from results.
  /// Returns up to 8 results. Minimum 2 chars required.
  Future<List<UserModel>> searchUsers(String query,
      {String? excludeUid}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    final snap = await _usernames
        .orderBy(FieldPath.documentId)
        .startAt([q])
        .endAt(['$q\uf8ff'])
        .limit(10) // fetch a few extra in case we filter some out
        .get();

    if (snap.docs.isEmpty) return [];

    // Batch fetch: one whereIn query instead of N individual getUser() calls.
    final uids = snap.docs
        .map((d) => d.data()['uid'] as String? ?? '')
        .where((uid) => uid.isNotEmpty && uid != excludeUid)
        .toSet()
        .take(10)
        .toList();
    if (uids.isEmpty) return [];

    final usersSnap = await _users.where(FieldPath.documentId, whereIn: uids).get();
    return usersSnap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .take(8)
        .toList();
  }

  /// Returns up to [limit] users with blitz rating close to [myRating],
  /// excluding [excludeUids]. Used for Friend Suggestions.
  Future<List<UserModel>> getSuggestedFriends({
    required int myRating,
    required List<String> excludeUids,
    int limit = 5,
  }) async {
    final low = (myRating - 300).clamp(0, 3000);
    final high = (myRating + 300).clamp(0, 3000);
    try {
      final snap = await _users
          .where('blitzStats.rating', isGreaterThanOrEqualTo: low)
          .where('blitzStats.rating', isLessThanOrEqualTo: high)
          .limit(limit + excludeUids.length + 1)
          .get();
      return snap.docs
          .map((d) => UserModel.fromMap(d.data()))
          .where((u) => !excludeUids.contains(u.uid))
          .take(limit)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── FCM token ──────────────────────────────────────────────────────────────

  /// Save or refresh the FCM device token for [uid].
  Future<void> saveFcmToken(String uid, String token) =>
      _users.doc(uid).update({'fcmToken': token});

  /// Remove the FCM token for [uid] so Cloud Functions stop targeting this
  /// device (used when the user turns off push notifications).
  Future<void> removeFcmToken(String uid) =>
      _users.doc(uid).update({'fcmToken': FieldValue.delete()});

  // ── Cloud Function triggers ────────────────────────────────────────────────

  /// Write a game-invite document that triggers the
  /// `sendGameInviteNotification` Cloud Function.
  ///
  /// Path: gameInvites/{toUid}/pending/{auto-id}
  Future<void> createGameInviteNotification({
    required String toUid,
    required String fromUid,
    required String fromUsername,
    required String timeControlLabel,
    required bool isWhite,
    String? gameType,
  }) =>
      _db
          .collection('gameInvites')
          .doc(toUid)
          .collection('pending')
          .add({
            'fromUid': fromUid,
            'fromUsername': fromUsername,
            'timeControlLabel': timeControlLabel,
            'isWhite': isWhite,
            'gameType': gameType ?? 'chess',
            'sentAt': FieldValue.serverTimestamp(),
          });

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _users.doc(uid).update(data);

  Future<void> updateRatingStats(
    String uid, {
    required TimeControlCategory category,
    required RatingStats stats,
  }) {
    final field = switch (category) {
      TimeControlCategory.bullet => 'bulletStats',
      TimeControlCategory.blitz => 'blitzStats',
      TimeControlCategory.rapid => 'rapidStats',
    };
    return _users.doc(uid).update({field: stats.toMap()});
  }

  Future<void> updateCampaignProgress(String uid, int progress, {String gameType = 'chess'}) {
    final field = switch (gameType) {
      'checkers' => 'checkersCampaignProgress',
      'domino'   => 'dominoCampaignProgress',
      _          => 'campaignProgress',
    };
    return _users.doc(uid).update({field: progress});
  }

  /// Ensures checkersStats and dominoStats fields exist in Firestore.
  /// Call once per user session so legacy accounts are patchable.
  Future<void> ensureGameFields(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      final updates = <String, dynamic>{};
      if (data['checkersStats'] == null) {
        updates['checkersStats'] = const RatingStats(rating: 300).toMap();
      }
      if (data['dominoStats'] == null) {
        updates['dominoStats'] = const RatingStats(rating: 300).toMap();
      }
      if (data['checkersCampaignProgress'] == null) {
        updates['checkersCampaignProgress'] = 0;
      }
      if (data['dominoCampaignProgress'] == null) {
        updates['dominoCampaignProgress'] = 0;
      }
      if (updates.isNotEmpty) {
        await _users.doc(uid).update(updates);
      }
    }
  }

  // Game operations
  Future<void> saveGame(GameModel game) =>
      _games.doc(game.id).set(game.toMap(), SetOptions(merge: true));

  Future<GameModel?> getGame(String id) async {
    final doc = await _games.doc(id).get();
    if (!doc.exists) return null;
    return GameModel.fromMap(doc.data()!);
  }

  Future<List<GameModel>> getRecentGames(String uid, {int limit = 10}) async {
    // Run both queries in parallel instead of sequentially.
    // orderBy is essential: without it Firestore returns the first N docs by
    // document ID (random UUIDs), so once a player has more than N games the
    // NEWEST games never make it into the result — the profile chart and
    // recent list silently freeze. Requires the whiteUid+createdAt /
    // blackUid+createdAt composite indexes (firestore.indexes.json).
    final futures = await Future.wait([
      _games
          .where('whiteUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()
          .catchError((_) => _games.limit(0).get()),
      _games
          .where('blackUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()
          .catchError((_) => _games.limit(0).get()),
    ]);

    final results = <String, GameModel>{};
    for (final snap in futures) {
      for (final doc in snap.docs) {
        final g = GameModel.fromMap(doc.data());
        results[g.id] = g;
      }
    }

    final sorted = results.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  Future<void> addRecentGameId(String uid, String gameId) async {
    // Use a transaction so the add + trim is atomic.
    // The old two-step approach (arrayUnion then read-modify-write) had a race:
    // concurrent calls could both read the pre-trim list and both write an
    // untrimmed version, defeating the 50-entry cap.
    final docRef = _users.doc(uid);
    await FirebaseFirestore.instance.runTransaction((t) async {
      final snap = await t.get(docRef);
      final ids = ((snap.data()?['recentGameIds'] as List<dynamic>?)
                  ?.cast<String>() ??
              [])
          .toList();
      if (!ids.contains(gameId)) ids.add(gameId);
      final trimmed = ids.length > 50 ? ids.sublist(ids.length - 50) : ids;
      t.update(docRef, {'recentGameIds': trimmed});
    });
  }

  // ── Player Map ──────────────────────────────────────────────────────────────

  /// Returns all users who have opted in to appear on the map.
  Future<List<UserModel>> getMapUsers() async {
    final snap =
        await _users.where('showOnMap', isEqualTo: true).get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .toList();
  }

  /// Live stream of users opted in to the map — capped at 300 to avoid OOM.
  Stream<List<UserModel>> watchMapUsers() {
    return _users
        .where('showOnMap', isEqualTo: true)
        .limit(300)
        .snapshots()
        .map((s) => s.docs.map((d) => UserModel.fromMap(d.data())).toList());
  }

  /// Updates only coordinates + lastSeen — does NOT change showOnMap flag.
  Future<void> updateLocationOnly(String uid, double lat, double lng) =>
      _users.doc(uid).update({
        'latitude': lat,
        'longitude': lng,
        'lastSeen': FieldValue.serverTimestamp(),
      });

  /// Updates the user's map location and opt-in flag.
  Future<void> updateMapSettings(
    String uid, {
    required bool showOnMap,
    double? latitude,
    double? longitude,
  }) =>
      _users.doc(uid).update({
        'showOnMap': showOnMap,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'lastSeen': FieldValue.serverTimestamp(),
      });

  /// Refreshes the user's `lastSeen` timestamp (called periodically).
  Future<void> updateLastSeen(String uid) =>
      _users.doc(uid).update({'lastSeen': FieldValue.serverTimestamp()});

  /// Updates the user's GPS coordinates and opts them into the map.
  Future<void> updateUserLocation(String uid, double lat, double lng) =>
      _users.doc(uid).update({
        'latitude': lat,
        'longitude': lng,
        'showOnMap': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

  /// Spectator: marks user as currently in a live game.
  Future<void> setCurrentGame(String uid, String gameId) =>
      _users.doc(uid).update({'currentGameId': gameId});

  /// Spectator: clears the current game marker when game ends.
  Future<void> clearCurrentGame(String uid) =>
      _users.doc(uid).update({'currentGameId': FieldValue.delete()});

  /// Updates the user's profile visibility ('Public' | 'Friends' | 'Private').
  Future<void> updateProfileVisibility(String uid, String visibility) =>
      _users.doc(uid).update({'profileVisibility': visibility});

  /// Saves user feedback or a bug report to the `feedback` collection.
  Future<void> saveFeedback({
    required String uid,
    required String username,
    required String email,
    required String text,
    required bool isBug,
    String? appVersion,
    String? deviceInfo,
  }) =>
      _db.collection('feedback').add({
        'uid': uid,
        'username': username,
        'email': email,
        'text': text,
        'isBug': isBug,
        'appVersion': appVersion,
        'deviceInfo': deviceInfo,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // ── Sessions ───────────────────────────────────────────────────────────────

  /// Save a login session for [uid]. Returns the new session document ID.
  Future<String> saveSession(String uid, Map<String, dynamic> data) async {
    final ref = await _db
        .collection('sessions')
        .doc(uid)
        .collection('devices')
        .add({
      ...data,
      'loginAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Stream of all active sessions for [uid].
  Stream<List<Map<String, dynamic>>> watchSessions(String uid) =>
      _db
          .collection('sessions')
          .doc(uid)
          .collection('devices')
          .orderBy('loginAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList());

  /// Delete a specific session document.
  Future<void> deleteSession(String uid, String sessionId) =>
      _db
          .collection('sessions')
          .doc(uid)
          .collection('devices')
          .doc(sessionId)
          .delete();

  /// Delete all sessions for [uid] except [exceptSessionId].
  Future<void> deleteOtherSessions(String uid, String exceptSessionId) async {
    final snap = await _db
        .collection('sessions')
        .doc(uid)
        .collection('devices')
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      if (doc.id != exceptSessionId) batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Update the lastActiveAt field for a session.
  Future<void> refreshSession(String uid, String sessionId) =>
      _db
          .collection('sessions')
          .doc(uid)
          .collection('devices')
          .doc(sessionId)
          .update({'lastActiveAt': FieldValue.serverTimestamp()});

  // ── Block / unblock ────────────────────────────────────────────────────────

  /// Add [targetUid] to the current user's blocked list.
  Future<void> blockUser(String uid, String targetUid) =>
      _users.doc(uid).update({
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
      });

  /// Remove [targetUid] from the current user's blocked list.
  Future<void> unblockUser(String uid, String targetUid) =>
      _users.doc(uid).update({
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      });

  // ── Privacy / security fields ──────────────────────────────────────────────

  Future<void> setTwoFactorEnabled(String uid, bool enabled) =>
      _users.doc(uid).update({'twoFactorEnabled': enabled});

  Future<void> setOnlineStatus(String uid, bool show) =>
      _users.doc(uid).update({'showOnlineStatus': show});

  Future<void> setInvisibleMode(String uid, bool invisible) =>
      _users.doc(uid).update({'invisibleMode': invisible});

  Future<void> setFriendRequestPrivacy(String uid, String value) =>
      _users.doc(uid).update({'friendRequestPrivacy': value});

  Future<void> setChallengePrivacy(String uid, String value) =>
      _users.doc(uid).update({'challengePrivacy': value});

  Future<void> setMessagePrivacy(String uid, String value) =>
      _users.doc(uid).update({'messagePrivacy': value});

  // ── Notification prefs (synced so Cloud Functions can read them) ──────────

  Future<void> setNotificationPrefs(String uid, Map<String, bool> prefs) =>
      _users.doc(uid).update(prefs.map((k, v) => MapEntry(k, v)));

}
