#!/usr/bin/env python3
"""Regenerate every Spaceballs sound effect from parameters. Standard library + ffmpeg only.

    python3 assets/audio/tools/make_cues.py                       # all files
    python3 assets/audio/tools/make_cues.py kick_4 cheer_1        # just these files
    python3 assets/audio/tools/make_cues.py --spectrograms handoff/spectrograms
    python3 assets/audio/tools/make_cues.py --keep-wav .scratch/wav

Adapted from openjar-launcher/assets/audio/tools/make_cues.py (same primitives, same loudness
pass). Every sound is synthesised here (additive partials, PolyBLEP saws through formant
filters for voices, filtered noise for hits and crowds), seeded per file so the output is
reproducible. WAV sources go to a temp dir and never into git. Each file is then encoded to
Ogg Vorbis q5 at 44.1 kHz and loudness-normalised with ffmpeg:
  - SFX of 0.6 s or more: -16 LUFS integrated.
  - shorter SFX: the cue looped 10x is measured, so "as loud as the rest while it sounds";
    a per-cue trim lets frequent cues (card_move, hop, whoosh) sit a little lower.
  - everything: true peak at or below -1 dBTP (checked after encoding).
Nothing is allowed above 9.5 kHz in the synths (partials are dropped, noise is low-passed):
small ears and TV tweeters both hate fizz up there.
Music is not made here: see assets/audio/CUES.md for the music file spec.
"""
import argparse
import math
import os
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
TAU = 2.0 * math.pi
PARTIAL_CEILING = 9500.0

AUDIO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_TARGET = -16.0
MUSIC_TARGET = -20.0
TP_CEILING = -1.0
SHORT_CUE = 0.6


# ---------------------------------------------------------------- primitives

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def silence(sec):
    return [0.0] * int(round(sec * SR))


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    """Add src into dst at `at` seconds. wrap=True folds overhang back to the start (loops)."""
    o = int(round(at * SR))
    n = len(dst)
    if wrap:
        for i, s in enumerate(src):
            dst[(o + i) % n] += s * gain
    else:
        for i in range(max(0, -o), min(len(src), n - o)):
            dst[o + i] += src[i] * gain
    return dst


def osc(dur, freq, partials=((1, 1.0, 1.0),), decay=None, attack=0.002, amp=None):
    """Additive oscillator. freq: Hz or f(t). partials: (ratio, gain, decay_scale); partial k
    decays as exp(-t * decay_scale / decay). amp: optional overall envelope f(t).
    Partials above PARTIAL_CEILING are skipped."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = [0.0] * len(partials)
    fixed = not callable(freq)
    for i in range(n):
        t = i / SR
        f = freq if fixed else freq(t)
        s = 0.0
        for k, (r, g, ds) in enumerate(partials):
            fk = f * r
            ph[k] += TAU * fk / SR
            if fk < PARTIAL_CEILING:
                s += (g if decay is None else g * math.exp(-t * ds / decay)) * math.sin(ph[k])
        a = min(1.0, t / attack) if attack > 0 else 1.0
        if amp is not None:
            a *= amp(t)
        out[i] = s * a
    return fades(out, 0.0, 0.003)   # never stop a ringing partial dead


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def envelope(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def svf(x, fc, q=0.707, mode="low", circular=False):
    """TPT state-variable filter. fc: Hz or f(t). circular: run twice so the state at the
    start equals the state at the end (seamless loops)."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    moving = callable(fc)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(fc) if not moving else (0, 0, 0)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            if moving:
                a1, a2, a3 = coeffs(fc(i / SR))
            v3 = v - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2 if mode == "low" else (k * v1 if mode == "band" else v - k * v1 - v2)
    return out


def soft(x, fc, circular=False):
    """4-pole low-pass (two cascaded SVFs): keeps noise sources out of the top octave."""
    return svf(svf(x, fc, circular=circular), fc, circular=circular)


def dc_block(x, circular=False):
    r = 0.9972  # ~20 Hz
    x1 = y1 = 0.0
    out = [0.0] * len(x)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            y1 = v - x1 + r * y1
            x1 = v
            out[i] = y1
    return out


def fades(x, fade_in=0.001, fade_out=0.02):
    n = len(x)
    fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        x[i] *= i / fi
    for i in range(min(fo, n)):
        x[n - 1 - i] *= (i / fo) ** 2
    return x


def limit(x, threshold, lookahead=0.002, release=0.06):
    """Lookahead peak limiter: shaves transients so loudness can rise under the peak ceiling."""
    n = len(x)
    la = int(lookahead * SR)
    need = [min(1.0, threshold / abs(v)) if v else 1.0 for v in x]
    gain = [1.0] * n
    for i in range(n):   # n is small (SFX only), so a plain window minimum is fine
        gain[i] = min(need[max(0, i - la):i + la + 1])
    rel = math.exp(-1.0 / (release * SR))
    g = 1.0
    for i in range(n):
        g = gain[i] if gain[i] < g else gain[i] + (g - gain[i]) * rel
        gain[i] = g
    return [v * gain[i] for i, v in enumerate(x)]


def peak_normalise(x, peak=0.5):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


# ---------------------------------------------------------------- instruments

MARIMBA = ((1, 1.0, 1.0), (3.98, 0.30, 3.0), (9.85, 0.06, 6.0))
XYLO = ((1, 1.0, 1.0), (3.0, 0.28, 2.5), (6.1, 0.07, 5.0))
BELL = ((1, 1.0, 1.0), (2.76, 0.40, 1.8), (5.40, 0.12, 3.0), (8.93, 0.04, 4.0))
WOOD = ((1, 1.0, 1.0), (2.57, 0.35, 1.6), (4.80, 0.12, 2.6))


def mallet(rng, fc=3000.0, sec=0.005, gain=0.25):
    n = int(sec * SR)
    x = [rng.uniform(-1, 1) * (1 - i / n) ** 2 for i in range(n)]
    return [v * gain for v in svf(x, fc)]


def struck(f, decay, rng, partials=MARIMBA, vel=1.0, click=0.2):
    """Marimba / xylophone / bell note: decaying partials plus a mallet tick."""
    x = osc(min(decay * 7.0, 3.0), f, partials, decay=decay, attack=0.0015)
    mix(x, mallet(rng, fc=min(4000.0, f * 4.0)), 0.0, click)
    return [v * vel for v in x]


def formant(x):
    return (0.25 + math.exp(-((x - 650) / 260) ** 2) + 0.6 * math.exp(-((x - 1700) / 420) ** 2)
            + 0.25 * math.exp(-((x - 2800) / 500) ** 2))


def kazoo(f, sec, vib_rate=5.5, vib_depth=0.012, attack=0.015, release=0.06):
    """Buzzy, voice-like toy horn: band-limited saw shaped by fixed formants, with vibrato."""
    parts = []
    n = 1
    while n * f < PARTIAL_CEILING:
        parts.append((n, formant(n * f) / n, 0.0))
        n += 1
    total = sec

    def amp(t):
        return min(1.0, (total - t) / release) if t > total - release else 1.0

    def freq(t):
        return f * (1.0 + vib_depth * min(1.0, t / 0.12) * math.sin(TAU * vib_rate * t))

    return osc(sec, freq, tuple(parts), attack=attack, amp=amp)


def chirp(f0, f1, sec, partials=((1, 1.0, 0.0),), attack=0.004):
    """Pitch glide f0 -> f1 (exponential) with a rounded envelope."""
    return osc(sec, lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), partials, attack=attack,
               amp=lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 0.6)


def sparkle(rng, count, start, end, gain=0.12, notes=(96, 98, 100, 103, 105)):
    """A few quiet glockenspiel pings from a high C-major pentatonic."""
    out = silence(end + 0.3)
    for _ in range(count):
        mix(out, struck(midi(rng.choice(notes)), 0.05, rng, BELL, click=0.05),
            rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


def chord(notes, decay, rng, partials=MARIMBA, vel=1.0):
    out = silence(min(decay * 7.0, 3.0) + 0.01)
    for n in notes:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), 0.0, vel / len(notes) ** 0.5)
    return out


# ---------------------------------------------------------------- cues
# Each returns raw samples at any scale; build() cleans them up.

# ---------------------------------------------------------------- spaceballs primitives

# Cartoon formants (F1, F2, F3), a little brighter than an adult voice so it reads as a Jarling.
VOWELS = {"a": (820, 1250, 2650), "e": (520, 1900, 2650), "i": (330, 2350, 3050),
          "o": (520, 880, 2500), "u": (360, 760, 2400), "l": (320, 1100, 2600)}
METAL = ((1, 1.0, 1.0), (2.41, 0.6, 1.4), (3.93, 0.4, 2.0), (5.33, 0.25, 3.0), (6.9, 0.12, 4.0))


