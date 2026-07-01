import 'dart:math';

// ── Domino Engine ───────────────────────────────────────────────────────────
// Double-Six dominoes with proper match play:
//
//  • Variants: Draw (boneyard — must draw when stuck) and Block (no drawing —
//    pass when stuck). 4-player games never use a boneyard (28/4 = 7).
//  • Match play: a match consists of rounds played to a target score
//    (100/150/200). The round winner collects the pips left in the
//    opponents' hands; in a blocked round the lowest hand wins the
//    difference. A tied blocked round is a wash (nobody scores).
//  • Opening rule: in the first round the player holding the highest double
//    MUST lead with it (no doubles anywhere → heaviest tile leads). In later
//    rounds the previous round's winner leads with any tile.
//  • Teams: optional 2v2 partnership for 4 players (seats 0&2 vs 1&3).
//  • AI: MCTS with hidden-information sampling (offline bots, run in an
//    isolate) plus a deterministic seeded greedy policy (online stand-ins,
//    so every client computes the identical move).

/// A single domino tile (bone).
class DominoTile {
  final int a;
  final int b;

  const DominoTile(this.a, this.b);

  bool get isDouble => a == b;
  int get total => a + b;
  int get maxPip => a > b ? a : b;

  bool canMatch(int value) => a == value || b == value;

  int otherEnd(int value) {
    if (a == value) return b;
    if (b == value) return a;
    throw StateError('Tile $this cannot match $value');
  }

  List<int> encode() => [a, b];

  static DominoTile decode(List<dynamic> v) =>
      DominoTile((v[0] as num).toInt(), (v[1] as num).toInt());

  @override
  bool operator ==(Object other) =>
      other is DominoTile &&
      ((a == other.a && b == other.b) || (a == other.b && b == other.a));

  @override
  int get hashCode => a <= b ? a * 10 + b : b * 10 + a;

  @override
  String toString() => '[$a|$b]';
}

enum DominoEnd { left, right }

class DominoPlay {
  final DominoTile tile;
  final DominoEnd end;

  const DominoPlay({required this.tile, required this.end});

  @override
  String toString() => '$tile → ${end.name}';
}

enum DominoVariant { draw, block }

/// Static match configuration.
class DominoConfig {
  final int playerCount;       // 2 or 4
  final DominoVariant variant; // draw | block
  final bool teams;            // 4P only: seats 0&2 vs 1&3
  final int targetScore;       // 100 / 150 / 200

  const DominoConfig({
    this.playerCount = 2,
    this.variant = DominoVariant.draw,
    this.teams = false,
    this.targetScore = 100,
  }) : assert(playerCount == 2 || playerCount == 4);

  Map<String, dynamic> toMap() => {
        'playerCount': playerCount,
        'variant': variant.index,
        'teams': teams,
        'targetScore': targetScore,
      };

  static DominoConfig fromMap(Map<String, dynamic> m) => DominoConfig(
        playerCount: (m['playerCount'] as num?)?.toInt() ?? 2,
        variant: DominoVariant.values[(m['variant'] as num?)?.toInt() ?? 0],
        teams: m['teams'] as bool? ?? false,
        targetScore: (m['targetScore'] as num?)?.toInt() ?? 100,
      );
}

/// What happened in the round that just finished.
class DominoRoundSummary {
  final int roundNumber;
  final int? winnerSeat;     // null → wash (tied blocked round)
  final int? winnerEntity;   // seat index (FFA) or team index (teams)
  final bool wasBlocked;
  final List<int> pipCounts; // per seat, at the moment the round ended
  final int scoreGained;
  final List<int> totalScores; // per entity, after the round

  const DominoRoundSummary({
    required this.roundNumber,
    required this.winnerSeat,
    required this.winnerEntity,
    required this.wasBlocked,
    required this.pipCounts,
    required this.scoreGained,
    required this.totalScores,
  });
}

/// The domino match state (rounds + scores + the live round).
class DominoEngine {
  final Random _rng;
  final DominoConfig config;

  late List<DominoTile> _boneyard;
  late List<List<DominoTile>> _hands; // indexed by seat
  late List<DominoTile> chain;
  int? leftEnd;
  int? rightEnd;
  int turnSeat = 0;
  int consecutivePasses = 0;
  List<String> moveLog = [];

