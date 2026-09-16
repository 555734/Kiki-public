#!/usr/bin/env python3
"""Synthesize the game's entire sound set.

No audio was supplied and none can be fetched, so every sound here is generated
from oscillators: square and pulse leads, a triangle bass, filtered noise for
percussion and impacts. That is a real constraint and it shows -- this is
chiptune, not recorded foley -- but the gap between "chiptune" and "silence" is
far larger than the gap between "chiptune" and "recorded".

Two things the game needs that a sound library would not have given for free:

* One palette. Every sound is built from the same three oscillators and the same
  short envelopes, so they belong together rather than merely coexisting.
* Pitch as meaning. The rescue sting is one sound at three pitches, the ability
  placements are one sound per tool a fourth apart. On a co-op game played over
  voice chat, the pitch IS the message -- the guardian hears how good their own
  catch was without looking away from the runner.

Output is 22.05kHz mono 16-bit WAV. Godot imports WAV natively with no extra
importer, and at this rate the whole set plus two music loops is about 1.5MB.

Usage:  python3 tools/make_audio.py
"""
from __future__ import annotations

import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

# ---------------------------------------------------------------- oscillators


def t_of(n: int) -> np.ndarray:
    return np.arange(n) / SR


def _phase(freq, n: int) -> np.ndarray:
    """Running phase, so a swept frequency stays continuous."""
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    return 2.0 * np.pi * np.cumsum(f) / SR


def square(freq, n: int, duty: float = 0.5) -> np.ndarray:
    ph = (_phase(freq, n) / (2.0 * np.pi)) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def triangle(freq, n: int) -> np.ndarray:
    ph = (_phase(freq, n) / (2.0 * np.pi)) % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def sine(freq, n: int) -> np.ndarray:
    return np.sin(_phase(freq, n))


def noise(n: int, seed: int = 0) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """One-pole. Crude, cheap, and exactly right for taking the fizz off noise."""
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        out[i] = acc
    return out


def env(n: int, attack: float = 0.004, decay: float = 0.12,
        sustain: float = 0.0, release: float = 0.05) -> np.ndarray:
    """Attack, exponential decay to a sustain floor, then a release tail."""
    t = t_of(n)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    d = sustain + (1.0 - sustain) * np.exp(-t / max(decay, 1e-5))
    r = np.clip((t[-1] - t) / max(release, 1e-5), 0.0, 1.0) if release > 0 else 1.0
    return a * d * r


def sweep(start: float, end: float, n: int, curve: float = 1.0) -> np.ndarray:
    """Exponential glide, which is how pitch actually reads to the ear."""
    x = np.linspace(0.0, 1.0, n) ** curve
    return start * (end / start) ** x


# ------------------------------------------------------------------ utilities


def norm(x: np.ndarray, peak: float = 0.85) -> np.ndarray:
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x * (peak / m) if m > 1e-6 else x


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name: str, x: np.ndarray) -> int:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    x = np.clip(x, -1.0, 1.0)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())
    return os.path.getsize(path)


def secs(s: float) -> int:
    return int(SR * s)


# --------------------------------------------------------------------- sounds


