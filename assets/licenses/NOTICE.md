# Third-Party Notices — CheckMate

CheckMate (package `chess_app`, bundle id `com.ludodo.checkmate`) bundles
artwork and relies on network services created by other people. This file
records what is included, who made it, and under which terms.

Licences for the Dart and Flutter packages the app depends on are shown in the
app itself: **About → Third-party licences** (Flutter's `showLicensePage`),
which also lists the entries below.

Last reviewed: 8 November 2026.

---

## Chess piece sets

Twenty-four SVG files in two sets of twelve, under `assets/pieces/`. Both are
standard sets distributed with [Lichess](https://github.com/lichess-org/lila)
(`public/piece/`), whose own `COPYING.md` is the authoritative upstream record.

### cburnett — `assets/pieces/cburnett/`

* **Author:** Colin M. L. Burnett
* **Source:** [Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces)
  (the `Chess_<piece><colour>45.svg` series), also redistributed with Lichess
* **Licence used here:** [CC BY-SA 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/)
  (Lichess lists the same set as GPLv2+)

This set **requires attribution and is share-alike**: the credit to Colin
M. L. Burnett must be kept, and any modified version of the artwork must be
released under CC BY-SA 3.0 as well.

### merida — `assets/pieces/merida/`

* **Author:** Armando Hernandez Marroquin
* **Source:** redistributed with [Lichess](https://github.com/lichess-org/lila)
* **Licence:** [GPLv2+](https://www.gnu.org/licenses/gpl-2.0.txt), as listed in
  Lichess's `COPYING.md` (checked 8 November 2026)

### alpha — removed

The "alpha" set by Eric Bentzen was removed on 8 November 2026. Lichess's
`COPYING.md` lists it as "free for personal non commercial use", which does not
cover distribution through the App Store or Google Play. A saved preference for
it falls back to cburnett.

---

## Map data and tiles

* **Map data:** © OpenStreetMap contributors, available under the
  [Open Database Licence (ODbL) 1.0](https://www.openstreetmap.org/copyright).
* **Tiles:** currently served by `tile.openstreetmap.org` under the
  [OSMF Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/).

The credit "© OpenStreetMap contributors" is displayed on the map screen, as the
copyright terms require.

**Note:** the OSMF Tile Usage Policy forbids using its tile servers as the tile
backend of a distributed app. The tile source must be moved to a keyed provider
(MapTiler, Stadia Maps, Thunderforest, or self-hosted tiles) before or shortly
after launch. The OpenStreetMap data credit above stays required either way.

---

## Chess engine service

Bot opponents and on-board hints may be computed by the **Stockfish Online
API** (<https://stockfish.online>), a third-party HTTPS service that runs the
Stockfish engine. The app sends the board position (FEN) to that service and
reads back the suggested move and evaluation.

The Stockfish engine itself is published under the
[GNU General Public License v3](https://stockfishchess.org). CheckMate does
**not** bundle, link against, or modify the engine — it only calls the network
API — so the GPL's distribution obligations are not triggered by shipping this
app. If the engine is ever embedded in the binary, that changes, and the app's
own licensing must be revisited.

---

## Fonts

The interface font **Geologica** is bundled in `assets/fonts/` under the
[SIL Open Font License 1.1](https://openfontlicense.org/). The licence text ships
beside the fonts (`assets/fonts/OFL.txt`) and is shown in the app's licence page.

---

## Contact

Questions or licence corrections: mecidovyusif079@gmail.com