  /// Most recently placed tile of the current round (UI "highlight last move").
  DominoTile? lastPlayedTile;

  // Match state
  late List<int> scores; // per entity
  int roundNumber = 1;
  int? matchWinner; // entity index — match over when non-null
  DominoRoundSummary? lastRoundSummary;
  int _roundStarterSeat = 0;
  DominoTile? requiredOpeningTile; // round 1 forced lead

  // Tile tracking for AI
  final Set<DominoTile> _playedTiles = {};
  final Map<int, Set<int>> _knownMissing = {}; // seat → values proven missing

  int get playerCount => config.playerCount;
  int get targetScore => config.targetScore;
  bool get matchOver => matchWinner != null;

  int get entityCount => config.teams ? 2 : playerCount;
  int entityOf(int seat) => config.teams ? seat % 2 : seat;

  DominoEngine({int? seed, this.config = const DominoConfig()})
      : _rng = Random(seed) {
    scores = List.filled(entityCount, 0);
    _dealRound();
  }

  DominoEngine._internal(this._rng, this.config);

  DominoEngine clone() {
    final e = DominoEngine._internal(Random(), config);
    e._boneyard = List.of(_boneyard);
    e._hands = _hands.map((h) => List.of(h)).toList();
    e.chain = List.of(chain);
    e.leftEnd = leftEnd;
    e.rightEnd = rightEnd;
    e.turnSeat = turnSeat;
    e.lastPlayedTile = lastPlayedTile;
    e.consecutivePasses = consecutivePasses;
    e.moveLog = [];
    e.scores = List.of(scores);
    e.roundNumber = roundNumber;
    e.matchWinner = matchWinner;
    e.lastRoundSummary = lastRoundSummary;
    e._roundStarterSeat = _roundStarterSeat;
    e.requiredOpeningTile = requiredOpeningTile;
    e._playedTiles.addAll(_playedTiles);
    for (final entry in _knownMissing.entries) {
      e._knownMissing[entry.key] = Set.of(entry.value);
    }
    return e;
  }

  // ── Serialization (isolate AI) ───────────────────────────────────────────

  Map<String, dynamic> toState() => {
        'config': config.toMap(),
        'boneyard': _boneyard.map((t) => t.encode()).toList(),
        'hands': _hands.map((h) => h.map((t) => t.encode()).toList()).toList(),
        'chain': chain.map((t) => t.encode()).toList(),
        'leftEnd': leftEnd,
        'rightEnd': rightEnd,
        'turnSeat': turnSeat,
        'consecutivePasses': consecutivePasses,
        'scores': scores,
        'roundNumber': roundNumber,
        'matchWinner': matchWinner,
        'roundStarterSeat': _roundStarterSeat,
        'requiredOpeningTile': requiredOpeningTile?.encode(),
        'playedTiles': _playedTiles.map((t) => t.encode()).toList(),
        'knownMissing': _knownMissing
            .map((k, v) => MapEntry(k.toString(), v.toList())),
      };

  factory DominoEngine.fromState(Map<String, dynamic> s) {
    final e = DominoEngine._internal(
        Random(), DominoConfig.fromMap(Map<String, dynamic>.from(s['config'])));
    e._boneyard =
        (s['boneyard'] as List).map((t) => DominoTile.decode(t as List)).toList();
    e._hands = (s['hands'] as List)
        .map((h) => (h as List).map((t) => DominoTile.decode(t as List)).toList())
        .toList();
    e.chain =
        (s['chain'] as List).map((t) => DominoTile.decode(t as List)).toList();
    e.leftEnd = (s['leftEnd'] as num?)?.toInt();
    e.rightEnd = (s['rightEnd'] as num?)?.toInt();
    e.turnSeat = (s['turnSeat'] as num).toInt();
    e.consecutivePasses = (s['consecutivePasses'] as num).toInt();
    e.scores = (s['scores'] as List).map((v) => (v as num).toInt()).toList();
    e.roundNumber = (s['roundNumber'] as num).toInt();
    e.matchWinner = (s['matchWinner'] as num?)?.toInt();
    e._roundStarterSeat = (s['roundStarterSeat'] as num).toInt();
    final opening = s['requiredOpeningTile'];
    e.requiredOpeningTile =
        opening == null ? null : DominoTile.decode(opening as List);
    for (final t in (s['playedTiles'] as List)) {
      e._playedTiles.add(DominoTile.decode(t as List));
    }
    (s['knownMissing'] as Map?)?.forEach((k, v) {
      e._knownMissing[int.parse(k.toString())] =
          (v as List).map((x) => (x as num).toInt()).toSet();
    });
    return e;
  }

