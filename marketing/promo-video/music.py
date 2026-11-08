"""Synthesises the 40-second soundtrack for the CheckMate promo.

    python music.py sfx.json out.wav

Everything is generated here (no samples, no licences): a 120 BPM track in
A minor (Am - F - C - G, one chord per two-second bar) whose sections follow
the video's scenes, plus a sound for every cue promo.html lists (pieces
landing, moves, hints, domino clacks, cuts, the end hit).
"""
import json
import sys

import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
DUR = 40.0
N = int(SR * DUR)
BEAT = 0.5
BAR = 2.0
rng = np.random.default_rng(20261108)

L = np.zeros(N)
R = np.zeros(N)
# Buses: music (gets ducked by the kick), drums, fx (reverb send), dry fx.
music = np.zeros((2, N))
drums = np.zeros((2, N))
fx = np.zeros((2, N))
duck = np.ones(N)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def tt(dur):
    return np.arange(int(SR * dur)) / SR


def add(bus, t0, sig, gain=1.0, pan=0.0):
    i = int(round(t0 * SR))
    if i >= N or i + len(sig) <= 0:
        return
    j0 = max(0, -i)
    sig = sig[j0:]
    i = max(0, i)
    n = min(len(sig), N - i)
    lg = gain * np.cos((pan + 1) * np.pi / 4)
    rg = gain * np.sin((pan + 1) * np.pi / 4)
    bus[0, i:i + n] += sig[:n] * lg * np.sqrt(2)
    bus[1, i:i + n] += sig[:n] * rg * np.sqrt(2)


