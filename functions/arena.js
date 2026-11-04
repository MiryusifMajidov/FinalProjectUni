'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Arena automation
//
//  • arenaTick          — every minute: creates the hourly arenas, trickles
//                         bots into waiting arenas, starts arenas at startsAt,
//                         plays bot-vs-bot games in live arenas, closes arenas
//                         whose time is up, and cleans up old hourly arenas.
//  • onArenaCreated     — a player created an arena: bots join within seconds
//                         and the arena goes live ~30 s later, so nobody sits
//                         in an empty lobby waiting for players who never come.
//  • reportArenaResult  — the only way scores change. Clients may not write
//                         participant documents (the rules never allowed it,
//                         which is why standings used to stay at zero).
//
// Everything here runs with the Admin SDK and therefore bypasses the
// Firestore security rules.
// ─────────────────────────────────────────────────────────────────────────────

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = () => getFirestore();

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

// ── Hourly arenas ────────────────────────────────────────────────────────────

/** Game types that get an arena every hour. Remove one to stop its arenas. */
const HOURLY_GAME_TYPES = ['chess', 'checkers', 'domino'];
/** Registration opens this long before the top of the hour. */
const HOURLY_LEAD_MS = 15 * MINUTE;
/** Hourly arenas run from :00 to :45. */
const HOURLY_DURATION_MIN = 45;
const HOURLY_MAX_PLAYERS = 64;
const SYSTEM_CREATOR = { uid: 'system', username: 'CheckMate' };

// Chess rotates through time controls so every hour feels different.
const CHESS_ROTATION = ['3+0', '5+0', '3+2', '1+0', '5+3', '10+0'];
const CHECKERS_ROTATION = [
  ['standard', 'Standard (8×8)'],
  ['russian', 'Russian (8×8)'],
  ['turkish', 'Turkish'],
  ['brazilian', 'Brazilian'],
  ['international', 'International (10×10)'],
];
const DOMINO_ROTATION = [
  ['draw', 'Draw · 100'],
  ['block', 'Block · 100'],
];

// ── Player-created arenas ────────────────────────────────────────────────────

/** Bots finish joining, and the arena goes live, this long after creation. */
const USER_ARENA_START_DELAY_MS = 30 * 1000;
/** A creator with this many open arenas gets no more bots (spam guard). */
const MAX_OPEN_ARENAS_PER_CREATOR = 3;

// ── Scoring ──────────────────────────────────────────────────────────────────

const POINTS = { win: 2, draw: 1, loss: 0 };
/** A game that was still being played when the clock ran out still counts. */
const RESULT_GRACE_MS = 10 * MINUTE;
/** Two reports from one player closer than this are rejected. */
const MIN_RESULT_GAP_MS = 15 * 1000;

// Mirrors GameTypeX.fakeBotNames in lib/core/models/game_type.dart.
const BOT_NAMES = {
  chess: [
    'NightRider88', 'CastleKing', 'BlitzMaster42', 'QueenSlayer',
    'PawnStorm', 'KnightErrant', 'TacticalGuru', 'OpeningTheory',
    'EndgamePro', 'SilentBishop', 'CheckmateAce', 'ForkMaster99',
    'PinAndWin', 'Grandmaster_X', 'RookLifter', 'MiddleGame77',
    'SicilianKing', 'CatoTheFish', 'IronDefense', 'TacticsWizard',
  ],
  checkers: [
    'JumpKing', 'DoubleJump', 'KingMeNow', 'DiagonalDash',
    'CrownSeeker', 'MultiCapture', 'BackRowHero', 'CornerKing',
    'CheckerChamp', 'DiscMaster', 'KingHunter', 'JumpStreak',
    'CaptureQueen', 'BoardSweeper', 'RedDisc99', 'DiscSlider',
    'CornerTrap', 'DoubleKing', 'RowRunner', 'JumpForce',
  ],
  domino: [
    'BoneyardKing', 'TileShark', 'DoubleSixer', 'PipCounter',
    'DominoWiz', 'TileChain', 'BlockMaster', 'SpinnerKing',
    'DrawPile', 'TableRunner', 'DotMatrix', 'BoneYard88',
    'TileSnap', 'EndGame99', 'ChainLink', 'PipTracker',
    'BlockDrop', 'TileMaster', 'DominoAce', 'SnapPlay',
  ],
};

