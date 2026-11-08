# Store screenshots

Eight screenshots form one panorama. The felt and the pieces run across the
seams, so the store shows a continuous table when you scroll.

## Where the images are and where they go

| File | Size | Upload to |
|---|---|---|
| `out/appstore-iphone-6.9in-1320x2868/iphone69-01–08.png` | 1320×2868 | App Store Connect → iPhone 6.9″ display. Smaller iPhone sizes are generated from it. |
| `out/appstore-iphone-6.5in-1284x2778/iphone65-01–08.png` | 1284×2778 | App Store Connect → iPhone 6.5″ display, if that slot is the one shown. |
| `out/appstore-6.9in/01–08.png` | 1290×2796 | The first 6.9″ set. Superseded by the 1320×2868 set above. |
| `out/googleplay/01–08.png` | 1080×1920 | Play Console → Phone screenshots |
| `out/googleplay/feature-graphic.png` | 1024×500 | Play Console → Feature graphic |

All images are RGB PNG with no alpha channel, as App Store Connect requires.

## The eight slides

1. "Three classics. One table." Home screen, chess.
2. "Hints drawn on the board." A chess game with the hint arrow.
3. "Six variants of draughts." A German draughts game with a capture hint.
4. "Dominoes: draw or block." A four-player domino table.
5. "Pick a game. The app follows." Three phones, one per game colour.
6. "A new arena every 30 minutes." The arena list.
7. "Six bot levels. Online or offline." The chess bot setup.
8. "Free. No ads. Ten languages." The profile tab.

## Where the screens come from

Every phone shows a real screen of the app:
- **Slides 1, 5, 6 and 8:** a Galaxy phone.
- **Slides 2, 3, 4 and 7:** the app's web build in offline play, at 430×932 @3x.

## Remake them

```bash
node render.mjs --w 1320 --h 2868 --out out/appstore-iphone-6.9in-1320x2868
node render.mjs --w 1284 --h 2778 --out out/appstore-iphone-6.5in-1284x2778
node render.mjs --w 1080 --h 1920 --out out/googleplay
node render.mjs --page feature.html --w 1024 --h 500 --n 1 --out out/googleplay --name feature-graphic
```

You need Chrome or Edge and Node 22 or newer. The PNGs Chrome writes keep an
alpha channel, so convert them to RGB before uploading (any image tool; a
Pillow `convert('RGB')` does it).

- **Copy:** the `SLIDES` list in `store.html` holds the headline and line for
  each slide.
- **Screens:** `shots/` holds the phone screens.
