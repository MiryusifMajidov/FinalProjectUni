'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Arenas, run the way chess.com and lichess run theirs
//
//  • Two live arenas per game at all times. A new one starts every 30 minutes
//    and runs for an hour, so two always overlap; each is listed (and can be
//    joined) 10 minutes before it starts. Every slot has a different name and
//    time control / ruleset, and a different crowd of bots.
//  • Join whenever you like and play as many games as you can: a win is worth
//    2 points, a draw 1, a loss 0. Two wins in a row put you "on fire": every
//    game then scores double (4 / 2) until you fail to win one.
//  • Bots from bots.js — always shown with a BOT badge, never in the world
//    ranking — fill every arena and play each other, so there is always an
//    opponent and the standings keep moving.
//  • A player's own arena waits two minutes for people to join, then fills
//    the empty seats with bots and starts by itself.
//
//  arenaTick          — every minute: creates the live arenas, starts and
//                       closes arenas on time, adds bots, plays bot games and
//                       cleans up old arenas.
//  onArenaCreated     — a player created an arena: it starts two minutes
//                       later (the tick is the fallback if this fails).
//  startArenaNow      — the creator's "Start now".
//  reportArenaResult  — the only way a player's score changes; clients may
//                       not write participant documents.
//
// Everything here runs with the Admin SDK and so bypasses the security rules.
// ─────────────────────────────────────────────────────────────────────────────

const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { pickBots } = require('./bots');

const db = () => getFirestore();

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

// ── Live (server-run) arenas ─────────────────────────────────────────────────

const LIVE_GAME_TYPES = ['chess', 'checkers', 'domino'];
/** A new live arena starts every 30 minutes … */
const SLOT_MS = 30 * MINUTE;
/** … and runs for an hour, so two are always live. */
const LIVE_DURATION_MIN = 60;
/** Listed and joinable this long before it starts. */
const LIVE_LEAD_MS = 10 * MINUTE;
/** Effectively unlimited, like chess.com arenas. */
const LIVE_MAX_PLAYERS = 500;
const SYSTEM_CREATOR = { uid: 'system', username: 'CheckMate' };

/** [translation key, English fallback]. Rotated so names keep changing. */
const THEMES = [
  ['arena_theme_grand', 'Grand Arena'],
  ['arena_theme_open', 'Open Arena'],
  ['arena_theme_rising', 'Rising Stars Arena'],
  ['arena_theme_champions', 'Champions Arena'],
  ['arena_theme_classic', 'Classic Arena'],
  ['arena_theme_masters', 'Masters Arena'],
  ['arena_theme_friendly', 'Friendly Arena'],
  ['arena_theme_royal', 'Royal Arena'],
  ['arena_theme_golden', 'Golden Arena'],
  ['arena_theme_crown', 'Crown Arena'],
];
const THEME_OFFSET = { chess: 0, checkers: 3, domino: 6 };

// Chess alternates between a fast and a slower rotation, so the two arenas
// that run at the same time are never the same speed.
const CHESS_FAST = ['3+0', '1+0', '3+2', '2+1', '1+1'];
const CHESS_SLOW = ['5+0', '10+0', '5+3', '10+5', '5+2'];
// Labels mirror GameTypeX.checkersVariants in lib/core/models/game_type.dart.
const CHECKERS_VARIANTS = [
  ['standard', 'Standard (8×8)'],
  ['russian', 'Russian (8×8)'],
  ['turkish', 'Turkish'],
  ['brazilian', 'Brazilian'],
  ['international', 'International (10×10)'],
];
const DOMINO_VARIANTS = [
  ['draw', 'Draw · 100'],
  ['block', 'Block · 100'],
];

// ── Player-created arenas ────────────────────────────────────────────────────