def lp(x, f, order=2):
    return sosfilt(butter(order, min(f, SR / 2 * 0.95), 'low', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def saw(f, dur, harmonics=None, detune=0.0, phase=0.0):
    t = tt(dur)
    out = np.zeros_like(t)
    kmax = harmonics or max(1, int(9000 / f))
    for k in range(1, kmax + 1):
        out += np.sin(2 * np.pi * k * f * (1 + detune) * t + phase * k) / k
    return out * 0.6


def env(dur, a=0.005, d=0.1, s=0.0, r=0.05, hold=None):
    t = tt(dur)
    e = np.ones_like(t)
    e[t < a] = t[t < a] / a
    dmask = (t >= a)
    e[dmask] = s + (1 - s) * np.exp(-(t[dmask] - a) / max(d, 1e-4))
    if r > 0:
        rel = t > dur - r
        e[rel] *= np.linspace(1, 0, rel.sum())
    return e


CHORDS = [  # (bass, pad voicing, arp notes)
    (33, [57, 60, 64, 71], [69, 72, 76, 79, 81, 79, 76, 72]),   # Am(add9)
    (29, [53, 57, 60, 67], [65, 69, 72, 77, 79, 77, 72, 69]),   # Fmaj(add9)
    (36, [55, 60, 64, 67], [67, 72, 76, 79, 84, 79, 76, 72]),   # C
    (31, [55, 59, 62, 67], [67, 71, 74, 79, 83, 79, 74, 71]),   # G
]


def chord_at(t):
    return CHORDS[int(t // BAR) % 4]


# ── Pad: detuned saws, slow attack, opens up through the video ──────────────
def pad(t0, dur, notes, gain, cutoff):
    for n in notes:
        for det, pan in ((-0.004, -0.5), (0.004, 0.5)):
            s = saw(midi(n), dur, detune=det, phase=rng.random() * 6)
            s = lp(s, cutoff * 1.7) * env(dur, a=0.35, d=10, s=1, r=0.6)
            add(music, t0, s, 1.9 * gain / len(notes), pan)


for b in range(20):
    t0 = b * BAR
    _, voicing, _ = chord_at(t0)
    if t0 < 4:
        g, cut = 0.32 * min(1, (t0 + 2) / 4), 900 + t0 * 150
    elif t0 < 32:
        g, cut = 0.24, 1400 + (t0 - 4) * 40
    elif t0 < 36:
        g, cut = 0.2, 2600
    else:
        g, cut = 0.0, 0
    if g:
        pad(t0, BAR + 0.6, voicing, g, cut)
# The end: an open Fmaj9 that rings out.
pad(36.0, 4.0, [53, 60, 64, 67, 72], 0.34, 2400)

# ── Bass: sub on the root, eighths with a bounce ─────────────────────────────
def bass_note(t0, f, dur, gain):
    t = tt(dur)
    s = np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * 2 * f * t) + 0.3 * np.sin(2 * np.pi * 3 * f * t)
    s = np.tanh(1.6 * s) * env(dur, a=0.004, d=0.18, s=0.5, r=0.04)
    add(music, t0, lp(s, 900), gain * 0.62)


for k in range(int(4 / 0.25), int(32 / 0.25)):
    t0 = k * 0.25
    root = chord_at(t0)[0]
    step = k % 8
    if step in (0, 3, 4, 6):
        bass_note(t0, midi(root + (12 if step == 6 else 0)), 0.22, 0.42)
for k in range(8):  # cuts: a root on every beat
    t0 = 32 + k * 0.5
    bass_note(t0, midi(chord_at(t0)[0]), 0.4, 0.5)
bass_note(36.0, midi(29), 3.6, 0.55)

# ── Pluck arpeggio, sixteenths, from the board scene on ─────────────────────
def pluck(t0, f, gain, pan, bright):
    dur = 0.32
    s = saw(f, dur, harmonics=14) * env(dur, a=0.002, d=0.09, s=0, r=0.02)
    add(music, t0, lp(s, bright), gain * 1.7, pan)
    add(fx, t0, lp(s, bright), gain * 0.6, pan)


for k in range(int(4 / 0.125), int(32 / 0.125)):
    t0 = k * 0.125
    notes = chord_at(t0)[2]
    n = notes[k % 8]
    sect = 0.10 if t0 < 12 else 0.12 if t0 < 20 else 0.15
    bright = 2800 + 4200 * min(1, max(0, (t0 - 4) / 28))
    pluck(t0, midi(n), sect, 0.35 * np.sin(k * 0.9), bright)

# ── Drums ────────────────────────────────────────────────────────────────────
def kick(t0, gain=1.0):
    t = tt(0.45)
    f = 48 + 110 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t * 7.5)
    s[:120] += rng.normal(0, 0.4, 120) * np.linspace(1, 0, 120)
    body = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 40) * 0.35
    add(drums, t0, np.tanh(1.8 * s) + body, 0.55 * gain)
    i = int(t0 * SR)
    n = min(int(0.38 * SR), N - i)
    if n > 0:
        duck[i:i + n] = np.minimum(duck[i:i + n], 1 - 0.55 * np.exp(-tt(0.38)[:n] * 9))


def hat(t0, gain=0.18, open_=False, pan=0.25):
    dur = 0.22 if open_ else 0.05
    s = hp(rng.normal(0, 1, int(dur * SR)), 7500) * np.exp(-tt(dur) / (0.07 if open_ else 0.012))
    add(drums, t0, s, gain * 2.2, pan)


def clap(t0, gain=0.35):
    dur = 0.3
    s = np.zeros(int(dur * SR))
    for off in (0, 0.011, 0.022):
        i = int(off * SR)
        s[i:] += np.exp(-np.arange(len(s) - i) / SR / 0.012)
    s = bp(rng.normal(0, 1, len(s)), 900, 3200) * (s + 0.6 * np.exp(-tt(dur) / 0.09))
    add(drums, t0, s, gain, -0.1)
    add(fx, t0, s, gain * 0.5)


def snare(t0, gain=0.3):
    dur = 0.18
    t = tt(dur)
    s = 0.6 * bp(rng.normal(0, 1, len(t)), 1200, 6000) * np.exp(-t / 0.05) + 0.5 * np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.04)
    add(drums, t0, s, gain)


