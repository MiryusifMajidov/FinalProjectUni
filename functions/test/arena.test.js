'use strict';
// Run with: npm test (inside functions/). Pure helpers only — no emulator.
const test = require('node:test');
const assert = require('node:assert');
const { _internal: a } = require('../arena');
const { POOL, pickBots } = require('../bots');
const { _internal: g } = require('../guest');

const MIN = 60 * 1000;
const slot = Date.UTC(2026, 10, 4, 14, 0, 0);

// ── Schedule ─────────────────────────────────────────────────────────────────

test('live arena ids are one per game per 30-minute slot', () => {
  assert.strictEqual(a.slotId('chess', slot), 'live_chess_202611041400');
  assert.strictEqual(a.slotId('domino', slot + 30 * MIN), 'live_domino_202611041430');
  assert.notStrictEqual(a.slotId('chess', slot), a.slotId('checkers', slot));
});

test('exactly two arenas are live at any moment, plus the next one shortly before it starts', () => {
  for (let t = slot; t < slot + 6 * 60 * MIN; t += 7 * MIN + 13 * 1000) {
    const slots = a.liveSlots(t);
    const live = slots.filter((s) => s <= t && t < s + a.LIVE_DURATION_MIN * MIN);
    assert.strictEqual(live.length, 2, `at ${new Date(t).toISOString()}`);
    const upcoming = slots.filter((s) => s > t);
    const inLead = t % a.SLOT_MS >= a.SLOT_MS - a.LIVE_LEAD_MS;
    assert.strictEqual(upcoming.length, inLead ? 1 : 0);
  }
});

test('the two live arenas of a game never share a name or a clock', () => {
  for (let i = 0; i < 48; i++) {
    const s = slot + i * a.SLOT_MS;
    for (const game of ['chess', 'checkers', 'domino']) {
      const x = a.slotSpec(game, s);
      const y = a.slotSpec(game, s + a.SLOT_MS);
      assert.notStrictEqual(x.nameKey, y.nameKey, `${game} slot ${i} name`);
      assert.notStrictEqual(x.timeControlLabel, y.timeControlLabel, `${game} slot ${i} clock`);
    }
  }
});

test('names and clocks keep changing through the day', () => {
  const names = new Set();
  const clocks = new Set();
  for (let i = 0; i < 48; i++) {
    const s = a.slotSpec('chess', slot + i * a.SLOT_MS);
    names.add(s.nameKey);
    clocks.add(s.timeControlLabel);
  }
  assert.strictEqual(names.size, a.THEMES.length);
  assert.ok(clocks.size >= 8, `only ${clocks.size} chess clocks`);
  assert.ok(a.slotSpec('checkers', slot).rulesKey);
  assert.ok(['draw', 'block'].includes(a.slotSpec('domino', slot).rulesKey));
});

test('bots arrive over time: a third at registration, all within 20 minutes of the start', () => {
  const startsAt = { toMillis: () => slot };
  const t = { botTarget: 30, startsAt };
  assert.strictEqual(a.desiredBots(t, slot - a.LIVE_LEAD_MS), 9);
  assert.strictEqual(a.desiredBots(t, slot), 21);
  assert.strictEqual(a.desiredBots(t, slot + 20 * MIN), 30);
  assert.strictEqual(a.desiredBots(t, slot + 50 * MIN), 30);
  assert.strictEqual(a.desiredBots({ startsAt }, slot), 0);
});

// ── Scoring ──────────────────────────────────────────────────────────────────

test('arena scoring: 2/1/0, double points after two wins in a row', () => {
  let p = {};
  const play = (o) => { p = { ...p, ...a.applyOutcome(p, o) }; return p; };
  play('win');
  assert.deepStrictEqual([p.score, p.streak, p.onFire], [2, 1, false]);
  play('win');
  assert.deepStrictEqual([p.score, p.streak, p.onFire], [4, 2, true]);
  play('win'); // on fire → 4
  assert.strictEqual(p.score, 8);
  play('draw'); // on fire → 2, streak over
  assert.deepStrictEqual([p.score, p.streak, p.onFire], [10, 0, false]);
  play('draw');
  assert.strictEqual(p.score, 11);
  play('loss');
  assert.strictEqual(p.score, 11);
  assert.deepStrictEqual(p.results, ['w2', 'w2', 'w4', 'd2', 'd1', 'l0']);
  assert.deepStrictEqual([p.wins, p.draws, p.losses, p.gamesPlayed], [3, 2, 1, 6]);
});