  // ── Deal ─────────────────────────────────────────────────────────────────

  void _dealRound({int? starterOverride}) {
    final tiles = <DominoTile>[];
    for (int a = 0; a <= 6; a++) {
      for (int b = a; b <= 6; b++) {
        tiles.add(DominoTile(a, b));
      }
    }
    tiles.shuffle(_rng);

    _hands = [];
    for (int i = 0; i < playerCount; i++) {
      _hands.add(tiles.sublist(i * 7, (i + 1) * 7));
    }
    // Boneyard exists only in 2-player games. In the Block variant the
    // remaining 14 tiles are set aside face-down and never drawn.
    _boneyard = playerCount == 2 ? tiles.sublist(14) : [];

    chain = [];
    leftEnd = null;
    rightEnd = null;
    lastPlayedTile = null;
    consecutivePasses = 0;
    moveLog = [];
    _playedTiles.clear();
    _knownMissing.clear();
    requiredOpeningTile = null;

    if (starterOverride != null) {
      // Later rounds: the previous winner leads with any tile.
      _roundStarterSeat = starterOverride;
    } else {
      // First round: highest double leads and MUST be played.
      int bestSeat = -1;
      DominoTile? bestTile;
      for (int i = 0; i < playerCount; i++) {
        for (final t in _hands[i]) {
          if (!t.isDouble) continue;
          if (bestTile == null || t.a > bestTile.a) {
            bestTile = t;
            bestSeat = i;
          }
        }
      }
      if (bestTile == null) {
        // No double anywhere → heaviest tile leads (and must be played).
        for (int i = 0; i < playerCount; i++) {
          for (final t in _hands[i]) {
            if (bestTile == null ||
                t.total > bestTile.total ||
                (t.total == bestTile.total && t.maxPip > bestTile.maxPip)) {
              bestTile = t;
              bestSeat = i;
            }
          }
        }
      }
      _roundStarterSeat = bestSeat;
      requiredOpeningTile = bestTile;
    }
    turnSeat = _roundStarterSeat;
  }

  // ── Hands ────────────────────────────────────────────────────────────────

  List<DominoTile> get currentHand => _hands[turnSeat];

  List<DominoTile> handOf(int seat) => _hands[seat];

  int pipCount(int seat) =>
      _hands[seat].fold(0, (s, t) => s + t.total);

  int get boneyardCount => _boneyard.length;

  // ── Legal plays ──────────────────────────────────────────────────────────

  List<DominoPlay> legalPlays() {
    if (matchOver) return [];
    final hand = currentHand;

    if (chain.isEmpty) {
      // Forced opening (round 1): only the designated tile may lead.
      if (requiredOpeningTile != null) {
        return hand.contains(requiredOpeningTile)
            ? [DominoPlay(tile: requiredOpeningTile!, end: DominoEnd.left)]
            : [];
      }
      return hand
          .map((t) => DominoPlay(tile: t, end: DominoEnd.left))
          .toList();
    }

    final plays = <DominoPlay>[];
    for (final t in hand) {
      if (t.canMatch(leftEnd!)) {
        plays.add(DominoPlay(tile: t, end: DominoEnd.left));
      }
      if (leftEnd != rightEnd && t.canMatch(rightEnd!)) {
        plays.add(DominoPlay(tile: t, end: DominoEnd.right));
      }
    }
    return plays;
  }

  /// Drawing is only part of the Draw variant; in Block you pass when stuck.
  bool get canDraw =>
      config.variant == DominoVariant.draw &&
      _boneyard.isNotEmpty &&
      !matchOver &&
      legalPlays().isEmpty;

  // ── Actions ──────────────────────────────────────────────────────────────

