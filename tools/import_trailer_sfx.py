#!/usr/bin/env python3
"""Cut the trailer's recorded sound effects out of the CC0 packs they came from.

    python3 -I tools/import_trailer_sfx.py <downloads folder>

The folder holds the packs as downloaded and unzipped (see SOURCES below):
impact/ and rpg/ (Kenney), oga/ (OpenGameArt). Each clip is trimmed, faded at
both ends, made mono 44.1 kHz 16-bit and peak-normalised to -1 dBFS into
tools/trailer_assets/sfx/, with tools/trailer_assets/sfx/SOURCES.md saying
where every one came from. Every source is CC0: no attribution is required,
but it is kept.

Needs ffmpeg for the .ogg and .mp3 sources.
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tools" / "trailer_assets" / "sfx"
RATE = 44100

KENNEY_IMPACT = "Kenney, Impact Sounds (CC0) -- https://kenney.nl/assets/impact-sounds"
KENNEY_RPG = "Kenney, RPG Audio (CC0) -- https://kenney.nl/assets/rpg-audio"
OGA_100 = "rubberduck, 100 CC0 SFX (CC0) -- https://opengameart.org/content/100-cc0-sfx"
OGA_100B = "rubberduck, 100 CC0 SFX #2 (CC0) -- https://opengameart.org/content/100-cc0-sfx-2"
OGA_BANG = "rubberduck, 25 CC0 bang / firework SFX (CC0) -- https://opengameart.org/content/25-cc0-bang-firework-sfx"
OGA_GUN = "Gunshots (CC0) -- https://opengameart.org/content/gunshots"
OGA_SQUISH = "2 wooden squish splatter sequences (CC0) -- https://opengameart.org/content/2-wooden-squish-splatter-sequences"
OGA_DOG = "Dog sounds (CC0) -- https://opengameart.org/content/dog-sounds"
OGA_WHOOSH = "Air whoosh (CC0) -- https://opengameart.org/content/air-whoosh"

# name: [(source file, start s, end s or None, gain dB), ...] -- several
# sources are layered into one clip.
CLIPS = {
    **{f"step_{i}": [(f"impact/Audio/footstep_concrete_00{i}.ogg", 0.0, None, 0.0)] for i in range(5)},
    **{f"gallop_{i}": [(f"impact/Audio/footstep_grass_00{i}.ogg", 0.0, None, 0.0)] for i in range(5)},
    "jump": [("rpg/Audio/cloth2.ogg", 0.0, None, 0.0)],
    "land": [("impact/Audio/impactSoft_medium_001.ogg", 0.0, None, 0.0),
             ("impact/Audio/footstep_concrete_003.ogg", 0.0, None, -4.0)],
    "gun": [("oga/22_Pistol.wav", 0.10, 0.62, 0.0)],
    "gun_hit": [("impact/Audio/impactPunch_heavy_000.ogg", 0.0, None, 0.0)],
    "cannon": [("oga/25-CC0-bang-sfx/cannon_01.ogg", 0.0, 1.2, 0.0)],
    "explosion": [("oga/100-CC0-SFX_0/explosion.ogg", 0.0, None, 0.0),
                  ("oga/25-CC0-bang-sfx/bang_03.ogg", 0.0, None, -2.0)],
    "stab": [("rpg/Audio/knifeSlice.ogg", 0.0, None, 0.0)],
    "squish": [("oga/crack.mp3", 8.25, 8.75, 0.0)],
    "thud": [("impact/Audio/impactSoft_heavy_000.ogg", 0.0, None, 0.0)],
    "bark_0": [("oga/montageAudio-20120706_125721.mp3", 16.0, 16.7, 0.0)],
    "bark_1": [("oga/montageAudio-20120706_125721.mp3", 17.2, 17.65, 0.0)],
    "whoosh": [("oga/whoosh2_0.wav", 0.95, 1.65, 0.0)],
    "whoosh_short": [("oga/sfx_100_v2/sfx100v2_air_03.ogg", 0.0, None, 0.0)],
    "punch_heavy": [("impact/Audio/impactPunch_heavy_001.ogg", 0.0, None, 0.0),
                    ("oga/sfx_100_v2/sfx100v2_stones_02.ogg", 0.0, None, -3.0)],
    "gate_slam": [("impact/Audio/impactMetal_heavy_000.ogg", 0.0, None, 0.0),
                  ("oga/100-CC0-SFX_0/slam_02.ogg", 0.0, None, -3.0)],
    "latch": [("rpg/Audio/metalLatch.ogg", 0.0, None, 0.0)],
    "creak": [("rpg/Audio/creak1.ogg", 0.0, None, 0.0)],
    "spring": [("oga/100-CC0-SFX_0/spring_03.ogg", 0.0, None, 0.0)],
    "catch": [("rpg/Audio/metalClick.ogg", 0.0, None, 0.0),
              ("rpg/Audio/cloth1.ogg", 0.0, None, -6.0)],
    "soft_hit": [("impact/Audio/impactSoft_medium_000.ogg", 0.0, None, 0.0)],
    "flap": [("rpg/Audio/bookFlip2.ogg", 0.0, None, 0.0)],
}

SOURCE_OF = {"impact/": KENNEY_IMPACT, "rpg/": KENNEY_RPG, "oga/100-CC0-SFX_0/": OGA_100,
             "oga/sfx_100_v2/": OGA_100B, "oga/25-CC0-bang-sfx/": OGA_BANG,
             "oga/22_Pistol": OGA_GUN, "oga/crack": OGA_SQUISH, "oga/montageAudio": OGA_DOG,
             "oga/whoosh2": OGA_WHOOSH}


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
                          "-f", "s16le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def source_of(name: str) -> str:
    for prefix, text in SOURCE_OF.items():
        if name.startswith(prefix):
            return text
    raise KeyError(name)


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1]).resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["# Trailer sound effects", "",
             "Recorded effects for the trailer's foley layer (tools/trailer_foley.gd,",
             "mixed by tools/trailer_mix.py). Cut by tools/import_trailer_sfx.py.",
             "Every source is CC0 (public domain): no attribution is required.", "",
             "| clip | cut from | source |", "|---|---|---|"]
    for name, parts in CLIPS.items():
        layers = []
        for file, a, b, gain in parts:
            x = decode(src / file)
            x = x[int(a * RATE): int(b * RATE) if b else len(x)]
            layers.append(x * 10.0 ** (gain / 20.0))
            lines.append(f"| {name} | {file} [{a}-{b if b else 'end'}s] | {source_of(file)} |")
        n = max(len(x) for x in layers)
        mix = np.zeros(n, dtype=np.float32)
        for x in layers:
            mix[: len(x)] += x
        fade = min(len(mix) // 4, int(0.008 * RATE))
        mix[:fade] *= np.linspace(0.0, 1.0, fade)
        tail = min(len(mix) // 3, int(0.06 * RATE))
        mix[-tail:] *= np.linspace(1.0, 0.0, tail)
        mix *= 10.0 ** (-1.0 / 20.0) / max(1e-6, float(np.max(np.abs(mix))))
        with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((mix * 32767.0).astype(np.int16).tobytes())
        print(f"{name}.wav  {len(mix) / RATE:.2f}s")
    (OUT / "SOURCES.md").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