// ── Small helpers ────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const randInt = (lo, hi) => lo + Math.floor(Math.random() * (hi - lo + 1));
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const millis = (ts) => (ts && typeof ts.toMillis === 'function' ? ts.toMillis() : 0);

function gaussian() {
  // Box–Muller; good enough for spreading bot ratings.
  let u = 0;
  let v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
}

function parseTc(label) {
  const [m, i] = String(label || '5+0').split('+');
  const mins = parseInt(m, 10);
  const inc = parseInt(i, 10);
  return {
    timeSeconds: (Number.isFinite(mins) ? mins : 5) * 60,
    incrementSeconds: Number.isFinite(inc) ? inc : 0,
  };
}

/** Normal around [mean], redrawn (not clamped) until inside [lo, hi]. */
function boundedNormal(mean, sd, lo, hi) {
  for (let i = 0; i < 20; i++) {
    const v = Math.round(mean + gaussian() * sd);
    if (v >= lo && v <= hi) return v;
  }
  return Math.round(mean);
}

function botRating(gameType) {
  if (gameType === 'chess') return boundedNormal(1180, 230, 750, 2050);
  // Checkers and domino use points that start at 300.
  return boundedNormal(310, 90, 160, 650);
}

/** Picks [count] bots whose names are not already in [taken]. */
function pickBots(gameType, count, taken = new Set()) {
  const pool = (BOT_NAMES[gameType] || BOT_NAMES.chess).filter((n) => !taken.has(n));
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, Math.max(0, count)).map((username) => ({
    uid: `bot_${username.toLowerCase()}`,
    username,
    rating: botRating(gameType),
  }));
}

/** Rough length of one game, used to pace bot-vs-bot results. */
function gameMinutes(t) {
  if ((t.gameType || 'chess') !== 'chess') return 6;
  const base = t.timeSeconds || 300;
  const inc = t.incrementSeconds || 0;
  return (2 * (base + 40 * inc) * 0.75) / 60 + 0.5;
}

/** Adds one bot participant (doc + count + roster) in a single batch. */
function addBotToBatch(batch, tRef, bot) {
  batch.set(tRef.collection('participants').doc(bot.uid), {
    uid: bot.uid,
    username: bot.username,
    rating: bot.rating,
    isBot: true,
    score: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    gamesPlayed: 0,
    joinedAt: FieldValue.serverTimestamp(),
  });
  batch.update(tRef, {
    participantCount: FieldValue.increment(1),
    bots: FieldValue.arrayUnion(bot),
  });
}

async function addBots(tRef, bots) {
  if (!bots.length) return;
  const batch = db().batch();
  for (const bot of bots) addBotToBatch(batch, tRef, bot);
  await batch.commit();
}

/** waiting → active, once. [endsAtMs] defaults to now + duration. */
async function activate(tRef, endsAtMs) {
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists) return;
    const t = snap.data();
    if (t.status !== 'waiting') return;
    const end = endsAtMs || Date.now() + (t.durationMinutes || 30) * MINUTE;
    tx.update(tRef, {
      status: 'active',
      startedAt: FieldValue.serverTimestamp(),
      endsAt: Timestamp.fromMillis(end),
    });
  });
}

/** Writes the current leader onto the tournament document. */
async function computeWinner(tRef) {
  const top = await tRef
    .collection('participants')
    .orderBy('score', 'desc')
    .limit(1)
    .get();
  if (top.empty) return { winnerUid: null, winnerUsername: null };
  const w = top.docs[0].data();
  if (!w.score) return { winnerUid: null, winnerUsername: null };
  return { winnerUid: w.uid || top.docs[0].id, winnerUsername: w.username || '' };
}

async function finish(tRef) {
  const winner = await computeWinner(tRef);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists || snap.data().status === 'finished') return;
    tx.update(tRef, {
      status: 'finished',
      finishedAt: FieldValue.serverTimestamp(),
      ...winner,
    });
  });
}

// ── Hourly creation ──────────────────────────────────────────────────────────

function hourlyId(gameType, slotStartMs) {
  const d = new Date(slotStartMs);
  const pad = (n) => String(n).padStart(2, '0');
  return `hourly_${gameType}_${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}` +
    `${pad(d.getUTCDate())}${pad(d.getUTCHours())}`;
}

