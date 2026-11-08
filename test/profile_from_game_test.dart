import 'package:chess_app/core/services/bot_cities.dart';
import 'package:chess_app/core/services/bot_pool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's route shape: profiles live under /home, games at the top level.
GoRouter _router(List<String> built) => GoRouter(
      initialLocation: '/game/1',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) {
            built.add('home');
            return const Text('home');
          },
          routes: [
            GoRoute(
              path: 'profile/:uid',
              builder: (_, s) {
                built.add('profile');
                return Text('profile ${s.pathParameters['uid']}');
              },
            ),
          ],
        ),
        GoRoute(
          path: '/game/:id',
          builder: (context, _) {
            built.add('game');
            return TextButton(
              onPressed: () => context.push('/home/profile/bot_0001'),
              child: const Text('game'),
            );
          },
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a profile opened from a game goes back to the game',
      (tester) async {
    final built = <String>[];
    final router = _router(built);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('game'));
    await tester.pumpAndSettle();
    expect(find.text('profile bot_0001'), findsOneWidget);
    expect(built, isNot(contains('home')));

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('game'), findsOneWidget);
  });

  group('bot profiles', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      // The pool is read from the asset bundle, as in the app.
      await rootBundle.loadString('assets/data/bots.json');
    });

    test('a bot reads the same every time and matches its pool entry', () async {
      final bot = (await BotPool.byUid('bot_0042'))!;
      final a = bot.toUser();
      final b = (await BotPool.userFor('bot_0042'))!;
      expect(a.username, bot.username);
      expect(a.countryCode, bot.countryCode);
      expect(a.blitzStats.rating, bot.chessRating);
      expect(a.checkersStats.rating, bot.checkersRating);
      expect(a.dominoStats.rating, bot.dominoRating);
      expect(b.blitzStats.wins, a.blitzStats.wins);
      expect(b.createdAt, a.createdAt);
    });

    test('every bot has played each game and has a believable record',
        () async {
      for (final bot in await BotPool.load()) {
        final u = bot.toUser();
        for (final s in [
          u.blitzStats,
          u.bulletStats,
          u.rapidStats,
          u.checkersStats,
          u.dominoStats
        ]) {
          expect(s.games, greaterThan(0));
          expect(s.wins, greaterThanOrEqualTo(0));
          expect(s.losses, greaterThanOrEqualTo(0));
          // A handful of games can go any way; a real record evens out.
          if (s.games >= 20) {
            final score = (s.wins + s.draws / 2) / s.games;
            expect(score, inInclusiveRange(0.2, 0.8));
          }
        }
        expect(u.createdAt.isBefore(DateTime(2026, 10, 26)), isTrue);
        expect(u.messagePrivacy, isNot('everyone'));
        expect(u.challengePrivacy, isNot('everyone'));
      }
    });

    test('stronger bots win more often', () async {
      final bots = await BotPool.load();
      double avgScore(Iterable<BotProfile> group) {
        final xs = group.map((b) {
          final s = b.toUser().blitzStats;
          return (s.wins + s.draws / 2) / s.games;
        }).toList();
        return xs.reduce((a, b) => a + b) / xs.length;
      }

      final weak = bots.where((b) => b.chessRating < 1000);
      final strong = bots.where((b) => b.chessRating > 1600);
      expect(avgScore(strong), greaterThan(avgScore(weak) + 0.05));
    });

    test('the record grows day by day and counts games played here', () async {
      final bot = (await BotPool.byUid('bot_0042'))!;
      final now = DateTime(2026, 11, 8, 12);
      final today = bot.toUser(now: now);
      final later = bot.toUser(now: now.add(const Duration(days: 30)));
      expect(later.blitzStats.games, greaterThan(today.blitzStats.games));
      expect(later.blitzStats.wins, greaterThanOrEqualTo(today.blitzStats.wins));
      expect(later.blitzStats.rating, today.blitzStats.rating);

      final mine = bot.toUser(
        now: now,
        mine: const BotRecord(byKind: {'checkers': (1, 0, 2)}),
      );
      expect(mine.checkersStats.wins, today.checkersStats.wins + 1);
      expect(mine.checkersStats.losses, today.checkersStats.losses + 2);
      expect(mine.checkersStats.games, today.checkersStats.games + 3);
    });

    test('unlabelled bots have a spot on the map in their country', () async {
      for (final bot in (await BotPool.load()).take(BotPool.unlabelledCount)) {
        final u = bot.toUser();
        expect(u.showOnMap, isTrue);
        final cities = kBotCities[bot.countryCode]!;
        final near = cities.any((c) =>
            (u.latitude! - c.$1).abs() <= 0.09 &&
            (u.longitude! - c.$2).abs() <= 0.12);
        expect(near, isTrue, reason: '${bot.uid} ${bot.countryCode}');
      }
    });

    test('the last 500 are labelled and stay off the map', () async {
      final bots = await BotPool.load();
      expect(bots.where((b) => b.labelled).length, 500);
      expect(bots[1999].labelled, isFalse);
      expect(bots[2000].labelled, isTrue);
      expect(BotPool.isLabelledUid('bot_2001'), isTrue);
      expect(BotPool.isLabelledUid('bot_2000'), isFalse);
      expect(BotPool.isLabelledUid('someUserId'), isFalse);
      expect(bots[2000].toUser().showOnMap, isFalse);
    });

    test('player search finds bots by the start of their name', () async {
      final bot = (await BotPool.byUid('bot_0007'))!;
      final found = await BotPool.search(bot.username.substring(0, 4));
      expect(found.map((u) => u.uid), contains('bot_0007'));
      expect((await BotPool.userByName(bot.username.toUpperCase()))!.uid,
          'bot_0007');
    });

    test('a believable number of bots is online, more in the evening',
        () async {
      // 16:00 UTC: evening in Azerbaijan, Turkey and Russia.
      final evening = await BotPool.onlineCount(
          now: DateTime.utc(2026, 11, 8, 16));
      // 00:30 UTC: night there, early evening in the Americas.
      final night = await BotPool.onlineCount(
          now: DateTime.utc(2026, 11, 8, 0, 30));
      expect(evening, inInclusiveRange(200, 450));
      expect(night, inInclusiveRange(60, 300));
      expect(evening, greaterThan(night));

      // A profile's online dot agrees with the count.
      final at = DateTime.utc(2026, 11, 8, 16);
      final bots = (await BotPool.load()).where((b) => !b.labelled);
      final dots = bots.where((b) {
        final seen = b.toUser(now: at).lastSeen!;
        return at.difference(seen).inMinutes < 5;
      }).length;
      expect(dots, evening);
    });

    test('a finished game is kept on the phone', () async {
      await BotRecords.add('bot_0010', 'blitz', 1);
      await BotRecords.add('bot_0010', 'blitz', -1);
      await BotRecords.add('bot_0010', 'domino', 0);
      final r = await BotRecords.of('bot_0010');
      expect(r.of('blitz'), (1, 0, 1));
      expect(r.of('domino'), (0, 1, 0));
      expect(r.lastPlayed, isNotNull);
    });

    test('names and ids look up the same bot', () async {
      final bot = (await BotPool.byUid('bot_1500'))!;
      expect((await BotPool.byName(bot.username))!.uid, 'bot_1500');
      expect(BotPool.isBotUid('bot_1500'), isTrue);
      expect(BotPool.isBotUid('Xy7aQ2bot_1'), isFalse);
      expect(await BotPool.userFor('bot_9999'), isNull);
    });
  });
}
