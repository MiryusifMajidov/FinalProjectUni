import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles live game sync via Firebase Realtime Database.
class RealtimeGameService {
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://chess-ac4eb-default-rtdb.firebaseio.com/',
  );

  DatabaseReference _gameRef(String gameId) =>
      _db.ref('live_games/$gameId');

  /// Write an entire game state snapshot.
  Future<void> writeGameState(String gameId, Map<String, dynamic> state) =>
      _gameRef(gameId).set(state);

  /// Push a move to the moves list.
  Future<void> pushMove(String gameId, Map<String, dynamic> move) =>
      _gameRef(gameId).child('moves').push().set(move);

  /// Update clock values.
  Future<void> updateClocks(
      String gameId, int whiteMsLeft, int blackMsLeft) =>
      _gameRef(gameId).child('clocks').set({
        'white': whiteMsLeft,
        'black': blackMsLeft,
        'updatedAt': ServerValue.timestamp,
      });

  /// Set game result.
  Future<void> setResult(String gameId, String result) =>
      _gameRef(gameId).child('result').set(result);

  /// Create a live game shell (used for rematch).
  Future<void> createLiveGame({
    required String gameId,
    required String whiteUid,
    required String blackUid,
    required String timeControlLabel,
  }) =>
      _db.ref('live_games/$gameId').set({
        'whiteUid': whiteUid,
        'blackUid': blackUid,
        'timeControl': timeControlLabel,
        'status': 'active',
        'createdAt': ServerValue.timestamp,
      });

  /// Watch game state stream.
  Stream<DatabaseEvent> watchGame(String gameId) =>
      _gameRef(gameId).onValue;

  /// Watch moves only.
  Stream<DatabaseEvent> watchMoves(String gameId) =>
      _gameRef(gameId).child('moves').onChildAdded;

  // ── Indexed action log (checkers / domino) ─────────────────────────────────
  // Actions are written at `actions/<index>` with a monotonically increasing
  // integer index. Every client applies them strictly in index order, which
  // makes the log replayable (resume after restart) and immune to push-key
  // clock skew. Turn-based games guarantee a single writer per index.

  Stream<DatabaseEvent> watchActions(String gameId) =>
      _gameRef(gameId).child('actions').onChildAdded;

  /// One-shot read of the whole action log (resume support).
  /// Returns actions sorted by integer index.
  Future<List<Map<String, dynamic>>> getActions(String gameId) async {
    final snap = await _gameRef(gameId).child('actions').get();
    if (!snap.exists || snap.value == null) return const [];
    final raw = snap.value;
    final entries = <int, Map<String, dynamic>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && v is Map) {
          entries[i] = Map<String, dynamic>.from(v);
        }
      });
    } else if (raw is List) {
      // RTDB collapses dense integer keys into a list.
      for (int i = 0; i < raw.length; i++) {
        final v = raw[i];
        if (v is Map) entries[i] = Map<String, dynamic>.from(v);
      }
    }
    final keys = entries.keys.toList()..sort();
    return [for (final k in keys) entries[k]!];
  }

  /// Write an action at a fixed index (single writer per index by protocol).
  Future<void> setAction(String gameId, int index, Map<String, dynamic> data) =>
      _gameRef(gameId).child('actions/$index').set(data);

  /// Write an action only if the slot is still empty. Used by the acting
  /// host for bot moves so a host hand-over can never double-write.
  Future<bool> setActionIfAbsent(
      String gameId, int index, Map<String, dynamic> data) async {
    final result = await _gameRef(gameId)
        .child('actions/$index')
        .runTransaction((current) {
      if (current != null) return Transaction.abort();
      return Transaction.success(data);
    });
    return result.committed;
  }

  // ── Multiplayer room (4-player domino) ─────────────────────────────────────

  /// Create the shared room document with seat assignments + game config.
  Future<void> createGameRoom(String gameId, Map<String, dynamic> data) =>
      _gameRef(gameId).set(data);

  /// Partial room update (e.g. the host flipping status waiting → active,
  /// or replacing absent seats with AI stand-ins).
  Future<void> updateGameRoom(String gameId, Map<String, dynamic> data) =>
      _gameRef(gameId).update(data);

  /// One-shot read of the room (seats / config).
  Future<Map<String, dynamic>?> getGameInfo(String gameId) async {
    final snap = await _gameRef(gameId).get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Stream<DatabaseEvent> watchGameInfo(String gameId) =>
      _gameRef(gameId).onValue;

  /// Mark a seat as resigned/abandoned — the seat is taken over by an
  /// AI-controlled stand-in on every client. Idempotent flag node.
  Future<void> setSeatResigned(String gameId, int seat) =>
      _gameRef(gameId).child('resigned/$seat').set(true);

  Stream<DatabaseEvent> watchResignedSeats(String gameId) =>
      _gameRef(gameId).child('resigned').onValue;

  /// Write game-over result so both players see the same ending.
  Future<void> setGameOver(String gameId, String result, String status) =>
      _gameRef(gameId).child('gameOver').set({
        'result': result,
        'status': status,
      });

  /// Watch for a game-over signal written by either player.
  Stream<DatabaseEvent> watchGameOver(String gameId) =>
      _gameRef(gameId).child('gameOver').onValue;

  /// One-shot read of the game-over node.
  /// Returns the result/status map if it was already written (e.g. while this
  /// player was offline), null if the game is still in progress.
  Future<Map<String, dynamic>?> getGameOver(String gameId) async {
    final snap = await _gameRef(gameId).child('gameOver').get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  // ── Draw offer ─────────────────────────────────────────────────────────────

  /// Write a draw offer from [fromUid].
  Future<void> sendDrawOffer(String gameId, String fromUid) =>
      _gameRef(gameId).child('drawOffer').set({
        'fromUid': fromUid,
        'sentAt': ServerValue.timestamp,
      });

  /// Watch the draw-offer node; fires whenever it is set or cleared.
  Stream<DatabaseEvent> watchDrawOffer(String gameId) =>
      _gameRef(gameId).child('drawOffer').onValue;

  /// Remove the draw offer (after accept or decline).
  Future<void> clearDrawOffer(String gameId) =>
      _gameRef(gameId).child('drawOffer').remove();

  /// Clean up after game ends.
  Future<void> deleteGame(String gameId) => _gameRef(gameId).remove();

  // ── Presence ───────────────────────────────────────────────────────────────

  DatabaseReference _presenceRef(String gameId, String uid) =>
      _gameRef(gameId).child('presence/$uid');

  /// Mark [uid] as online in this game.
  /// Also registers an `onDisconnect` handler so Firebase automatically
  /// marks the player offline if they lose connection or close the app.
  Future<void> goOnline(String gameId, String uid) async {
    final ref = _presenceRef(gameId, uid);
    // Register disconnect handler BEFORE writing online:true
    await ref.onDisconnect().update({
      'online': false,
      'disconnectedAt': ServerValue.timestamp,
    });
    await ref.update({
      'online': true,
      'disconnectedAt': null,
    });
  }

  /// Mark [uid] as offline (called on clean app exit / resign / game end).
  Future<void> goOffline(String gameId, String uid) =>
      _presenceRef(gameId, uid).update({
        'online': false,
        'disconnectedAt': ServerValue.timestamp,
      });

  /// Cancel the onDisconnect handler (call when game ends cleanly so the
  /// handler doesn't fire and confuse the next session).
  Future<void> cancelDisconnectHandler(String gameId, String uid) =>
      _presenceRef(gameId, uid).onDisconnect().cancel();

  /// Stream of the opponent's presence node.
  Stream<DatabaseEvent> watchPresence(String gameId, String uid) =>
      _presenceRef(gameId, uid).onValue;

  // Matchmaking queue
  DatabaseReference get _matchmakingRef => _db.ref('matchmaking');

  Future<void> joinQueue(String uid, int rating, String timeControlLabel,
          {String? gameType, String? username}) =>
      _matchmakingRef.child(uid).set({
        'uid': uid,
        'rating': rating,
        'timeControl': timeControlLabel,
        'gameType': gameType ?? 'chess',
        if (username != null) 'username': username,
        'joinedAt': ServerValue.timestamp,
        'gameId': null,
      });

  Future<void> leaveQueue(String uid) =>
      _matchmakingRef.child(uid).remove();

  /// Watch the whole queue filtered by time control (live updates).
  Stream<DatabaseEvent> watchQueue(String timeControlLabel) => _db
      .ref('matchmaking')
      .orderByChild('timeControl')
      .equalTo(timeControlLabel)
      .onValue;

  /// Watch a single player's queue entry so they can detect when matched.
  Stream<DatabaseEvent> watchQueueEntry(String uid) =>
      _matchmakingRef.child(uid).onValue;

  /// Atomically claim [opponentUid] as a match partner.
  ///
  /// - Runs a RTDB transaction on the opponent's queue entry.
  /// - If not yet matched, stamps both entries with [gameId] and creates the
  ///   live-game shell in `/live_games/{gameId}`.
  /// - Returns `true` if the claim succeeded, `false` on conflict/not found.
  Future<bool> tryClaimMatch({
    required String myUid,
    required String opponentUid,
    required String gameId,
    required String timeControlLabel,
  }) async {
    final opponentRef = _matchmakingRef.child(opponentUid);

    final result = await opponentRef.runTransaction((currentData) {
      if (currentData == null) return Transaction.abort();
      final map = Map<String, dynamic>.from(currentData as Map);
      // If opponent already has a gameId, someone else claimed them first.
      if (map['gameId'] != null) return Transaction.abort();

      return Transaction.success({
        ...map,
        'gameId': gameId,
        'opponentUid': myUid,
        'isWhite': false, // opponent plays black
      });
    });

    if (!result.committed) return false;

    // Stamp my own entry (best-effort — I created the game so I don't need it
    // to be atomic, but it lets my own watcher see the match too).
    await _matchmakingRef.child(myUid).update({
      'gameId': gameId,
      'opponentUid': opponentUid,
      'isWhite': true,
    });

    // Create the live-game shell that both clients will load.
    await _db.ref('live_games/$gameId').set({
      'whiteUid': myUid,
      'blackUid': opponentUid,
      'timeControl': timeControlLabel,
      'status': 'active',
      'createdAt': ServerValue.timestamp,
    });

    return true;
  }

  /// Atomically claim [opponentUid] for a specific seat in a multi-seat game
  /// (4-player domino). Unlike [tryClaimMatch] this does NOT create the
  /// live-game shell — the host writes the room once all claims are done.
  ///
  /// Returns the opponent's queue entry data on success (username, rating),
  /// or null when someone else claimed them first.
  Future<Map<String, dynamic>?> tryClaimSeat({
    required String myUid,
    required String opponentUid,
    required String gameId,
    required int seat,
  }) async {
    final opponentRef = _matchmakingRef.child(opponentUid);
    Map<String, dynamic>? claimedData;

    final result = await opponentRef.runTransaction((currentData) {
      if (currentData == null) return Transaction.abort();
      final map = Map<String, dynamic>.from(currentData as Map);
      if (map['gameId'] != null) return Transaction.abort();
      claimedData = map;
      return Transaction.success({
        ...map,
        'gameId': gameId,
        'opponentUid': myUid,
        'seat': seat,
      });
    });

    if (!result.committed) return null;
    return claimedData;
  }

  /// Stamp my own queue entry with the room I just created (host side).
  Future<void> stampOwnQueueEntry(
          String uid, String gameId, int seat) =>
      _matchmakingRef.child(uid).update({
        'gameId': gameId,
        'seat': seat,
      });

  // ── Rematch ────────────────────────────────────────────────────────────────

  DatabaseReference _rematchRef(String originalGameId) =>
      _db.ref('rematch/$originalGameId');

  /// Sender writes the rematch invite + creates the new live game shell.
  Future<void> sendRematchInvite({
    required String originalGameId,
    required String newGameId,
    required String fromUid,
    required String whiteUidInNew,
    required String blackUidInNew,
    required String timeControlLabel,
  }) async {
    await createLiveGame(
      gameId: newGameId,
      whiteUid: whiteUidInNew,
      blackUid: blackUidInNew,
      timeControlLabel: timeControlLabel,
    );
    await _rematchRef(originalGameId).set({
      'requestedBy': fromUid,
      'newGameId': newGameId,
      'status': 'pending',
    });
  }

  Future<void> acceptRematch(String originalGameId) =>
      _rematchRef(originalGameId).update({'status': 'accepted'});

  Future<void> declineRematch(String originalGameId) =>
      _rematchRef(originalGameId).update({'status': 'declined'});

  Stream<DatabaseEvent> watchRematch(String originalGameId) =>
      _rematchRef(originalGameId).onValue;

  Future<void> cleanupRematch(String originalGameId) =>
      _rematchRef(originalGameId).remove();

  // Invites
  DatabaseReference _inviteRef(String uid) =>
      _db.ref('invites/$uid');

  /// Sends a game invite and returns the auto-generated RTDB push key.
  /// The inviter uses this key to watch for the recipient's response.
  /// [options] carries per-game rule settings (checkers variant, domino
  /// ruleset/target) so both clients start with identical configurations.
  Future<String> sendInvite({
    required String fromUid,
    required String fromUsername,
    required String toUid,
    required String timeControlLabel,
    required bool isWhite,
    String? gameType,
    Map<String, dynamic>? options,
  }) async {
    final newRef = _inviteRef(toUid).push();
    await newRef.set({
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'timeControlLabel': timeControlLabel,
      'isWhite': isWhite,
      'gameType': gameType ?? 'chess',
      if (options != null && options.isNotEmpty) 'options': options,
      'sentAt': ServerValue.timestamp,
      'status': 'pending',
    });
    return newRef.key!;
  }

  Stream<DatabaseEvent> watchInvites(String uid) =>
      _inviteRef(uid).onValue;

  /// Watch a single invite document — used by the inviter to detect acceptance.
  Stream<DatabaseEvent> watchInviteStatus(String toUid, String inviteKey) =>
      _inviteRef(toUid).child(inviteKey).onValue;

  /// Called by the recipient when they accept: writes both status and gameId
  /// so the waiting inviter can read the gameId and navigate.
  Future<void> acceptInviteWithGame(
    String toUid,
    String inviteKey,
    String gameId,
  ) =>
      _inviteRef(toUid).child(inviteKey).update({
        'status': 'accepted',
        'gameId': gameId,
      });

  /// Decline (or timeout-cancel) an invite.
  Future<void> respondToInvite(
          String toUid, String inviteKey, String status) =>
      _inviteRef(toUid).child(inviteKey).child('status').set(status);

  /// Delete the invite entirely (used by the inviter when they cancel).
  Future<void> deleteInvite(String toUid, String inviteKey) =>
      _inviteRef(toUid).child(inviteKey).remove();

  // ── Arena queue & pairing ─────────────────────────────────────────────────

  DatabaseReference _arenaQueueRef(String tournamentId) =>
      _db.ref('arena_queue/$tournamentId');

  DatabaseReference _arenaPairingRef(String tournamentId, String uid) =>
      _db.ref('arena_pairings/$tournamentId/$uid');

  /// Add the player to the arena ready queue.
  Future<void> joinArenaQueue({
    required String tournamentId,
    required String uid,
    required String username,
    required int rating,
  }) =>
      _arenaQueueRef(tournamentId).child(uid).set({
        'uid': uid,
        'username': username,
        'rating': rating,
        'joinedAt': ServerValue.timestamp,
      });

  /// Remove the player from the arena ready queue.
  Future<void> leaveArenaQueue(String tournamentId, String uid) =>
      _arenaQueueRef(tournamentId).child(uid).remove();

  /// Live stream of the entire ready queue for a tournament.
  Stream<DatabaseEvent> watchArenaQueue(String tournamentId) =>
      _arenaQueueRef(tournamentId).onValue;

  /// Watch MY pairing result node.
  Stream<DatabaseEvent> watchMyArenaPairing(String tournamentId, String uid) =>
      _arenaPairingRef(tournamentId, uid).onValue;

  /// Clear my pairing result (call after navigating to the game).
  Future<void> clearArenaPairing(String tournamentId, String uid) =>
      _arenaPairingRef(tournamentId, uid).remove();

  /// Atomically claim an opponent from the arena ready queue.
  ///
  /// Steps:
  ///  1. Atomically remove myself from queue (fails if already removed/claimed).
  ///  2. Atomically remove opponent from queue (fails if already claimed).
  ///  3. Write pairing nodes for both players + create the live game shell.
  ///
  /// Returns true on success.  Caller should NOT call this when myUid >= opponentUid
  /// (use UID-comparison convention to avoid symmetric races).
  Future<bool> tryClaimArenaPairing({
    required String tournamentId,
    required String myUid,
    required String myUsername,
    required int myRating,
    required String opponentUid,
    required String gameId,
    required String timeControlLabel,
  }) async {
    final myQueueRef = _arenaQueueRef(tournamentId).child(myUid);
    final oppQueueRef = _arenaQueueRef(tournamentId).child(opponentUid);

    // Step 1: Remove myself atomically
    final myResult = await myQueueRef.runTransaction((data) {
      if (data == null) return Transaction.abort();
      return Transaction.success(null);
    });
    if (!myResult.committed) return false; // Already removed/claimed

    // Step 2: Remove opponent atomically — capture their data for rollback
    Map<Object?, Object?>? oppSnapshot;
    final oppResult = await oppQueueRef.runTransaction((data) {
      if (data == null) return Transaction.abort();
      if (data is Map) oppSnapshot = Map.from(data);
      return Transaction.success(null);
    });

    if (!oppResult.committed) {
      // Opponent already gone — put myself back and bail
      await myQueueRef.set({
        'uid': myUid,
        'username': myUsername,
        'rating': myRating,
        'joinedAt': ServerValue.timestamp,
      });
      return false;
    }

    // Both removed. Write pairings + create live game.
    try {
      await Future.wait([
        _arenaPairingRef(tournamentId, myUid).set({
          'opponentUid': opponentUid,
          'gameId': gameId,
          'isWhite': true,
          'pairedAt': ServerValue.timestamp,
        }),
        _arenaPairingRef(tournamentId, opponentUid).set({
          'opponentUid': myUid,
          'gameId': gameId,
          'isWhite': false,
          'pairedAt': ServerValue.timestamp,
        }),
        _db.ref('live_games/$gameId').set({
          'whiteUid': myUid,
          'blackUid': opponentUid,
          'timeControl': timeControlLabel,
          'status': 'active',
          'arenaId': tournamentId,
          'createdAt': ServerValue.timestamp,
        }),
      ]);
      return true;
    } catch (e) {
      // Rollback: put both players back in the queue with their original data.
      // Previously used hardcoded username:'' / rating:0 for the opponent,
      // which corrupted their queue entry.
      await Future.wait([
        myQueueRef.set({
          'uid': myUid,
          'username': myUsername,
          'rating': myRating,
          'joinedAt': ServerValue.timestamp,
        }),
        oppQueueRef.set(
          oppSnapshot != null
              ? {...oppSnapshot!, 'joinedAt': ServerValue.timestamp}
              : {
                  'uid': opponentUid,
                  'joinedAt': ServerValue.timestamp,
                },
        ),
      ]);
      return false;
    }
  }
}

final realtimeGameServiceProvider =
    Provider((_) => RealtimeGameService());