def saw(freq, sec):
    """PolyBLEP sawtooth (cheap, nearly alias-free); freq: Hz or f(t)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    fixed = not callable(freq)
    for i in range(n):
        dt = (freq if fixed else freq(i / SR)) / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        v = 2.0 * ph - 1.0
        if ph < dt:
            x = ph / dt
            v -= x + x - x * x - 1.0
        elif ph > 1.0 - dt:
            x = (ph - 1.0) / dt
            v -= x * x + x + x + 1.0
        out[i] = v
    return out


def ar(total, attack=0.01, release=0.05):
    """Attack / release envelope as f(t)."""
    def f(t):
        a = min(1.0, t / attack) if attack > 0 else 1.0
        return a * (max(0.0, (total - t) / release) if t > total - release else 1.0)
    return f


def voice(f0, sec, vowel="a", amp=None, rng=None, breath=0.04, scale=1.0, rough=0.0,
          gains=(1.0, 0.55, 0.22), qs=(4.0, 7.0, 9.0)):
    """Formant voice: a saw through three band-pass filters. vowel: key of VOWELS, a tuple, or
    f(t) -> (F1, F2, F3) for glides (\"mi-a-ow\"). rough: amplitude flutter for croaks."""
    src = saw(f0, sec)
    if rng is not None and breath:
        src = [v + breath * rng.uniform(-1, 1) for v in src]
    if rough:
        src = [v * (1.0 - rough + rough * abs(math.sin(math.pi * 38.0 * i / SR)))
               for i, v in enumerate(src)]
    out = [0.0] * len(src)
    for k in range(3):
        if callable(vowel):
            fc = (lambda t, k=k: vowel(t)[k] * scale)
        else:
            fc = (VOWELS[vowel] if isinstance(vowel, str) else vowel)[k] * scale
        mix(out, svf(src, fc, qs[k], "band"), 0.0, gains[k])
    env = amp or ar(sec)
    return fades([v * env(i / SR) for i, v in enumerate(out)], 0.002, 0.01)


def glide(a, b, t0, t1):
    """Vowel glide a -> b between t0 and t1 as f(t) -> formants."""
    va, vb = VOWELS[a], VOWELS[b]

    def f(t):
        u = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
        return tuple(x + (y - x) * u for x, y in zip(va, vb))
    return f


def burst(rng, sec, fc, q=1.0, decay=0.01, mode="band"):
    """Filtered noise hit with an exponential tail: cracks, slaps, claps, ticks."""
    x = svf(noise(sec, rng), fc, q, mode)
    return fades([v * math.exp(-i / SR / decay) for i, v in enumerate(x)], 0.0005, 0.004)


def thump(f0, f1, sec, decay):
    """Sine with a falling pitch: the body of every kick and landing."""
    return osc(sec, lambda t: f1 + (f0 - f1) * math.exp(-t / (decay * 0.6)), decay=decay,
               attack=0.001)


def rumble(rng, sec, fc, decay, attack=0.003):
    x = soft(noise(sec, rng), fc)
    return fades([v * min(1.0, i / SR / attack) * math.exp(-i / SR / decay)
                  for i, v in enumerate(x)], 0.0, 0.05)


def whistle(f0, f1, sec, rng, curve=1.3, vib=0.018, breath=0.06):
    """Slide whistle: a near-sine rising f0 -> f1 with vibrato and a little breath."""
    def freq(t):
        u = min(1.0, t / sec) ** curve
        return f0 * (f1 / f0) ** u * (1.0 + vib * math.sin(TAU * 6.0 * t))
    x = osc(sec, freq, ((1, 1.0, 0.0), (2, 0.07, 0.0), (3, 0.02, 0.0)), attack=0.03,
            amp=lambda t: min(1.0, (sec - t) / 0.08) if t > sec - 0.08 else 1.0)
    air = svf(noise(sec, rng), (f0 + f1) * 0.6, 2.0, "band")
    return [v + breath * a for v, a in zip(x, air)]


def notes_seq(seq, rng, partials=MARIMBA, decay=0.12, vel=1.0):
    """[(midi_note, at_seconds), ...] of struck notes."""
    end = max(at for _, at in seq)
    out = silence(end + min(decay * 7.0, 3.0) + 0.02)
    for n, at in seq:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), at, vel)
    return out


def brass(f, sec, rng, wah=None, vib=0.0, scoop=0.0, bright=2200.0):
    """Toy trombone / fanfare horn: saw, brightness follows the envelope (wah: f(t) 0..1)."""
    def freq(t):
        s = 1.0 - scoop * math.exp(-t / 0.04)
        return f * s * (1.0 + vib * min(1.0, t / 0.4) * math.sin(TAU * 5.0 * t))
    src = saw(freq, sec)
    w = wah or (lambda t: 1.0)
    x = svf(src, lambda t: 250.0 + bright * w(t), 1.2)
    env = ar(sec, 0.02, 0.08)
    return [v * env(i / SR) for i, v in enumerate(x)]


def clap(rng):
    x = burst(rng, 0.06, rng.uniform(1100, 1700), 1.4, 0.008)
    mix(x, burst(rng, 0.06, rng.uniform(700, 900), 2.0, 0.012), 0.0, 0.4)
    return x


# ---------------------------------------------------------------- cues: run-up and kicks

def steps(rng, kind, times):
    """Silly footsteps. bare: wet slaps (Jeff). boot: heavy clonks (Chuck)."""
    out = silence(times[-1] + 0.3)
    for i, at in enumerate(times):
        lr = 1.0 if i % 2 == 0 else 0.86   # left / right foot differ a little
        if kind == "bare":
            s = burst(rng, 0.05, 1500 * lr * rng.uniform(0.9, 1.1), 1.3, 0.011)
            mix(s, thump(260 * lr, 130, 0.07, 0.025), 0.0, 0.5)
        else:
            s = thump(120 * lr, 55, 0.18, 0.06)
            mix(s, struck(midi(47 + (0 if i % 2 == 0 else 2)), 0.035, rng, WOOD, click=0.4), 0.0, 0.55)
            mix(s, burst(rng, 0.08, 650, 0.9, 0.02), 0.0, 0.5)
        mix(out, s, at, rng.uniform(0.85, 1.0))
    return out


def windup_char(kind, n_steps, gap0, gap1, wf0, wf1):
    """Run-up: scampering steps that speed up under a rising slide whistle."""
    def make(rng):
        times, at = [], 0.0
        for i in range(n_steps):
            times.append(at)
            at += gap0 + (gap1 - gap0) * i / max(1, n_steps - 1)
        out = steps(rng, kind, times)
        w = whistle(wf0, wf1, times[-1] + 0.1, rng)
        out = out + silence(max(0.0, (times[-1] + 0.35) - len(out) / SR))
        mix(out, w, 0.08, 0.18)
        return out
    return make


def windup(f0, f1, sec):
    def make(rng):
        out = whistle(f0, f1, sec, rng, curve=1.8)
        mix(out, osc(0.12, 90.0, decay=0.05), 0.0, 0.3)   # a little knee-bend boing
        return out + silence(0.05)
    return make


def kick_thwack(f0, crack_fc, wood):
    def make(rng):
        out = thump(f0, 65, 0.25, 0.05)
        mix(out, burst(rng, 0.08, crack_fc, 0.9, 0.014), 0.0, 0.9)
        mix(out, struck(midi(wood), 0.04, rng, WOOD, click=0.3), 0.0, 0.35)
        return out
    return make


def kick_big(f0, crack_fc, wood):
    def make(rng):
        out = thump(f0, 48, 0.45, 0.1)
        mix(out, burst(rng, 0.12, crack_fc, 0.8, 0.025), 0.0, 1.0)
        mix(out, struck(midi(wood), 0.06, rng, WOOD, click=0.3), 0.0, 0.4)
        mix(out, rumble(rng, 0.4, 350, 0.08), 0.0, 0.5)
        return out
    return make


def kick_cannon(rng):
    out = thump(95, 32, 1.3, 0.3)
    mix(out, rumble(rng, 1.3, 260, 0.35), 0.0, 1.2)
    mix(out, burst(rng, 0.05, 2400, 0.7, 0.008), 0.0, 0.8)
    for _ in range(14):   # debris and crackle
        mix(out, burst(rng, 0.03, rng.uniform(900, 2600), 2.0, 0.004), rng.uniform(0.15, 0.8),
            rng.uniform(0.08, 0.2))
    return out


def kick_sonic(rng):
    out = silence(2.0)
    for at in (0.0, 0.085):   # the N-wave: two cracks
        mix(out, burst(rng, 0.06, 1800, 0.6, 0.01), at, 1.0)
        mix(out, thump(110, 40, 0.5, 0.12), at, 0.8)
    mix(out, rumble(rng, 1.8, 180, 0.55, attack=0.02), 0.05, 1.3)
    zoom = osc(0.9, lambda t: 2400 * (380 / 2400) ** (t / 0.9), ((1, 1.0, 0.0), (2, 0.1, 0.0)),
               amp=lambda t: math.sin(math.pi * t / 0.9) ** 0.8)
    mix(out, zoom, 0.15, 0.22)
    mix(out, sparkle(rng, 5, 0.3, 0.9, 0.5), 0.0, 0.5)
    return out


def whoosh(f_lo, f_hi, sec, tone):
    def make(rng):
        def fc(t):
            return f_lo + (f_hi - f_lo) * math.sin(math.pi * min(1.0, t / sec)) ** 1.5
        x = svf(noise(sec, rng), fc, 2.6, "band")
        if tone:
            mix(x, osc(sec, lambda t: fc(t) * 0.5), 0.0, 0.08)
        return [v * math.sin(math.pi * i / SR / sec) ** 1.2 for i, v in enumerate(x)]
    return make