function hourlySpec(gameType, slotStartMs) {
  const hourIndex = Math.floor(slotStartMs / HOUR);
  if (gameType === 'checkers') {
    const [key, label] = CHECKERS_ROTATION[hourIndex % CHECKERS_ROTATION.length];
    return { nameKey: 'hourly_arena_checkers', name: 'Hourly Checkers Arena',
      rulesKey: key, timeControlLabel: label, ...parseTc('5+0') };
  }
  if (gameType === 'domino') {
    const [key, label] = DOMINO_ROTATION[hourIndex % DOMINO_ROTATION.length];
    return { nameKey: 'hourly_arena_domino', name: 'Hourly Domino Arena',
      rulesKey: key, timeControlLabel: label, ...parseTc('5+0') };
  }
  const tc = CHESS_ROTATION[hourIndex % CHESS_ROTATION.length];
  const { timeSeconds, incrementSeconds } = parseTc(tc);
  const kind = timeSeconds < 180 ? 'bullet' : timeSeconds >= 600 ? 'rapid' : 'blitz';
  return {
    nameKey: `hourly_arena_${kind}`,
    name: `Hourly ${kind[0].toUpperCase()}${kind.slice(1)} Arena`,
    rulesKey: null,
    timeControlLabel: tc,
    timeSeconds,
    incrementSeconds,
  };
}

async function createHourlyArena(gameType, slotStartMs, nowMs) {
  const spec = hourlySpec(gameType, slotStartMs);
  const tRef = db().collection('tournaments').doc(hourlyId(gameType, slotStartMs));
  const target = randInt(8, 12);
  const live = nowMs >= slotStartMs;
  // A third of the bots are there when registration opens and the rest
  // trickle in until the start (see tickWaiting). An arena created after its
  // start (first deploy mid-hour, or a missed tick) gets them all at once.
  const first = pickBots(gameType, live ? target : Math.ceil(target / 3));
  try {
    await tRef.create({
      name: spec.name,
      nameKey: spec.nameKey,
      description: null,
      gameType,
      ...(spec.rulesKey ? { rulesKey: spec.rulesKey } : {}),
      format: 'arena',
      status: live ? 'active' : 'waiting',
      isSystem: true,
      creatorUid: SYSTEM_CREATOR.uid,
      creatorUsername: SYSTEM_CREATOR.username,
      maxPlayers: HOURLY_MAX_PLAYERS,
      timeControlLabel: spec.timeControlLabel,
      timeSeconds: spec.timeSeconds,
      incrementSeconds: spec.incrementSeconds,
      durationMinutes: HOURLY_DURATION_MIN,
      startsAt: Timestamp.fromMillis(slotStartMs),
      ...(live
        ? { endsAt: Timestamp.fromMillis(slotStartMs + HOURLY_DURATION_MIN * MINUTE) }
        : {}),
      createdAt: FieldValue.serverTimestamp(),
      participantCount: 0,
      bots: [],
      botTarget: target,
      botsSeeded: true,
    });
  } catch (e) {
    // ALREADY_EXISTS: another tick (or a retry) created it first.
    if (e.code === 6 || /already exists/i.test(String(e.message))) return false;
    throw e;
  }
  await addBots(tRef, first);
  console.log(`[Arena] created ${tRef.id} (${spec.timeControlLabel}, ${target} bots planned)`);
  return true;
}

/**
 * Makes sure the arena for the current hour (until it ends) and for the next
 * hour (from 15 minutes before it starts) exist. [openIds] holds the ids of
 * waiting/active arenas, so existing ones cost no extra read.
 */
async function ensureHourlyArenas(nowMs, openIds) {
  const current = Math.floor(nowMs / HOUR) * HOUR;
  const slots = [];
  if (nowMs < current + HOURLY_DURATION_MIN * MINUTE) slots.push(current);
  if (nowMs >= current + HOUR - HOURLY_LEAD_MS) slots.push(current + HOUR);
  for (const gameType of HOURLY_GAME_TYPES) {
    for (const slot of slots) {
      if (openIds.has(hourlyId(gameType, slot))) continue;
      try {
        await createHourlyArena(gameType, slot, nowMs);
      } catch (e) {
        console.error(`[Arena] creating hourly ${gameType} failed:`, e.message);
      }
    }
  }
}

