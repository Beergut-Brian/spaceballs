#!/usr/bin/env python3
"""Designed placeholder for the Dragon's rumble-purr (sb-curses-1, 2026-11-10).

The Dragon's library barks (`openjar-characters` v0.5.1, characters/dragon/voice/) are not rendered
yet, so this synthesises `assets/audio/sfx/dragon_purr.ogg`: a warm, low purr (two slow breaths of a
~24 Hz flutter over a 55 Hz hum) ending in a small happy rising "mm". Never a growl. Standard library
+ ffmpeg only, seeded. Replace it with the library's `dragon_purr` once the Character lane renders it.
    python3 assets/audio/tools/make_dragon_purr.py
"""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "sfx", "dragon_purr.ogg")


def purr(sec=1.9, seed=7):
    rng = random.Random(seed)
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    lp = 0.0
    for i in range(n):
        t = i / SR
        # Pitch: 55 Hz hum, the last 0.45 s glides up (the happy "mm").
        f = 55.0 + (max(0.0, t - (sec - 0.45)) / 0.45) ** 1.5 * 45.0
        ph += f / SR
        tone = sum(math.sin(2 * math.pi * ph * k) / k ** 1.3 for k in range(1, 7))
        # Two breaths of purr, then the "mm".
        breath = math.sin(math.pi * min(t / 0.75, 1.0)) if t < 0.75 else \
            (math.sin(math.pi * (t - 0.8) / 0.65) if 0.8 <= t < 1.45 else 0.0)
        mm = math.sin(math.pi * (t - (sec - 0.5)) / 0.5) if t >= sec - 0.5 else 0.0
        flutter = 0.55 + 0.45 * max(0.0, math.sin(2 * math.pi * 24.0 * t)) ** 2
        env = max(breath * flutter, mm * 0.85)
        x = tone * env + (rng.random() - 0.5) * 0.08 * breath
        lp += (x - lp) * 0.08   # soft low-pass: warm, no edge
        out[i] = lp
    peak = max(abs(v) for v in out) or 1.0
    fade = int(0.03 * SR)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return [v / peak * 0.6 for v in out]


def main():
    samples = purr()
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "purr.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", "loudnorm=I=-20:TP=-2",
                        "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", os.path.abspath(OUT)], check=True)
    print("wrote", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
