#!/usr/bin/env python3
# PLACEHOLDER (systems grey-box): synthesises a placeholder beep for every Audio cue into
# assets/audio/sfx/<cue>.ogg so the grey-box makes noise. The Audio lane replaces them.
# Python stdlib only (wave, math, random) + ffmpeg for .ogg. Run from the repo root:
#   python3 scripts/tools/make_beeps.py
import math, os, random, struct, subprocess, sys, tempfile, wave

RATE = 44100
OUT = "assets/audio/sfx"


def tone(f0, f1, dur, wave_kind="sine", vol=0.5, noise=0.0, vib=0.0):
    """Frequency sweep f0 -> f1 (Hz, exponential) with a click-free envelope."""
    n = int(RATE * dur)
    out, phase = [], 0.0
    rnd = random.Random(int(f0 * 1000 + f1))
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        if vib:
            f *= 1.0 + 0.03 * math.sin(2 * math.pi * vib * i / RATE)
        phase += 2 * math.pi * f / RATE
        if wave_kind == "square":
            s = 1.0 if math.sin(phase) >= 0 else -1.0
            s *= 0.6
        elif wave_kind == "tri":
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:
            s = math.sin(phase)
        s = s * (1 - noise) + (rnd.random() * 2 - 1) * noise
        env = min(1.0, i / (0.005 * RATE)) * (1 - t) ** 1.5
        out.append(s * env * vol)
    return out


def seq(*parts, gap=0.02):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out


def mix(a, b):
    n = max(len(a), len(b))
    a, b = a + [0.0] * (n - len(a)), b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


CUES = {
    # template cues
    "ui_move_1": tone(880, 880, 0.05, "tri"),
    "ui_move_2": tone(990, 990, 0.05, "tri"),
    "ui_confirm": seq(tone(660, 660, 0.06), tone(990, 990, 0.1)),
    "player_join": seq(tone(523, 523, 0.08), tone(659, 659, 0.08), tone(784, 784, 0.14)),
    "round_start": seq(tone(440, 440, 0.1, "square", 0.3), tone(880, 880, 0.16, "square", 0.3)),
    "round_end": seq(tone(784, 784, 0.1), tone(523, 523, 0.18)),
    "pause": tone(600, 300, 0.12, "tri"),
    # GAME.md Audio table
    "windup": tone(300, 1400, 0.55, "sine", 0.4, vib=9),
    "kick_1": tone(180, 90, 0.12, "sine", 0.7, noise=0.35),
    "kick_2": tone(140, 60, 0.2, "square", 0.5, noise=0.4),
    "kick_3": mix(tone(110, 40, 0.35, "square", 0.55, noise=0.5), tone(900, 200, 0.2, "sine", 0.3)),
    "kick_4": mix(tone(90, 30, 0.6, "square", 0.6, noise=0.6), tone(2000, 120, 0.5, "sine", 0.35)),
    "whoosh": tone(300, 900, 0.5, "sine", 0.35, noise=0.8),
    "tier_up": seq(tone(1046, 1046, 0.06, "tri"), tone(1318, 1318, 0.06, "tri"), tone(1568, 1568, 0.12, "tri"), gap=0.0),
    "land": tone(220, 110, 0.18, "sine", 0.6, noise=0.25),
    "card_move": tone(1200, 1300, 0.04, "tri", 0.4),
    "card_pick": seq(tone(700, 1400, 0.08), tone(1400, 1400, 0.1)),
    "upgrade_on": tone(400, 1600, 0.25, "tri", 0.45, vib=12),
    "curse": seq(tone(400, 380, 0.15, "square", 0.3), tone(300, 280, 0.15, "square", 0.3), tone(200, 150, 0.3, "square", 0.3)),
    "frog": seq(tone(160, 260, 0.08, "square", 0.4), tone(160, 300, 0.12, "square", 0.4), gap=0.05),
    "space": seq(tone(523, 523, 0.12), tone(784, 784, 0.12), tone(1046, 1046, 0.12), tone(1568, 1568, 0.5, vib=6)),
    "cheer": mix(tone(500, 900, 0.3, "tri", 0.35, vib=14), tone(300, 300, 0.3, "sine", 0.1, noise=0.9)),
    # grey-box extras (docs/contracts.md)
    "hop": tone(300, 600, 0.1, "sine", 0.45),
    "shout": tone(500, 700, 0.18, "square", 0.3, vib=20),
    "restart_arm": tone(500, 500, 0.08, "square", 0.3),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for cue, samples in CUES.items():
            wav = os.path.join(tmp, cue + ".wav")
            with wave.open(wav, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in samples))
            dst = os.path.join(OUT, cue + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3",
                            "-map_metadata", "-1", "-fflags", "+bitexact", dst], check=True)
            print(dst)


if __name__ == "__main__":
    sys.exit(main())
