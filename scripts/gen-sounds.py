#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Generates Altair's built-in UI sounds into assets/sounds/<style>/<event>.wav.
#
#   scripts/gen-sounds.py [output-dir]
#
# Every sound is synthesised here (no samples), so the files are our own work
# (CC0, see CREDITS.md). Pure standard library, no numpy.
#
# Design rules: very short, soft, no reverb tails, peaks well below 0 dBFS,
# 48 kHz mono 16-bit WAV (QtMultimedia's SoundEffect plays WAV without any
# decoder). Frequent sounds (typing, slider ticks) are much quieter than rare
# ones (notification), and come in variants so repeats don't sound mechanical.
import math
import os
import random
import struct
import sys
import wave

RATE = 48000
random.seed(7)  # reproducible noise


def silence(sec):
    return [0.0] * int(sec * RATE)


def mix(*parts):
    """Mix (offset_seconds, samples) pairs."""
    n = max(int(o * RATE) + len(s) for o, s in parts)
    out = [0.0] * n
    for o, s in parts:
        i0 = int(o * RATE)
        for i, v in enumerate(s):
            out[i0 + i] += v
    return out


def env(i, attack, decay):
    """Attack (s) then exponential decay with time constant `decay` (s)."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    a = math.sin(a * math.pi / 2)  # smooth start: no click
    return a * math.exp(-max(0.0, t - attack) / decay)


def tone(freq, dur, partials=((1, 1, 1),), attack=0.002, decay=0.05, glide=0.0):
    """Sum of partials (ratio, amplitude, decay factor). `glide` = pitch change
    in semitones over the duration (smooth, exponential)."""
    n = int(dur * RATE)
    out = []
    phases = [0.0] * len(partials)
    for i in range(n):
        t = i / n
        f = freq * 2 ** (glide * (1 - (1 - t) ** 2) / 12)
        v = 0.0
        for k, (ratio, amp, dk) in enumerate(partials):
            phases[k] += 2 * math.pi * f * ratio / RATE
            v += amp * math.sin(phases[k]) * env(i, attack, decay * dk)
        out.append(v)
    return fade_tail(out)


def noise_tick(dur, cutoff_hp, cutoff_lp, decay):
    """Band-limited noise burst: a soft physical 'tick'."""
    n = int(dur * RATE)
    a_hp = math.exp(-2 * math.pi * cutoff_hp / RATE)
    a_lp = math.exp(-2 * math.pi * cutoff_lp / RATE)
    lp = hp_prev_in = hp = 0.0
    out = []
    for i in range(n):
        x = random.uniform(-1, 1)
        hp = a_hp * (hp + x - hp_prev_in)  # one-pole high-pass
        hp_prev_in = x
        lp = (1 - a_lp) * hp + a_lp * lp   # one-pole low-pass
        out.append(lp * env(i, 0.0005, decay))
    return fade_tail(out)


def lowpass(s, cutoff):
    a = math.exp(-2 * math.pi * cutoff / RATE)
    y = 0.0
    out = []
    for x in s:
        y = (1 - a) * x + a * y
        out.append(y)
    return out


def fade_tail(s, sec=0.006):
    n = min(len(s), int(sec * RATE))
    for i in range(n):
        s[len(s) - n + i] *= 0.5 * (1 + math.cos(math.pi * i / n))
    return s


def normalize(s, peak_db):
    m = max(abs(v) for v in s) or 1.0
    g = 10 ** (peak_db / 20) / m
    return [v * g for v in s]


def note(name):
    """'A5' -> Hz (equal temperament, A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) - 4)
    return 440 * 2 ** (semis / 12)


def write(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(v * 32767)))) for v in s))


# ---- Styles ---------------------------------------------------------------
# Each style: event -> samples (a list), or a tuple of variants (frequent
# events; slider ticks: one per pitch step).

