#!/usr/bin/env python3
"""The trailer's score, composed to the cut.

    python3 tools/trailer_music.py <capture dir> <out.wav>

Same palette as the game's own music (tools/make_audio.py): pulse and
triangle waves and noise drums. It is laid out from the cues the capture
wrote to shots.json, so the music always fits the picture it is under:

    music_in  .. drive_in    BUILD   arpeggio and bass, drums coming in bar by
                                     bar, a snare roll and a riser into a
                                     one-beat gap
    drive_in  .. drive_out   DROP    full kit, driving bass, the lead tune
    drive_out ..             STING   one big chord and a crash, ringing out

The shots after music_in are timed in beats of TEMPO (capture_trailer.gd),
so section changes fall on bar lines.
"""
import json
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
TEMPO = 110.0
BEAT = 60.0 / TEMPO

# A minor: Am - F - C - G, one chord a bar.
CHORDS = [
    (57, [57, 60, 64]),   # Am
    (53, [53, 57, 60]),   # F
    (48, [55, 60, 64]),   # C
    (55, [55, 59, 62]),   # G
]
# The lead over eight bars, in eighths: MIDI note, 0 rest, -1 hold.
TUNE = [
    [76, -1, 76, 74, 72, -1, 69, -1],
    [72, -1, 72, 74, 76, -1, 72, -1],
    [79, -1, 79, 77, 76, -1, 72, -1],
    [74, -1, -1, -1, 71, -1, 74, -1],
    [76, -1, 76, 74, 72, -1, 69, -1],
    [72, -1, 74, 76, 77, -1, 76, -1],
    [79, -1, 81, -1, 79, 77, 76, 74],
    [76, -1, -1, -1, -1, -1, 0, 0],
]


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def env(n: int, attack: float, release: float, sustain: float = 1.0) -> np.ndarray:
    t = np.arange(n) / RATE
    e = np.minimum(1.0, t / max(attack, 1e-4))
    tail = np.clip((n / RATE - t) / max(release, 1e-4), 0.0, 1.0)
    return (e * tail * sustain).astype(np.float32)


def pulse(freq: float, n: int, duty: float = 0.5, vibrato: float = 0.0) -> np.ndarray:
    t = np.arange(n) / RATE
    phase = freq * t
    if vibrato > 0.0:
        # Vibrato that arrives after the note has spoken.
        depth = vibrato * np.clip((t - 0.12) / 0.2, 0.0, 1.0)
        phase = np.cumsum(freq * (1.0 + depth * np.sin(2 * np.pi * 5.5 * t))) / RATE
    return np.where((phase % 1.0) < duty, 1.0, -1.0).astype(np.float32)


def triangle(freq: float, n: int) -> np.ndarray:
    t = np.arange(n) / RATE
    x = 4.0 * np.abs((freq * t) % 1.0 - 0.5) - 1.0
    # Stepped, as the 2A03's was: sixteen levels.
    return (np.round(x * 7.5) / 7.5).astype(np.float32)


def noise(n: int, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1, 1, n).astype(np.float32)


def onepole(x: np.ndarray, cutoff: float, high: bool = False) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return x - y if high else y


