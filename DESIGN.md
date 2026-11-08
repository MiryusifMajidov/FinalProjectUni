---
name: CheckMate
description: Chess, draughts and dominoes on one club table — felt ground, catalin pieces, the board first.
colors:
  felt: "#111915"
  felt-surface: "#17211C"
  felt-card: "#1D2923"
  felt-raised: "#26352D"
  ink: "#EEF1EC"
  ink-dim: "#B4BEB8"
  ink-mute: "#8D9993"
  ink-faint: "#55615B"
  butterscotch: "#F0A93B"
  butterscotch-lip: "#B9761A"
  on-butterscotch: "#241703"
  cherry: "#E2565E"
  jade: "#4CBF95"
  hint-violet: "#9D8CF2"
  win: "#7FCC8C"
  loss: "#F07A6E"
  draw: "#B9B4A6"
  live: "#FF6F61"
  bullet: "#F28B4C"
  blitz: "#72B6EA"
  board-light: "#F0D9B5"
  board-dark: "#B58863"
typography:
  display:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "40px"
    fontWeight: 800
    letterSpacing: "-1px"
    fontFeature: "tnum"
  headline:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "25px"
    fontWeight: 700
    lineHeight: 1.22
    letterSpacing: "-0.4px"
  title:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 700
  body:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 600
  clock:
    fontFamily: "Geologica, Roboto, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    fontFeature: "tnum"
rounded:
  chip: "10px"
  control: "12px"
  tile: "14px"
  hero: "16px"
  panel: "18px"
  sheet: "20px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  section: "28px"
components:
  button-primary:
    backgroundColor: "{colors.butterscotch}"
    textColor: "{colors.on-butterscotch}"
    typography: "{typography.title}"
    rounded: "{rounded.tile}"
    height: "58px"
  button-tonal:
    backgroundColor: "{colors.felt-raised}"
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    rounded: "{rounded.tile}"
    height: "54px"
  mode-tile:
    backgroundColor: "{colors.felt-card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tile}"
    padding: "12px 12px 12px 14px"
  game-chip-selected:
    backgroundColor: "{colors.butterscotch}"
    textColor: "{colors.on-butterscotch}"
    rounded: "{rounded.control}"
    height: "48px"
  game-chip:
    backgroundColor: "{colors.felt-card}"
    textColor: "{colors.ink-dim}"
    rounded: "{rounded.control}"
    height: "48px"
  clock-running:
    backgroundColor: "{colors.butterscotch}"
    textColor: "{colors.on-butterscotch}"
    typography: "{typography.clock}"
    rounded: "{rounded.chip}"
  clock-idle:
    backgroundColor: "{colors.felt-card}"
    textColor: "{colors.ink-dim}"
    typography: "{typography.clock}"
    rounded: "{rounded.chip}"
  input:
    backgroundColor: "{colors.felt-card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "15px 16px"
---

# Design System: CheckMate

## Overview

**Creative North Star: "The Club Table"**

CheckMate is a table in a games club: dark green felt, a board in the middle, and pieces made of moulded catalin, the glossy plastic of old domino and draughts sets. The app follows the shape players already know from big chess apps (a Play tab led by the board and one large Play button, game modes as a list, bottom navigation), and puts its own material on it rather than copying anyone's colours.

Density is a working app's: tone steps separate surfaces, nothing is outlined, and every number that moves (ratings, clocks, move numbers) sits in tabular figures. The world shows in four places only: the felt, the type, the three catalin colours and the moulded controls. Layout, navigation and controls stay standard Material on Android.

The system replaced a near-black, gold-glow, Inter-everywhere look whose owners felt it read as AI-made; that look is the anti-reference: no glows, no gradients, no hairline-bordered card stacks, no tracked all-caps labels.

**Key Characteristics:**
- Dark felt ground with three tone-stepped surfaces, never a neutral black.
- One identity colour per game: butterscotch chess, cherry draughts, jade dominoes.
- Moulded controls: a darker lip under every token, gone while pressed.
- Geologica in sentence case, tabular figures for every number.
- A real board (or tiles) shown before any statistic.

## Colors

A felt-green ground with catalin accents; colour does jobs (which game, which action, which result), never decoration.

### Primary
- **Butterscotch**: chess's colour: the chess board's screens, the running clock, Start game in chess. Text on it is always the near-black **Butterscotch Ink**, which also reads on cherry and jade.
- **The selected game's colour** (`AppColors.accent`): the screens around the games (settings, profile, friends, chat, groups, leaderboard, map, arenas, the home tabs and the app theme's buttons, switches and focus outlines) wear the colour of the game selected on the Play tab: butterscotch with chess, cherry with draughts, jade with dominoes (owner, 2026-11-08).

### Secondary
- **Cherry**: draughts. Its game chip, its Play button, its bot-setup selection.

### Tertiary
- **Jade**: dominoes. Same roles as cherry. The tiles themselves stay ivory; jade marks the UI only (bone was tried and is indistinguishable from the ink).

### Neutral
- **Felt**: the ground of every screen, the Android window and the navigation bar.
- **Felt Surface**: app bars, bottom navigation, panels (player panel, arena row, guest banner, sheets).
- **Felt Card**: tiles, inputs, unselected chips and tokens.
- **Felt Raised**: secondary (tonal) buttons and icon wells inside tiles.
- **Ink / Ink Dim / Ink Mute**: primary text, secondary text, meta text. Ink Mute holds 4.9:1 on Felt Card.
- **Hint Violet**: engine suggestions on a board only (the Hint arrow); a colour no game and no time control owns.
- **Win / Loss / Draw / Live** and the **Bullet / Blitz** time-control colours carry state, never decoration.

