import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tournament_model.dart';

/// Outcome of an arena game from the reporting player's point of view.
enum ArenaOutcome { win, draw, loss }

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');

  CollectionReference<Map<String, dynamic>> _participants(String id) =>
      _tournaments.doc(id).collection('participants');

  // ── Create / Join / Leave ──────────────────────────────────────────────────

  /// Creates a player-hosted arena. The `onArenaCreated` Cloud Function then
  /// fills it with bots and starts it within about half a minute, so nobody
  /// waits in an empty lobby for players who are not coming.
  Future<String> createTournament(TournamentModel tournament) async {
    final ref = _tournaments.doc();
    await ref.set(tournament.toMap());
    return ref.id;
  }

  Future<void> joinTournament({
    required String tournamentId,
    required String uid,
    required String username,
    required int rating,
  }) async {
    final batch = _db.batch();
    batch.set(_participants(tournamentId).doc(uid), {
      'uid': uid,
      'username': username,
      'rating': rating,
      'score': 0.0,
      'wins': 0,
      'draws': 0,
      'losses': 0,
      'gamesPlayed': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    // Allowed for every participant by the rules (participantCount ±1 only).
    // It used to be creator-only, so for everyone else the whole batch was
    // rejected and joining someone else's arena always failed.
    batch.update(_tournaments.doc(tournamentId), {
      'participantCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> leaveTournament(String tournamentId, String uid) async {
    final batch = _db.batch();
    batch.delete(_participants(tournamentId).doc(uid));
    batch.update(_tournaments.doc(tournamentId), {
      'participantCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Future<bool> isParticipant(String tournamentId, String uid) async {
    final doc = await _participants(tournamentId).doc(uid).get();
    return doc.exists;
  }

  // ── Arena lifecycle ────────────────────────────────────────────────────────

  /// Creator's "Start now": status → active, records endsAt. (Arenas also
  /// start on their own — see `onArenaCreated` / `arenaTick` on the server —
  /// and the server closes them when endsAt passes.)
  Future<void> startArena(String tournamentId, int durationMinutes) async {
    final endsAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await _tournaments.doc(tournamentId).update({
      'status': TournamentStatus.active.name,
      'endsAt': Timestamp.fromDate(endsAt),
    });
  }

  // ── Arena result recording ─────────────────────────────────────────────────

  /// Reports a finished arena game to the `reportArenaResult` Cloud Function,
  /// which scores it (win 2, draw 1, loss 0) for both sides.
  ///
  /// Scores used to be written straight from the client, but the security
  /// rules have never allowed updating participant documents — every result
  /// was silently rejected and standings stayed at zero. The server also
  /// de-duplicates by [gameId], so both players can safely report the same
  /// game, and it credits the bot when the opponent was one.
  ///
  /// [opponentUid] is the other player's uid, or the arena bot's `bot_…` id.
  Future<void> reportArenaResult({
    required String tournamentId,
    required String gameId,
    required ArenaOutcome outcome,
    String? opponentUid,
  }) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await FirebaseFunctions.instance
            .httpsCallable('reportArenaResult')
            .call<void>({
          'tournamentId': tournamentId,
          'gameId': gameId,
          'outcome': outcome.name,
          if (opponentUid != null) 'opponentUid': opponentUid,
        });
        return;
      } on FirebaseFunctionsException catch (e) {
        // Rejections (duplicate, arena over, not a participant) are final.
        if (e.code != 'unavailable' && e.code != 'internal' &&
            e.code != 'deadline-exceeded') {
          debugPrint('[Arena] result not counted: ${e.code} ${e.message}');
          return;
        }
        if (attempt == 3) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<TournamentModel>> watchTournaments() {
    return _tournaments
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => TournamentModel.fromMap(d.id, d.data())).toList());
  }

  Stream<TournamentModel> watchTournament(String tournamentId) {
    return _tournaments.doc(tournamentId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Tournament not found');
      return TournamentModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<ArenaParticipant>> watchParticipants(String tournamentId) {
    return _participants(tournamentId)
        .orderBy('score', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ArenaParticipant.fromMap(d.data())).toList());
  }

  Future<TournamentModel?> getTournament(String tournamentId) async {
    final doc = await _tournaments.doc(tournamentId).get();
    if (!doc.exists) return null;
    return TournamentModel.fromMap(doc.id, doc.data()!);
  }
}

final tournamentServiceProvider =
    Provider<TournamentService>((ref) => TournamentService());

/// Live list of arenas, shared by the Arena tab and the home teaser so the
/// query runs once.
final tournamentsStreamProvider =
    StreamProvider<List<TournamentModel>>((ref) {
  return ref.read(tournamentServiceProvider).watchTournaments();
});