# ---------------------------------------------------------------- cues: the climb

def tier_up(seq):
    def make(rng):
        out = notes_seq([(n, i * 0.055) for i, n in enumerate(seq)], rng, BELL, 0.09)
        mix(out, sparkle(rng, 8, 0.1, 0.5, 0.35), 0.0, 1.0)
        return out
    return make


def gag_cat(rng):
    # "mi-a-ow?": a startled rooftop cat
    def f0(t):
        return 520 + 220 * math.sin(math.pi * min(1.0, t / 0.55)) - 120 * max(0.0, t - 0.45)

    def vowel(t):
        if t < 0.12:
            return glide("i", "a", 0.0, 0.12)(t)
        return glide("a", "u", 0.3, 0.6)(t)
    return voice(f0, 0.7, vowel, ar(0.7, 0.04, 0.2), rng, 0.06, 1.25) + silence(0.05)


def gag_birds(rng):
    # A squawk and two tweets
    out = silence(0.9)

    def sq(t):
        return 700 + 500 * math.sin(math.pi * min(1.0, t / 0.22))
    mix(out, voice(sq, 0.24, (900, 1900, 3000), ar(0.24, 0.01, 0.08), rng, 0.15, 1.0, rough=0.5),
        0.0, 1.0)
    for at, f in ((0.38, 2600), (0.55, 3000)):
        mix(out, chirp(f * 0.7, f, 0.09, ((1, 1.0, 0.0), (2, 0.05, 0.0))), at, 0.35)
    return out


def gag_plane(rng):
    sec = 2.2

    def f(t):   # Doppler: the plane passes overhead
        return 92 * (1.0 + 0.06 * math.tanh((1.1 - t) * 2.5))
    x = [a + b for a, b in zip(saw(f, sec), saw(lambda t: f(t) * 1.013, sec))]
    x = svf(x, lambda t: 500 + 500 * math.sin(math.pi * t / sec), 1.0)
    mix(x, soft(noise(sec, rng), 700), 0.0, 0.25)
    return [v * math.sin(math.pi * i / SR / sec) ** 1.5 for i, v in enumerate(x)]


def gag_satellite(rng):
    out = silence(0.9)
    for i, (f, at) in enumerate(((1320, 0.0), (990, 0.16), (1320, 0.32), (1760, 0.48))):
        mix(out, osc(0.11, f, ((1, 1.0, 0.0), (3, 0.12, 0.0)), attack=0.004, amp=ar(0.11, 0.004, 0.02)),
            at, 0.6)
    return out


def gag_alien(rng):
    # "boop be-doop": a wobbly, friendly theremin hello
    out = silence(1.0)
    for f0, f1, at, sec in ((400, 640, 0.0, 0.22), (700, 520, 0.3, 0.12), (520, 880, 0.45, 0.3)):
        x = osc(sec, lambda t, f0=f0, f1=f1, sec=sec: f0 * (f1 / f0) ** (t / sec)
                * (1.0 + 0.03 * math.sin(TAU * 9.0 * t)), ((1, 1.0, 0.0), (2, 0.15, 0.0)),
                attack=0.01, amp=ar(sec, 0.01, 0.06))
        mix(out, x, at, 0.6)
    return out


def land_thud(rng):
    out = thump(120, 55, 0.3, 0.06)
    mix(out, rumble(rng, 0.2, 450, 0.035), 0.0, 0.7)
    return out


def land_bonk(rng):
    out = osc(0.35, lambda t: 760 * (1.0 - 0.25 * min(1.0, t / 0.12)), WOOD, decay=0.07, attack=0.001)
    mix(out, thump(160, 70, 0.2, 0.04), 0.0, 0.7)
    mix(out, mallet(rng, 2500), 0.0, 1.0)
    return out


# ---------------------------------------------------------------- cues: picking upgrades

def card_move(note):
    return lambda rng: struck(midi(note), 0.035, rng, XYLO, click=0.25)[:int(0.25 * SR)]


def card_pick(rng):
    out = silence(0.8)
    fwip = svf(noise(0.09, rng), lambda t: 900 * (3.5 ** (t / 0.09)), 2.0, "band")
    mix(out, [v * math.sin(math.pi * i / SR / 0.09) for i, v in enumerate(fwip)], 0.0, 0.8)
    mix(out, chord((84, 91), 0.12, rng), 0.07, 0.9)
    return out


def upgrade_clank(rng):
    out = silence(0.7)
    mix(out, osc(0.6, 520, METAL, decay=0.12), 0.0, 1.0)
    mix(out, burst(rng, 0.03, 3000, 1.0, 0.004), 0.0, 0.6)
    mix(out, osc(0.5, 690, METAL, decay=0.08), 0.09, 0.5)
    return out


def upgrade_boing(rng):
    sec = 0.75
    return osc(sec, lambda t: 170 * (1.0 + 0.9 * t) * (1.0 + 0.45 * math.exp(-t / 0.22)
                                                       * math.sin(TAU * 13.0 * t)),
               ((1, 1.0, 1.0), (2, 0.25, 1.5)), decay=0.3, attack=0.002)


def upgrade_zip(rng):
    out = silence(0.75)
    at, gap = 0.0, 0.03
    while at < 0.33:
        mix(out, burst(rng, 0.01, 3800, 2.0, 0.0015), at, 0.7)
        at += gap
        gap = max(0.009, gap * 0.9)
    mix(out, chirp(400, 1600, 0.33), 0.0, 0.25)
    mix(out, struck(midi(96), 0.08, rng, BELL, click=0.1), 0.34, 0.5)
    return out


def curse(rng):
    # Sad trombone: wah, wah, wah, waaaaah
    out = silence(2.4)
    seq = ((55, 0.0, 0.3), (54, 0.34, 0.3), (53, 0.68, 0.3), (52, 1.02, 1.2))
    for n, at, sec in seq:
        last = sec > 1.0
        wah = (lambda t: 0.25 + 0.75 * (0.5 - 0.5 * math.cos(TAU * 2.6 * t))) if last else \
              (lambda t, s=sec: 0.2 + 0.8 * math.sin(math.pi * min(1.0, t / s)))
        mix(out, brass(midi(n), sec, rng, wah, vib=0.02 if last else 0.0, scoop=0.03, bright=1500),
            at, 1.0)
    return out


def frog_ribbit(f0, scale):
    def make(rng):
        out = silence(0.45)
        mix(out, voice(lambda t: f0 * (1.1 - 0.4 * t / 0.1), 0.1, glide("i", "u", 0.0, 0.1),
                       ar(0.1, 0.008, 0.03), rng, 0.08, scale, rough=0.8), 0.0, 1.0)
        mix(out, voice(lambda t: f0 * 1.15, 0.13, glide("i", "e", 0.0, 0.13),
                       ar(0.13, 0.006, 0.05), rng, 0.08, scale, rough=0.8), 0.15, 1.0)
        return out
    return make


def frog_boop(rng):
    out = silence(0.5)
    mix(out, chirp(300, 1800, 0.07), 0.0, 0.5)   # thwip: out goes the tongue
    mix(out, osc(0.22, lambda t: 620 * (360 / 620) ** (t / 0.22), ((1, 1.0, 0.0), (2, 0.2, 0.0)),
                 attack=0.005, amp=ar(0.22, 0.005, 0.08)), 0.09, 0.9)
    return out


# ---------------------------------------------------------------- cues: space and the crowd

def space(rng):
    out = silence(3.0)
    mix(out, brass(midi(55), 0.16, rng, scoop=0.02), 0.0, 0.7)   # ta-
    for n in (60, 64, 67, 72):                                   # -DAAA
        mix(out, brass(midi(n), 1.25, rng, lambda t: min(1.0, 0.4 + t * 1.5) * math.exp(-t * 0.8),
                       vib=0.01), 0.2, 0.45)
    mix(out, thump(90, 45, 0.6, 0.2), 0.2, 0.9)
    mix(out, sparkle(rng, 10, 0.3, 1.3, 0.4), 0.0, 1.0)
    # then the radio: quindar beep, crackle, a little muffled chatter, beep
    mix(out, osc(0.12, 2500, attack=0.004, amp=ar(0.12, 0.004, 0.02)), 1.55, 0.18)
    hiss = svf(noise(1.15, rng), 1700, 1.5, "band")
    mix(out, [v * ar(1.15, 0.05, 0.1)(i / SR) for i, v in enumerate(hiss)], 1.7, 0.12)
    for _ in range(18):
        mix(out, burst(rng, 0.02, rng.uniform(1200, 3200), 2.0, 0.003), rng.uniform(1.7, 2.8),
            rng.uniform(0.1, 0.3))
    chat = voice(lambda t: 170 + 40 * math.sin(TAU * 3.0 * t), 0.75,
                 lambda t: VOWELS["aeoua"[int(t * 9) % 5]], ar(0.75, 0.02, 0.1), rng, 0.1)
    mix(out, svf(chat, 1500, 1.2, "band"), 1.85, 0.35)
    mix(out, osc(0.12, 2500, attack=0.004, amp=ar(0.12, 0.004, 0.02)), 2.75, 0.18)
    return out