/** How long a player's arena waits for people before bots fill it. */
const USER_ARENA_WAIT_MS = 2 * MINUTE;
/** A player may have this many open arenas; further ones are closed. */
const MAX_OPEN_ARENAS_PER_CREATOR = 3;
/** A player's arena starts with about this many players in total … */
const USER_ARENA_FIELD = [8, 12];
/** … and never with fewer bots than this (opponents while people play). */
const USER_ARENA_MIN_BOTS = 3;

// ── Scoring ──────────────────────────────────────────────────────────────────

/** A game still being played when the arena closed counts if reported soon. */
const RESULT_GRACE_MS = 10 * MINUTE;
/** Two reports from one player closer than this are rejected. */
const MIN_RESULT_GAP_MS = 15 * 1000;
/** Per-game point codes kept for the standings ("w2", "w4", "d1", "l0"…). */
const RESULTS_KEPT = 40;
const OUTCOMES = ['win', 'draw', 'loss'];

// ── Small helpers ────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const randInt = (lo, hi) => lo + Math.floor(Math.random() * (hi - lo + 1));
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const millis = (ts) => (ts && typeof ts.toMillis === 'function' ? ts.toMillis() : 0);
const opposite = (o) => (o === 'win' ? 'loss' : o === 'loss' ? 'win' : 'draw');
const roster = (t) => (Array.isArray(t.bots) ? t.bots : []);

function parseTc(label) {
  const [m, i] = String(label || '5+0').split('+');
  const mins = parseInt(m, 10);
  const inc = parseInt(i, 10);
  return {
    timeSeconds: (Number.isFinite(mins) ? mins : 5) * 60,
    incrementSeconds: Number.isFinite(inc) ? inc : 0,
  };
}

/**
 * The participant fields after one more game, with chess.com / lichess arena
 * scoring: 2 for a win, 1 for a draw; once the previous two games were both
 * wins ("on fire") a win scores 4 and a draw 2. Anything but a win ends the
 * streak. [p] is the participant document as it is now.
 */
function applyOutcome(p, outcome) {
  const streak = Number(p.streak) || 0;
  const onFire = streak >= 2;
  const points = outcome === 'win' ? (onFire ? 4 : 2) : outcome === 'draw' ? (onFire ? 2 : 1) : 0;
  const nextStreak = outcome === 'win' ? streak + 1 : 0;
  const results = (Array.isArray(p.results) ? p.results : [])
    .concat(`${outcome[0]}${points}`)
    .slice(-RESULTS_KEPT);
  return {
    score: (Number(p.score) || 0) + points,
    wins: (Number(p.wins) || 0) + (outcome === 'win' ? 1 : 0),
    draws: (Number(p.draws) || 0) + (outcome === 'draw' ? 1 : 0),
    losses: (Number(p.losses) || 0) + (outcome === 'loss' ? 1 : 0),
    gamesPlayed: (Number(p.gamesPlayed) || 0) + 1,
    streak: nextStreak,
    onFire: nextStreak >= 2,
    results,
  };
}

function botParticipant(bot) {
  return {
    uid: bot.uid,
    username: bot.username,
    rating: bot.rating,
    countryCode: bot.countryCode || null,
    isBot: true,
    score: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    gamesPlayed: 0,
    streak: 0,
    onFire: false,
    results: [],
    joinedAt: FieldValue.serverTimestamp(),
  };
}

/** Adds [count] new bots (participant docs, counter, roster) in one batch. */
async function addBots(tRef, t, count) {
  const bots = pickBots(t.gameType || 'chess', count, new Set(roster(t).map((b) => b.uid)));
  if (!bots.length) return [];
  const batch = db().batch();
  for (const bot of bots) {
    batch.set(tRef.collection('participants').doc(bot.uid), botParticipant(bot));
  }
  batch.update(tRef, {
    participantCount: FieldValue.increment(bots.length),
    bots: FieldValue.arrayUnion(...bots),
  });
  await batch.commit();
  return bots;
}

