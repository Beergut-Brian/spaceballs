#!/usr/bin/env python3
"""Music layers for field_loop.ogg (GAME.md Audio: "one upbeat loop that gains a layer per height tier").

Synthesises three stems that play in sync on top of assets/audio/music/field_loop.ogg
(Audio.music_level fades them in: layer 1 at tiers 3-4, 2 at 5-6, 3 at 7-8):

  field_loop_layer_1.ogg  shaker 16ths + tambourine on 2 and 4          (a little more energy)
  field_loop_layer_2.ogg  four-on-the-floor kick + claps on 2 and 4     (it starts to drive)
  field_loop_layer_3.ogg  bell arpeggio on the loop's chords + a "whee" slide every 4 bars + a crash

The grid and the chords were measured from field_loop.ogg itself (stdlib onset comb + Goertzel
chroma, 2026-11-10): 120 BPM, first beat at 0.032 s, C major, a 16 s progression of half-bar chords
C C F F C C C G C Am F Dm C C C G. Each stem has exactly the base loop's sample count, so the
AudioStreamSynchronized layers wrap with it; the last 60 ms fade out so nothing clicks at the seam.

Python stdlib + ffmpeg, seeded, reproducible:  python3 assets/audio/tools/make_music_layers.py
"""
import array
import math
import os
import random
import subprocess
import sys
import tempfile
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
MUSIC = os.path.normpath(os.path.join(HERE, "..", "music"))
BASE = os.path.join(MUSIC, "field_loop.ogg")
SR = 44100
BPM = 120.0
BEAT = 60.0 / BPM
T0 = 0.032
# Half-bar chords (1 s each), 16 s cycle, as pitch classes (C = 0).
CHORDS = ["C", "C", "F", "F", "C", "C", "C", "G", "C", "Am", "F", "Dm", "C", "C", "C", "G"]
TRIADS = {"C": [0, 4, 7], "F": [5, 9, 0], "G": [7, 11, 2], "Am": [9, 0, 4], "Dm": [2, 5, 9]}
# Stem peak levels (linear, after each stem is peak-normalised).
PEAK = {1: 0.30, 2: 0.26, 3: 0.22}
SEAM_FADE = 0.06


def base_length() -> int:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", BASE, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return len(raw) // 2


class Stem:
    def __init__(self, n: int):
        self.n = n
        self.l = array.array("f", bytes(4 * n))
        self.r = array.array("f", bytes(4 * n))

    def add(self, t: float, buf, pan: float = 0.0, gain: float = 1.0) -> None:
        """Mix a mono buffer in at t seconds (pan -1..1). Anything past the loop end is dropped."""
        start = int(round(t * SR))
        gl = gain * math.cos((pan + 1.0) * math.pi / 4.0) * math.sqrt(2.0)
        gr = gain * math.sin((pan + 1.0) * math.pi / 4.0) * math.sqrt(2.0)
        for i, v in enumerate(buf):
            j = start + i
            if j >= self.n:
                break
            if j >= 0:
                self.l[j] += v * gl
                self.r[j] += v * gr

    def finish(self, peak: float) -> None:
        m = max(max(abs(v) for v in self.l), max(abs(v) for v in self.r), 1e-9)
        k = peak / m
        fade = int(SEAM_FADE * SR)
        for i in range(self.n):
            g = k
            if i >= self.n - fade:
                g *= (self.n - i) / fade
            elif i < 64:
                g *= i / 64.0
            self.l[i] *= g
            self.r[i] *= g

    def write(self, path: str) -> None:
        with tempfile.TemporaryDirectory() as d:
            wav = os.path.join(d, "stem.wav")
            frames = array.array("h", bytes(4 * self.n))
            for i in range(self.n):
                frames[2 * i] = int(max(-1.0, min(1.0, self.l[i])) * 32767)
                frames[2 * i + 1] = int(max(-1.0, min(1.0, self.r[i])) * 32767)
            with wave.open(wav, "wb") as w:
                w.setnchannels(2)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes(frames.tobytes())
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", path], check=True)


# --- instruments ---------------------------------------------------------------------

def noise_hit(rng, dur: float, decay: float, bright: float = 0.85):
    """Noise burst, high-passed by a one-pole difference (bright 0..1), exponential decay."""
    out = []
    prev = 0.0
    for i in range(int(dur * SR)):
        v = rng.uniform(-1.0, 1.0)
        hp = v - bright * prev
        prev = v
        out.append(hp * math.exp(-i / (decay * SR)))
    return out


def kick(dur: float = 0.22):
    out = []
    phase = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        f = 45.0 + 110.0 * math.exp(-t * 28.0)
        phase += 2 * math.pi * f / SR
        env = math.exp(-t * 14.0) * min(1.0, i / 40.0)
        out.append(math.sin(phase) * env)
    return out