# Struck glass: inharmonic partials (free bar ratios), higher ones die faster.
GLASS = ((1, 1.0, 1.0), (2.756, 0.35, 0.45), (5.404, 0.12, 0.25))
# Soft: sine with a touch of octave, warm.
SOFT = ((1, 1.0, 1.0), (2, 0.12, 0.6))
# Minimal: pure sine.
PURE = ((1, 1.0, 1.0),)


def glass(f, dur=0.12, decay=0.04, glide=0.0):
    return tone(f, dur, GLASS, attack=0.0015, decay=decay, glide=glide)


def soft(f, dur=0.12, decay=0.045, glide=0.0):
    return lowpass(tone(f, dur, SOFT, attack=0.006, decay=decay, glide=glide), 3500)


def pure(f, dur=0.05, decay=0.015, glide=0.0):
    return tone(f, dur, PURE, attack=0.002, decay=decay, glide=glide)


# Wood: marimba bar (tuned bar ratios ~1 : 3.9 : 9.2), quick mallet attack.
MARIMBA = ((1, 1.0, 1.0), (3.93, 0.28, 0.35), (9.2, 0.07, 0.16))


def drop(f, dur=0.07, decay=0.022, glide=9.0):
    """Water drop: a pure tone whose pitch jumps up right after the start."""
    return lowpass(tone(f, dur, ((1, 1.0, 1.0), (2, 0.06, 0.5)), attack=0.0025, decay=decay, glide=glide), 6000)


def wood(f, dur=0.12, decay=0.035, glide=0.0):
    return lowpass(tone(f, dur, MARIMBA, attack=0.001, decay=decay, glide=glide), 5000)


def fm(f, dur=0.08, decay=0.025, ratio=2.0, index=2.0, glide=0.0):
    """Two-operator FM: bright at the start, the brightness (index) fades
    twice as fast as the volume, so it settles into a soft sine."""
    n = int(dur * RATE)
    out = []
    pc = pm = 0.0
    for i in range(n):
        t = i / n
        fi = f * 2 ** (glide * (1 - (1 - t) ** 2) / 12)
        pm += 2 * math.pi * fi * ratio / RATE
        pc += 2 * math.pi * fi / RATE
        out.append(math.sin(pc + index * env(i, 0.001, decay * 0.5) * math.sin(pm)) * env(i, 0.002, decay))
    return lowpass(fade_tail(out), 7000)


def steps(fn, lo, hi, n):
    """n variants rising from lo to hi Hz (slider ticks: pitch follows the value)."""
    return tuple(fn(lo * (hi / lo) ** (k / (n - 1))) for k in range(n))


SLIDE_STEPS = 8

