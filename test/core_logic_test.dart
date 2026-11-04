import 'package:chess_app/core/models/game_type.dart';
import 'package:chess_app/core/models/tournament_model.dart';
import 'package:chess_app/core/models/user_model.dart';
import 'package:chess_app/core/services/bot_pool.dart';
import 'package:chess_app/core/utils/email_validator.dart';
import 'package:chess_app/features/tournaments/screens/tournament_list_screen.dart'
    show formatCountdown, sortArenas;
import 'package:flutter_test/flutter_test.dart';

TournamentModel _arena(
  String id, {
  TournamentStatus status = TournamentStatus.waiting,
  DateTime? startsAt,
  DateTime? endsAt,
  bool isSystem = false,
  int participants = 1,
  int max = 16,
  DateTime? createdAt,
}) =>
    TournamentModel(
      id: id,
      name: id,
      status: status,
      creatorUid: 'u',
      creatorUsername: 'u',
      maxPlayers: max,
      timeControlLabel: '3+0',
      timeSeconds: 180,
      incrementSeconds: 0,
      durationMinutes: 45,
      startsAt: startsAt,
      endsAt: endsAt,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      participantCount: participants,
      isSystem: isSystem,
    );

void main() {
  group('isValidEmail', () {
    test('accepts addresses on sub-domains (the old regex did not)', () {
      expect(isValidEmail('tester.one@student.bhos.edu.az'), isTrue);
      expect(isValidEmail('name@mail.example.co.uk'), isTrue);
      expect(isValidEmail('a+b@gmail.com'), isTrue);
      expect(isValidEmail('  padded@gmail.com  '), isTrue);
    });

    test('rejects obvious typos', () {
      expect(isValidEmail('no-at-sign.com'), isFalse);
      expect(isValidEmail('name@domain'), isFalse);
      expect(isValidEmail('name@domain.c'), isFalse);
      expect(isValidEmail('two words@gmail.com'), isFalse);
      expect(isValidEmail(''), isFalse);
    });
  });

  group('UserModel.overallRating', () {
    test('uses the starting rating before the first game', () {
      final beginner = UserModel(
        uid: 'x',
        username: 'x',
        email: '',
        createdAt: DateTime(2026),
        bulletStats: const RatingStats(rating: 400),
        blitzStats: const RatingStats(rating: 400),
        rapidStats: const RatingStats(rating: 400),
      );
      expect(beginner.overallRating, 400);
    });

    test('averages only the time controls that were played', () {
      final u = UserModel(
        uid: 'x',
        username: 'x',
        email: '',
        createdAt: DateTime(2026),
        bulletStats: const RatingStats(rating: 1000),
        blitzStats: const RatingStats(rating: 1300, wins: 3),
        rapidStats: const RatingStats(rating: 1500, losses: 1),
      );
      expect(u.overallRating, 1400);
    });

    test('isGuest round-trips through Firestore maps', () {
      final u = UserModel(
          uid: 'g', username: 'SwiftKnight42', email: '', createdAt: DateTime(2026), isGuest: true);
      final map = u.toMap();
      expect(map['isGuest'], isTrue);
      expect(UserModel.fromMap(map).isGuest, isTrue);
      expect(UserModel.fromMap({...map}..remove('isGuest')).isGuest, isFalse);
    });
  });

  group('TournamentModel', () {
    test('an active arena past endsAt counts as finished', () {
      final t = _arena('a',
          status: TournamentStatus.active,
          endsAt: DateTime.now().subtract(const Duration(seconds: 5)));
      expect(t.isActive, isFalse);
      expect(t.isFinished, isTrue);
      expect(t.effectiveStatus, TournamentStatus.finished);
      expect(t.canJoin, isFalse);
    });

    test('live arenas with room can still be joined', () {
      final t = _arena('a',
          status: TournamentStatus.active,
          endsAt: DateTime.now().add(const Duration(minutes: 10)));
      expect(t.canJoin, isTrue);
      expect(_arena('b', participants: 16, max: 16).canJoin, isFalse);
    });

    test('ArenaParticipant treats bot_ uids as bots', () {
      expect(ArenaParticipant.fromMap({'uid': 'bot_pawnstorm'}).isBot, isTrue);
      expect(ArenaParticipant.fromMap({'uid': 'abc'}).isBot, isFalse);
    });

    test('reads streaks, per-game points and the bots that are busy', () {
      final p = ArenaParticipant.fromMap({
        'uid': 'u1',
        'score': 8,
        'streak': 2,
        'onFire': true,
        'results': ['w2', 'w2', 'w4', 7, null],
        'countryCode': 'AZ',
      });
      expect(p.results, ['w2', 'w2', 'w4']);
      expect(p.onFire, isTrue);
      expect(p.countryCode, 'AZ');

      final t = TournamentModel.fromMap('t', {
        'status': 'active',
        'cancelled': true,
        'botGames': [
          {'a': 'bot_0001', 'b': 'bot_0002', 'oa': 'win', 'at': 1},
          'junk',
        ],
      });
      expect(t.busyBotUids, {'bot_0001', 'bot_0002'});
      expect(t.cancelled, isTrue);
    });

    test('standings: points, then wins, then fewer games', () {
      ArenaParticipant p(String uid, double score, int wins, int games) =>
          ArenaParticipant(
            uid: uid,
            username: uid,
            rating: 1200,
            score: score,
            wins: wins,
            gamesPlayed: games,
            joinedAt: DateTime(2026),
          );
      final list = [
        p('a', 6, 2, 4),
        p('b', 8, 3, 5),
        p('c', 6, 3, 4),
        p('d', 6, 3, 3),
      ]..sort(ArenaParticipant.compare);
      expect(list.map((e) => e.uid), ['b', 'd', 'c', 'a']);
    });
  });

  group('BotPool', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('loads the 2000 bots shared with the server', () async {
      final bots = await BotPool.load();
      expect(bots.length, 2000);
      expect(bots.first.uid, 'bot_0001');
      expect(bots.last.uid, 'bot_2000');
      expect(bots.map((b) => b.username.toLowerCase()).toSet().length, 2000);
    });

    test('picks a bot near the player\'s rating', () async {
      for (var i = 0; i < 20; i++) {
        final bot = await BotPool.near(GameType.chess, 1500);
        expect((bot.chessRating - 1500).abs(), lessThanOrEqualTo(60));
      }
      final far = await BotPool.near(GameType.domino, 5000);
      expect(far.dominoRating, greaterThan(600));
      expect((await BotPool.some(3)).map((b) => b.uid).toSet().length, 3);
    });
  });

  group('sortArenas', () {
    test('live first (server arenas before player arenas), then upcoming soonest first, then finished', () {
      final now = DateTime.now();
      final sorted = sortArenas([
        _arena('finished', status: TournamentStatus.finished),
        _arena('upcoming-late', startsAt: now.add(const Duration(minutes: 30))),
        _arena('live-player',
            status: TournamentStatus.active,
            endsAt: now.add(const Duration(minutes: 5)),
            createdAt: now),
        _arena('upcoming-soon', startsAt: now.add(const Duration(minutes: 2))),
        _arena('live-server',
            status: TournamentStatus.active,
            endsAt: now.add(const Duration(minutes: 20)),
            isSystem: true),
      ]).map((t) => t.id).toList();
      expect(sorted, [
        'live-server',
        'live-player',
        'upcoming-soon',
        'upcoming-late',
        'finished',
      ]);
    });
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(minutes: 4, seconds: 7)), '04:07');
    expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatCountdown(const Duration(seconds: -3)), '00:00');
  });
}
