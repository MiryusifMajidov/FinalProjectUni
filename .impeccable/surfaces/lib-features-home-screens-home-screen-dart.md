---
version: 1
slug: "lib-features-home-screens-home-screen-dart"
primary_target: "lib/features/home/screens/home_screen.dart"
related_targets: ["lib/features/auth/screens/login_screen.dart","lib/features/game/screens/game_screen.dart"]
---

# App shell and play surfaces

Scope: the whole Flutter app, led by sign-in, the offline hub, the Play tab,
setup screens and game chrome. Mode: Operate.

Audience and job: international players getting into a chess, draughts or
dominoes game in one or two taps; half of installers never got past sign-in,
and offline players found no way to play.

Constraints: data shapes and translation keys unchanged; ten languages incl.
Azerbaijani (ə), Cyrillic and RTL Urdu; one dark scheme.

## Direction contract

THESIS: The category standard (chess.com-type shell: board-forward Play tab, one big Play button, mode list, bottom navigation) built as our own club table, refusing both the copied green-on-brown and the old black-and-gold glow.

OWN-WORLD: Deep felt-green ground (#111915 → surfaces #19231F/#21302A), bone ink. Catalin colours as identity: butterscotch #F0A93B (chess, primary action), cherry #E2565E (draughts), jade #4CBF95 (dominoes); the Play button takes the active game's colour. Amended at build: cherry lightened from #D9434B for 4.5:1 on the felt; dominoes moved from bone to jade because bone (#E8E1CF) is indistinguishable from the ink (#EEF1EC) as a UI colour, and the tiles themselves stay bone. Engine suggestions use a colour no game and no time control owns, violet #9D8CF2. Geologica throughout, sentence case, tabular figures. No gradients, glows or hairline-bordered card stacks; tone steps separate surfaces. Signature move: moulded catalin controls, a button is a pressed-plastic token with a 4dp darker lip that sinks on press.

STORY: The player sees the active game's board and their rating, presses one obvious Play, and is in a game; bot and same-phone play are always reachable, signed in or not.

FIRST VIEWPORT: Top bar (CheckMate wordmark, settings); game switcher of three catalin chips; a real mini board of the active game with its rating beside it (chess: the final position of the player's last game, the start position before the first; draughts and dominoes: the opening setup, since their saved games keep no board state); full-width moulded Play online button; list tiles for Vs bot, A friend, Campaign, Arena; bottom navigation bar.

FORM: Category standard (canon), user-pinned: "type 4 but not a chess.com copy"; identity material from candidate 1 (Catalin sets); seed: seed:4a446f6e0665b0f2

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