/** Leader first; ties go to more wins, then to fewer games. */
async function computeWinner(tRef) {
  const top = await tRef
    .collection('participants')
    .orderBy('score', 'desc')
    .limit(10)
    .get();
  const rows = top.docs.map((d) => ({ id: d.id, ...d.data() }));
  rows.sort((a, b) =>
    (b.score || 0) - (a.score || 0) ||
    (b.wins || 0) - (a.wins || 0) ||
    (a.gamesPlayed || 0) - (b.gamesPlayed || 0));
  const w = rows[0];
  if (!w || !w.score) return { winnerUid: null, winnerUsername: null };
  return { winnerUid: w.uid || w.id, winnerUsername: w.username || '' };
}

async function finish(tRef) {
  const winner = await computeWinner(tRef);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists || snap.data().status === 'finished') return;
    tx.update(tRef, {
      status: 'finished',
      finishedAt: FieldValue.serverTimestamp(),
      botGames: [],
      ...winner,
    });
  });
}

// ── Live arena schedule ──────────────────────────────────────────────────────

function slotId(gameType, slotStartMs) {
  const d = new Date(slotStartMs);
  const pad = (n) => String(n).padStart(2, '0');
  return `live_${gameType}_${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}` +
    `${pad(d.getUTCDate())}${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}`;
}

/** Name, rules and clock of the live arena that starts at [slotStartMs]. */
function slotSpec(gameType, slotStartMs) {
  const n = Math.floor(slotStartMs / SLOT_MS);
  // 7 and 10 share no factor: consecutive slots never get the same name.
  const [nameKey, name] = THEMES[(n * 7 + (THEME_OFFSET[gameType] || 0)) % THEMES.length];
  if (gameType === 'checkers') {
    const [rulesKey, label] = CHECKERS_VARIANTS[n % CHECKERS_VARIANTS.length];
    return { nameKey, name, rulesKey, timeControlLabel: label, ...parseTc('5+0') };
  }
  if (gameType === 'domino') {
    const [rulesKey, label] = DOMINO_VARIANTS[n % DOMINO_VARIANTS.length];
    return { nameKey, name, rulesKey, timeControlLabel: label, ...parseTc('5+0') };
  }
  const list = n % 2 === 0 ? CHESS_FAST : CHESS_SLOW;
  const tc = list[Math.floor(n / 2) % list.length];
  return { nameKey, name, rulesKey: null, timeControlLabel: tc, ...parseTc(tc) };
}

/**
 * Start times of the live arenas that should exist at [nowMs]: the two that
 * are running and, in the last 10 minutes of a slot, the next one.
 */
function liveSlots(nowMs) {
  const current = Math.floor(nowMs / SLOT_MS) * SLOT_MS;
  const slots = [current - SLOT_MS, current];
  if (nowMs >= current + SLOT_MS - LIVE_LEAD_MS) slots.push(current + SLOT_MS);
  return slots.filter((s) => s + LIVE_DURATION_MIN * MINUTE > nowMs);
}

/** Bots that should have joined by now, out of [target]. */
function desiredBots(t, nowMs) {
  const target = t.botTarget || 0;
  const startsAt = millis(t.startsAt);
  if (!target || !startsAt) return 0;
  if (nowMs < startsAt) {
    // 30 % when registration opens, 70 % by the start …
    const progress = clamp(1 - (startsAt - nowMs) / LIVE_LEAD_MS, 0, 1);
    return Math.round(target * (0.3 + 0.4 * progress));
  }
  // … and the rest join during the first 20 minutes, like late joiners.
  const progress = clamp((nowMs - startsAt) / (20 * MINUTE), 0, 1);
  return Math.round(target * (0.7 + 0.3 * progress));
}

