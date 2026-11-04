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

  /// Creates a player-hosted arena. The `onArenaCreated` Cloud Function gives
  /// people two minutes to join, then fills the empty seats with bots and
  /// starts it, so nobody waits in an empty lobby for players who never come.
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
    String? countryCode,
  }) async {
    final batch = _db.batch();
    batch.set(_participants(tournamentId).doc(uid), {
      'uid': uid,
      'username': username,
      'rating': rating,
      if (countryCode != null && countryCode.isNotEmpty)
        'countryCode': countryCode,
      'score': 0.0,
      'wins': 0,
      'draws': 0,
      'losses': 0,
      'gamesPlayed': 0,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    // Allowed for every participant by the rules (participantCount ±1 only).
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

  // ── Arena lifecycle ────────────────────────────────────────────────────────

  /// The creator's "Start now": the `startArenaNow` Cloud Function fills the
  /// empty seats with bots and starts the arena at once. (It also starts by
  /// itself two minutes after it was created, and the server closes it when
  /// its time is up.)
  Future<void> startArenaNow(String tournamentId) async {
    await FirebaseFunctions.instance
        .httpsCallable('startArenaNow')
        .call<void>({'tournamentId': tournamentId});
  }

  // ── Arena result recording ─────────────────────────────────────────────────

  /// Reports a finished arena game to the `reportArenaResult` Cloud Function,
  /// which scores it for both sides: win 2, draw 1, loss 0, and double after
  /// two wins in a row. Clients may not write participant documents, and the
  /// server de-duplicates by [gameId], so both players can report the same
  /// game safely; it credits the bot too when the opponent was one.
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

  /// Every arena that is open (waiting or live), for all three games: a
  /// handful of documents, so one listener serves the Arena tab and home.
  Stream<List<TournamentModel>> watchOpenTournaments() {
    return _tournaments
        .where('status', whereIn: [
          TournamentStatus.waiting.name,
          TournamentStatus.active.name,
        ])
        .snapshots()
        .map((s) =>
            s.docs.map((d) => TournamentModel.fromMap(d.id, d.data())).toList());
  }

  /// The most recently finished arenas of one game.
  Stream<List<TournamentModel>> watchFinishedTournaments(String gameType,
      {int limit = 10}) {
    return _tournaments
        .where('gameType', isEqualTo: gameType)
        .where('status', isEqualTo: TournamentStatus.finished.name)
        .orderBy('finishedAt', descending: true)
        .limit(limit)
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

  /// Standings, best first (see [ArenaParticipant.compare]).
  Stream<List<ArenaParticipant>> watchParticipants(String tournamentId) {
    return _participants(tournamentId)
        .orderBy('score', descending: true)
        .limit(300)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ArenaParticipant.fromMap(d.data()))
            .toList()
          ..sort(ArenaParticipant.compare));
  }
}

final tournamentServiceProvider =
    Provider<TournamentService>((ref) => TournamentService());

/// Open (waiting or live) arenas of every game, shared by the Arena tab and
/// the home teaser so the query runs once.
final openArenasProvider = StreamProvider<List<TournamentModel>>((ref) {
  return ref.read(tournamentServiceProvider).watchOpenTournaments();
});

/// Recently finished arenas of one game (the Arena tab's last section).
final finishedArenasProvider = StreamProvider.autoDispose
    .family<List<TournamentModel>, String>((ref, gameType) {
  return ref
      .read(tournamentServiceProvider)
      .watchFinishedTournaments(gameType);
});
