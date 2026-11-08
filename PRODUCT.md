# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

One Flutter codebase. Live on Google Play as `com.ludodo.checkmate`; the iOS
build (iPhone only, iOS 15+) ships the same UI and is in App Store preparation.
The design language is shared across both, not adapted per OS.

## Users

International players of classic board games, reached through Google Play.
They open the app to get a game going quickly (online, against a friend, or
against the bot), to keep a rating, and to play with people they know.
Confirmed by the owner on 2026-11-07: the audience is international, not a
local or academic one. The app ships in 10 languages (en, az, tr, ru, de, es,
fr, hi, ur, zh), so every screen must hold up in long German/Russian strings
and in right-to-left Urdu.

## Product Purpose

Three classic board games in one account: chess, draughts (checkers) and
dominoes, with real opponents, separate ratings per game, and no ads or
purchases. Success is a player who installs, gets into a first game without
friction, and comes back.

Known funnel problem (owner, 2026-11-07): more than 1,000 installs, but only
about 500 registered accounts. Roughly half of installers never get past the
sign-in wall. First-run and sign-in are therefore the highest-value surfaces.

## Positioning

Chess, draughts and dominoes under one identity, with one rating system per
game, an arena format that runs on the server with bots filling empty seats,
a single-player campaign across all three games, and an opt-in nearby-players
map. Free with nothing locked; no ads, no trackers.

## Operating Context

- Phone-first, portrait, one-handed play; games are timed (chess clocks;
  30 s per move in draughts and dominoes), so the board and clocks must stay
  legible and responsive under time pressure.
- Online play through Firebase (Auth, Firestore, Realtime Database, Cloud
  Functions); bots step in when no human is free.
- Social layer: friends, groups, one-to-one and group chat, in-game chat,
  spectating live chess games, invites.
- Guest play exists ("Play as guest", user#0001 style names).

## Capabilities and Constraints

- Real users and data exist: Firestore schema, stored ratings, user documents
  and translation keys must stay compatible. Visual changes must not change
  data shapes.
- Chess: full rules, bot with six levels, local two-player, online with
  bullet/blitz/rapid, replay, spectating. Draughts: six variants (German
  "Dame" added 2026-11-07 after a Play review), bot and
  online. Dominoes: bot, shared table, boneyard draw.
- Stand-in bots (matchmaking after 30 s, arena seats) play under their pool
  names with no BOT badge and at a person's pace (owner, 2026-11-07). They
  have profiles, show up in player search and on the player map, and their
  records grow (owner, 2026-11-08). The search screen and the store text
  still say a bot steps in when nobody is free, and those games stay
  unrated. A further 500 bots (bot_2001 … bot_2500) carry a Bot badge
  wherever their name shows (owner, 2026-11-08).
- The app ships one dark scheme (the light theme was never switched on and
  is not maintained).
- Board themes and three piece sets (cburnett, merida, alpha) are user
  settings.
- Nothing visual is fixed: icon, name styling and piece sets may all change
  (owner, 2026-11-07).

## Brand Commitments

- Name: CheckMate (store name "CheckMate: Chess Dama Domino"; Android label
  currently "Chess Draughts Dominoes").
- Voice in the store copy: plain, factual, no hype ("real opponents, real
  ratings and no ads").
- Owner requirement for the redesign: the app must not read as AI-generated.

## Evidence on Hand

- Store copy: `APP_STORE_DESCRIPTION.txt`, `APP_STORE_METADATA.md`.
- Install and registration figures above are the owner's numbers; there is no
  analytics SDK in the app, so no other usage data exists. Do not invent
  ratings counts, reviews or player numbers in UI copy.

## Product Principles

1. A first game should be one or two taps away, signed in or not.
2. The board is the product: nothing on a game screen competes with it.
3. Three games, one family: shared structure, each game recognisable at a
   glance.
4. Honest status: ratings, timers, queue state and errors say exactly what is
   happening.
5. Every screen works in all ten languages, at large system font sizes,
   and right to left.

## Accessibility & Inclusion

Ten languages including RTL Urdu and long-string German/Russian. Text must
scale with system font size without clipping on game-critical UI (clocks,
ratings, buttons).