async function createLiveArena(gameType, slotStartMs, nowMs) {
  const spec = slotSpec(gameType, slotStartMs);
  const tRef = db().collection('tournaments').doc(slotId(gameType, slotStartMs));
  const live = nowMs >= slotStartMs;
  const doc = {
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
    maxPlayers: LIVE_MAX_PLAYERS,
    timeControlLabel: spec.timeControlLabel,
    timeSeconds: spec.timeSeconds,
    incrementSeconds: spec.incrementSeconds,
    durationMinutes: LIVE_DURATION_MIN,
    startsAt: Timestamp.fromMillis(slotStartMs),
    endsAt: Timestamp.fromMillis(slotStartMs + LIVE_DURATION_MIN * MINUTE),
    ...(live ? { startedAt: FieldValue.serverTimestamp() } : {}),
    createdAt: FieldValue.serverTimestamp(),
    participantCount: 0,
    bots: [],
    botTarget: gameType === 'chess' ? randInt(18, 36) : randInt(12, 26),
    botsSeeded: true,
    botGames: [],
  };
  try {
    await tRef.create(doc);
  } catch (e) {
    // ALREADY_EXISTS: another tick (or a retry) created it first.
    if (e.code === 6 || /already exists/i.test(String(e.message))) return false;
    throw e;
  }
  const first = desiredBots({ ...doc, startsAt: doc.startsAt }, nowMs);
  await addBots(tRef, doc, first);
  console.log(`[Arena] created ${tRef.id} (${spec.timeControlLabel}, ${doc.botTarget} bots planned)`);
  return true;
}

/** [openIds]: ids of waiting/active arenas, so existing ones cost no read. */
async function ensureLiveArenas(nowMs, openIds) {
  for (const gameType of LIVE_GAME_TYPES) {
    for (const slot of liveSlots(nowMs)) {
      if (openIds.has(slotId(gameType, slot))) continue;
      try {
        await createLiveArena(gameType, slot, nowMs);
      } catch (e) {
        console.error(`[Arena] creating live ${gameType} arena failed:`, e.message);
      }
    }
  }
}

// ── Bot games ────────────────────────────────────────────────────────────────

/** Share of minutes a bot is ready for a new game (some bots play more). */
function activity(uid) {
  const n = parseInt(String(uid).replace(/\D/g, ''), 10) || 0;
  return 0.55 + ((n * 7919) % 41) / 100; // 0.55 … 0.95
}

/** How long a bot game takes, in milliseconds. */
function gameMs(t) {
  if (t.gameType === 'checkers') return (150 + Math.random() * 330) * 1000;
  if (t.gameType === 'domino') return (240 + Math.random() * 360) * 1000;
  const base = t.timeSeconds || 300;
  const inc = t.incrementSeconds || 0;
  return (2 * (base + 40 * inc) * (0.35 + Math.random() * 0.6) + 10 + Math.random() * 30) * 1000;
}

/** The result for [a] against [b], from their ratings. */
function simulate(t, a, b) {
  const scale = t.gameType === 'chess' ? 400 : 250;
  const expected = 1 / (1 + Math.pow(10, ((b.rating || 0) - (a.rating || 0)) / scale));
  const drawRate = t.gameType === 'domino' ? 0.03 : t.gameType === 'checkers' ? 0.15 : 0.1;
  const pWin = Math.max(0, expected - drawRate / 2);
  const r = Math.random();
  return r < pWin ? 'win' : r < pWin + drawRate ? 'draw' : 'loss';
}

/** Scores a finished bot-vs-bot game for both bots. */
async function settleBotGame(tRef, g) {
  const aRef = tRef.collection('participants').doc(g.a);
  const bRef = tRef.collection('participants').doc(g.b);
  await db().runTransaction(async (tx) => {
    const [aSnap, bSnap] = await Promise.all([tx.get(aRef), tx.get(bRef)]);
    if (!aSnap.exists || !bSnap.exists) return;
    tx.update(aRef, applyOutcome(aSnap.data(), g.oa));
    tx.update(bRef, applyOutcome(bSnap.data(), opposite(g.oa)));
  });
}

/**
 * Scores the bot games that have finished and pairs the free bots for new
 * ones. Like arena pairing, bots meet opponents of similar rating. A game is
 * only started if it can end before the arena does.
 */