  bool play(DominoPlay move) {
    if (matchOver) return false;
    final hand = currentHand;
    if (!hand.contains(move.tile)) return false;

    if (chain.isEmpty) {
      if (requiredOpeningTile != null && move.tile != requiredOpeningTile) {
        return false;
      }
      chain.add(move.tile);
      leftEnd = move.tile.a;
      rightEnd = move.tile.b;
      requiredOpeningTile = null;
    } else {
      final matchValue =
          move.end == DominoEnd.left ? leftEnd! : rightEnd!;
      if (!move.tile.canMatch(matchValue)) return false;

      if (move.end == DominoEnd.left) {
        chain.insert(0, move.tile);
        leftEnd = move.tile.otherEnd(matchValue);
      } else {
        chain.add(move.tile);
        rightEnd = move.tile.otherEnd(matchValue);
      }
    }

    hand.remove(move.tile);
    _playedTiles.add(move.tile);
    lastPlayedTile = move.tile;
    consecutivePasses = 0;
    moveLog.add('P$turnSeat: $move');

    if (hand.isEmpty) {
      _endRound(blocked: false);
      return true;
    }

    _nextTurn();
    return true;
  }

  DominoTile? drawTile() {
    if (!canDraw) return null;
    // Drawing proves the seat held no tile matching either open end at this
    // moment — keep only the freshest evidence (older info goes stale as
    // soon as new tiles enter the hand).
    _recordMissing();
    final tile = _boneyard.removeLast();
    currentHand.add(tile);
    moveLog.add('P$turnSeat: drew');
    return tile;
  }

  bool pass() {
    if (matchOver) return false;
    if (legalPlays().isNotEmpty) return false;
    if (canDraw) return false; // Draw variant: must draw while tiles remain

    _recordMissing();
    consecutivePasses++;
    moveLog.add('P$turnSeat: passed');

    if (consecutivePasses >= playerCount) {
      _endRound(blocked: true);
      return true;
    }

    _nextTurn();
    return true;
  }

  void _recordMissing() {
    if (leftEnd == null) return;
    final missing = <int>{leftEnd!};
    if (rightEnd != null) missing.add(rightEnd!);
    _knownMissing[turnSeat] = missing;
  }

  void _nextTurn() {
    turnSeat = (turnSeat + 1) % playerCount;
  }

  // ── Round / match resolution ─────────────────────────────────────────────

  void _endRound({required bool blocked}) {
    final pips = [for (int i = 0; i < playerCount; i++) pipCount(i)];

    final entityPips = List.filled(entityCount, 0);
    for (int s = 0; s < playerCount; s++) {
      entityPips[entityOf(s)] += pips[s];
    }

    int? winnerSeat;
    int? winnerEntity;
    int gained = 0;

    if (!blocked) {
      // Someone dominoed — they collect every opponent pip.
      winnerSeat = turnSeat;
      winnerEntity = entityOf(winnerSeat);
      for (int e = 0; e < entityCount; e++) {
        if (e != winnerEntity) gained += entityPips[e];
      }
    } else {
      // Blocked round: lowest entity total wins the difference; tie → wash.
      int minPips = entityPips[0];
      int minEntity = 0;
      bool tied = false;
      for (int e = 1; e < entityCount; e++) {
        if (entityPips[e] < minPips) {
          minPips = entityPips[e];
          minEntity = e;
          tied = false;
        } else if (entityPips[e] == minPips) {
          tied = true;
        }
      }
      if (!tied) {
        winnerEntity = minEntity;
        // Representative seat: lowest individual hand within the entity.
        int bestSeat = -1;
        for (int s = 0; s < playerCount; s++) {
          if (entityOf(s) != minEntity) continue;
          if (bestSeat == -1 || pips[s] < pips[bestSeat]) bestSeat = s;
        }
        winnerSeat = bestSeat;
        for (int e = 0; e < entityCount; e++) {
          if (e != winnerEntity) gained += entityPips[e];
        }
        gained -= entityPips[winnerEntity];
        if (gained < 0) gained = 0;
      }
    }

    if (winnerEntity != null) {
      scores[winnerEntity] += gained;
    }

    lastRoundSummary = DominoRoundSummary(
      roundNumber: roundNumber,
      winnerSeat: winnerSeat,
      winnerEntity: winnerEntity,
      wasBlocked: blocked,
      pipCounts: pips,
      scoreGained: gained,
      totalScores: List.of(scores),
    );

    if (winnerEntity != null && scores[winnerEntity] >= targetScore) {
      matchWinner = winnerEntity;
      return;
    }

    // Next round: the winner leads; after a wash the lead rotates.
    final nextStarter =
        winnerSeat ?? (_roundStarterSeat + 1) % playerCount;
    roundNumber++;
    _dealRound(starterOverride: nextStarter);
  }