class Track:
    def __init__(self, seconds: float) -> None:
        self.n = int(seconds * RATE) + RATE * 4
        self.buf = np.zeros(self.n, dtype=np.float32)
        self._noise_cache: dict = {}

    def put(self, at: float, x: np.ndarray, gain: float) -> None:
        a = int(at * RATE)
        if a >= self.n or a + len(x) <= 0:
            return
        if a < 0:
            x = x[-a:]
            a = 0
        x = x[: self.n - a]
        self.buf[a:a + len(x)] += x * gain

    # ------------------------------------------------------------ voices
    def lead(self, at: float, note: int, beats: float, gain: float) -> None:
        n = int(beats * BEAT * RATE)
        self.put(at, pulse(hz(note), n, 0.5, 0.012) * env(n, 0.005, 0.06, 1.0), gain)
        # A quieter echo an eighth late: the cheap chiptune "reverb".
        self.put(at + BEAT * 0.75, pulse(hz(note), n, 0.25) * env(n, 0.005, 0.06), gain * 0.22)

    def arp(self, at: float, note: int, gain: float, duty: float = 0.25) -> None:
        n = int(BEAT * 0.25 * RATE)
        self.put(at, pulse(hz(note), n, duty) * env(n, 0.002, 0.03), gain)

    def bass(self, at: float, note: int, beats: float, gain: float) -> None:
        n = int(beats * BEAT * RATE)
        self.put(at, triangle(hz(note), n) * env(n, 0.003, 0.03), gain)

    def kick(self, at: float, gain: float) -> None:
        n = int(0.22 * RATE)
        t = np.arange(n) / RATE
        f = 50.0 + 110.0 * np.exp(-t * 40.0)
        x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14.0)
        self.put(at, x.astype(np.float32), gain)

    def _noise(self, key: str, n: int, cutoff: float, high: bool) -> np.ndarray:
        k = (key, n)
        if k not in self._noise_cache:
            self._noise_cache[k] = onepole(noise(n, hash(key) & 0xffff), cutoff, high)
        return self._noise_cache[k]

    def snare(self, at: float, gain: float, length: float = 0.16) -> None:
        n = int(length * RATE)
        t = np.arange(n) / RATE
        body = self._noise(f"snare{n}", n, 900.0, True) * np.exp(-t * 22.0)
        tone = np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 30.0) * 0.5
        self.put(at, (body + tone).astype(np.float32), gain)

    def hat(self, at: float, gain: float, open_: bool = False) -> None:
        n = int((0.18 if open_ else 0.04) * RATE)
        t = np.arange(n) / RATE
        x = self._noise(f"hat{n}", n, 6000.0, True) * np.exp(-t * (14.0 if open_ else 80.0))
        self.put(at, x.astype(np.float32), gain)

    def crash(self, at: float, gain: float) -> None:
        n = int(2.2 * RATE)
        t = np.arange(n) / RATE
        x = self._noise("crash", n, 3500.0, True) * np.exp(-t * 2.2)
        self.put(at, x.astype(np.float32), gain)

    def riser(self, at: float, seconds: float, gain: float) -> None:
        n = int(seconds * RATE)
        t = np.arange(n) / RATE
        k = t / seconds
        f = 200.0 * (2.0 ** (k * 3.0))
        sweep = np.where((np.cumsum(f) / RATE) % 1.0 < 0.5, 1.0, -1.0) * 0.35
        hiss = onepole(noise(n, 99), 2000.0 + 6000.0 * float(k[-1]), True)
        self.put(at, ((sweep + hiss) * k ** 2).astype(np.float32), gain)

    def boom(self, at: float, gain: float) -> None:
        n = int(1.8 * RATE)
        t = np.arange(n) / RATE
        f = 34.0 + 70.0 * np.exp(-t * 16.0)
        x = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 2.6)
        self.put(at, x.astype(np.float32), gain)