def sfx() -> dict[str, np.ndarray]:
    s: dict[str, np.ndarray] = {}

    # --- the runner ---------------------------------------------------------
    n = secs(0.20)
    s["jump"] = norm(square(sweep(300, 720, n), n, 0.35) * env(n, 0.002, 0.07), 0.55)

    n = secs(0.16)
    s["land"] = norm(mix(
        lowpass(noise(n, 1), 900.0) * env(n, 0.001, 0.05) * 0.9,
        triangle(sweep(180, 90, n), n) * env(n, 0.001, 0.045) * 0.7), 0.5)

    n = secs(0.26)
    s["dash"] = norm(mix(
        lowpass(noise(n, 2), 2600.0) * env(n, 0.004, 0.10) * 0.8,
        square(sweep(520, 220, n), n, 0.2) * env(n, 0.003, 0.09) * 0.5), 0.5)

    n = secs(0.38)
    s["hurt"] = norm(mix(
        square(sweep(420, 150, n), n, 0.5) * env(n, 0.001, 0.14),
        lowpass(noise(n, 3), 1400.0) * env(n, 0.001, 0.08) * 0.8), 0.75)

    # A falling minor third, which is the sound every game has used for losing
    # since 1985 because it is the one everybody reads instantly.
    n = secs(0.9)
    die = np.zeros(n)
    for i, (f, start, dur) in enumerate([(392, 0.0, 0.16), (330, 0.14, 0.16),
                                         (262, 0.28, 0.18), (196, 0.46, 0.42)]):
        m = secs(dur)
        die[secs(start):secs(start) + m] += square(f, m, 0.5) * env(m, 0.004, dur * 0.6)
    s["die"] = norm(die, 0.7)

    n = secs(0.34)
    s["respawn"] = norm(mix(
        square(sweep(220, 660, n), n, 0.25) * env(n, 0.01, 0.13),
        sine(sweep(440, 1320, n), n) * env(n, 0.01, 0.10) * 0.5), 0.6)

    # --- pickups ------------------------------------------------------------
    # Two clean tones a fifth apart: the arcade coin, and unmistakable.
    n = secs(0.30)
    coin = np.zeros(n)
    first, second = secs(0.055), n - secs(0.055)
    coin[:first] = sine(988, first) * env(first, 0.001, 0.05, 0.8, 0.0)
    coin[first:] = sine(1480, second) * env(second, 0.001, 0.16)
    s["coin"] = norm(mix(coin, coin * 0.35 * sine(1480 * 2, n)), 0.5)

    n = secs(0.34)
    s["spring"] = norm(mix(
        triangle(sweep(160, 900, n), n, ) * env(n, 0.002, 0.13),
        square(sweep(320, 1800, n), n, 0.3) * env(n, 0.002, 0.09) * 0.4), 0.65)

    # --- the guardian's tools ----------------------------------------------
    # One shape, three pitches, a fourth apart. The runner learns which tool
    # arrived behind them without turning to look.
    for name, base in (("place_platform", 440.0), ("place_wall", 330.0),
                       ("place_warp", 587.0)):
        n = secs(0.40)
        body = mix(
            sine(base, n) * env(n, 0.006, 0.16) * 0.8,
            sine(base * 1.5, n) * env(n, 0.010, 0.13) * 0.5,
            sine(base * 3.0, n) * env(n, 0.004, 0.06) * 0.25,
            lowpass(noise(n, 7), 3000.0) * env(n, 0.001, 0.03) * 0.30)
        s[name] = norm(body, 0.55)

    n = secs(0.22)
    s["refuse"] = norm(square(sweep(200, 130, n), n, 0.5) * env(n, 0.002, 0.07), 0.45)

    n = secs(0.30)
    s["shot"] = norm(mix(
        lowpass(noise(n, 4), 5000.0) * env(n, 0.0008, 0.05),
        square(sweep(1600, 300, n), n, 0.15) * env(n, 0.0008, 0.055) * 0.7,
        triangle(sweep(220, 70, n), n) * env(n, 0.001, 0.10) * 0.6), 0.7)

    n = secs(0.26)
    s["hit"] = norm(mix(
        lowpass(noise(n, 5), 3200.0) * env(n, 0.0008, 0.07),
        sine(sweep(900, 300, n), n) * env(n, 0.001, 0.06) * 0.8), 0.65)

    n = secs(0.42)
    s["enemy_die"] = norm(mix(
        square(sweep(300, 80, n), n, 0.4) * env(n, 0.002, 0.14),
        lowpass(noise(n, 6), 1800.0) * env(n, 0.001, 0.10) * 0.7), 0.6)

    n = secs(0.30)
    s["scope_up"] = norm(sine(sweep(500, 1100, n), n) * env(n, 0.02, 0.11) * 0.8, 0.35)
    s["scope_down"] = norm(sine(sweep(1100, 500, n), n) * env(n, 0.02, 0.11) * 0.8, 0.35)

    n = secs(0.5)
    s["warp"] = norm(mix(
        sine(sweep(200, 1400, n), n) * env(n, 0.01, 0.18),
        square(sweep(400, 2800, n), n, 0.25) * env(n, 0.01, 0.14) * 0.4,
        lowpass(noise(n, 8), 4000.0) * env(n, 0.02, 0.12) * 0.3), 0.6)

    # --- the rescue sting ---------------------------------------------------
    # One arpeggio at three transpositions. The pitch is the grade: the guardian
    # hears how late they left it, which is the whole point of scoring it.
    for name, mul in (("rescue_1", 1.0), ("rescue_2", 1.26), ("rescue_3", 1.5)):
        n = secs(0.62)
        r = np.zeros(n)
        for i, step in enumerate([1.0, 1.25, 1.5, 2.0]):
            m = secs(0.16)
            at = secs(0.055 * i)
            r[at:at + m] += (sine(523 * mul * step, m) * env(m, 0.003, 0.10) * 0.7
                             + square(523 * mul * step * 2, m, 0.3)
                             * env(m, 0.003, 0.05) * 0.18)
        s[name] = norm(r, 0.55)

    # --- structure ----------------------------------------------------------
    n = secs(0.36)
    s["switch"] = norm(mix(
        square(sweep(660, 990, n), n, 0.3) * env(n, 0.004, 0.12),
        sine(1320, n) * env(n, 0.01, 0.08) * 0.4), 0.5)

    n = secs(0.7)
    s["gate"] = norm(mix(
        lowpass(noise(n, 9), 700.0) * env(n, 0.05, 0.28) * 0.9,
        triangle(sweep(90, 150, n), n) * env(n, 0.05, 0.26) * 0.7), 0.55)

    n = secs(0.55)
    cp = np.zeros(n)
    for i, f in enumerate([523, 659, 784]):
        m = secs(0.20)
        at = secs(0.085 * i)
        cp[at:at + m] += sine(f, m) * env(m, 0.005, 0.13) * 0.8
    s["checkpoint"] = norm(cp, 0.55)

    n = secs(0.24)
    s["countdown"] = norm(sine(880, n) * env(n, 0.003, 0.08), 0.5)

    # Stage clear: the same I-V-vi-IV the music uses, resolved.
    n = secs(2.0)
    clear = np.zeros(n)
    for i, (f, start, dur) in enumerate([(523, 0.0, 0.18), (659, 0.15, 0.18),
                                         (784, 0.30, 0.18), (1047, 0.45, 0.55),
                                         (784, 0.95, 0.20), (1047, 1.10, 0.85)]):
        m = secs(dur)
        at = secs(start)
        clear[at:at + m] += (square(f, m, 0.4) * env(m, 0.006, dur * 0.5) * 0.6
                             + sine(f * 2, m) * env(m, 0.006, dur * 0.4) * 0.25)
    s["stage_clear"] = norm(clear, 0.7)

    n = secs(1.6)
    over = np.zeros(n)
    for i, (f, start, dur) in enumerate([(392, 0.0, 0.30), (370, 0.26, 0.30),
                                         (349, 0.52, 0.34), (262, 0.84, 0.76)]):
        m = secs(dur)
        at = secs(start)
        over[at:at + m] += (triangle(f, m) * env(m, 0.01, dur * 0.55) * 0.8
                            + square(f / 2, m, 0.5) * env(m, 0.01, dur * 0.5) * 0.3)
    s["game_over"] = norm(over, 0.7)

    return s


