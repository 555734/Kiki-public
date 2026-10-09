#!/usr/bin/env python3
"""Cut the trailer's recorded sound effects out of the CC0 packs they came from.

    python3 -I tools/import_trailer_sfx.py <downloads folder>

The folder holds the sources as downloaded: fs/<id>.mp3 (Freesound previews,
see FREESOUND below), impact/ and rpg/ (Kenney packs, unzipped). Each clip is trimmed, faded at
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

# Freesound sounds (all CC0, licence checked on each sound's page), by id:
# (title, author). Downloaded as the site's high-quality previews into fs/.
FREESOUND = {
    "475499": ("Steps_stone_2(running).wav", "o_ciz"),
    "461522": ("dog_running on stone tiles 2.wav", "15GPanskaBokstefflova_Nicola"),
    "320144": ("Blanket Movement 6", "OwlStorm"),
    "447922": ("Thud / Falling on wooden floor / Snapping", "Breviceps"),
    "504626": ("BODY FALL - V HVY - DIRT", "leonelmail"),
    "415912": ("Heathers Gunshot Effect2.wav", "okieactor"),
    "94778": ("Punch_1-2.wav", "taylorsyoung@gmail.com"),
    "244513": ("Realistic Punch", "JewTwinz"),
    "448002": ("cannon.mp3", "Kneeling"),
    "235968": ("Explosion_01.wav", "tommccann"),
    "179222": ("Knife Stab.wav", "Mixedupmoviestuff"),
    "445109": ("Mud Splat", "Breviceps"),
    "271666": ("Tomato squish;wet.wav", "HonorHunter"),
    "332176": ("Dog_Bark_Agressive.wav", "ivolipa"),
    "386766": ("Dog_Barking.wav", "ken788"),
    "481642": ("Monster Growl", "JonCon_Library"),
    "60013": ("Whoosh", "qubodup"),
    "244983": ("ANI Big Pipe Hit", "ani_music"),
    "109360": ("stone falls and breaks low pitch.aiff", "SoundCollectah"),
    "336888": ("Gate-Heavy-OpenClose-WAV.wav", "Omnisis"),
    "218890": ("Door Smash 1", "qubodup"),
    "370877": ("Chains.wav", "cribbler"),
    "383240": ("Bounce", "Jofae"),
    "450725": ("basketball grab 2versions.flac", "kyles"),
    "389634": ("Wing Flap 1.wav", "_stubb"),
    "445958": ("Cartoon - Bat / Mouse Squeak", "Breviceps"),
    "458113": ("Countryside", "brunoboselli"),
}

# name: [(source file, start s, end s or None, gain dB[, channel]), ...] --
# several sources are layered into one clip. Picked by the many people who
# downloaded and rated them, and cut at the onsets measured in each.
STEPS = [(6.37, 6.50), (6.96, 7.09), (7.72, 7.86), (7.99, 8.12), (6.78, 6.94), (7.41, 7.55)]
CLIPS = {
    **{f"step_{i}": [("fs/475499.mp3", a, b, 0.0)] for i, (a, b) in enumerate(STEPS)},
    "gallop": [("fs/461522.mp3", 0.26, 1.62, 0.0)],
    "jump": [("fs/320144.mp3", 0.30, 0.75, 0.0)],
    "land": [("fs/447922.mp3", 0.0, None, 0.0)],
    "thud": [("fs/504626.mp3", 0.38, 1.40, 0.0)],
    "gun": [("fs/415912.mp3", 0.0, 1.2, 0.0)],
    "gun_hit": [("fs/94778.mp3", 0.18, 0.63, 0.0), ("fs/244513.mp3", 0.0, None, -4.0)],
    "cannon": [("fs/448002.mp3", 0.12, 2.0, 0.0)],
    "explosion": [("fs/235968.mp3", 0.35, 3.5, 0.0)],
    "stab": [("fs/179222.mp3", 0.12, 1.0, 0.0)],
    "squish": [("fs/445109.mp3", 0.0, None, 0.0), ("fs/271666.mp3", 0.05, 0.5, -3.0)],
    "bark_0": [("fs/332176.mp3", 0.15, 0.40, 0.0)],
    "bark_1": [("fs/332176.mp3", 1.08, 1.35, 0.0)],
    "bark_2": [("fs/386766.mp3", 0.64, 0.95, 0.0)],
    "growl": [("fs/481642.mp3", 1.20, 2.60, 0.0)],
    "whoosh": [("fs/60013.mp3", 0.0, None, 0.0)],
    "whoosh_short": [("fs/60013.mp3", 0.02, 0.30, 0.0)],
    "punch_heavy": [("fs/244983.mp3", 0.0, None, 0.0), ("fs/109360.mp3", 0.0, 1.2, -4.0)],
    "gate_slam": [("fs/218890.mp3", 1.98, 3.2, 0.0), ("fs/336888.mp3", 4.18, 5.4, -3.0)],
    "latch": [("rpg/Audio/metalLatch.ogg", 0.0, None, 0.0)],
    "creak": [("fs/370877.mp3", 0.0, 1.6, 0.0, "left")],
    "spring": [("fs/383240.mp3", 0.20, 0.65, 0.0)],
    "catch": [("fs/450725.mp3", 0.0, 0.6, 0.0)],
    "soft_hit": [("impact/Audio/impactSoft_medium_000.ogg", 0.0, None, 0.0)],
    "flap": [("fs/389634.mp3", 0.10, 0.80, 0.0)],
    "squeak": [("fs/445958.mp3", 0.0, None, 0.0)],
    "ambience": [("fs/458113.mp3", 5.0, 35.0, 0.0)],
}

SOURCE_OF = {"impact/": KENNEY_IMPACT, "rpg/": KENNEY_RPG}


def decode(path: Path, channel: str = "") -> np.ndarray:
    # A recording whose two channels are out of phase folds to silence: take
    # one side of it instead.
    mono = ["-af", "pan=mono|c0=c0"] if channel == "left" else ["-ac", "1"]
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), *mono, "-ar", str(RATE),
                          "-f", "s16le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def source_of(name: str) -> str:
    if name.startswith("fs/"):
        sid = name[3:].split(".")[0]
        title, user = FREESOUND[sid]
        return f"{user}, \"{title}\" (CC0) -- https://freesound.org/s/{sid}/"
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
        for part in parts:
            file, a, b, gain = part[:4]
            x = decode(src / file, part[4] if len(part) > 4 else "")
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
        # Level by loudness, not peak: a clip's body is what is heard. The
        # bed is kept quiet; everything else to one loudness, peaks capped.
        rms = float(np.sqrt(np.mean(mix ** 2))) + 1e-9
        target = 0.05 if name == "ambience" else 0.16
        mix *= target / rms
        peak = float(np.max(np.abs(mix)))
        if peak > 0.89:
            mix *= 0.89 / peak
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