def compose(music_in: float, drop: float, title: float, end: float) -> np.ndarray:
    tr = Track(end)
    bar = BEAT * 4

    # ---------------------------------------------------------------- BUILD
    build_bars = max(1, round((drop - music_in) / bar))
    for b in range(build_bars):
        t0 = music_in + b * bar
        root, chord = CHORDS[b % 4]
        last = b == build_bars - 1
        lift = (b + 1) / build_bars            # 0..1 across the build
        tr.bass(t0, root - 12, 4, 0.30)
        for s in range(16):
            if last and s >= 12:
                break                           # the gap before the drop
            note = chord[s % 3] + (12 if (s // 3) % 2 else 0)
            tr.arp(t0 + s * BEAT / 4, note + 12, 0.06 + 0.07 * lift, 0.125 if b == 0 else 0.25)
        if b >= 1:
            for s in range(8):
                if not (last and s >= 6):
                    tr.hat(t0 + s * BEAT / 2, 0.05 + 0.05 * lift)
        if b >= 2 or build_bars <= 2:
            tr.kick(t0, 0.55)
            if not last:
                tr.kick(t0 + 2 * BEAT, 0.5)
        if last:
            # A snare roll that doubles up, and a riser, into a beat of nothing.
            for s in range(12):
                tr.snare(t0 + s * BEAT / 4, 0.12 + 0.03 * s, 0.08)
            tr.riser(t0, bar - BEAT, 0.5)

    # ----------------------------------------------------------------- DROP
    drop_bars = max(1, round((title - drop) / bar))
    tr.boom(drop, 0.9)
    for b in range(drop_bars):
        t0 = drop + b * bar
        root, chord = CHORDS[b % 4]
        if b % 4 == 0:
            tr.crash(t0, 0.32)
        # Kit: kick on 1 and the "and" of 2 and 3, snare on 2 and 4.
        for beat in (0.0, 1.5, 2.0):
            tr.kick(t0 + beat * BEAT, 0.8)
        for beat in (1.0, 3.0):
            tr.snare(t0 + beat * BEAT, 0.42)
        for s in range(8):
            tr.hat(t0 + s * BEAT / 2, 0.07 if s % 2 == 0 else 0.11, open_=(s % 4 == 3))
        # Bass in eighths with an octave jump: the engine.
        for s in range(8):
            note = root - 12 + (12 if s in (3, 7) else 0)
            tr.bass(t0 + s * BEAT / 2, note, 0.45, 0.42)
        # Arpeggio under it, quieter now that the tune is on top.
        for s in range(16):
            note = chord[s % 3] + 12 + (12 if (s // 3) % 2 else 0)
            tr.arp(t0 + s * BEAT / 4, note, 0.06)
        # The tune.
        line = TUNE[b % len(TUNE)]
        for s, note in enumerate(line):
            if note > 0:
                held = 1
                while s + held < 8 and line[s + held] == -1:
                    held += 1
                tr.lead(t0 + s * BEAT / 2, note, held * 0.5 * 0.95, 0.16)

    # ---------------------------------------------------------------- STING
    tr.boom(title, 1.0)
    tr.crash(title, 0.45)
    ring = max(1.0, end - title)
    for note in (48, 55, 60, 64, 67, 72):        # C major, wide
        n = int(ring * RATE)
        x = pulse(hz(note), n, 0.25 if note > 60 else 0.5) * env(n, 0.004, ring * 0.9)
        tr.put(title, x * np.exp(-np.arange(n) / RATE * 0.9).astype(np.float32), 0.07)
    tr.bass(title, 36, ring / BEAT, 0.45)

    # The build sits well under the drop and swells towards it, as the
    # reference trailer's music does (about -27 dB rising to -21, then -12).
    out = tr.buf[: int(end * RATE)]
    a, b = int(music_in * RATE), int(drop * RATE)
    if b > a:
        out[a:b] *= np.linspace(0.3, 0.6, b - a, dtype=np.float32)
    return out


def cue_times(capture: Path) -> tuple:
    shots = json.loads((capture / "shots.json").read_text())
    duration = shots["frames"] / shots["fps"]
    cues = {c["cue"]: float(c["t"]) for c in reversed(shots.get("cues", []))}
    music_in = cues.get("music_in", 0.0)
    drop = cues.get("drive_in", music_in + 8 * BEAT * 4)
    title = cues.get("drive_out", duration)
    return music_in, drop, title, duration


def write(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    cap = Path(sys.argv[1])
    m, d, t, e = cue_times(cap)
    score = compose(m, d, t, e)
    score /= max(1e-6, float(np.max(np.abs(score))))
    write(Path(sys.argv[2]), score * 0.9)
    print(f"score: build {m:.2f}s, drop {d:.2f}s, sting {t:.2f}s, end {e:.2f}s")