def clap(rng):
    out = [0.0] * int(0.2 * SR)
    for k, off in enumerate((0.0, 0.011, 0.022)):
        burst = noise_hit(rng, 0.2 - off, 0.012 if k < 2 else 0.06, 0.6)
        s = int(off * SR)
        for i, v in enumerate(burst):
            if s + i < len(out):
                out[s + i] += v * (0.7 if k < 2 else 1.0)
    # A soft band: average neighbours to take the fizz off.
    return [(out[i] + out[i - 1] + out[i - 2]) / 3.0 if i > 1 else out[i] for i in range(len(out))]


def tambourine(rng):
    jingle = noise_hit(rng, 0.16, 0.05, 0.98)
    return [v + 0.25 * math.sin(2 * math.pi * 7400 * i / SR) * math.exp(-i / (0.03 * SR)) for i, v in enumerate(jingle)]


def bell(freq: float, dur: float = 0.42):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        v = (math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 9)
             + 0.12 * math.sin(2 * math.pi * freq * 3.0 * t) * math.exp(-t * 14))
        out.append(v * math.exp(-t * 7.0) * min(1.0, i / 60.0))
    return out


def whee(dur: float = BEAT * 2):
    """A rising slide-whistle 'wheee' across two beats, C5 up to C7 on the loop's key."""
    out = []
    phase = 0.0
    n = int(dur * SR)
    for i in range(n):
        x = i / n
        f = 523.25 * 2 ** (2.0 * x * x)
        phase += 2 * math.pi * f / SR
        vib = 1.0 + 0.02 * math.sin(2 * math.pi * 6.0 * i / SR)
        env = math.sin(math.pi * min(1.0, x * 1.15)) ** 0.7 if x < 0.87 else max(0.0, (1.0 - x) / 0.13) * 0.9
        out.append(math.sin(phase * vib) * env * 0.6)
    return out


def crash(rng):
    return noise_hit(rng, 1.6, 0.45, 0.9)


def midi_freq(pc: int, octave: int) -> float:
    return 440.0 * 2 ** ((pc - 9) / 12.0 + (octave - 4))


# --- the stems --------------------------------------------------------------------------

def beats(n: int):
    k = 0
    while True:
        t = T0 + k * BEAT
        if t * SR >= n:
            return
        yield k, t
        k += 1


def layer_1(n: int) -> Stem:
    rng = random.Random(101)
    s = Stem(n)
    for k, t in beats(n):
        for q in range(4):   # 16ths, accent the offbeat 8th
            acc = 1.0 if q == 2 else (0.55 if q == 0 else 0.4)
            s.add(t + q * BEAT / 4, noise_hit(rng, 0.07, 0.018, 0.95), pan=0.35, gain=acc)
        if k % 2 == 1:
            s.add(t, tambourine(rng), pan=-0.3, gain=0.8)
    s.finish(PEAK[1])
    return s


def layer_2(n: int) -> Stem:
    rng = random.Random(202)
    s = Stem(n)
    for k, t in beats(n):
        s.add(t, kick(), gain=1.0)
        if k % 2 == 1:
            s.add(t, clap(rng), pan=0.0, gain=0.55)
    s.finish(PEAK[2])
    return s


def layer_3(n: int) -> Stem:
    rng = random.Random(303)
    s = Stem(n)
    s.add(T0, crash(rng), pan=0.2, gain=0.35)
    # Up-and-down 8ths through the half-bar's triad, two octaves.
    shape = [(0, 5), (1, 5), (2, 5), (0, 6)]
    for k, t in beats(n):
        for e in range(2):
            te = t + e * BEAT / 2
            slot = int((te - T0) / 1.0 + 1e-6) % 16
            triad = TRIADS[CHORDS[slot]]
            idx, octv = shape[(k * 2 + e) % 4]
            s.add(te, bell(midi_freq(triad[idx], octv)), pan=-0.4 if e == 0 else 0.4, gain=0.8 if e == 0 else 0.6)
        if k % 16 == 14:   # the last two beats of every 4 bars: wheee
            s.add(t, whee(), pan=0.0, gain=0.9)
    s.finish(PEAK[3])
    return s


def main() -> int:
    n = base_length()
    print("field_loop: %d samples (%.3f s)" % (n, n / SR))
    for i, make in ((1, layer_1), (2, layer_2), (3, layer_3)):
        path = os.path.join(MUSIC, "field_loop_layer_%d.ogg" % i)
        make(n).write(path)
        print("wrote", os.path.relpath(path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
