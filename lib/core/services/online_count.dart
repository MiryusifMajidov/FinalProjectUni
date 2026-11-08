import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'bot_pool.dart';

/// How many players are online right now: people the app saw in the last
/// five minutes (their `lastSeen`) plus the bots that are online (see
/// BotProfile.onlineAt; labelled bots are not counted). The home screen and
/// the player map show this same number.
///
/// The number moves like a live count: the bots are recounted every 15
/// seconds (on the phone, free). The people are recounted every two
/// minutes, the rate at which the app refreshes `lastSeen`, with one
/// aggregation query (billed as one read per thousand players), not by
/// reading their documents.
final onlineCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final fs = ref.read(firestoreServiceProvider);
  var people = await fs.countOnlineUsers();
  var peopleAt = DateTime.now();
  while (true) {
    if (DateTime.now().difference(peopleAt) >= const Duration(minutes: 2)) {
      people = await fs.countOnlineUsers();
      peopleAt = DateTime.now();
    }
    yield people + await BotPool.onlineCount();
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});