async function playBotGames(tRef, t, bots, nowMs, endsAtMs) {
  const pending = Array.isArray(t.botGames) ? t.botGames : [];
  const due = pending.filter((g) => g.at <= nowMs);
  const running = pending.filter((g) => g.at > nowMs);

  const settled = await Promise.allSettled(due.map((g) => settleBotGame(tRef, g)));
  settled.forEach((s) => {
    if (s.status === 'rejected') console.warn(`[Arena] bot game in ${tRef.id}:`, s.reason?.message);
  });

  const busy = new Set(running.flatMap((g) => [g.a, g.b]));
  const spread = t.gameType === 'chess' ? 300 : 120;
  const ready = bots
    .filter((b) => !busy.has(b.uid) && Math.random() < activity(b.uid))
    .map((b) => ({ bot: b, key: (b.rating || 0) + (Math.random() - 0.5) * spread }))
    .sort((x, y) => x.key - y.key)
    .map((x) => x.bot);

  const fresh = [];
  for (let i = 0; i + 1 < ready.length; i += 2) {
    const at = nowMs + gameMs(t);
    if (at > endsAtMs) continue;
    const [a, b] = Math.random() < 0.5 ? [ready[i], ready[i + 1]] : [ready[i + 1], ready[i]];
    fresh.push({ a: a.uid, b: b.uid, oa: simulate(t, a, b), at: Math.round(at) });
  }
  if (due.length || fresh.length) {
    await tRef.update({ botGames: running.concat(fresh) });
  }
}

// ── Per-arena tick ───────────────────────────────────────────────────────────

/** A live arena whose start time has come: waiting → active, once. */
async function activateLive(tRef) {
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists) return;
    const t = snap.data();
    if (t.status !== 'waiting') return;
    const startsAt = millis(t.startsAt) || Date.now();
    tx.update(tRef, {
      status: 'active',
      startedAt: FieldValue.serverTimestamp(),
      // Keep the published schedule even if this tick ran late.
      endsAt: t.endsAt || Timestamp.fromMillis(startsAt + (t.durationMinutes || LIVE_DURATION_MIN) * MINUTE),
    });
  });
}

/**
 * Starts a player's arena: fills the empty seats with bots and goes live.
 * An arena nobody stayed in is closed instead. Returns null when it was not
 * waiting any more (someone else started it).
 */
async function startUserArena(tRef) {
  return db().runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    if (!snap.exists) return null;
    const t = snap.data();
    if (t.status !== 'waiting') return null;

    const count = t.participantCount || 0;
    const humans = Math.max(0, count - roster(t).length);
    if (humans === 0) {
      tx.update(tRef, {
        status: 'finished',
        cancelled: true,
        finishedAt: FieldValue.serverTimestamp(),
        winnerUid: null,
        winnerUsername: null,
      });
      return { started: false, cancelled: true };
    }

    const room = Math.max(0, (t.maxPlayers || 16) - count);
    const want = Math.max(USER_ARENA_MIN_BOTS, randInt(...USER_ARENA_FIELD) - humans);
    const bots = pickBots(t.gameType || 'chess', Math.min(room, want),
      new Set(roster(t).map((b) => b.uid)));
    for (const bot of bots) {
      tx.set(tRef.collection('participants').doc(bot.uid), botParticipant(bot));
    }
    tx.update(tRef, {
      status: 'active',
      startedAt: FieldValue.serverTimestamp(),
      endsAt: Timestamp.fromMillis(Date.now() + (t.durationMinutes || 30) * MINUTE),
      botsSeeded: true,
      botGames: [],
      ...(bots.length
        ? { participantCount: FieldValue.increment(bots.length), bots: FieldValue.arrayUnion(...bots) }
        : {}),
    });
    return { started: true, humans, bots: bots.length };
  });
}