  // ── Deterministic greedy policy (online stand-ins) ───────────────────────
  // Must be reproducible on every client: same engine state + same seed →
  // identical move. Heuristic: dump doubles early, keep end variety, shed
  // heavy tiles.

  DominoPlay? greedyBotPlay(Random rng) {
    final plays = legalPlays();
    if (plays.isEmpty) return null;
    if (plays.length == 1) return plays.first;

    final hand = currentHand;
    // Count how many tiles in hand carry each pip value (end flexibility).
    final valueCounts = List.filled(7, 0);
    for (final t in hand) {
      valueCounts[t.a]++;
      if (!t.isDouble) valueCounts[t.b]++;
    }

    double scoreOf(DominoPlay p) {
      double s = p.tile.total * 1.0; // shed heavy tiles
      if (p.tile.isDouble) s += 4.0; // doubles are liabilities — play early
      // Prefer keeping ends we are rich in: the new open end after playing.
      final matchValue =
          chain.isEmpty ? p.tile.a : (p.end == DominoEnd.left ? leftEnd! : rightEnd!);
      final newEnd = chain.isEmpty ? p.tile.b : p.tile.otherEnd(matchValue);
      s += valueCounts[newEnd] * 1.5;
      return s;
    }

    final scored = plays
        .map((p) => (p, scoreOf(p)))
        .toList()
      ..sort((x, y) {
        final d = y.$2.compareTo(x.$2);
        if (d != 0) return d;
        // Deterministic tie-break.
        final tx = x.$1.tile, ty = y.$1.tile;
        if (tx.a != ty.a) return tx.a - ty.a;
        if (tx.b != ty.b) return tx.b - ty.b;
        return x.$1.end.index - y.$1.end.index;
      });

    // Small seeded variety between the top two when they are close.
    if (scored.length > 1 &&
        (scored[0].$2 - scored[1].$2) < 1.0 &&
        rng.nextInt(4) == 0) {
      return scored[1].$1;
    }
    return scored[0].$1;
  }

  // ── Bot AI: MCTS with tile tracking (offline play) ───────────────────────

  DominoPlay? bestBotPlay({int simulations = 500}) {
    final plays = legalPlays();
    if (plays.isEmpty) return null;
    if (plays.length == 1) return plays.first;

    final rng = Random();
    final myEntity = entityOf(turnSeat);
    final wins = <int, double>{};
    final visits = <int, int>{};

    for (int i = 0; i < plays.length; i++) {
      wins[i] = 0.0;
      visits[i] = 0;
    }

    for (int sim = 0; sim < simulations; sim++) {
      final playIdx = _selectPlay(plays.length, wins, visits, sim);

      final simEngine = clone();
      final startRound = simEngine.roundNumber;
      simEngine.play(plays[playIdx]);

      // Randomize unknown opponent hands based on tracked information.
      if (simEngine.roundNumber == startRound && !simEngine.matchOver) {
        simEngine._randomizeUnknownHands(turnSeat, rng);
      }

      final winnerEntity = simEngine._roundPlayout(rng, startRound);

      visits[playIdx] = visits[playIdx]! + 1;
      if (winnerEntity == myEntity) {
        wins[playIdx] = wins[playIdx]! + 1.0;
      } else if (winnerEntity == -1) {
        wins[playIdx] = wins[playIdx]! + 0.5; // wash
      }
    }

    // Robust choice: most-visited arm (UCB concentrates visits on the best).
    int bestIdx = 0;
    int bestVisits = -1;
    double bestRate = -1;
    for (int i = 0; i < plays.length; i++) {
      final v = visits[i]!;
      final rate = v > 0 ? wins[i]! / v : 0.0;
      if (v > bestVisits || (v == bestVisits && rate > bestRate)) {
        bestVisits = v;
        bestRate = rate;
        bestIdx = i;
      }
    }

    return plays[bestIdx];
  }