def cheer(n_voices, claps, sec):
    """A small crowd of Jarlings: \"yaaay!\" voices, a breathy roar, and claps."""
    def make(rng):
        out = silence(sec)
        for _ in range(n_voices):
            f = rng.uniform(290, 520)
            d = rng.uniform(0.6, 1.1)
            at = rng.uniform(0.0, 0.25)
            v = voice(lambda t, f=f, d=d: f * (1.0 + 0.25 * min(1.0, t / 0.15) - 0.1 * t / d)
                      * (1.0 + 0.02 * math.sin(TAU * 6.0 * t)),
                      d, glide("e", "a", 0.05, 0.25), ar(d, 0.04, 0.3), rng, 0.08, rng.uniform(1.05, 1.3))
            mix(out, v, at, rng.uniform(0.25, 0.45))
        roar = svf(noise(sec, rng), 1100, 0.6, "band")
        mix(out, [v * ar(sec, 0.08, sec * 0.6)(i / SR) for i, v in enumerate(roar)], 0.0, 0.25)
        for _ in range(claps):
            mix(out, clap(rng), rng.uniform(0.15, sec - 0.2), rng.uniform(0.3, 0.6))
        return out
    return make


def confetti(rng):
    out = silence(1.5)
    mix(out, burst(rng, 0.05, 2000, 0.8, 0.008), 0.0, 1.0)   # party popper
    mix(out, thump(170, 80, 0.12, 0.03), 0.0, 0.8)
    for _ in range(140):                                      # paper rustling down
        at = 0.05 + 1.25 * rng.random() ** 1.6
        mix(out, burst(rng, 0.01, rng.uniform(3500, 7000), 1.5, 0.0015), at, rng.uniform(0.1, 0.3))
    mix(out, sparkle(rng, 6, 0.08, 0.6, 0.5), 0.0, 0.8)
    return out


def honk(times):
    """Clown bike horn: a squeezed buzzy saw through a nasal formant."""
    def make(rng):
        out = silence(times[-1] + 0.4)
        for at in times:
            sec = 0.26
            x = voice(lambda t: 370 * (1.0 - 0.06 * max(0.0, t - 0.18) / 0.08), sec,
                      (950, 1550, 2600), ar(sec, 0.01, 0.05), rng, 0.05, qs=(3.0, 5.0, 6.0))
            mix(out, [math.tanh(3.0 * v) for v in x], at, 1.0)
        return out
    return make


def opera(rng):
    # "La-LAAAAA": the diva kick
    sec = 1.9

    def f0(t):
        base = midi(69) if t < 0.28 else midi(76) + (midi(69) - midi(76)) * math.exp(-(t - 0.28) / 0.05)
        return base * (1.0 + 0.035 * min(1.0, max(0.0, t - 0.4) / 0.5) * math.sin(TAU * 5.6 * t))

    def vowel(t):
        if t < 0.28:
            return glide("l", "a", 0.0, 0.06)(t)
        return glide("l", "a", 0.28, 0.34)(t)
    x = voice(f0, sec, vowel, lambda t: (0.6 if t < 0.28 else min(1.0, 0.6 + (t - 0.28)))
              * ar(sec, 0.03, 0.25)(t), rng, 0.03, 1.1)
    mix(x, svf(x, 3000, 5.0, "band"), 0.0, 0.5)   # singer's ring
    return x


# ---------------------------------------------------------------- cues: input and flow

def hop(f0):
    sec = 0.25
    return lambda rng: osc(sec, lambda t: f0 * (1.0 + 0.9 * t / sec)
                           * (1.0 + 0.12 * math.exp(-t / 0.08) * math.sin(TAU * 24.0 * t)),
                           ((1, 1.0, 0.0), (2, 0.2, 0.0)), attack=0.003, amp=ar(sec, 0.003, 0.12))


def shout(f0, f1, a, b):
    sec = 0.22
    return lambda rng: voice(lambda t: f0 + (f1 - f0) * t / sec, sec, glide(a, b, 0.03, 0.14),
                             ar(sec, 0.01, 0.08), rng, 0.08, 1.2)


def ui_confirm(rng):
    return notes_seq([(72, 0.0), (79, 0.07)], rng, MARIMBA, 0.12)


def player_join(rng):
    out = notes_seq([(72, 0.06), (76, 0.13), (79, 0.2), (84, 0.27)], rng, MARIMBA, 0.1)
    mix(out, chirp(400, 1200, 0.07), 0.0, 0.4)
    return out


def round_start(rng):
    # A friendly pea whistle: two short trilled toots
    out = silence(0.75)
    for at, sec in ((0.0, 0.16), (0.24, 0.36)):
        x = osc(sec, lambda t: 1750 * (1.0 + 0.04 * math.sin(TAU * 28.0 * t)),
                ((1, 1.0, 0.0), (2, 0.05, 0.0)), attack=0.01, amp=ar(sec, 0.01, 0.04))
        mix(out, x, at, 0.6)
        mix(out, [v * 0.06 for v in svf(noise(sec, rng), 1750, 3.0, "band")], at)
    return out


def round_end(rng):
    out = notes_seq([(67, 0.0), (72, 0.12)], rng, MARIMBA, 0.15)
    mix(out, chord((72, 76, 79), 0.18, rng), 0.12, 0.7)
    return out


def pause(rng):
    return notes_seq([(76, 0.0), (72, 0.08)], rng, XYLO, 0.08)


def restart_arm(rng):
    return notes_seq([(79, 0.0), (74, 0.13)], rng, WOOD, 0.04)


# ---------------------------------------------------------------- cues: menus (Showtime kit)
# scenes/ui/kit/ui_sound.gd plays sfx/<cue>.ogg when it exists (else a raw code synth) and passes
# its pitch through, so P1 / P2 and the countdown's rising ticks keep their pitch moves.

def ui_move(rng):
    return struck(midi(84), 0.03, rng, XYLO, click=0.3)[:int(0.12 * SR)]


def ui_back(rng):
    return notes_seq([(79, 0.0), (72, 0.06)], rng, WOOD, 0.045)


def ui_tick(rng):
    return struck(midi(91), 0.012, rng, WOOD, click=0.35)[:int(0.06 * SR)]


def ui_toggle(rng):
    out = silence(0.16)
    mix(out, struck(midi(67), 0.025, rng, WOOD, click=0.4), 0.0, 0.9)
    mix(out, struck(midi(79), 0.03, rng, XYLO, click=0.2), 0.04, 0.6)
    return out


def player_ready(rng):
    out = notes_seq([(72, 0.0), (76, 0.07), (79, 0.14)], rng, MARIMBA, 0.1)
    mix(out, thump(160, 70, 0.18, 0.06), 0.21, 0.8)
    mix(out, chord((84, 88), 0.14, rng), 0.21, 0.6)
    return out


def player_unready(rng):
    return notes_seq([(76, 0.0), (69, 0.09)], rng, MARIMBA, 0.08)


def count_tick(rng):
    # A woodblock "tok" with a little marimba tone in it: the lobby raises its pitch each dot.
    out = silence(0.2)
    mix(out, struck(midi(81), 0.03, rng, WOOD, click=0.35), 0.0, 1.0)
    mix(out, struck(midi(81), 0.06, rng, MARIMBA, click=0.0), 0.0, 0.35)
    return out


def ui_go(rng):
    out = chord((72, 76, 79, 84), 0.22, rng)
    mix(out, thump(120, 55, 0.3, 0.1), 0.0, 0.9)
    mix(out, chirp(500, 1600, 0.12), 0.0, 0.25)
    return out


def ui_wipe(rng):
    out = silence(0.55)
    for i, at in enumerate((0.0, 0.13, 0.26)):
        mix(out, whoosh(400 + 150 * i, 2400 + 300 * i, 0.22, False)(rng), at, 0.8)
    return out


def ui_card(rng):
    # A soft cymbal-ish swell (low-passed noise, nothing above 9.5 kHz) into a marimba ding.
    sec = 0.55
    sw = svf(noise(sec, rng), lambda t: 2500 + 4500 * t / sec, 0.9, "band")
    out = silence(0.85)
    mix(out, [v * (i / SR / sec) ** 2 for i, v in enumerate(sw)], 0.0, 0.5)
    mix(out, chord((84, 91), 0.12, rng), sec, 0.8)
    return out


def ui_pause(rng):
    out = silence(0.65)
    mix(out, chirp(700, 260, 0.16, ((1, 1.0, 0.0), (2, 0.3, 0.0))), 0.0, 0.6)
    mix(out, notes_seq([(64, 0.0), (60, 0.1)], rng, MARIMBA, 0.14), 0.12, 0.8)
    return out


def char_swap(rng):
    out = silence(0.25)
    puff = svf(noise(0.08, rng), 1400, 0.8, "band")
    mix(out, [v * math.sin(math.pi * i / SR / 0.08) for i, v in enumerate(puff)], 0.0, 0.5)
    mix(out, chirp(380, 1100, 0.11), 0.05, 0.6)
    return out


# ---------------------------------------------------------------- cues: upgrade-piece gags
# upgrade_piece.gd plays gag_cue only if sfx/<cue>.ogg exists (no _N variants), so one file each.