async function tickWaiting(doc, nowMs) {
  const t = doc.data();
  const tRef = doc.ref;
  const startsAt = millis(t.startsAt);

  if (t.isSystem) {
    if (startsAt && startsAt <= nowMs) {
      await activateLive(tRef);
      return;
    }
    const missing = desiredBots(t, nowMs) - roster(t).length;
    if (missing > 0) await addBots(tRef, t, missing);
    return;
  }

  // A player's arena. onArenaCreated normally starts it on time; this is the
  // fallback for a failed or never-delivered trigger.
  const createdAt = millis(t.createdAt);
  if (createdAt && nowMs - createdAt > 2 * HOUR) {
    await tRef.update({
      status: 'finished',
      cancelled: true,
      finishedAt: FieldValue.serverTimestamp(),
    });
    return;
  }
  const due = startsAt || (createdAt ? createdAt + USER_ARENA_WAIT_MS : 0);
  if (due && due + 30 * 1000 <= nowMs) await startUserArena(tRef);
}

async function tickActive(doc, nowMs) {
  const t = doc.data();
  const tRef = doc.ref;
  const endsAt = millis(t.endsAt);

  if (!endsAt || endsAt <= nowMs) {
    // Score the bot games that ended in time, then close the arena.
    const pending = Array.isArray(t.botGames) ? t.botGames : [];
    await Promise.allSettled(pending.filter((g) => g.at <= (endsAt || nowMs))
      .map((g) => settleBotGame(tRef, g)));
    await finish(tRef);
    console.log(`[Arena] finished ${doc.id}`);
    return;
  }

  let bots = roster(t);
  if (t.isSystem) {
    const missing = desiredBots(t, nowMs) - bots.length;
    if (missing > 0) bots = bots.concat(await addBots(tRef, t, missing));
  }
  if (bots.length >= 2) await playBotGames(tRef, t, bots, nowMs, endsAt);
}

/**
 * Deletes live arenas a day after they finished and players' arenas a week
 * after, so the finished list (and the database) stays small.
 */
async function cleanupFinishedArenas(nowMs) {
  const snap = await db()
    .collection('tournaments')
    .where('status', '==', 'finished')
    .where('finishedAt', '<', Timestamp.fromMillis(nowMs - 24 * HOUR))
    .orderBy('finishedAt')
    .limit(60)
    .get();
  let removed = 0;
  for (const d of snap.docs) {
    const t = d.data();
    if (!t.isSystem && nowMs - millis(t.finishedAt) < 7 * 24 * HOUR) continue;
    try {
      await db().recursiveDelete(d.ref);
      removed++;
    } catch (e) {
      console.warn(`[Arena] cleanup of ${d.id} failed:`, e.message);
    }
  }
  if (removed) console.log(`[Arena] cleaned up ${removed} finished arenas`);
}

// ── Exports ──────────────────────────────────────────────────────────────────

exports.arenaTick = onSchedule(
  { schedule: 'every 1 minutes', timeoutSeconds: 240, memory: '256MiB', maxInstances: 1 },
  async () => {
    const nowMs = Date.now();
    const open = await db()
      .collection('tournaments')
      .where('status', 'in', ['waiting', 'active'])
      .get();

    await ensureLiveArenas(nowMs, new Set(open.docs.map((d) => d.id)));

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
        await cleanupFinishedArenas(nowMs);
      } catch (e) {
        console.error('[Arena] cleanup failed:', e.message);
      }
    }
  },
);

