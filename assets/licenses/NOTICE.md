# Third-Party Notices — CheckMate

CheckMate (package `chess_app`, bundle id `com.chessapp.chessApp`) bundles
artwork and relies on network services created by other people. This file
records what is included, who made it, and under which terms.

Licences for the Dart and Flutter packages the app depends on are shown in the
app itself: **About → Third-party licences** (Flutter's `showLicensePage`),
which also lists the entries below.

Last reviewed: 21 September 2026.

---

## Chess piece sets

Thirty-six SVG files in three sets of twelve, under `assets/pieces/`. All three
are the standard sets distributed with [Lichess](https://github.com/lichess-org/lila)
(`public/piece/`), whose own `COPYING.md` is the authoritative upstream record.

### cburnett — `assets/pieces/cburnett/`

* **Author:** Colin M. L. Burnett
* **Source:** [Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces)
  (the `Chess_<piece><colour>45.svg` series), also redistributed with Lichess
* **Licence used here:** [CC BY-SA 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/)

This set **requires attribution and is share-alike**: the credit to Colin
M. L. Burnett must be kept, and any modified version of the artwork must be
released under CC BY-SA 3.0 as well. The Commons originals are multi-licensed —
GFDL and a BSD-style licence are also offered — so other terms may be available;
**verify upstream terms** before relying on anything other than CC BY-SA 3.0.

### merida — `assets/pieces/merida/`

* **Author:** Armando Hernandez Marroquin
* **Source:** redistributed with [Lichess](https://github.com/lichess-org/lila)

The set is widely redistributed as free software and is commonly described as
GPL-licensed, but no licence text ships with the SVG files in this repository
and the exact version has not been confirmed. **Verify upstream terms** in
Lichess's `public/piece/COPYING.md` before redistributing, and record the result
here.

### alpha — `assets/pieces/alpha/`

* **Author:** Eric Bentzen
* **Source:** redistributed with [Lichess](https://github.com/lichess-org/lila)

Eric Bentzen's chess fonts have historically been published as **free for
personal, non-commercial use**. That grant may not cover distribution inside an
app on the App Store or Google Play. **Verify upstream terms and obtain written
permission, or remove this set**, before treating it as cleared for commercial
distribution. This is the one bundled asset whose terms are a real risk.

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

Bot opponents and post-game analysis are computed by the **Stockfish Online
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

Interface fonts are fetched at runtime by the `google_fonts` package from
`fonts.gstatic.com`:

* **Fraunces**, **Inter** and **JetBrains Mono** — each published under the
  [SIL Open Font License 1.1](https://openfontlicense.org/).

The OFL requires the licence to accompany the fonts when they are redistributed.
These fonts are downloaded rather than bundled; **verify upstream terms** for
each family if they are ever vendored into `assets/`.

---

## Contact

Questions or licence corrections: privacy@grandmasterapp.com
