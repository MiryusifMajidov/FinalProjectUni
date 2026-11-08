# CheckMate promo video (40 s)

`checkmate-promo-40s.mp4` is a 1080×1920 vertical video at 60 fps for
Instagram Reels, TikTok and YouTube Shorts. The sound is AAC, mastered to
−14 LUFS.

Nothing in the video uses outside material:
- **Pictures:** the app's own fonts (Geologica), cburnett chess pieces, the
  store icon, and phone screenshots of the app (`shots/`).
- **Music and sound effects:** synthesised by `music.py`, so there are no
  licences to clear.

## Remake it

```bash
node render.mjs --out frames --fps 60 --sfx sfx.json   # 2400 JPEG frames + the sound cues (≈5 min)
python music.py sfx.json music.wav                      # the soundtrack
ffmpeg -framerate 60 -i frames/f%05d.jpg -i music.wav \
  -filter:a "lowshelf=f=110:g=-3,highshelf=f=3500:g=4,loudnorm=I=-14:TP=-2:LRA=9,aresample=48000,alimiter=limit=0.7:attack=1:release=60:level=disabled,lowpass=f=17500" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -r 60 -c:a aac -b:a 192k -ar 48000 \
  -movflags +faststart -shortest checkmate-promo-40s.mp4
```

You need Chrome or Edge, Node 22 or newer, Python with numpy and scipy, and ffmpeg.

- **Look at one moment:** open `promo.html?t=12.5` in a browser. It is drawn
  for 1080×1920.
- **Play it through:** open `promo.html?play`.
- **Timeline:** each scene in `promo.html` is a function of time.
- **Sound cues:** the `cue(...)` calls in `promo.html` list the sound
  effects; `music.py` turns them into the soundtrack.

## Scenes

| Time | Scene |
|---|---|
| 0–4 s | A knight, a draughtsman and a domino drop onto the felt: "One table. Three classics." |
| 4–12 s | One board: a chess opening with the on-board hint, then a draughts double jump, then a domino line laid tile by tile. |
| 12–20 s | The app on a phone: tapping Draughts recolours it; three phones show the three colours. |
| 20–26 s | Arena standings that move: "A new arena every 30 minutes." |
| 26–32 s | "Play" in the app's ten languages, then the six bot levels. |
| 32–36 s | Eight cuts on the beat: Chess, Draughts, Dominoes, Arenas, Friends, Hints, No ads, Free. |
| 36–40 s | The icon, the name and "Free on Google Play". |

The video makes no claims about player numbers or reviews. The arena
standings are an illustration, with names from the app's bot pool.