def achoo(rng):
    # "ah... ah... AH-CHOO!": two breathy rising ahs, a bigger one, then a soft "choo"
    out = silence(1.25)
    for at, sec, f, g in ((0.0, 0.2, 330, 0.45), (0.27, 0.22, 370, 0.6), (0.56, 0.18, 420, 0.8)):
        mix(out, voice(lambda t, f=f, sec=sec: f * (1.0 + 0.25 * t / sec), sec, "a",
                       ar(sec, 0.05, 0.06), rng, 0.25, 1.15), at, g)
    ch = svf(noise(0.11, rng), 3200, 1.4, "band")   # "ch": soft and band-limited, not a spit
    mix(out, [v * ar(0.11, 0.005, 0.07)(i / SR) for i, v in enumerate(ch)], 0.76, 0.5)
    mix(out, voice(lambda t: 470 * (1.0 - 0.35 * t / 0.4), 0.4, "u", ar(0.4, 0.01, 0.25), rng,
                   0.12, 1.15), 0.82, 1.0)
    return out


def cannon_boom(rng):
    # A toy cannon: cork "pomf", a round low boom, a smoke puff and a falling slide whistle
    out = silence(1.5)
    mix(out, thump(900, 300, 0.05, 0.012), 0.0, 0.5)                # cork pop
    mix(out, thump(85, 34, 1.0, 0.24), 0.01, 1.0)
    mix(out, rumble(rng, 1.0, 220, 0.25, attack=0.01), 0.02, 0.9)
    mix(out, [v * ar(0.4, 0.02, 0.3)(i / SR) for i, v in enumerate(svf(noise(0.4, rng), 900, 0.8, "band"))],
        0.03, 0.25)                                                   # puff of smoke
    mix(out, whistle(1500, 500, 0.55, rng, curve=0.8), 0.45, 0.12)  # ...and away it goes
    return out


def confetti_pop(rng):
    # Party popper "pok!", a quick shower of paper and two glock pings
    out = silence(0.9)
    mix(out, thump(600, 180, 0.06, 0.015), 0.0, 0.8)
    mix(out, burst(rng, 0.04, 1600, 1.0, 0.006), 0.0, 0.8)
    for _ in range(70):
        at = 0.04 + 0.6 * rng.random() ** 1.4
        mix(out, burst(rng, 0.01, rng.uniform(3000, 6500), 1.5, 0.0015), at, rng.uniform(0.1, 0.25))
    mix(out, struck(midi(96), 0.07, rng, BELL, click=0.05), 0.08, 0.3)
    mix(out, struck(midi(100), 0.07, rng, BELL, click=0.05), 0.17, 0.25)
    return out


def hic(rng):
    # "hic!": a little glottal click and a squeaky upward "i"
    out = silence(0.3)
    mix(out, burst(rng, 0.01, 900, 1.5, 0.002), 0.0, 0.5)
    mix(out, voice(lambda t: 560 * (1.0 + 0.6 * t / 0.11), 0.11, glide("e", "i", 0.0, 0.05),
                   ar(0.11, 0.004, 0.04), rng, 0.15, 1.3), 0.005, 1.0)
    return out


def opera_la(rng):
    # A diva warming up: "la-la-LAAA!" (short; the long "la-LAAAA" is `opera`)
    out = silence(1.15)
    for n, at, sec in ((72, 0.0, 0.13), (76, 0.15, 0.13), (79, 0.3, 0.75)):
        def f0(t, n=n, long=sec > 0.5):
            return midi(n) * (1.0 + (0.03 * min(1.0, max(0.0, t - 0.15) / 0.3)
                                     * math.sin(TAU * 5.8 * t) if long else 0.0))
        x = voice(f0, sec, glide("l", "a", 0.0, 0.04), ar(sec, 0.012, 0.2 if sec > 0.5 else 0.03),
                  rng, 0.03, 1.1)
        mix(x, svf(x, 3000, 5.0, "band"), 0.0, 0.4)
        mix(out, x, at, 0.75 if sec < 0.5 else 1.0)
    return out


def slip(rng):
    # Banana peel: a squeaky skid, a zippy slide whistle up, and a soft bump on the bottom
    out = silence(1.0)
    mix(out, osc(0.12, lambda t: 1100 * (1.0 + 0.5 * t / 0.12), ((1, 1.0, 0.0), (2, 0.15, 0.0)),
                 attack=0.004, amp=ar(0.12, 0.004, 0.03)), 0.0, 0.35)   # skid squeak
    mix(out, whistle(500, 2100, 0.42, rng, curve=1.6), 0.08, 0.4)
    mix(out, thump(140, 60, 0.3, 0.07), 0.58, 1.0)
    mix(out, rumble(rng, 0.15, 500, 0.03), 0.58, 0.5)
    mix(out, osc(0.3, lambda t: 420 * (1.0 + 0.25 * math.exp(-t / 0.1) * math.sin(TAU * 16.0 * t)),
                 ((1, 1.0, 1.0),), decay=0.12), 0.6, 0.25)                # boing of the bottom
    return out


def squawk(rng):
    # Rubber chicken: a squeezed, nasal "bwaaa-aaak" that wheezes out
    sec = 0.55

    def f0(t):
        return 520 + 380 * math.sin(math.pi * min(1.0, t / 0.4)) ** 0.7 - 250 * max(0.0, t - 0.4)
    x = voice(f0, sec, lambda t: glide("u", "a", 0.0, 0.08)(t) if t < 0.3 else glide("a", "e", 0.3, 0.5)(t),
              ar(sec, 0.02, 0.12), rng, 0.12, 1.35, rough=0.35, qs=(3.0, 5.0, 6.0))
    out = [math.tanh(2.5 * v) for v in x]
    wheeze = svf(noise(0.18, rng), 2000, 2.0, "band")
    mix(out, [v * ar(0.18, 0.05, 0.1)(i / SR) for i, v in enumerate(wheeze)], sec - 0.12, 0.08)
    return out + silence(0.08)


def squeak(rng):
    # Balloon animal: two twisty rubber squeaks, "eek-eeek"
    out = silence(0.5)
    for at, sec, f in ((0.0, 0.12, 1250), (0.16, 0.22, 1400)):
        def freq(t, f=f, sec=sec):
            return f * (1.0 + 0.3 * t / sec) * (1.0 + 0.06 * math.sin(TAU * 42.0 * t))
        mix(out, osc(sec, freq, ((1, 1.0, 0.0), (2, 0.25, 0.0), (3, 0.08, 0.0)), attack=0.01,
                     amp=lambda t, sec=sec: math.sin(math.pi * t / sec) ** 0.5), at, 0.6)
    return out


def ref_whistle(rng):
    # Coach's pea whistle: "tweet-TWEEEET" (rounder and lower than a real one)
    out = silence(0.85)
    for at, sec, g in ((0.0, 0.13, 0.75), (0.19, 0.5, 1.0)):
        x = osc(sec, lambda t: 2100 * (1.0 + 0.035 * math.sin(TAU * 34.0 * t)),
                ((1, 1.0, 0.0), (2, 0.04, 0.0)), attack=0.012,
                amp=lambda t, sec=sec: ar(sec, 0.012, 0.05)(t) * (0.8 + 0.2 * math.sin(TAU * 34.0 * t)))
        mix(out, x, at, 0.6 * g)
        mix(out, [v * 0.05 for v in svf(noise(sec, rng), 2100, 3.0, "band")], at, g)
    return out


# ---------------------------------------------------------------- cues: gameplay gags

def frog_bloop(depth):
    # A sad little bloop (a deflated frog): a falling bubble, then a smaller lower "blp"
    def make(rng):
        out = silence(0.75)
        for at, sec, f0, f1, g in ((0.0, 0.26, 520, 520 * depth, 1.0), (0.32, 0.18, 330, 330 * depth, 0.6)):
            mix(out, osc(sec, lambda t, f0=f0, f1=f1, sec=sec: f0 * (f1 / f0) ** (t / sec)
                         * (1.0 + 0.04 * math.sin(TAU * 11.0 * t)), ((1, 1.0, 0.0), (2, 0.12, 0.0)),
                         attack=0.008, amp=ar(sec, 0.008, 0.1)), at, g)
        return out
    return make


def crowd_aww(n_voices, sec):
    """The Jarling crowd goes "awww" (so close!): falling voices and a soft breathy sigh."""
    def make(rng):
        out = silence(sec + 0.2)
        for _ in range(n_voices):
            f = rng.uniform(280, 480)
            d = rng.uniform(sec * 0.7, sec)
            at = rng.uniform(0.0, 0.15)
            v = voice(lambda t, f=f, d=d: f * (1.08 - 0.3 * t / d) * (1.0 + 0.015 * math.sin(TAU * 5.0 * t)),
                      d, glide("a", "o", 0.1, d * 0.8), ar(d, 0.08, d * 0.5), rng, 0.03,
                      rng.uniform(1.05, 1.25))
            mix(out, v, at, rng.uniform(0.25, 0.45))
        sigh = svf(noise(sec, rng), lambda t: 900 - 300 * t / sec, 0.8, "band")
        mix(out, [v * ar(sec, 0.1, sec * 0.6)(i / SR) for i, v in enumerate(sigh)], 0.0, 0.06)
        return out
    return make