exports.onArenaCreated = onDocumentCreated(
  { document: 'tournaments/{tournamentId}', timeoutSeconds: 300 },
  async (event) => {
    const snap = event.data;
    const t = snap?.data();
    if (!t || t.isSystem || t.status !== 'waiting') return;

    // Spam guard: every player arena gets bots, so cap how many one player
    // can have open at a time.
    if (t.creatorUid) {
      const mine = await db()
        .collection('tournaments')
        .where('creatorUid', '==', t.creatorUid)
        .get();
      const open = mine.docs.filter((d) => ['waiting', 'active'].includes(d.data().status));
      if (open.length > MAX_OPEN_ARENAS_PER_CREATOR) {
        await snap.ref.update({
          status: 'finished',
          cancelled: true,
          finishedAt: FieldValue.serverTimestamp(),
        }).catch(() => {});
        console.log(`[Arena] ${event.params.tournamentId}: creator has ${open.length} open arenas, closed`);
        return;
      }
    }

    const startsAt = (millis(t.createdAt) || Date.now()) + USER_ARENA_WAIT_MS;
    try {
      await snap.ref.update({ startsAt: Timestamp.fromMillis(startsAt) });
    } catch (e) {
      return; // deleted already
    }
    const wait = startsAt - Date.now();
    if (wait > 0) await sleep(wait);
    const res = await startUserArena(snap.ref);
    console.log(`[Arena] ${event.params.tournamentId}:`, JSON.stringify(res));
  },
);

exports.startArenaNow = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');
  const { tournamentId } = request.data ?? {};
  if (typeof tournamentId !== 'string' || !tournamentId || tournamentId.includes('/')) {
    throw new HttpsError('invalid-argument', 'tournamentId required');
  }
  const tRef = db().collection('tournaments').doc(tournamentId);
  const snap = await tRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Arena not found');
  const t = snap.data();
  if (t.isSystem || t.creatorUid !== uid) {
    throw new HttpsError('permission-denied', 'Only the creator can start it');
  }
  return (await startUserArena(tRef)) ?? { started: false };
});

exports.reportArenaResult = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Login required');

  const { tournamentId, gameId, outcome, opponentUid } = request.data ?? {};
  if (typeof tournamentId !== 'string' || !tournamentId || tournamentId.includes('/') ||
      typeof gameId !== 'string' || !gameId || gameId.includes('/')) {
    throw new HttpsError('invalid-argument', 'tournamentId and gameId required');
  }
  if (!OUTCOMES.includes(outcome)) {
    throw new HttpsError('invalid-argument', 'outcome must be win, draw or loss');
  }
  if (opponentUid !== undefined && opponentUid !== null &&
      (typeof opponentUid !== 'string' || !opponentUid ||
       opponentUid.includes('/') || opponentUid === uid)) {
    throw new HttpsError('invalid-argument', 'bad opponentUid');
  }

  const tRef = db().collection('tournaments').doc(tournamentId);
  const meRef = tRef.collection('participants').doc(uid);
  const resultRef = tRef.collection('results').doc(gameId);
  const oppRef = opponentUid ? tRef.collection('participants').doc(opponentUid) : null;

  const res = await db().runTransaction(async (tx) => {
    const [tSnap, resultSnap, meSnap, oppSnapRaw] = await Promise.all([
      tx.get(tRef), tx.get(resultRef), tx.get(meRef), oppRef ? tx.get(oppRef) : null,
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
    const oppSnap = oppSnapRaw && oppSnapRaw.exists ? oppSnapRaw : null;
    if (oppSnap && oppSnap.data().isBot !== true) {
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

    const mine = applyOutcome(meSnap.data(), myOutcome);
    tx.create(resultRef, {
      reporterUid: uid,
      opponentUid: oppSnap ? opponentUid : null,
      outcome: myOutcome,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(meRef, { ...mine, lastResultAt: Timestamp.fromMillis(nowMs) });
    if (oppSnap) tx.update(oppRef, applyOutcome(oppSnap.data(), opposite(myOutcome)));
    return {
      counted: true,
      outcome: myOutcome,
      points: mine.score - (Number(meSnap.data().score) || 0),
      onFire: mine.onFire,
      finished: t.status === 'finished',
    };
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
  applyOutcome, slotId, slotSpec, liveSlots, desiredBots, gameMs, simulate,
  activity, parseTc, SLOT_MS, LIVE_LEAD_MS, LIVE_DURATION_MIN, THEMES,
};
