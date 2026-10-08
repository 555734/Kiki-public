#!/usr/bin/env python3
"""Mix the trailer's soundtrack: the game's own music plus every sound the
game played while the shots were filmed.

    python3 tools/trailer_mix.py <capture dir> <out.wav>

<capture dir> is what tools/capture_trailer.gd wrote (shots.json, sfx.json).
The music is the stage loop and its drive layer from tools/make_audio.py, both
132 BPM and the same length, so the cut list -- which is counted in beats --
lands on the bar lines without any alignment here:

    beats  0-24   base loop only          (the three statements)
    beats 24-54   base + drive            (the montage)
    beats 54-     base only, fading out   (the title)
"""
import json
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
RATE = 44100
BEAT = 60.0 / 132.0

DRIVE_IN = 24 * BEAT
DRIVE_OUT = 54 * BEAT
MUSIC_DB = -5.0
SFX_DB = -4.0


def load(name: str) -> np.ndarray:
    with wave.open(str(AUDIO / f"{name}.wav")) as w:
        assert w.getsampwidth() == 2, name
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
        data = data.astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
        return resample(data, w.getframerate() / RATE)


def resample(x: np.ndarray, step: float) -> np.ndarray:
    """Read `x` every `step` source samples: rate conversion and, with a step
    other than the rate ratio, the pitch shift the game applied."""
    n = int(len(x) / step)
    return np.interp(np.arange(n) * step, np.arange(len(x)), x).astype(np.float32)


def db(v: float) -> float:
    return 10.0 ** (v / 20.0)


def ramp(n: int, t: np.ndarray, at: float, length: float, up: bool) -> np.ndarray:
    k = np.clip((t - at) / max(length, 1e-6), 0.0, 1.0)
    return k if up else 1.0 - k


def main() -> None:
    cap = Path(sys.argv[1])
    out = Path(sys.argv[2])
    shots = json.loads((cap / "shots.json").read_text())
    sfx = json.loads((cap / "sfx.json").read_text())
    duration = shots["frames"] / shots["fps"]
    n = int(round(duration * RATE))
    t = np.arange(n) / RATE

    base = load("music_stage")
    drive = load("music_drive")
    loops = n // len(base) + 1
    base = np.tile(base, loops)[:n]
    drive = np.tile(drive, loops)[:n]
    drive_gain = ramp(n, t, DRIVE_IN - 0.02, 0.04, True) * ramp(n, t, DRIVE_OUT, 0.35, False)
    music = base + drive * drive_gain
    music *= ramp(n, t, duration - 2.2, 2.2, False)
    mix = music * db(MUSIC_DB)

    cache: dict = {}
    for s in sfx:
        key = s["key"]
        if key not in cache:
            cache[key] = load(key)
        clip = cache[key]
        pitch = float(s.get("pitch", 1.0))
        if abs(pitch - 1.0) > 1e-3:
            clip = resample(clip, pitch)
        at = int(round(float(s["t"]) * RATE))
        if at >= n:
            continue
        clip = clip[: n - at] * db(float(s.get("db", 0.0)) + SFX_DB)
        mix[at:at + len(clip)] += clip

    # Gentle bus compression by a soft clip, then peak at -1 dBFS.
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    mix *= db(-1.0) / max(1e-6, float(np.max(np.abs(mix))))
    stereo = np.repeat((mix * 32767.0).astype(np.int16)[:, None], 2, axis=1)
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(stereo.tobytes())
    print(f"mixed {duration:.2f}s, {len(sfx)} sounds -> {out}")


if __name__ == "__main__":
    main()
