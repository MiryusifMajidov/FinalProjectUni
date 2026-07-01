import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tournament_model.dart';

class TournamentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tournaments =>
      _db.collection('tournaments');

  CollectionReference<Map<String, dynamic>> _participants(String id) =>
      _tournaments.doc(id).collection('participants');

  // ── Create / Join / Leave ──────────────────────────────────────────────────

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

  /// Activates the tournament: sets status → active, records endsAt.
  Future<void> startArena(String tournamentId, int durationMinutes) async {
    final endsAt = DateTime.now().add(Duration(minutes: durationMinutes));
    await _tournaments.doc(tournamentId).update({
      'status': TournamentStatus.active.name,
      'endsAt': Timestamp.fromDate(endsAt),
    });
  }

  /// Marks the tournament as finished (idempotent via transaction).
  Future<void> finishArena(String tournamentId) async {
    await _db.runTransaction((tx) async {
      final doc = await tx.get(_tournaments.doc(tournamentId));
      if (!doc.exists) return;
      final status = doc.data()?['status'] as String?;
      if (status == TournamentStatus.finished.name) return;
      tx.update(_tournaments.doc(tournamentId), {
        'status': TournamentStatus.finished.name,
      });
    });
  }

  // ── Arena result recording ─────────────────────────────────────────────────

  /// Updates participant scores for a completed arena game.
  /// Win = 2 pts, Draw = 1 pt, Loss = 0 pts.
  /// Call from only ONE side (white player) to avoid double-counting.
  Future<void> recordArenaResult({
    required String tournamentId,
    required String whiteUid,
    required String blackUid,
    required String? winnerUid, // null if draw
    required bool isDraw,
  }) async {
    final whiteWon = winnerUid == whiteUid;
    final blackWon = winnerUid == blackUid;

    final whiteDelta = isDraw ? 1.0 : (whiteWon ? 2.0 : 0.0);
    final blackDelta = isDraw ? 1.0 : (blackWon ? 2.0 : 0.0);

    final batch = _db.batch();

    batch.update(_participants(tournamentId).doc(whiteUid), {
      'score': FieldValue.increment(whiteDelta),
      'wins': FieldValue.increment(whiteWon ? 1 : 0),
      'draws': FieldValue.increment(isDraw ? 1 : 0),
      'losses': FieldValue.increment(!whiteWon && !isDraw ? 1 : 0),
      'gamesPlayed': FieldValue.increment(1),
    });

    batch.update(_participants(tournamentId).doc(blackUid), {
      'score': FieldValue.increment(blackDelta),
      'wins': FieldValue.increment(blackWon ? 1 : 0),
      'draws': FieldValue.increment(isDraw ? 1 : 0),
      'losses': FieldValue.increment(!blackWon && !isDraw ? 1 : 0),
      'gamesPlayed': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Records an arena result for a single participant (used for the bot
  /// fallback games where the opponent has no participant document).
  /// Win = 2 pts, Draw = 1 pt, Loss = 0 pts.
  Future<void> recordArenaResultSingle({
    required String tournamentId,
    required String uid,
    required bool won,
    required bool isDraw,
  }) async {
    final delta = isDraw ? 1.0 : (won ? 2.0 : 0.0);
    await _participants(tournamentId).doc(uid).update({
      'score': FieldValue.increment(delta),
      'wins': FieldValue.increment(won ? 1 : 0),
      'draws': FieldValue.increment(isDraw ? 1 : 0),
      'losses': FieldValue.increment(!won && !isDraw ? 1 : 0),
      'gamesPlayed': FieldValue.increment(1),
    });
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
