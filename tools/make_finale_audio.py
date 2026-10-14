#!/usr/bin/env python3
"""Synthesize 1-10's own sounds: the storm, falling stone, the giant, the
incoming call and the title sting.

Same oscillators and envelopes as tools/make_audio.py (imported from it), so
these sit in the same chiptune palette as the rest of the set. Only the files
listed here are written; the main set is left untouched.

Usage:  python3 tools/make_finale_audio.py
"""
from __future__ import annotations

import numpy as np

from make_audio import (env, lowpass, mix, noise, norm, save, secs, sine,
                        square, sweep, t_of, triangle)


def thunder() -> np.ndarray:
    n = secs(1.5)
    crack = lowpass(noise(secs(0.12), 11), 5200.0) * env(secs(0.12), 0.001, 0.04)
    roll = lowpass(noise(n, 12), 380.0) * env(n, 0.03, 0.55, 0.0, 0.3)
    sub = sine(sweep(70.0, 32.0, n), n) * env(n, 0.01, 0.5)
    return norm(mix(crack * 0.9, roll * 1.6, sub * 0.7), 0.95)


def crumble() -> np.ndarray:
    n = secs(0.9)
    out = np.zeros(n)
    rng = np.random.default_rng(5)
    for i in range(9):
        at = int(rng.uniform(0.0, 0.6) * 22050)
        k = secs(rng.uniform(0.05, 0.12))
        hit = lowpass(noise(k, 20 + i), rng.uniform(600.0, 1800.0)) * env(k, 0.001, 0.03)
        out[at:at + k] += hit[: max(0, min(k, n - at))] * rng.uniform(0.5, 1.0)
    thud = sine(sweep(110.0, 45.0, secs(0.35)), secs(0.35)) * env(secs(0.35), 0.002, 0.12)
    return norm(mix(out, thud * 0.9), 0.9)


def boom() -> np.ndarray:
    n = secs(1.3)
    body = sine(sweep(95.0, 30.0, n, 0.6), n) * env(n, 0.004, 0.45)
    grit = lowpass(noise(n, 31), 520.0) * env(n, 0.002, 0.25)
    return norm(mix(body * 1.2, grit * 0.8), 0.95)


def whoosh() -> np.ndarray:
    n = secs(0.55)
    t = t_of(n)
    swell = np.sin(np.pi * t / t[-1]) ** 2
    air = lowpass(noise(n, 41), 1500.0) - lowpass(noise(n, 41), 260.0)
    return norm(air * swell, 0.8)


def rumble() -> np.ndarray:
    n = secs(1.2)
    t = t_of(n)
    wobble = 0.7 + 0.3 * np.sin(2 * np.pi * 7.0 * t)
    low = lowpass(noise(n, 51), 160.0) * wobble * env(n, 0.08, 0.9, 0.3, 0.3)
    return norm(mix(low, sine(48.0, n) * 0.3 * env(n, 0.1, 0.8)), 0.9)


def ring() -> np.ndarray:
    """A generic two-burst phone ring: no recorded or branded tone."""
    burst_n = secs(0.36)
    t = t_of(burst_n)
    trem = 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 18.0 * t))
    burst = (sine(988.0, burst_n) * 0.6 + sine(1319.0, burst_n) * 0.4) * trem * env(burst_n, 0.004, 0.6, 0.6, 0.04)
    gap = np.zeros(secs(0.14))
    return norm(np.concatenate([burst, gap, burst]), 0.7)


def accept() -> np.ndarray:
    a = square(784.0, secs(0.07), 0.25) * env(secs(0.07), 0.002, 0.05)
    b = square(1175.0, secs(0.16), 0.25) * env(secs(0.16), 0.002, 0.08)
    return norm(np.concatenate([a, b]), 0.6)


def bubble() -> np.ndarray:
    n = secs(0.35)
    pop = sine(sweep(180.0, 950.0, n, 0.5), n) * env(n, 0.002, 0.12)
    return norm(mix(pop, lowpass(noise(secs(0.05), 61), 3000.0) * 0.4), 0.8)


def sizzle() -> np.ndarray:
    n = secs(0.8)
    hiss = (noise(n, 71) - lowpass(noise(n, 71), 2500.0)) * env(n, 0.02, 0.35, 0.2, 0.2)
    return norm(mix(hiss, lowpass(noise(n, 72), 200.0) * 0.6 * env(n, 0.01, 0.3)), 0.75)


def sting() -> np.ndarray:
    """The title hit: a bright major chord over a noise splash."""
    n = secs(1.4)
    chord = sum(square(f, n, 0.25) * w for f, w in [(523.25, 0.5), (659.25, 0.4), (783.99, 0.4), (1046.5, 0.25)])
    bass = triangle(130.81, n) * 0.8
    splash = lowpass(noise(n, 81), 4000.0) * env(n, 0.001, 0.18)
    return norm(mix(chord * env(n, 0.003, 0.5, 0.15, 0.4), bass * env(n, 0.003, 0.7), splash * 0.6), 0.85)


def horn() -> np.ndarray:
    n = secs(0.7)
    tone = square(311.13, n, 0.4) * 0.5 + square(392.0, n, 0.4) * 0.5
    return norm(lowpass(tone, 1400.0) * env(n, 0.03, 0.8, 0.7, 0.15), 0.6)


SOUNDS = {
    "thunder": thunder, "crumble": crumble, "boom": boom, "whoosh": whoosh,
    "rumble": rumble, "ring": ring, "accept": accept, "bubble": bubble,
    "sizzle": sizzle, "sting": sting, "horn": horn,
}


def main() -> int:
    total = 0
    for name, make in SOUNDS.items():
        total += save(name, make())
    print(f"  {len(SOUNDS)} files, {total // 1024}KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