for k in range(int(4 / BEAT), int(32 / BEAT)):
    t0 = k * BEAT
    if 31.0 <= t0 < 32:
        continue  # the fill takes over
    kick(t0, 1.0 if t0 >= 12 else 0.85)
    hat(t0 + 0.25, 0.16 if t0 < 20 else 0.2, open_=(t0 >= 20 and k % 4 == 3))
    if t0 >= 20:
        hat(t0 + 0.125, 0.09, pan=-0.25)
        hat(t0 + 0.375, 0.09, pan=-0.25)
    if t0 >= 12 and k % 2 == 1:
        clap(t0)
# Fill into the cuts: sixteenth snares that speed up and rise.
for i in range(16):
    t0 = 31.0 + i * 0.0625
    snare(t0, 0.12 + 0.02 * i)
for k in range(8):
    kick(32 + k * 0.5, 1.15)
    hat(32 + k * 0.5 + 0.25, 0.2, open_=True)

# ── Risers and hits ──────────────────────────────────────────────────────────
def riser(t0, dur, gain=0.25):
    t = tt(dur)
    s = rng.normal(0, 1, len(t))
    # Sweep a band-pass upward by filtering in short blocks.
    out = np.zeros_like(s)
    blk = 1024
    for i in range(0, len(s), blk):
        fc = 300 + 7000 * (i / len(s)) ** 2
        out[i:i + blk] = bp(s[max(0, i - 2048):i + blk], fc * 0.7, min(fc * 1.4, 20000))[-len(s[i:i + blk]):]
    out *= np.linspace(0, 1, len(t)) ** 2
    add(fx, t0, out, gain)
    add(music, t0, out, gain * 0.6)


for t0, d in ((2.9, 1.1), (10.9, 1.1), (18.9, 1.1), (24.9, 1.1), (30.8, 1.2), (35.0, 1.0)):
    riser(t0, d, 0.22)


def impact(t0, gain=1.0, big=False):
    kick(t0, 1.2 * gain)
    dur = 2.5 if big else 1.2
    t = tt(dur)
    s = lp(rng.normal(0, 1, len(t)), 5000) * np.exp(-t / (0.5 if big else 0.25))
    add(fx, t0, s, 0.35 * gain)
    if big:
        f = 30 + 60 * np.exp(-t * 3)
        sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.9)
        add(drums, t0, sub, 0.5)


# ── Cue sounds ───────────────────────────────────────────────────────────────
def wood(t0, f=900, gain=0.4, dur=0.12, pan=0.0):
    t = tt(dur)
    s = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t)) * np.exp(-t / 0.025)
    s[:60] += rng.normal(0, 0.5, 60)
    add(fx, t0, s, gain * 0.5, pan)
    add(drums, t0, s, gain, pan)


def bell(t0, f, gain=0.25, dur=1.4, pan=0.0):
    t = tt(dur)
    s = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t / (0.5 / m ** 0.5)) for m, a in ((1, 1), (2.0, .4), (3.01, .2), (4.2, .1)))
    add(fx, t0, s, gain * 0.7, pan)
    add(music, t0, s, gain * 0.5, pan)


def whoosh(t0, gain=0.3, dur=0.45):
    t = tt(dur)
    s = rng.normal(0, 1, len(t))
    s = bp(s, 500, 4000) * np.sin(np.pi * t / dur) ** 2
    add(fx, t0 - dur * 0.5, s, gain)