  int _selectPlay(int count, Map<int, double> wins, Map<int, int> visits, int totalSims) {
    if (totalSims < count) return totalSims; // visit each at least once

    double bestUcb = double.negativeInfinity;
    int bestIdx = 0;
    final logTotal = log(totalSims + 1);

    for (int i = 0; i < count; i++) {
      final v = visits[i]!;
      if (v == 0) return i;
      final winRate = wins[i]! / v;
      final exploration = sqrt(2 * logTotal / v);
      final ucb = winRate + exploration;
      if (ucb > bestUcb) {
        bestUcb = ucb;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void _randomizeUnknownHands(int botSeat, Random rng) {
    // Collect all tiles not yet played and not in the bot's hand.
    final allTiles = <DominoTile>[];
    for (int a = 0; a <= 6; a++) {
      for (int b = a; b <= 6; b++) {
        allTiles.add(DominoTile(a, b));
      }
    }

    final botHand = _hands[botSeat];
    final known = <DominoTile>{...botHand, ..._playedTiles};
    final unknown = allTiles.where((t) => !known.contains(t)).toList();
    unknown.shuffle(rng);

    // Redistribute unknown tiles to the other seats, honouring what we
    // know about values they cannot hold.
    for (int i = 0; i < playerCount; i++) {
      if (i == botSeat) continue;
      final handSize = _hands[i].length;
      final newHand = <DominoTile>[];
      final missingVals = _knownMissing[i] ?? const <int>{};

      for (int j = 0; j < unknown.length && newHand.length < handSize; j++) {
        final t = unknown[j];
        if (missingVals.contains(t.a) || missingVals.contains(t.b)) continue;
        newHand.add(t);
        unknown.removeAt(j);
        j--;
      }
      while (newHand.length < handSize && unknown.isNotEmpty) {
        newHand.add(unknown.removeAt(0));
      }

      _hands[i] = newHand;
    }

    _boneyard = unknown;
  }

  /// Plays the current round out with a light heuristic policy and returns
  /// the winning entity (-1 for a wash). Stops at the round boundary so the
  /// evaluation signal stays sharp.
  int _roundPlayout(Random rng, int startRound) {
    int safetyCounter = 300;
    while (!matchOver && roundNumber == startRound && safetyCounter-- > 0) {
      final plays = legalPlays();
      if (plays.isNotEmpty) {
        // Prefer doubles and heavy tiles, with a little randomness.
        plays.sort((a, b) {
          if (a.tile.isDouble && !b.tile.isDouble) return -1;
          if (!a.tile.isDouble && b.tile.isDouble) return 1;
          return b.tile.total.compareTo(a.tile.total);
        });
        final topN = plays.length < 3 ? plays.length : 3;
        play(plays[rng.nextInt(topN)]);
      } else if (canDraw) {
        drawTile();
      } else {
        pass();
      }
    }

    final summary = lastRoundSummary;
    if (summary == null || summary.roundNumber != startRound) return -1;
    return summary.winnerEntity ?? -1;
  }

  // ── Info ──────────────────────────────────────────────────────────────────

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('Round $roundNumber | Scores: $scores → $targetScore');
    buf.writeln('Chain: ${chain.join(' ')}');
    buf.writeln('Ends: $leftEnd | $rightEnd');
    for (int i = 0; i < playerCount; i++) {
      buf.writeln('P$i (${_hands[i].length}): ${_hands[i].join(' ')}');
    }
    buf.writeln('Boneyard: ${_boneyard.length}');
    buf.writeln('Turn: P$turnSeat | MatchWinner: $matchWinner');
    return buf.toString();
  }
}

// ── Isolate entry point ──────────────────────────────────────────────────────
// Top-level so it can be used with Flutter's `compute()`.

Map<String, dynamic>? dominoBestPlayIsolate(Map<String, dynamic> args) {
  final engine =
      DominoEngine.fromState(Map<String, dynamic>.from(args['state'] as Map));
  final play = engine.bestBotPlay(
      simulations: (args['simulations'] as num?)?.toInt() ?? 500);
  if (play == null) return null;
  return {
    'a': play.tile.a,
    'b': play.tile.b,
    'end': play.end.index,
  };
}
