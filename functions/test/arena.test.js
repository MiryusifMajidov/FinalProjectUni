'use strict';
// Run with: npm test (inside functions/). Pure helpers only — no emulator.
const test = require('node:test');
const assert = require('node:assert');
const { _internal: a } = require('../arena');

const slot = Date.UTC(2026, 10, 4, 14, 0, 0);

test('hourly arena ids are one per game per UTC hour', () => {
  assert.strictEqual(a.hourlyId('chess', slot), 'hourly_chess_2026110414');
  assert.strictEqual(a.hourlyId('domino', slot + 59 * 60 * 1000), 'hourly_domino_2026110414');
  assert.notStrictEqual(a.hourlyId('chess', slot), a.hourlyId('chess', slot + 3600 * 1000));
});

test('chess rotates time controls and names them by speed', () => {
  const labels = [];
  for (let h = 0; h < 6; h++) labels.push(a.hourlySpec('chess', slot + h * 3600 * 1000));
  assert.strictEqual(new Set(labels.map((s) => s.timeControlLabel)).size, 6);
  for (const s of labels) {
    const kind = s.timeSeconds < 180 ? 'bullet' : s.timeSeconds >= 600 ? 'rapid' : 'blitz';
    assert.strictEqual(s.nameKey, `hourly_arena_${kind}`);
  }
});

test('checkers and domino carry a rules key', () => {
  assert.ok(a.hourlySpec('checkers', slot).rulesKey);
  assert.ok(['draw', 'block'].includes(a.hourlySpec('domino', slot).rulesKey));
});

test('pickBots returns distinct, untaken names with sane ratings', () => {
  const bots = a.pickBots('chess', 12, new Set(['PawnStorm']));
  assert.strictEqual(bots.length, 12);
  assert.strictEqual(new Set(bots.map((b) => b.uid)).size, 12);
  assert.ok(!bots.some((b) => b.username === 'PawnStorm'));
  for (const b of bots) {
    assert.ok(b.uid.startsWith('bot_'));
    assert.ok(b.rating >= 750 && b.rating <= 2050, `rating ${b.rating}`);
  }
  for (const b of a.pickBots('domino', 8)) assert.ok(b.rating >= 160 && b.rating <= 650);
});

test('game length estimate grows with the clock', () => {
  const bullet = a.gameMinutes({ gameType: 'chess', timeSeconds: 60 });
  const blitz = a.gameMinutes({ gameType: 'chess', timeSeconds: 180 });
  const rapid = a.gameMinutes({ gameType: 'chess', timeSeconds: 600 });
  assert.ok(bullet < blitz && blitz < rapid);
  assert.strictEqual(a.gameMinutes({ gameType: 'domino' }), 6);
});