// ── Per-arena tick ───────────────────────────────────────────────────────────

async function tickWaiting(doc, nowMs) {
  const t = doc.data();
  const tRef = doc.ref;
  const startsAt = millis(t.startsAt);
  const createdAt = millis(t.createdAt);
  const bots = Array.isArray(t.bots) ? t.bots : [];

  if (t.isSystem) {
    if (startsAt && startsAt <= nowMs) {
      // Keep the published schedule: end at :45 even if this tick ran late.
      await activate(tRef, startsAt + (t.durationMinutes || HOURLY_DURATION_MIN) * MINUTE);
      return;
    }
    const missing = (t.botTarget || 10) - bots.length;
    if (missing > 0 && startsAt) {
      // Spread the remaining joins over the minutes left before the start.
      const minutesLeft = Math.max(1, Math.ceil((startsAt - nowMs) / MINUTE));
      const perTick = missing / minutesLeft;
      const n = Math.floor(perTick) + (Math.random() < perTick % 1 ? 1 : 0);
      if (n > 0) {
        await addBots(tRef, pickBots(t.gameType, Math.min(n, missing),
          new Set(bots.map((b) => b.username))));
      }
    }
    return;
  }

  // Player-created arena.
  if (startsAt && startsAt <= nowMs) {
    await activate(tRef);
    return;
  }
  // Abandoned long ago (e.g. created before arenas started themselves, and
  // nobody ever pressed Start): close it rather than revive it with bots.
  if (createdAt && nowMs - createdAt > 2 * HOUR) {
    await tRef.update({ status: 'finished', finishedAt: FieldValue.serverTimestamp() });
    return;
  }
  // onArenaCreated normally does this within seconds; this is the fallback
  // for a failed or never-delivered trigger.
  if (!t.botsSeeded && createdAt && nowMs - createdAt > 90 * 1000) {
    await seedUserArena(tRef, t, { paced: false });
  }
}

async function tickActive(doc, nowMs) {
  const t = doc.data();
  const tRef = doc.ref;
  const endsAt = millis(t.endsAt);

  if (!endsAt || endsAt <= nowMs) {
    await finish(tRef);
    console.log(`[Arena] finished ${doc.id}`);
    return;
  }

  let bots = Array.isArray(t.bots) ? t.bots : [];

  // An hourly arena that went live short of its bots (e.g. a tick was missed
  // during registration) gets the rest now.
  if (t.isSystem && bots.length < (t.botTarget || 0)) {
    const extra = pickBots(t.gameType, t.botTarget - bots.length,
      new Set(bots.map((b) => b.username)));
    await addBots(tRef, extra);
    bots = bots.concat(extra);
  }

  // Bot-vs-bot games, paced so each bot plays about one game per game-length.
  if (bots.length < 2) return;
  const expected = bots.length / 2 / gameMinutes(t);
  let games = Math.floor(expected) + (Math.random() < expected % 1 ? 1 : 0);
  games = Math.min(games, Math.floor(bots.length / 2));
  if (games <= 0) return;

  const shuffled = [...bots].sort(() => Math.random() - 0.5);
  const drawRate = t.gameType === 'domino' ? 0.02 : t.gameType === 'checkers' ? 0.1 : 0.12;
  const batch = db().batch();
  for (let g = 0; g < games; g++) {
    const a = shuffled[2 * g];
    const b = shuffled[2 * g + 1];
    const expectedA = 1 / (1 + Math.pow(10, ((b.rating || 1200) - (a.rating || 1200)) / 400));
    const r = Math.random();
    const pWinA = Math.max(0, expectedA - drawRate / 2);
    const outcomeA = r < pWinA ? 'win' : r < pWinA + drawRate ? 'draw' : 'loss';
    const outcomeB = outcomeA === 'win' ? 'loss' : outcomeA === 'loss' ? 'win' : 'draw';
    batch.update(tRef.collection('participants').doc(a.uid), scoreUpdate(outcomeA));
    batch.update(tRef.collection('participants').doc(b.uid), scoreUpdate(outcomeB));
  }
  try {
    await batch.commit();
  } catch (e) {
    // A bot document is missing (e.g. deleted by hand) — skip this round.
    console.warn(`[Arena] bot round in ${doc.id} skipped:`, e.message);
  }
}