# ---------------------------------------------------------------------- music

BPM = 132.0
BEAT = 60.0 / BPM
BARS = 8
LOOP_N = secs(BEAT * 4 * BARS)

# I - V - vi - IV, two bars each, in C. The stage is bright green fields under a
# blue sky; this is the progression that sounds like that.
CHORDS = [
    (261.63, [261.63, 329.63, 392.00]),   # C
    (196.00, [246.94, 293.66, 392.00]),   # G/B
    (220.00, [261.63, 329.63, 440.00]),   # Am
    (174.61, [261.63, 349.23, 440.00]),   # F
]


def _place(buf: np.ndarray, at: int, x: np.ndarray) -> None:
    """Write into the loop, wrapping the tail back to the start.

    Wrapping rather than truncating is what makes the loop seamless: a note that
    rings past the last sample continues over the first, which is exactly what
    it would do if the loop were played twice in a row.
    """
    n = len(buf)
    at %= n
    end = at + len(x)
    if end <= n:
        buf[at:end] += x
    else:
        buf[at:] += x[: n - at]
        buf[: end - n] += x[n - at:]


def music_base() -> np.ndarray:
    bass = np.zeros(LOOP_N)
    pad = np.zeros(LOOP_N)
    lead = np.zeros(LOOP_N)

    for bar in range(BARS):
        root, chord = CHORDS[(bar // 2) % 4]
        bar_at = secs(BEAT * 4 * bar)
        # Bass on every beat, eighth-note push on the last.
        for beat in range(4):
            dur = BEAT * (0.45 if beat < 3 else 0.22)
            m = secs(dur)
            f = root if beat != 3 else root * 1.5
            _place(bass, bar_at + secs(BEAT * beat),
                   triangle(f, m) * env(m, 0.006, dur * 0.55) * 0.55)
        # Pad: the chord, soft, held.
        m = secs(BEAT * 3.8)
        for f in chord:
            _place(pad, bar_at, square(f, m, 0.5) * env(m, 0.09, BEAT * 2.4) * 0.085)
        # Lead: an arpeggio in sixteenths over the second half of each bar.
        for step in range(8):
            dur = BEAT * 0.22
            m = secs(dur)
            f = chord[step % 3] * (2.0 if step >= 4 else 1.0)
            _place(lead, bar_at + secs(BEAT * (2.0 + step * 0.25)),
                   square(f, m, 0.25) * env(m, 0.004, dur * 0.5) * 0.14)

    return mix(bass, pad, lead)


def music_drive() -> np.ndarray:
    """The layer that fades in when the runner is in trouble.

    Same tempo, same length, same chords -- it is mixed on top of the base loop
    rather than crossfaded with it, so the music gets more urgent without ever
    restarting or changing key. Drums and an octave lead.
    """
    drums = np.zeros(LOOP_N)
    lead = np.zeros(LOOP_N)

    for bar in range(BARS):
        _, chord = CHORDS[(bar // 2) % 4]
        bar_at = secs(BEAT * 4 * bar)
        for beat in range(4):
            at = bar_at + secs(BEAT * beat)
            # Kick on 1 and 3, snare on 2 and 4, hats on the eighths.
            if beat % 2 == 0:
                m = secs(0.14)
                _place(drums, at, triangle(sweep(140, 45, m), m)
                       * env(m, 0.001, 0.055) * 0.7)
            else:
                m = secs(0.16)
                _place(drums, at, lowpass(noise(m, 20 + beat), 4200.0)
                       * env(m, 0.001, 0.055) * 0.42)
            for half in (0.0, 0.5):
                m = secs(0.05)
                _place(drums, at + secs(BEAT * half),
                       lowpass(noise(m, 40 + beat), 9000.0)
                       * env(m, 0.0005, 0.018) * 0.16)
        for step in range(8):
            dur = BEAT * 0.24
            m = secs(dur)
            f = chord[(step * 2) % 3] * 2.0
            _place(lead, bar_at + secs(BEAT * step * 0.5),
                   square(f, m, 0.12) * env(m, 0.003, dur * 0.45) * 0.11)

    return mix(drums, lead)


def main() -> int:
    total = 0
    made = 0
    for name, wave_data in sfx().items():
        total += save(name, wave_data)
        made += 1
    base = music_base()
    drive = music_drive()
    # Normalised together, so the drive layer sits under the base at the same
    # relative level it was written at rather than being pushed to the same peak.
    peak = max(float(np.max(np.abs(base))), 1e-6)
    total += save("music_stage", np.clip(base / peak * 0.62, -1, 1))
    total += save("music_drive", np.clip(drive / peak * 0.62, -1, 1))
    made += 2
    print(f"  {made} files, {total // 1024}KB, loop {LOOP_N / SR:.2f}s at {BPM:.0f} BPM")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