### Named Rules
**The Three Pieces Rule.** Butterscotch, cherry and jade belong to chess, draughts and dominoes. A game's colour appears on that game's chip, its Play button and its selections, and the whole app around the games takes the colour of the selected game; it never appears where it could be mistaken for another game.

**The No Glow Rule.** Coloured shadows, gradients and halos are not part of this palette. Depth is a darker lip or a neutral drop shadow under a physical object.

## Typography

**Display, Body and Label Font:** Geologica (bundled; fallback Roboto, then the system font for Hindi, Urdu and Chinese)

**Character:** one soft geometric grotesque for everything, compact enough for German and Russian labels, with ə, ğ, ı, İ and Cyrillic covered. Hierarchy comes from size and weight, never from case or tracking.

### Hierarchy
- **Display** (800, 40px, tabular): the rating on the Play tab.
- **Headline** (700, 25px, 1.22): the sign-in statement; level names on bot setup (800, 26px).
- **Title** (700, 16–20px): tile titles, Play online (800, 20px), section titles (17–18px).
- **Body** (400, 14–16px, 1.4–1.45): descriptions, captions, dialogs.
- **Label** (600, 13–14px): meta lines, chip text, small section labels (Ink Dim).
- **Clock** (700, 24px, tabular): game clocks inside their block.

### Named Rules
**The Sentence Case Rule.** No forced uppercase and no tracked text. `AppFonts.ui` caps positive letter-spacing at 0.2.

**The Tabular Rule.** Every rating, clock, score and move number uses tabular figures.

## Layout

Phone-first portrait. Screens sit on a 16–20px side margin; groups inside a screen are 8–12px apart and sections 24–28px apart, with more room above a section title than below it. The Play tab's first viewport is fixed in order: top bar (wordmark; ranking, map and settings buttons), the three game chips, the player panel (a real board or tiles beside the rating), the full-width Play online button, then the mode tiles and the live arena. On the Play tab the board beside the rating is real: chess shows the final position of the player's last game (the start position before the first); draughts and dominoes show their opening setup. Game screens size the board from the space left after the top bar, player strips, move strip and action row, and keep the move strip's room from the first frame so the board never moves. Touch targets are at least 48dp.

## Elevation & Depth

Flat surfaces separated by tone (Felt → Surface → Card → Raised). The only lifted things are physical: the moulded lip under controls, and a soft neutral drop shadow under the board, draughtsman and domino illustrations.

### Named Rules
**The Tone Step Rule.** Surfaces are separated by their fill, not by lines. A 1px border appears only as a divider between rows.

## Shapes

Softly squared corners that grow with the element: 10px chips and clocks, 12px controls and inputs, 14px tiles and large buttons, 16px the Play online button, 18px panels, 20px sheet tops. Pieces are round; boards are square with a thin wooden frame.

## Components

### Buttons
Tactile and confident: every button is a moulded token.
- **Shape:** 12–14px corners, a 3–5px darker lip along the bottom edge (a 30% black shade of the face).
- **Primary:** butterscotch face, near-black label in 16–18px bold; the Play online button takes the active game's colour.
- **Pressed:** the lip disappears and the face drops onto it; no ripple.
- **Tonal:** Felt Raised face, ink label; used for Play offline, Google, Apple and e-mail sign-in.
- **Disabled:** the face fades toward the felt and the lip goes.

### Chips
- **Style:** moulded tokens, Felt Card when unselected with the game colour on the icon only.
- **Selected:** filled with the game's colour (butterscotch in chess contexts), near-black label.

### Cards / Containers
- **Corner Style:** 14–18px.
- **Background:** Felt Surface for panels, Felt Card for tiles.
- **Shadow Strategy:** none; see Elevation.
- **Border:** none.
- **Internal Padding:** 12–16px.

### Inputs / Fields
- **Style:** filled Felt Card, no stroke, 12px corners, 14px label above in Ink Dim.
- **Focus:** a 2px butterscotch outline.
- **Error:** a 1.5–2px loss outline; the message sits below the field.

### Navigation
Material bottom bar on Felt Surface, 68px: icon in a butterscotch-tinted pill when selected, 12px labels (bold ink when selected, Ink Mute otherwise). Screen app bars are left-aligned with a 48dp arrow-left back token.

### Game clock (signature)
The running player's clock is a solid butterscotch block with near-black tabular numbers; it turns loss-coral under 20 seconds; the waiting player's clock is a Felt Card block in Ink Dim.

### Hint on the board (signature)
The suggested move is drawn on the board: the origin square tinted Hint Violet under the piece, a violet arrow through every square of the move (one segment in chess, several for a draughts multi-jump) and a ring on the final square. It grows out of the origin in 320ms (instant with Remove animations) and disappears when a move is played.

## Do's and Don'ts

### Do:
- **Do** lead with the board: show a real board or tiles before any statistic.
- **Do** build every new control from the moulded token (`Moulded`, `AppButton`, the themed Material buttons).
- **Do** keep each game's colour to that game, and Hint Violet to engine suggestions.
- **Do** keep every number tabular and every label in sentence case.
- **Do** give every touch target 48dp and every icon button a tooltip.

### Don't:
- **Don't** use coloured glows, gradients, glass or blurred halos.
- **Don't** outline cards or stack bordered boxes; separate by tone.
- **Don't** set labels in uppercase or add letter-spacing to small text.
- **Don't** put an eyebrow or kicker label above a heading.
- **Don't** invent a statistic the data does not hold (the old averaged "Overall rating").