function scoreUpdate(outcome) {
  return {
    score: FieldValue.increment(POINTS[outcome]),
    wins: FieldValue.increment(outcome === 'win' ? 1 : 0),
    draws: FieldValue.increment(outcome === 'draw' ? 1 : 0),
    losses: FieldValue.increment(outcome === 'loss' ? 1 : 0),
    gamesPlayed: FieldValue.increment(1),
  };
}

/** Deletes hourly arenas that finished more than two days ago. */
async function cleanupOldSystemArenas(nowMs) {
  const cutoff = nowMs - 48 * HOUR;
  const snap = await db()
    .collection('tournaments')
    .where('isSystem', '==', true)
    .where('status', '==', 'finished')
    .get();
  const old = snap.docs.filter((d) => millis(d.data().endsAt) < cutoff).slice(0, 15);
  for (const d of old) {
    try {
      await db().recursiveDelete(d.ref);
    } catch (e) {
      console.warn(`[Arena] cleanup of ${d.id} failed:`, e.message);
    }
  }
  if (old.length) console.log(`[Arena] cleaned up ${old.length} old hourly arenas`);
}

// ── Player-created arenas: bots + quick start ────────────────────────────────

/**
 * Fills a player's arena with a handful of bots (leaving at least half the
 * seats for people) and schedules the start. With [paced] the bots arrive a
 * few seconds apart, so the creator watches the lobby fill up.
 */
async function seedUserArena(tRef, t, { paced }) {
  const claimed = await db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists) return false;
    const cur = snap.data();
    if (cur.botsSeeded || cur.status !== 'waiting') return false;
    tx.update(tRef, {
      botsSeeded: true,
      startsAt: Timestamp.fromMillis(Date.now() + (paced ? USER_ARENA_START_DELAY_MS : 20 * 1000)),
    });
    return true;
  });
  if (!claimed) return null;

  // Spam guard: a creator hosting several open arenas gets no extra bots.
  if (t.creatorUid) {
    const open = await db()
      .collection('tournaments')
      .where('creatorUid', '==', t.creatorUid)
      .get();
    const openCount = open.docs.filter((d) =>
      ['waiting', 'active'].includes(d.data().status)).length;
    if (openCount > MAX_OPEN_ARENAS_PER_CREATOR) {
      console.log(`[Arena] ${tRef.id}: creator has ${openCount} open arenas, no bots`);
      return [];
    }
  }

  const maxPlayers = t.maxPlayers || 16;
  const count = Math.min(Math.floor(maxPlayers / 2), randInt(4, 7));
  const bots = pickBots(t.gameType || 'chess', count);
  if (!paced) {
    await addBots(tRef, bots);
    return bots;
  }
  for (const bot of bots) {
    await addBots(tRef, [bot]);
    await sleep(randInt(1800, 3800));
  }
  return bots;
}

// ── Exports ──────────────────────────────────────────────────────────────────

exports.arenaTick = onSchedule(
  { schedule: 'every 1 minutes', timeoutSeconds: 120, memory: '256MiB', maxInstances: 1 },
  async () => {
    const nowMs = Date.now();
    const open = await db()
      .collection('tournaments')
      .where('status', 'in', ['waiting', 'active'])
      .get();

    await ensureHourlyArenas(nowMs, new Set(open.docs.map((d) => d.id)));

    for (const doc of open.docs) {
      try {
        if (doc.data().status === 'waiting') await tickWaiting(doc, nowMs);
        else await tickActive(doc, nowMs);
      } catch (e) {
        console.error(`[Arena] tick for ${doc.id} failed:`, e.message);
      }
    }

    // Once an hour is plenty for housekeeping.
    if (new Date(nowMs).getUTCMinutes() === 50) {
      try {
        await cleanupOldSystemArenas(nowMs);
      } catch (e) {
        console.error('[Arena] cleanup failed:', e.message);
      }
    }
  },
);

exports.onArenaCreated = onDocumentCreated(
  { document: 'tournaments/{tournamentId}', timeoutSeconds: 120 },
  async (event) => {
    const snap = event.data;
    const t = snap?.data();
    if (!t || t.isSystem || t.status !== 'waiting') return;

    const bots = await seedUserArena(snap.ref, t, { paced: true });
    if (bots === null) return; // someone else already handled it

    const fresh = (await snap.ref.get()).data() || {};
    const wait = millis(fresh.startsAt) - Date.now();
    if (wait > 0) await sleep(wait);
    await activate(snap.ref);
    console.log(`[Arena] ${event.params.tournamentId}: ${bots.length} bots joined, arena live`);
  },
);