test('a loss while on fire scores nothing and ends the streak', () => {
  const p = a.applyOutcome({ score: 8, streak: 3, results: [] }, 'loss');
  assert.deepStrictEqual([p.score, p.streak, p.onFire], [8, 0, false]);
});

test('only the latest results are kept', () => {
  const p = a.applyOutcome({ results: Array(40).fill('l0') }, 'win');
  assert.strictEqual(p.results.length, 40);
  assert.strictEqual(p.results[39], 'w2');
});

// ── Bots ─────────────────────────────────────────────────────────────────────

test('the bot pool has 2000 unique, valid bots', () => {
  assert.strictEqual(POOL.length, 2000);
  assert.strictEqual(new Set(POOL.map((b) => b.uid)).size, 2000);
  assert.strictEqual(new Set(POOL.map((b) => b.username.toLowerCase())).size, 2000);
  for (const b of POOL) {
    assert.match(b.username, /^[A-Za-z0-9_]{3,20}$/);
    assert.match(b.countryCode, /^[A-Z]{2}$/);
    assert.ok(b.ratings.chess >= 600 && b.ratings.chess <= 2350);
    assert.ok(b.ratings.domino >= 150 && b.ratings.domino <= 900);
  }
});

test('pickBots skips bots already in the arena and uses the game\'s rating', () => {
  const taken = new Set(POOL.slice(0, 1990).map((b) => b.uid));
  const bots = pickBots('checkers', 30, taken);
  assert.strictEqual(bots.length, 10); // only ten are left
  assert.ok(bots.every((b) => !taken.has(b.uid)));
  const byUid = new Map(POOL.map((b) => [b.uid, b]));
  for (const b of bots) assert.strictEqual(b.rating, byUid.get(b.uid).ratings.checkers);
  assert.strictEqual(new Set(pickBots('chess', 25).map((b) => b.uid)).size, 25);
});

test('bot games last about as long as a real game', () => {
  for (let i = 0; i < 200; i++) {
    const bullet = a.gameMs({ gameType: 'chess', timeSeconds: 60 });
    const rapid = a.gameMs({ gameType: 'chess', timeSeconds: 600, incrementSeconds: 5 });
    assert.ok(bullet > 30 * 1000 && bullet < 3 * MIN, `bullet ${bullet}`);
    assert.ok(rapid > 5 * MIN && rapid < 30 * MIN, `rapid ${rapid}`);
    const domino = a.gameMs({ gameType: 'domino' });
    assert.ok(domino >= 4 * MIN && domino <= 10 * MIN);
  }
});

test('the stronger bot wins more often', () => {
  let wins = 0;
  for (let i = 0; i < 4000; i++) {
    if (a.simulate({ gameType: 'chess' }, { rating: 1800 }, { rating: 1200 }) === 'win') wins++;
  }
  assert.ok(wins > 3200, `${wins} wins`);
  assert.ok(['win', 'draw', 'loss'].includes(a.simulate({ gameType: 'domino' }, {}, {})));
  assert.ok(a.activity('bot_0001') >= 0.55 && a.activity('bot_2000') <= 0.95);
});

// ── Guests ───────────────────────────────────────────────────────────────────

test('guest names are user# plus a padded number', () => {
  assert.strictEqual(g.guestName(1), 'user#0001');
  assert.strictEqual(g.guestName(12345), 'user#12345');
});

test('the country comes from the caller\'s IP, or nothing', () => {
  const req = (ip, extra = {}) => ({ headers: { 'x-forwarded-for': `${ip}, 10.0.0.1`, ...extra } });
  assert.strictEqual(g.clientIp(req('85.132.0.1')), '85.132.0.1');
  assert.strictEqual(g.countryFor(req('85.132.0.1')), 'AZ');
  assert.strictEqual(g.countryFor(req('8.8.8.8')), 'US');
  assert.strictEqual(g.countryFor(req('10.1.2.3')), null);
  assert.strictEqual(g.countryFor(req('not-an-ip')), null);
  assert.strictEqual(g.countryFor({ headers: {} }), null);
  assert.strictEqual(g.countryFor(req('8.8.8.8', { 'x-appengine-country': 'tr' })), 'TR');
  assert.strictEqual(g.countryFor(req('8.8.8.8', { 'x-appengine-country': 'ZZ' })), 'US');
});
