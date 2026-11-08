'use strict';

// Generates the pool of 2500 arena / matchmaking bots.
//
//   node scripts/generate_bot_pool.js
//
// Writes the same list to functions/bot_pool.json (used by the arena
// functions) and assets/data/bots.json (used by the app's matchmaking
// fallback), so a bot has the same name, flag and ratings everywhere.
//
// The first 2000 (bot_0001 … bot_2000) play under their names like any
// player; the 500 after them (bot_2001 … bot_2500) carry a "Bot" badge
// everywhere their name shows (BotPool.isLabelledUid in the app). None of
// them appear in the world ranking: they have no users/ document. The output
// is deterministic (fixed seed) and the labelled bots are drawn after the
// first 2000, so adding them left bot_0001 … bot_2000 unchanged.

const fs = require('fs');
const path = require('path');

const UNLABELLED = 2000;
const LABELLED = 500;
const COUNT = UNLABELLED + LABELLED;
const SEED = 20261104;

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(SEED);
const pick = (list) => list[Math.floor(rand() * list.length)];
const int = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));

function normal() {
  let u = 0;
  let v = 0;
  while (u === 0) u = rand();
  while (v === 0) v = rand();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function boundedNormal(mean, sd, lo, hi) {
  for (let i = 0; i < 30; i++) {
    const v = Math.round(mean + normal() * sd);
    if (v >= lo && v <= hi) return v;
  }
  return Math.round(mean);
}

// Country → weight and a few common first names (ASCII only, so every name
// renders in the app's font and fits the username rules).
const COUNTRIES = {
  AZ: [14, ['Elvin', 'Rauf', 'Kamran', 'Nigar', 'Aysel', 'Murad', 'Orxan', 'Leyla', 'Tural', 'Farid', 'Rashad', 'Gunay', 'Nurlan', 'Sabina']],
  TR: [12, ['Emre', 'Burak', 'Mert', 'Elif', 'Zeynep', 'Can', 'Kerem', 'Deniz', 'Cem', 'Ayse', 'Onur', 'Selin']],
  RU: [10, ['Dmitry', 'Ivan', 'Sergey', 'Olga', 'Anna', 'Nikita', 'Pavel', 'Alexei', 'Maria', 'Artem', 'Egor']],
  US: [9, ['Jake', 'Tyler', 'Emily', 'Chris', 'Ryan', 'Megan', 'Josh', 'Kevin', 'Ashley', 'Matt', 'Brandon']],
  IN: [8, ['Arjun', 'Rohan', 'Priya', 'Vikram', 'Ananya', 'Rahul', 'Karthik', 'Sneha', 'Aditya', 'Neha', 'Varun']],
  DE: [5, ['Lukas', 'Jonas', 'Lena', 'Felix', 'Leon', 'Mia', 'Paul', 'Hannah', 'Tim', 'Max']],
  GB: [4, ['Oliver', 'Harry', 'Jack', 'Amelia', 'George', 'Charlie', 'Sophie', 'James', 'Ella', 'Tom']],
  FR: [4, ['Lucas', 'Hugo', 'Louis', 'Chloe', 'Manon', 'Theo', 'Julien', 'Camille', 'Antoine', 'Ines']],
  ES: [4, ['Pablo', 'Alvaro', 'Lucia', 'Sergio', 'Diego', 'Carmen', 'Javier', 'Marta', 'Raul', 'Elena']],
  BR: [5, ['Joao', 'Pedro', 'Gabriel', 'Ana', 'Rafael', 'Bruna', 'Thiago', 'Larissa', 'Mateus', 'Caio']],
  PK: [4, ['Ali', 'Hamza', 'Usman', 'Ayesha', 'Bilal', 'Fatima', 'Zain', 'Saad', 'Hira', 'Imran']],
  UA: [4, ['Taras', 'Oksana', 'Andriy', 'Bohdan', 'Iryna', 'Mykola', 'Olena', 'Yurii', 'Dmytro', 'Sofiia']],
  KZ: [3, ['Nursultan', 'Aruzhan', 'Dias', 'Aigerim', 'Yerlan', 'Daniyar', 'Madina', 'Askar']],
  GE: [3, ['Giorgi', 'Nino', 'Levan', 'Tamar', 'Davit', 'Luka', 'Mariam', 'Irakli']],
  UZ: [3, ['Jasur', 'Dilnoza', 'Sardor', 'Bekzod', 'Malika', 'Aziz', 'Shahzod', 'Nodira']],
  IR: [4, ['Reza', 'Amir', 'Sara', 'Mehdi', 'Neda', 'Parisa', 'Hossein', 'Arash']],
  IT: [3, ['Marco', 'Luca', 'Giulia', 'Matteo', 'Sofia', 'Andrea', 'Francesca', 'Davide']],
  PL: [3, ['Jakub', 'Kacper', 'Zofia', 'Piotr', 'Michal', 'Ola', 'Bartek', 'Kasia']],
  EG: [3, ['Omar', 'Youssef', 'Ahmed', 'Nour', 'Karim', 'Salma', 'Mostafa', 'Hana']],
  ID: [3, ['Budi', 'Agus', 'Putri', 'Rizky', 'Dewi', 'Andi', 'Siti', 'Fajar']],
  MX: [3, ['Carlos', 'Jose', 'Fernanda', 'Luis', 'Valeria', 'Miguel', 'Ximena', 'Jorge']],
  AR: [2, ['Santiago', 'Martina', 'Facundo', 'Mateo', 'Valentina', 'Nicolas']],
  CA: [2, ['Liam', 'Noah', 'Olivia', 'Ethan', 'Chloe', 'Logan']],
  NL: [2, ['Daan', 'Sem', 'Emma', 'Bram', 'Fleur', 'Jesse']],
  CN: [3, ['Wei', 'Hao', 'Lei', 'Jing', 'Yan', 'Chen', 'Bo']],
  JP: [1, ['Haruto', 'Yuki', 'Sota', 'Hina', 'Ren', 'Akira']],
  KR: [1, ['Minjun', 'Jiwoo', 'Seojun', 'Hayun', 'Doyun']],
  PH: [2, ['Mark', 'Paolo', 'Angel', 'Kyle', 'Bea', 'Migs']],
  NG: [2, ['Chidi', 'Tunde', 'Ada', 'Emeka', 'Ngozi', 'Femi']],
  SA: [2, ['Faisal', 'Abdullah', 'Noura', 'Khalid', 'Lama', 'Turki']],
};

const COUNTRY_CODES = Object.keys(COUNTRIES);
const TOTAL_WEIGHT = COUNTRY_CODES.reduce((s, c) => s + COUNTRIES[c][0], 0);

function pickCountry() {
  let r = rand() * TOTAL_WEIGHT;
  for (const c of COUNTRY_CODES) {
    r -= COUNTRIES[c][0];
    if (r < 0) return c;
  }
  return COUNTRY_CODES[0];
}

const ADJECTIVES = [
  'Swift', 'Silent', 'Iron', 'Golden', 'Dark', 'Brave', 'Lucky', 'Clever',
  'Rapid', 'Royal', 'Shadow', 'Cosmic', 'Calm', 'Wild', 'Frozen', 'Crimson',
  'Mighty', 'Hidden', 'Noble', 'Lazy', 'Sneaky', 'Bold', 'Tiny', 'Grand',
  'Polar', 'Mystic', 'Electric', 'Steady', 'Quiet', 'Furious',
];
const NOUNS = [
  'Knight', 'Bishop', 'Rook', 'Queen', 'King', 'Pawn', 'Tiger', 'Falcon',
  'Wolf', 'Fox', 'Eagle', 'Bear', 'Lion', 'Panda', 'Owl', 'Dragon', 'Storm',
  'Comet', 'Tactic', 'Gambit', 'Castle', 'Fork', 'Pin', 'Domino', 'Tile',
  'Checker', 'Crown', 'Blitz', 'Phoenix', 'Raven',
];
const GAME_WORDS = [
  'zugzwang', 'endgame', 'opening', 'gambit', 'fianchetto', 'enpassant',
  'tempo', 'blunder', 'checkmate', 'stalemate', 'sacrifice', 'outpost',
  'double_six', 'boneyard', 'kingme', 'jumper', 'spinner', 'pipcount',
];
const GAME_SUFFIXES = ['_fan', '_lover', '_king', '_queen', 'Enjoyer', 'Hunter', '_master', 'Addict', 'Pro', '_guy'];

function withDigits(base) {
  const r = rand();
  if (r < 0.35) return base;
  if (r < 0.65) return `${base}${int(1, 99)}`;
  if (r < 0.85) return `${base}${int(1970, 2010)}`;
  return `${base}${int(100, 999)}`;
}

function personName(country) {
  const first = pick(COUNTRIES[country][1]);
  const lower = first.toLowerCase();
  const initial = String.fromCharCode(65 + int(0, 25));
  switch (int(0, 6)) {
    case 0: return `${lower}_${int(1, 99)}`;
    case 1: return `${first}${int(1975, 2009)}`;
    case 2: return `${lower}_chess`;
    case 3: return `${first}${initial}${int(1, 99)}`;
    case 4: return `the_${lower}`;
    case 5: return `${lower}${int(100, 9999)}`;
    default: return `${first}_${initial}`;
  }
}

function handle() {
  const r = rand();
  if (r < 0.5) return withDigits(`${pick(ADJECTIVES)}${pick(NOUNS)}`);
  return withDigits(`${pick(GAME_WORDS)}${pick(GAME_SUFFIXES)}`);
}

const VALID = /^[A-Za-z0-9_]{3,20}$/;

function generate() {
  const bots = [];
  const taken = new Set();
  while (bots.length < COUNT) {
    const country = pickCountry();
    const username = rand() < 0.45 ? personName(country) : handle();
    const key = username.toLowerCase();
    if (!VALID.test(username) || taken.has(key)) continue;
    taken.add(key);
    // Chess in Elo; checkers and domino in the app's points (start at 300).
    const chess = boundedNormal(1250, 320, 600, 2350);
    const checkers = boundedNormal(330, 110, 150, 900);
    const domino = boundedNormal(330, 110, 150, 900);
    bots.push([username, country, chess, checkers, domino]);
  }
  return bots;
}

const bots = generate();
const json = `${JSON.stringify(bots)}\n`;
const targets = [
  path.join(__dirname, '..', 'bot_pool.json'),
  path.join(__dirname, '..', '..', 'assets', 'data', 'bots.json'),
];
for (const file of targets) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, json);
  console.log(`wrote ${bots.length} bots to ${path.relative(process.cwd(), file)}`);
}
