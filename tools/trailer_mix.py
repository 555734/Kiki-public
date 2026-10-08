#!/usr/bin/env python3
"""Mix the trailer's soundtrack: the score composed to the cut
(tools/trailer_music.py), every sound the game played while the shots were
filmed, and the designed sounds the shots' cues ask for.

    python3 tools/trailer_mix.py <capture dir> <out.wav>

<capture dir> is what tools/capture_trailer.gd wrote (shots.json, sfx.json).
Besides <out.wav> it writes <capture dir>/stems/{music,sfx,design}.wav, the
three layers before the final mix, for an editor to rebalance.

Cues (shots.json "cues", each at a film time):
    rumble / rumble_stop   a low earth rumble that builds, then stops dead
    silence                the effects drop out until the music comes in
    music_in               the score begins, on an impact
    drive_in / drive_out   the score's drop and its closing sting
"""
import json
import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trailer_music

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
RATE = 44100

MUSIC_DB = -3.0
SFX_DB = -6.0


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


def ramp(t: np.ndarray, at: float, length: float, up: bool) -> np.ndarray:
    k = np.clip((t - at) / max(length, 1e-6), 0.0, 1.0)
    return k if up else 1.0 - k


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def rumble(seconds: float, seed: int = 7) -> np.ndarray:
    """Brown-ish noise under 120 Hz, swelling: the ground starting to go."""
    n = int(seconds * RATE)
    rng = np.random.default_rng(seed)
    x = lowpass(lowpass(rng.standard_normal(n).astype(np.float32), 120.0), 90.0)
    x /= max(1e-6, float(np.max(np.abs(x))))
    t = np.arange(n) / RATE
    swell = np.clip(t / seconds, 0.0, 1.0) ** 1.5
    wobble = 0.75 + 0.25 * np.sin(2 * np.pi * 7.0 * t)
    return x * swell * wobble * 0.9


def impact(seed: int = 3) -> np.ndarray:
    """A sub thump with a short bright burst on top."""
    n = int(1.6 * RATE)
    t = np.arange(n) / RATE
    freq = 38.0 + 60.0 * np.exp(-t * 18.0)
    thump = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 3.2)
    rng = np.random.default_rng(seed)
    burst = lowpass(rng.standard_normal(n).astype(np.float32), 2500.0) * np.exp(-t * 14.0)
    return (thump * 0.95 + burst * 0.5).astype(np.float32)


def write_wav(path: Path, x: np.ndarray, channels: int) -> None:
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16)
    if channels == 2:
        pcm = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main() -> None:
    cap = Path(sys.argv[1])
    out = Path(sys.argv[2])
    shots = json.loads((cap / "shots.json").read_text())
    sfx = json.loads((cap / "sfx.json").read_text())
    cues = shots.get("cues", [])
    duration = shots["frames"] / shots["fps"]
    n = round(duration * RATE)
    t = np.arange(n) / RATE

    def first(name: str, default: float) -> float:
        for c in cues:
            if c["cue"] == name:
                return float(c["t"])
        return default

    # The score, composed to this cut's cues.
    music_in, drop, title, _ = trailer_music.cue_times(cap)
    score = trailer_music.compose(music_in, drop, title, duration)
    score /= max(1e-6, float(np.max(np.abs(score))))
    music = np.zeros(n, dtype=np.float32)
    music[: min(n, len(score))] = score[:n]
    music *= ramp(t, duration - 1.2, 1.2, False)
    music *= db(MUSIC_DB)

    # Effects, dropped while a silence holds (until the music arrives).
    silence = first("silence", -1.0)
    cache: dict = {}
    sfx_track = np.zeros(n, dtype=np.float32)
    for s in sfx:
        at_s = float(s["t"])
        if silence >= 0.0 and silence <= at_s < music_in:
            continue
        key = s["key"]
        if key not in cache:
            cache[key] = load(key)
        clip = cache[key]
        pitch = float(s.get("pitch", 1.0))
        if abs(pitch - 1.0) > 1e-3:
            clip = resample(clip, pitch)
        at = round(at_s * RATE)
        if at >= n:
            continue
        clip = clip[: n - at] * db(float(s.get("db", 0.0)) + SFX_DB)
        sfx_track[at:at + len(clip)] += clip
    if silence >= 0.0:
        sfx_track *= np.where((t >= silence) & (t < music_in), 0.0, 1.0).astype(np.float32)

    # Designed sound: the rumble, and the impact the score comes in on.
    design = np.zeros(n, dtype=np.float32)
    r0 = first("rumble", -1.0)
    if r0 >= 0.0:
        r1 = first("rumble_stop", r0 + 2.0)
        x = rumble(r1 - r0)
        a = int(r0 * RATE)
        design[a:a + len(x)] += x[: n - a] * db(-3.0)
    if "music_in" in [c["cue"] for c in cues]:
        boom = impact()
        a = int(music_in * RATE)
        design[a:a + len(boom)] += boom[: n - a] * db(-4.0)

    stems = cap / "stems"
    stems.mkdir(exist_ok=True)
    for name, layer in (("music", music), ("sfx", sfx_track), ("design", design)):
        write_wav(stems / f"{name}.wav", layer, 1)
    mix = music + sfx_track + design

    # Gentle bus compression by a soft clip, then peak at -1 dBFS.
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    mix *= db(-1.0) / max(1e-6, float(np.max(np.abs(mix))))
    out.parent.mkdir(parents=True, exist_ok=True)
    write_wav(out, mix, 2)
    print(f"mixed {duration:.2f}s, {len(sfx)} sounds, {len(cues)} cues -> {out}")


if __name__ == "__main__":
    main()