styles = {
    "glass": {
        "notification": mix((0, glass(note("E6"), 0.42, 0.11)), (0.07, glass(note("B6"), 0.38, 0.10))),
        "open": mix((0, glass(note("C6"), 0.14, 0.035)), (0.035, glass(note("G6"), 0.16, 0.045))),
        "close": mix((0, glass(note("G6"), 0.12, 0.03)), (0.035, glass(note("C6"), 0.14, 0.035))),
        "click": glass(note("A6"), 0.06, 0.012),
        "toggle-on": mix((0, glass(note("E6"), 0.08, 0.02)), (0.04, glass(note("B6"), 0.1, 0.025))),
        "toggle-off": mix((0, glass(note("B6"), 0.08, 0.02)), (0.04, glass(note("E6"), 0.1, 0.025))),
        "typing": tuple(glass(f, 0.035, 0.007) for f in (2900, 3150, 3400)),
        "volume": glass(note("E6"), 0.09, 0.025),
        "edit-enter": mix(*[(i * 0.03, glass(note(n), 0.16, 0.04)) for i, n in enumerate(("C6", "E6", "G6", "C7"))]),
        "edit-exit": mix(*[(i * 0.03, glass(note(n), 0.16, 0.04)) for i, n in enumerate(("C7", "G6", "E6", "C6"))]),
        "snap": mix((0, glass(note("D7"), 0.04, 0.008)), (0.022, glass(note("A7"), 0.05, 0.01))),
        "slide": steps(lambda f: glass(f, 0.035, 0.007), 1600, 3600, SLIDE_STEPS),
    },
    "soft": {
        "notification": mix((0, soft(note("G5"), 0.4, 0.12)), (0.09, soft(note("D6"), 0.38, 0.11))),
        "open": soft(note("E5"), 0.14, 0.05, glide=4),
        "close": soft(note("G#5"), 0.14, 0.05, glide=-4),
        "click": soft(note("C6"), 0.05, 0.014),
        "toggle-on": soft(note("D5"), 0.11, 0.035, glide=5),
        "toggle-off": soft(note("G5"), 0.11, 0.035, glide=-5),
        "typing": tuple(soft(f, 0.03, 0.008) for f in (900, 980, 1060)),
        "volume": soft(note("A5"), 0.08, 0.025),
        "edit-enter": mix((0, soft(note("C5"), 0.2, 0.06, glide=7)), (0.05, soft(note("G5"), 0.2, 0.06))),
        "edit-exit": mix((0, soft(note("G5"), 0.2, 0.06, glide=-7)), (0.05, soft(note("C5"), 0.2, 0.06))),
        "snap": soft(note("E6"), 0.04, 0.01),
        "slide": steps(lambda f: soft(f, 0.03, 0.008), 520, 1250, SLIDE_STEPS),
    },
    "minimal": {
        "notification": mix((0, pure(note("A5"), 0.18, 0.05)), (0.08, pure(note("E6"), 0.18, 0.05))),
        "open": pure(note("C6"), 0.06, 0.018, glide=3),
        "close": pure(note("D#6"), 0.06, 0.018, glide=-3),
        "click": noise_tick(0.02, 1800, 7000, 0.003),
        "toggle-on": pure(note("A5"), 0.045, 0.012),
        "toggle-off": pure(note("E5"), 0.045, 0.012),
        "typing": tuple(noise_tick(0.015, 2000 + 300 * k, 8000, 0.0022) for k in range(3)),
        "volume": pure(note("A5"), 0.05, 0.015),
        "edit-enter": mix((0, pure(note("C6"), 0.06, 0.016)), (0.06, pure(note("G6"), 0.07, 0.018))),
        "edit-exit": mix((0, pure(note("G6"), 0.06, 0.016)), (0.06, pure(note("C6"), 0.07, 0.018))),
        "snap": noise_tick(0.02, 2500, 9000, 0.003),
        "slide": tuple(noise_tick(0.014, 1200 * (2.2 ** (k / 7)), 9000, 0.002) for k in range(SLIDE_STEPS)),
    },
    "bubble": {
        "notification": mix((0, drop(note("G5"), 0.16, 0.05, 10)), (0.1, drop(note("D6"), 0.18, 0.06, 10))),
        "open": drop(note("C6"), 0.09, 0.028, 9),
        "close": drop(note("G6"), 0.09, 0.028, -9),
        "click": drop(note("A6"), 0.035, 0.009, 6),
        "toggle-on": drop(note("E5"), 0.08, 0.024, 12),
        "toggle-off": drop(note("E6"), 0.08, 0.024, -12),
        "typing": tuple(drop(f, 0.025, 0.006, 5) for f in (1400, 1550, 1700)),
        "volume": drop(note("A5"), 0.06, 0.018, 6),
        "edit-enter": mix(*[(i * 0.06, drop(note(n), 0.08, 0.022, 9)) for i, n in enumerate(("C6", "E6", "G6"))]),
        "edit-exit": mix(*[(i * 0.06, drop(note(n), 0.08, 0.022, -9)) for i, n in enumerate(("G6", "E6", "C6"))]),
        "snap": drop(note("E7"), 0.03, 0.008, 4),
        "slide": steps(lambda f: drop(f, 0.025, 0.006, 4), 700, 1800, SLIDE_STEPS),
    },
    "wood": {
        "notification": mix((0, wood(note("G5"), 0.32, 0.09)), (0.09, wood(note("D6"), 0.32, 0.09))),
        "open": mix((0, wood(note("E5"), 0.1, 0.03)), (0.045, wood(note("B5"), 0.14, 0.04))),
        "close": mix((0, wood(note("B5"), 0.1, 0.03)), (0.045, wood(note("E5"), 0.14, 0.04))),
        "click": wood(note("C6"), 0.05, 0.012),
        "toggle-on": mix((0, wood(note("D5"), 0.08, 0.025)), (0.04, wood(note("A5"), 0.1, 0.03))),
        "toggle-off": mix((0, wood(note("A5"), 0.08, 0.025)), (0.04, wood(note("D5"), 0.1, 0.03))),
        "typing": tuple(wood(f, 0.03, 0.007) for f in (1100, 1200, 1300)),
        "volume": wood(note("A5"), 0.08, 0.025),
        "edit-enter": mix(*[(i * 0.04, wood(note(n), 0.16, 0.045)) for i, n in enumerate(("C5", "E5", "G5", "C6"))]),
        "edit-exit": mix(*[(i * 0.04, wood(note(n), 0.16, 0.045)) for i, n in enumerate(("C6", "G5", "E5", "C5"))]),
        "snap": wood(note("G6"), 0.04, 0.009),
        "slide": steps(lambda f: wood(f, 0.03, 0.007), 500, 1200, SLIDE_STEPS),
    },
    "pulse": {
        "notification": mix((0, fm(note("E6"), 0.22, 0.07, 3.5, 1.8)), (0.09, fm(note("B6"), 0.24, 0.08, 3.5, 1.8))),
        "open": fm(note("C6"), 0.1, 0.03, 2, 2.2, glide=5),
        "close": fm(note("G6"), 0.1, 0.03, 2, 2.2, glide=-5),
        "click": fm(note("B6"), 0.035, 0.009, 2, 1.4),
        "toggle-on": mix((0, fm(note("A5"), 0.05, 0.014, 2, 1.6)), (0.05, fm(note("E6"), 0.06, 0.016, 2, 1.6))),
        "toggle-off": mix((0, fm(note("E6"), 0.05, 0.014, 2, 1.6)), (0.05, fm(note("A5"), 0.06, 0.016, 2, 1.6))),
        "typing": tuple(fm(f, 0.022, 0.005, 2, 1.0) for f in (2400, 2600, 2800)),
        "volume": fm(note("A5"), 0.06, 0.018, 2, 1.6),
        "edit-enter": fm(note("C5"), 0.2, 0.06, 2, 2.5, glide=12),
        "edit-exit": fm(note("C6"), 0.2, 0.06, 2, 2.5, glide=-12),
        "snap": fm(note("F#7"), 0.03, 0.007, 2, 1.2),
        "slide": steps(lambda f: fm(f, 0.022, 0.005, 2, 1.0), 900, 2600, SLIDE_STEPS),
    },
}

# Loudness per event (peak dBFS). Frequent sounds are quieter.
LEVEL = {
    "notification": -8, "open": -13, "close": -14, "click": -15,
    "toggle-on": -13, "toggle-off": -14, "typing": -21, "volume": -13,
    "edit-enter": -11, "edit-exit": -12, "snap": -15, "slide": -20,
}

out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
count = 0
for style, events in styles.items():
    for event, s in events.items():
        variants = s if isinstance(s, tuple) else (s,)
        for k, v in enumerate(variants):
            name = event if len(variants) == 1 else f"{event}-{k}"
            write(os.path.join(out_dir, style, name + ".wav"), normalize(v, LEVEL[event]))
            count += 1
print(f"wrote {count} files to {os.path.normpath(out_dir)}")