cues = json.load(open(sys.argv[1], encoding='utf-8'))
for c in cues:
    t0, kind, g = c['t'], c['type'], c.get('gain', 1)
    if kind == 'drop':
        t = tt(0.5)
        f = 60 + 90 * np.exp(-t * 18)
        thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
        add(drums, t0, thud, 0.9 * g)
        wood(t0, 520, 0.5 * g)
        add(fx, t0, lp(rng.normal(0, 1, int(0.6 * SR)), 2500) * np.exp(-tt(0.6) / 0.12), 0.25 * g)
    elif kind == 'word':
        wood(t0, 1800, 0.12 * g, pan=0.2)
    elif kind in ('whoosh', 'swish'):
        whoosh(t0, 0.32 * g)
    elif kind == 'hit':
        impact(t0, 0.9 * g)
    elif kind == 'boom':
        impact(t0, 1.0, big=True)
    elif kind == 'tick':
        wood(t0, 2200 + rng.random() * 600, 0.16 * g, 0.05, pan=rng.uniform(-.5, .5))
    elif kind == 'move':
        wood(t0, 980, 0.42 * g)
    elif kind == 'jump':
        wood(t0, 760, 0.45 * g); wood(t0 + 0.05, 1150, 0.25 * g)
    elif kind == 'clack':
        wood(t0, 1500 + rng.random() * 300, 0.4 * g, pan=rng.uniform(-.4, .4)); wood(t0 + 0.018, 2600, 0.2 * g)
    elif kind == 'hint':
        bell(t0, midi(81), 0.18 * g); bell(t0 + 0.09, midi(88), 0.14 * g, pan=0.3)
    elif kind == 'swap':
        bell(t0, midi(76), 0.12 * g, dur=0.6)
    elif kind == 'tap':
        wood(t0, 1300, 0.3 * g)
    elif kind == 'pop':
        t = tt(0.12)
        f = 500 + 1400 * t / 0.12
        add(fx, t0, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.04), 0.3 * g)
        add(drums, t0, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.04), 0.25 * g)
    elif kind == 'score':
        for i, n in enumerate((84, 88, 91)):
            bell(t0 + i * 0.04, midi(n), 0.1 * g, dur=0.7, pan=(i - 1) * 0.3)
    elif kind == 'win':
        for i, n in enumerate((72, 76, 79, 84)):
            bell(t0 + i * 0.05, midi(n), 0.14, dur=1.6, pan=(i - 1.5) * 0.25)
    elif kind == 'flick':
        wood(t0, 2600, 0.12 * g, 0.04, pan=rng.uniform(-.3, .3))
    elif kind == 'level':
        bell(t0, midi(64 + int((g - 0.5) * 10) * 2), 0.12, dur=0.5)
    elif kind == 'stab':
        _, voicing, _ = chord_at(t0)
        for n in voicing + [voicing[0] + 12]:
            s = lp(saw(midi(n), 0.4, harmonics=20), 3500) * env(0.4, a=0.003, d=0.12, s=0, r=0.03)
            add(music, t0, s, 0.12 * g)
        add(fx, t0, lp(rng.normal(0, 1, int(0.3 * SR)), 6000) * np.exp(-tt(0.3) / 0.05), 0.12 * g)

# ── Mix ─────────────────────────────────────────────────────────────────────
ir_t = tt(2.2)
ir = np.stack([rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t / 0.55) for _ in range(2)])
ir[:, :int(0.012 * SR)] = 0
ir /= np.abs(ir).sum(axis=1, keepdims=True) / 6
wet = np.stack([fftconvolve(lp(fx[c] + 0.35 * music[c], 6000), ir[c])[:N] for c in range(2)])

mix = music * duck + drums + 0.55 * fx + 0.32 * wet
mix = np.stack([hp(mix[c], 32) for c in range(2)])
# Fade out the last second; a gentle soft clip; peak at -1 dBFS. The final
# loudness (-14 LUFS, the level social apps play at) is set when encoding.
mix[:, -int(1.0 * SR):] *= np.linspace(1, 0, int(1.0 * SR)) ** 1.5
mix /= np.max(np.abs(mix))
mix = np.tanh(mix * 1.4) / np.tanh(1.4)
mix *= 10 ** (-1 / 20) / np.max(np.abs(mix))

from scipy.io import wavfile
wavfile.write(sys.argv[2], SR, (mix.T * 32767).astype(np.int16))
print('wrote', sys.argv[2], f'{DUR:.0f} s')