def orbit_chime(seq):
    """Magic twinkle as a ball settles into orbit: a rising bell run, then a shimmering ring."""
    def make(rng):
        out = notes_seq([(n, i * 0.07) for i, n in enumerate(seq)], rng, BELL, 0.18, 0.7)
        ring = osc(1.1, midi(seq[-1]), ((1, 1.0, 1.0), (2.0, 0.3, 1.5)), decay=0.5, attack=0.03,
                   amp=lambda t: 0.75 + 0.25 * math.sin(TAU * 7.0 * t))    # shimmer
        mix(out, ring, len(seq) * 0.07, 0.35)
        mix(out, sparkle(rng, 9, 0.1, 1.0, 0.3), 0.0, 1.0)
        return out
    return make


def crowd_wild(n_voices, claps, sec):
    """Big crowd: a roar of "yaaay!", lots of claps, and two-finger whistles (wheee-whoo)."""
    def make(rng):
        out = cheer(n_voices, claps, sec)(rng)
        for _ in range(2):   # more waves of voices
            mix(out, cheer(n_voices // 2, claps // 2, sec * 0.7)(rng), rng.uniform(0.5, 0.8), 0.7)
        for at in (rng.uniform(0.1, 0.3), rng.uniform(0.9, 1.3)):
            f = rng.uniform(1500, 1800)
            mix(out, osc(0.5, lambda t, f=f: f * (1.0 + 0.35 * math.sin(math.pi * min(1.0, t / 0.5)) - 0.2 * t),
                         ((1, 1.0, 0.0), (2, 0.04, 0.0)), attack=0.02, amp=ar(0.5, 0.02, 0.1)), at, 0.22)
        return out
    return make


def trip(f0):
    """Shoelaces tied: a scuff, a startled "whoa!", two stumbling steps and a soft flop."""
    def make(rng):
        out = silence(1.0)
        sc = svf(noise(0.1, rng), lambda t: 1800 - 900 * t / 0.1, 1.2, "band")
        mix(out, [v * ar(0.1, 0.005, 0.06)(i / SR) for i, v in enumerate(sc)], 0.0, 0.5)
        mix(out, voice(lambda t: f0 * (1.0 + 0.4 * math.sin(math.pi * min(1.0, t / 0.25))), 0.25,
                       glide("u", "a", 0.02, 0.15), ar(0.25, 0.01, 0.08), rng, 0.08, 1.2), 0.06, 0.8)
        mix(out, steps(rng, "bare", (0.3, 0.42)), 0.0, 0.6)
        mix(out, thump(130, 55, 0.3, 0.07), 0.62, 1.0)
        mix(out, rumble(rng, 0.2, 450, 0.04), 0.62, 0.6)
        return out
    return make


def waddle(notes):
    """Too much lunch: three heavy, squishy steps, each with a tuba "bwomp" and a belly wobble."""
    def make(rng):
        out = silence(1.2)
        for i, n in enumerate(notes):
            at = i * 0.3
            mix(out, thump(110, 50, 0.2, 0.05), at, 0.6)
            mix(out, brass(midi(n), 0.2, rng, lambda t: math.sin(math.pi * min(1.0, t / 0.2)),
                           scoop=0.05, bright=700), at, 0.8)
            mix(out, osc(0.22, lambda t: 140 * (1.0 + 0.3 * math.exp(-t / 0.08) * math.sin(TAU * 12.0 * t)),
                         decay=0.08), at + 0.02, 0.35)   # belly jiggle
        return out
    return make


def butterfly(notes):
    """A butterfly flutters by: soft wing flaps and a light rising glockenspiel twinkle."""
    def make(rng):
        out = silence(1.4)
        at, k = 0.0, 0
        while at < 1.0:
            flap = svf(noise(0.03, rng), 1300 + 300 * math.sin(k), 1.0, "band")
            mix(out, [v * math.sin(math.pi * i / len(flap)) for i, v in enumerate(flap)], at,
                0.25 * (0.6 + 0.4 * math.sin(math.pi * at)))
            at += 0.055 + 0.01 * math.sin(k * 0.7)
            k += 1
        mix(out, notes_seq([(n, 0.05 + i * 0.16) for i, n in enumerate(notes)], rng, BELL, 0.07), 0.0, 0.45)
        return out
    return make


# ---------------------------------------------------------------- sky objects (Sky lane)
# The ball bumps into things on the way up (scenes/sky/): one cue per kind of bump.

def sky_pop(f):
    def make(rng):
        # Balloon "BANG-pff": a sharp rubber crack, a puff of air, a few paper bits, a glock ping
        out = silence(0.7)
        mix(out, burst(rng, 0.05, f, 0.8, 0.008), 0.0, 1.0)
        mix(out, burst(rng, 0.03, f * 2.6, 1.2, 0.003, "high"), 0.0, 0.6)
        mix(out, thump(f * 0.25, f * 0.08, 0.08, 0.025), 0.0, 0.6)
        mix(out, rumble(rng, 0.3, 900, 0.09), 0.01, 0.35)
        for _ in range(30):
            at = 0.05 + 0.45 * rng.random() ** 1.3
            mix(out, burst(rng, 0.01, rng.uniform(3000, 6000), 1.5, 0.0015), at, rng.uniform(0.08, 0.18))
        mix(out, struck(midi(98), 0.08, rng, BELL, click=0.05), 0.07, 0.25)
        return out
    return make


def sky_bonk(rng):
    # A hollow tin "BONK" with a wobble, then a small cross "hey!"
    out = silence(0.85)
    mix(out, osc(0.45, lambda t: 330 * (1.0 + 0.04 * math.sin(TAU * 9.0 * t)), METAL, decay=0.12), 0.0, 0.7)
    mix(out, burst(rng, 0.03, 1800, 1.2, 0.005), 0.0, 0.6)
    mix(out, thump(220, 90, 0.12, 0.04), 0.0, 0.6)
    mix(out, voice(lambda t: 300 + 140 * math.sin(math.pi * min(1.0, t / 0.22)), 0.26,
                   glide("e", "i", 0.04, 0.18), ar(0.26, 0.015, 0.09), rng, 0.08, 1.15), 0.42, 0.8)
    return out


def sky_flutter(rng):
    # Startled birds: a burst of wing flaps that thins out, and three panicky tweets
    out = silence(0.95)
    at = 0.0
    k = 0
    while at < 0.6:
        mix(out, burst(rng, 0.05, rng.uniform(700, 1400), 0.9, 0.012), at, 0.55 * (1.0 - at))
        at += 0.035 + 0.05 * at + 0.01 * rng.random()
        k += 1
    for at, f in ((0.05, 2700), (0.2, 3200), (0.33, 2900)):
        mix(out, chirp(f * 0.7, f, 0.08, ((1, 1.0, 0.0), (2, 0.05, 0.0))), at, 0.35)
    return out


def sky_boing(rng):
    # A soft, cushiony boing (cloud, balloon envelope, blimp): low sprung sine and a puff of air
    sec = 0.6

    def f(t):
        return 140 * (1.0 + 0.9 * t / sec) * (1.0 + 0.18 * math.exp(-t / 0.18) * math.sin(TAU * 13.0 * t))
    out = silence(0.7)
    mix(out, osc(sec, f, ((1, 1.0, 0.0), (2, 0.25, 0.0)), attack=0.01, amp=ar(sec, 0.01, 0.3)), 0.0, 0.8)
    mix(out, rumble(rng, 0.25, 700, 0.07), 0.0, 0.5)
    return out


def sky_twang(rng):
    # A kite string snags: a rubbery twang, then the kite whirring round, "fwip-fwip-fwip"
    out = silence(1.0)
    mix(out, osc(0.5, lambda t: 196 * (1.0 + 0.03 * math.exp(-t / 0.1) * math.sin(TAU * 7.0 * t)),
                 ((1, 1.0, 1.0), (2, 0.5, 1.5), (3, 0.3, 2.0), (4, 0.15, 3.0)), decay=0.18), 0.0, 0.8)
    for i in range(5):
        mix(out, burst(rng, 0.06, 900 + 220 * i, 1.4, 0.018), 0.18 + i * 0.13, 0.5 - 0.06 * i)
    return out


def sky_ping(rng):
    # Satellite / comet: a bright sonar "ping!" with a shimmer
    out = silence(0.9)
    mix(out, struck(midi(93), 0.35, rng, BELL, click=0.1), 0.0, 0.8)
    mix(out, osc(0.6, lambda t: 2093 * (1.0 + 0.004 * math.sin(TAU * 6.0 * t)), decay=0.25), 0.0, 0.25)
    mix(out, sparkle(rng, 4, 0.08, 0.5), 0.0, 1.0)
    return out


def sky_catch(rng):
    # The saucer's beam: "vwoom", a held wobble, then the toss: a rising alien "wheee!"
    out = silence(1.2)
    mix(out, osc(0.45, lambda t: 180 + 60 * math.sin(TAU * 6.0 * t), ((1, 1.0, 0.0), (2, 0.4, 0.0)),
                 attack=0.03, amp=ar(0.45, 0.03, 0.12)), 0.0, 0.6)
    mix(out, osc(0.55, lambda t: 500 * 2.0 ** (1.4 * t / 0.55) * (1.0 + 0.03 * math.sin(TAU * 7.0 * t)),
                 ((1, 1.0, 0.0), (3, 0.1, 0.0)), attack=0.02, amp=ar(0.55, 0.02, 0.15)), 0.4, 0.55)
    mix(out, sparkle(rng, 3, 0.75, 1.05), 0.0, 1.0)
    return out


def sky_flap(rng):
    # Laundry: a wet cloth "fwap", a flap and a peg flicking off
    out = silence(0.6)
    mix(out, burst(rng, 0.09, 1100, 0.8, 0.03), 0.0, 0.9)
    mix(out, burst(rng, 0.07, 1500, 0.9, 0.02), 0.16, 0.6)
    mix(out, struck(midi(84), 0.05, rng, MARIMBA, click=0.2), 0.3, 0.35)
    return out


# ---------------------------------------------------------------- files
# stem: (make, kind, trim dB). A stem ending in _<n> is variant n of its cue (Audio.gd picks one).


# ---------------------------------------------------------------- gap-close-3: cues the gags asked for

def inhale(f0):
    """Sneeze build-up: one breathy rising "hah" (the gag plays it three times, pitched up)."""
    def make(rng):
        out = silence(0.4)
        air = svf(noise(0.3, rng), 1800, 0.8, "band")
        mix(out, [v * ar(0.3, 0.15, 0.08)(i / SR) for i, v in enumerate(air)], 0.0, 0.35)
        mix(out, voice(lambda t: f0 * (1.0 + 0.3 * t / 0.22), 0.22, "a", ar(0.22, 0.08, 0.07), rng,
                       0.3, 1.15), 0.08, 0.6)
        return out
    return make


def choo(rng):
    # The sneeze itself: a quick breathy "AH", then a soft band-limited "CHOO" that falls.
    out = silence(0.7)
    mix(out, voice(lambda t: 440 * (1.0 + 0.2 * t / 0.12), 0.12, "a", ar(0.12, 0.02, 0.04), rng,
                   0.25, 1.15), 0.0, 0.8)
    ch = svf(noise(0.1, rng), 3200, 1.4, "band")
    mix(out, [v * ar(0.1, 0.004, 0.06)(i / SR) for i, v in enumerate(ch)], 0.13, 0.55)
    mix(out, voice(lambda t: 480 * (1.0 - 0.35 * t / 0.4), 0.4, "u", ar(0.4, 0.01, 0.25), rng,
                   0.12, 1.15), 0.18, 1.0)
    return out


def burp(rng):
    # Too Much Lunch: a long, low, rattly "buuuurp" with a little pop at the end.
    out = silence(0.8)
    mix(out, voice(lambda t: 95 * (1.0 + 0.15 * math.sin(math.pi * t / 0.55)), 0.55, "o",
                   ar(0.55, 0.03, 0.15), rng, 0.1, 0.9, rough=0.55), 0.0, 1.0)
    mix(out, thump(180, 90, 0.08, 0.03), 0.55, 0.4)
    return out


def uh_oh(rng):
    # The picked card shivers before the curse flips: a Jarling "uh-oh!" (two notes, down).
    out = silence(0.6)
    mix(out, voice(lambda t: 420.0, 0.16, "u", ar(0.16, 0.02, 0.05), rng, 0.05, 1.2), 0.0, 0.8)
    mix(out, voice(lambda t: 330 * (1.0 - 0.08 * t / 0.28), 0.28, "o", ar(0.28, 0.02, 0.12), rng,
                   0.05, 1.2), 0.2, 1.0)
    return out


def poof(rng):
    # Gear swaps on, or the frog turns back: a soft cushiony "pff" of smoke, a low pop, two twinkles.
    out = silence(0.7)
    air = svf(noise(0.3, rng), 900, 0.7, "band")
    mix(out, [v * ar(0.3, 0.01, 0.22)(i / SR) for i, v in enumerate(air)], 0.0, 0.7)
    mix(out, thump(240, 120, 0.09, 0.03), 0.0, 0.5)
    mix(out, sparkle(rng, 4, 0.08, 0.45, 0.25), 0.0, 1.0)
    return out


def crowd_clap(n, sec):
    """A decent kick: the sideline claps (no "yaaay"), a few whoops underneath."""
    def make(rng):
        out = silence(sec)
        for _ in range(n):
            mix(out, clap(rng), rng.uniform(0.0, sec - 0.15), rng.uniform(0.3, 0.6))
        for _ in range(2):
            f = rng.uniform(380, 520)
            mix(out, voice(lambda t, f=f: f * (1.0 + 0.3 * min(1.0, t / 0.1)), 0.25, "u",
                           ar(0.25, 0.03, 0.1), rng, 0.08, 1.2), rng.uniform(0.05, 0.4), 0.2)
        return out
    return make


FILES = {
    "windup_jeff_1": (windup_char("bare", 8, 0.16, 0.08, 520, 1900), "sfx", 0.0),
    "windup_jeff_2": (windup_char("bare", 9, 0.14, 0.07, 600, 2100), "sfx", 0.0),
    "windup_chuck_1": (windup_char("boot", 6, 0.22, 0.13, 380, 1400), "sfx", 0.0),
    "windup_chuck_2": (windup_char("boot", 7, 0.2, 0.12, 340, 1300), "sfx", 0.0),
    "windup_1": (windup(500, 1900, 0.55), "sfx", -1.0),
    "windup_2": (windup(440, 1700, 0.6), "sfx", -1.0),
    "kick_1_1": (kick_thwack(190, 1900, 64), "sfx", 0.0),
    "kick_1_2": (kick_thwack(170, 1600, 61), "sfx", 0.0),
    "kick_2_1": (kick_big(150, 1400, 57), "sfx", 0.0),
    "kick_2_2": (kick_big(135, 1200, 55), "sfx", 0.0),
    "kick_3": (kick_cannon, "sfx", 0.0),
    "kick_4": (kick_sonic, "sfx", 0.0),
    "whoosh_1": (whoosh(350, 2200, 1.3, False), "sfx", -3.0),
    "whoosh_2": (whoosh(300, 1800, 1.5, True), "sfx", -3.0),
    "tier_up_1": (tier_up((84, 88, 91, 96)), "sfx", -1.0),
    "tier_up_2": (tier_up((86, 89, 93, 98)), "sfx", -1.0),
    "gag_rooftops": (gag_cat, "sfx", -2.0),
    "gag_treetops": (gag_birds, "sfx", -2.0),
    "gag_clouds": (gag_plane, "sfx", -4.0),
    "gag_edge": (gag_satellite, "sfx", -3.0),
    "gag_space": (gag_alien, "sfx", -2.0),
    "land_1": (land_thud, "sfx", 0.0),
    "land_2": (land_bonk, "sfx", 0.0),
    "card_move_1": (card_move(79), "sfx", -2.0),
    "card_move_2": (card_move(81), "sfx", -2.0),
    "card_pick": (card_pick, "sfx", 0.0),
    "upgrade_on_1": (upgrade_clank, "sfx", 0.0),
    "upgrade_on_2": (upgrade_boing, "sfx", 0.0),
    "upgrade_on_3": (upgrade_zip, "sfx", 0.0),
    "curse": (curse, "sfx", 0.0),
    "frog_1": (frog_ribbit(210, 1.0), "sfx", -1.0),
    "frog_2": (frog_ribbit(170, 0.9), "sfx", -1.0),
    "frog_3": (frog_boop, "sfx", -1.0),
    "space": (space, "sfx", 0.0),
    "cheer_1": (cheer(12, 22, 1.8), "sfx", 0.0),
    "cheer_2": (cheer(14, 26, 1.9), "sfx", 0.0),
    "cheer_3": (cheer(10, 18, 1.6), "sfx", 0.0),
    "confetti": (confetti, "sfx", -1.0),
    "honk": (honk((0.0,)), "sfx", -1.0),   # one file: upgrade_piece.gd looks for honk.ogg
    "opera": (opera, "sfx", 0.0),
    "hop_1": (hop(320), "sfx", -2.0),
    "hop_2": (hop(360), "sfx", -2.0),
    "shout_1": (shout(400, 320, "u", "a"), "sfx", -1.0),
    "shout_2": (shout(430, 500, "e", "i"), "sfx", -1.0),
    "ui_confirm": (ui_confirm, "sfx", -1.0),
    "player_join": (player_join, "sfx", 0.0),
    "round_start": (round_start, "sfx", -3.0),
    "round_end": (round_end, "sfx", 0.0),
    "pause": (pause, "sfx", -2.0),
    "restart_arm": (restart_arm, "sfx", -1.0),
    # menus (Showtime kit, see above)
    "ui_move": (ui_move, "sfx", -4.0),
    "ui_back": (ui_back, "sfx", -3.0),
    "ui_tick": (ui_tick, "sfx", -5.0),
    "ui_toggle": (ui_toggle, "sfx", -3.0),
    "player_ready": (player_ready, "sfx", 0.0),
    "player_unready": (player_unready, "sfx", -2.0),
    "count_tick": (count_tick, "sfx", -2.0),
    "ui_go": (ui_go, "sfx", 0.0),
    "ui_wipe": (ui_wipe, "sfx", -3.0),
    "ui_card": (ui_card, "sfx", -2.0),
    "ui_pause": (ui_pause, "sfx", -1.0),
    "char_swap": (char_swap, "sfx", -2.0),
    # upgrade-piece gags (one file each, see above)
    "achoo": (achoo, "sfx", 0.0),
    "cannon_boom": (cannon_boom, "sfx", 0.0),
    "confetti_pop": (confetti_pop, "sfx", -1.0),
    "hic": (hic, "sfx", -2.0),
    "opera_la": (opera_la, "sfx", 0.0),
    "slip": (slip, "sfx", 0.0),
    "squawk": (squawk, "sfx", -1.0),
    "squeak": (squeak, "sfx", -2.0),
    "whistle": (ref_whistle, "sfx", -3.0),
    # gameplay gags
    "frog_bloop_1": (frog_bloop(0.45), "sfx", -1.0),
    "frog_bloop_2": (frog_bloop(0.55), "sfx", -1.0),
    "crowd_aww_1": (crowd_aww(12, 1.5), "sfx", 0.0),
    "crowd_aww_2": (crowd_aww(10, 1.3), "sfx", 0.0),
    "orbit_chime_1": (orbit_chime((84, 88, 91, 96, 100)), "sfx", -1.0),
    "orbit_chime_2": (orbit_chime((86, 89, 93, 98, 101)), "sfx", -1.0),
    "crowd_wild": (crowd_wild(16, 34, 2.6), "sfx", 0.0),
    "trip_1": (trip(380), "sfx", 0.0),
    "trip_2": (trip(430), "sfx", 0.0),
    "waddle_1": (waddle((41, 38, 41)), "sfx", -1.0),
    "waddle_2": (waddle((43, 41, 38)), "sfx", -1.0),
    "butterfly_1": (butterfly((88, 91, 93, 96, 100)), "sfx", -2.0),
    "butterfly_2": (butterfly((86, 91, 95, 98)), "sfx", -2.0),
    "inhale": (inhale(300), "sfx", -2.0),
    "choo": (choo, "sfx", 0.0),
    "burp": (burp, "sfx", -1.0),
    "uh_oh": (uh_oh, "sfx", -1.0),
    "poof": (poof, "sfx", -2.0),
    "crowd_clap_1": (crowd_clap(14, 1.1), "sfx", -1.0),
    "crowd_clap_2": (crowd_clap(18, 1.3), "sfx", -1.0),
    # sky objects (Sky lane, scenes/sky/)
    "sky_pop_1": (sky_pop(2200), "sfx", -1.0),
    "sky_pop_2": (sky_pop(2600), "sfx", -1.0),
    "sky_bonk": (sky_bonk, "sfx", -1.0),
    "sky_flutter": (sky_flutter, "sfx", -2.0),
    "sky_boing": (sky_boing, "sfx", -2.0),
    "sky_twang": (sky_twang, "sfx", -2.0),
    "sky_ping": (sky_ping, "sfx", -2.0),
    "sky_catch": (sky_catch, "sfx", -1.0),
    "sky_flap": (sky_flap, "sfx", -2.0),
}


# ---------------------------------------------------------------- ffmpeg

def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<i", int(round(max(-1.0, min(1.0, v)) * 8388607)))[:3]
                               for v in x))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def measure(path, tile=1):
    """(integrated LUFS, true peak dBTP) via ebur128. tile > 1 loops the input first."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats"]
    if tile > 1:
        cmd += ["-stream_loop", str(tile - 1)]
    cmd += ["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]
    err = run(cmd).stderr
    summary = err[err.rfind("Summary:"):]
    num = r"(-?inf|-?\d+(?:\.\d+)?)"
    lufs = float(re.search(r"I:\s+" + num + r" LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+" + num, summary).group(1))
    return lufs, peak


def rms_db(path, highpass=None):
    af = "astats=metadata=0"
    if highpass:
        af = "highpass=f=%d,highpass=f=%d,highpass=f=%d," % ((highpass,) * 3) + af
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    return float(re.findall(r"RMS level dB:\s+(-?inf|-?\d+(?:\.\d+)?)", err)[-1])


def dc_offset(path):
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "astats=metadata=0",
               "-f", "null", "-"]).stderr
    return float(re.findall(r"DC offset:\s+(-?\d+(?:\.\d+)?)", err)[-1])


def duration(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-count_packets",
               "-show_entries", "stream=duration_ts,sample_rate,duration", "-of",
               "default=nw=1", path]).stdout
    return float(re.search(r"duration=([\d.]+)", out).group(1))


def decoded_samples(path):
    raw = run_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-"])
    return struct.unpack("<%df" % (len(raw) // 4), raw)


def run_bytes(cmd):
    return subprocess.run(cmd, capture_output=True, check=True).stdout


def encode(wav, ogg, gain_db):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", wav, "-af", "volume=%.2fdB" % gain_db,
         "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])


def build(stem, tmp):
    make, kind, trim = FILES[stem]
    rng = random.Random("openjar-spaceballs:" + stem)
    x = make(rng)
    if kind == "sfx":
        x = fades(dc_block(soft(x, 9500.0)), 0.001, 0.005)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    secs = len(x) / SR
    tile = 10 if kind == "sfx" and secs < SHORT_CUE else 1
    target = (MUSIC_TARGET if kind == "music" else SFX_TARGET) + trim
    lufs, peak = measure(wav, tile)
    short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    if kind == "sfx" and short_by > 0.5:
        # Peak-bound, not loudness-bound: limit the transients (at most 8 dB) and re-measure.
        x = peak_normalise(limit(x, 0.5 * 10.0 ** (-min(short_by, 8.0) / 20.0)), 0.5)
        write_wav(wav, x)
        lufs, peak = measure(wav, tile)
    gain = min(target - lufs, TP_CEILING - 0.3 - peak)
    out_dir = os.path.join(AUDIO_DIR, "music" if kind == "music" else "sfx")
    ogg = os.path.join(out_dir, stem + ".ogg")
    for _ in range(4):   # Vorbis can push peaks up a little; back off until under the ceiling
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, tile)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    file_lufs = measure(ogg)[0] if tile > 1 else lufs
    return {"stem": stem, "ogg": ogg,
            "kind": kind, "seconds": duration(ogg), "lufs": file_lufs,
            "active_lufs": lufs if tile > 1 else None, "true_peak": peak, "target": target,
            "hf_db": rms_db(ogg, 10000) - rms_db(ogg), "dc": dc_offset(ogg),
            "samples_in": len(x)}


def loop_seam(ogg, samples_in):
    """Decoded length must equal the rendered length; the jump across the seam should look
    like an ordinary sample-to-sample step."""
    y = decoded_samples(ogg)
    steps = [abs(y[i + 1] - y[i]) for i in range(len(y) - 1)]
    typical = sorted(steps)[int(len(steps) * 0.99)]
    return {"decoded": len(y), "rendered": samples_in, "first": y[0], "last": y[-1],
            "seam_step": abs(y[0] - y[-1]), "p99_step": typical, "max_step": max(steps)}


def spectrogram(ogg, out_png):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", ogg, "-filter_complex",
         "[0:a]asplit[a][b];[a]showspectrumpic=s=640x240:legend=0:stop=16000[s];"
         "[b]showwavespic=s=640x120:colors=white[w];[s][w]vstack", "-frames:v", "1", out_png])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("only", nargs="*", help="file stems to build (default: all)")
    ap.add_argument("--keep-wav", help="write WAV sources here instead of a deleted temp dir")
    ap.add_argument("--spectrograms", help="also render <stem>.png spectrogram+waveform here")
    args = ap.parse_args()
    stems = args.only or list(FILES)
    unknown = [s for s in stems if s not in FILES]
    if unknown:
        sys.exit("unknown stem(s): %s (known: %s)" % (", ".join(unknown), ", ".join(FILES)))
    tmp = args.keep_wav or tempfile.mkdtemp(prefix="oj-cues-")
    os.makedirs(tmp, exist_ok=True)
    if args.spectrograms:
        os.makedirs(args.spectrograms, exist_ok=True)
    print("%-16s %-5s %7s %9s %9s %8s %8s %8s" % ("file", "kind", "sec", "LUFS", "active", "TP dB",
                                                 ">10k dB", "DC"))
    if not args.only:
        # A stale cue.ogg would shadow the cue_1.ogg.. variants in Audio.gd: keep sfx/ exact.
        sfx = os.path.join(AUDIO_DIR, "sfx")
        for f in sorted(os.listdir(sfx)):
            if f.endswith(".ogg") and f[:-4] not in FILES:
                print("removing stale sfx/%s" % f)
                os.remove(os.path.join(sfx, f))
    try:
        for stem in stems:
            r = build(stem, tmp)
            act = "%9.1f" % r["active_lufs"] if r["active_lufs"] is not None else "%9s" % "-"
            print("%-16s %-5s %7.3f %9.1f %s %8.1f %8.1f %8.5f" % (
                stem, r["kind"], r["seconds"], r["lufs"], act, r["true_peak"], r["hf_db"], r["dc"]))
            if r["kind"] == "music":
                s = loop_seam(r["ogg"], r["samples_in"])
                print("  loop: decoded %d / rendered %d samples, first %.4f last %.4f, seam step %.4f "
                      "(p99 step %.4f, max %.4f)" % (s["decoded"], s["rendered"], s["first"], s["last"],
                                                     s["seam_step"], s["p99_step"], s["max_step"]))
            if args.spectrograms:
                spectrogram(r["ogg"],
                            os.path.join(args.spectrograms, stem + ".png"))
    finally:
        if not args.keep_wav:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