exports.reportArenaResult = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { tournamentId, gameId, outcome, opponentUid } = request.data ?? {};
  if (typeof tournamentId !== 'string' || !tournamentId ||
      typeof gameId !== 'string' || !gameId || gameId.includes('/')) {
    throw new HttpsError('invalid-argument', 'tournamentId and gameId required');
  }
  if (!Object.prototype.hasOwnProperty.call(POINTS, outcome)) {
    throw new HttpsError('invalid-argument', 'outcome must be win, draw or loss');
  }
  if (opponentUid !== undefined && opponentUid !== null &&
      (typeof opponentUid !== 'string' || opponentUid.includes('/') || opponentUid === uid)) {
    throw new HttpsError('invalid-argument', 'bad opponentUid');
  }

  const tRef = db().collection('tournaments').doc(tournamentId);
  const meRef = tRef.collection('participants').doc(uid);
  const resultRef = tRef.collection('results').doc(gameId);

  const res = await db().runTransaction(async (tx) => {
    const [tSnap, resultSnap, meSnap] = await Promise.all([
      tx.get(tRef), tx.get(resultRef), tx.get(meRef),
    ]);
    if (!tSnap.exists) throw new HttpsError('not-found', 'Arena not found');
    if (resultSnap.exists) return { counted: false, reason: 'duplicate' };

    const t = tSnap.data();
    const nowMs = Date.now();
    if (t.status === 'waiting') {
      throw new HttpsError('failed-precondition', 'Arena has not started');
    }
    if (nowMs > millis(t.endsAt) + RESULT_GRACE_MS) {
      throw new HttpsError('failed-precondition', 'Arena is over');
    }
    if (!meSnap.exists) {
      throw new HttpsError('permission-denied', 'Not a participant');
    }
    if (nowMs - millis(meSnap.data().lastResultAt) < MIN_RESULT_GAP_MS) {
      throw new HttpsError('resource-exhausted', 'Too many results');
    }

    let myOutcome = outcome;
    let oppSnap = null;
    if (opponentUid) {
      oppSnap = await tx.get(tRef.collection('participants').doc(opponentUid));
      if (!oppSnap.exists) {
        oppSnap = null;
      } else if (oppSnap.data().isBot !== true) {
        // Two people: trust the saved game, not the caller's claim.
        const gameSnap = await tx.get(db().collection('games').doc(gameId));
        const g = gameSnap.exists ? gameSnap.data() : null;
        const players = g ? [g.whiteUid, g.blackUid] : [];
        if (!g || !players.includes(uid) || !players.includes(opponentUid) ||
            !['white', 'black', 'draw'].includes(g.result)) {
          throw new HttpsError('failed-precondition', 'Game result not found');
        }
        myOutcome = g.result === 'draw' ? 'draw'
          : (g.result === 'white') === (g.whiteUid === uid) ? 'win' : 'loss';
      }
    }

    const oppOutcome = myOutcome === 'win' ? 'loss' : myOutcome === 'loss' ? 'win' : 'draw';
    tx.create(resultRef, {
      reporterUid: uid,
      opponentUid: oppSnap ? opponentUid : null,
      outcome: myOutcome,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(meRef, { ...scoreUpdate(myOutcome), lastResultAt: Timestamp.fromMillis(nowMs) });
    if (oppSnap) tx.update(oppSnap.ref, scoreUpdate(oppOutcome));
    return { counted: true, outcome: myOutcome, finished: t.status === 'finished' };
  });

  // A late result can change who won an arena that has already closed.
  if (res.counted && res.finished) {
    try {
      await tRef.update(await computeWinner(tRef));
    } catch (e) {
      console.warn('[Arena] winner refresh failed:', e.message);
    }
  }
  return res;
});

// Exposed for unit tests.
exports._internal = {
  hourlyId, hourlySpec, pickBots, gameMinutes, parseTc, ensureHourlyArenas,
  tickWaiting, tickActive, seedUserArena, activate, finish, computeWinner,
};
