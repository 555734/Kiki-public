#!/usr/bin/env python3
"""Cut the trailer's recorded sound effects out of the CC0 packs they came from.

    python3 -I tools/import_trailer_sfx.py <downloads folder>

The folder holds the sources as downloaded: fs/<id>.mp3 (Freesound previews,
see FREESOUND below), bsb/<number>.mp3 (BigSoundBank, see BIGSOUNDBANK),
lab/<name>.mp3 (Sound Effect Lab, see LAB), impact/ and rpg/ (Kenney packs,
unzipped). Each clip is trimmed, faded at both ends, made mono 44.1 kHz 16-bit
and levelled into tools/trailer_assets/sfx/, with
tools/trailer_assets/sfx/SOURCES.md saying where every one came from.

Every source but LAB is CC0: no attribution is required, but it is kept. The
LAB sounds are free to use in the trailer but may not be redistributed, so
they are written to tools/trailer_assets/sfx_lab/ instead, which git ignores:
download them by hand from the pages SOURCES.md lists before mixing.

Needs ffmpeg for the .ogg and .mp3 sources.
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tools" / "trailer_assets" / "sfx"
OUT_LAB = ROOT / "tools" / "trailer_assets" / "sfx_lab"
RATE = 44100

KENNEY_IMPACT = "Kenney, Impact Sounds (CC0) -- https://kenney.nl/assets/impact-sounds"
KENNEY_RPG = "Kenney, RPG Audio (CC0) -- https://kenney.nl/assets/rpg-audio"

# Freesound sounds (all CC0, licence checked on each sound's page), by id:
# (title, author). Downloaded as the site's high-quality previews into fs/.
FREESOUND = {
    "411148": ("running in grass", "EvanSki"),
    "461522": ("dog_running on stone tiles 2.wav", "15GPanskaBokstefflova_Nicola"),
    "320144": ("Blanket Movement 6", "OwlStorm"),
    "447922": ("Thud / Falling on wooden floor / Snapping", "Breviceps"),
    "504626": ("BODY FALL - V HVY - DIRT", "leonelmail"),
    "448002": ("cannon.mp3", "Kneeling"),
    "420449": ("Barking 2.wav", "Mrthenoronha"),
    "481642": ("Monster Growl", "JonCon_Library"),
    "60013": ("Whoosh", "qubodup"),
    "841804": ("Metallic Slam (Anvil)", "OOF9"),
    "370877": ("Chains.wav", "cribbler"),
    "383240": ("Bounce", "Jofae"),
    "450725": ("basketball grab 2versions.flac", "kyles"),
    "458113": ("Countryside", "brunoboselli"),
}
# BigSoundBank sounds by Joseph SARDIN (CC0, licence stated on each sound's
# page), by number: (title, page). Downloaded as the site's MP3 into bsb/.
BIGSOUNDBANK = {
    "0397": ("Shot of Winchester Magnum XTR", "shot-of-winchester-magnum-xtr-s0397.html"),
    "0128": ("Sword Through the Air", "sword-through-the-air-s0128.html"),
}
# Sound Effect Lab (https://soundeffect-lab.info/): free for use in a video,
# no credit needed, but no redistribution -- so never committed. By file:
# (title, category page). Downloaded by hand from that page into lab/.
LAB = {
    "blow8": ("打撃8", "battle/"),
    "mobile-phone-ringtone1": ("携帯電話の着信音1", "machine/"),
    "bomb3": ("爆発3", "battle/"),
    "punch-heavy1": ("重いパンチ1", "battle/"),
}

# name: [(source file, start s, end s or None, gain dB[, channel]), ...] --
# several sources are layered into one clip. Each moment's sound was chosen
# by ear from candidates heard against the trailer's own picture; cut at the
# onsets measured in each.
STEPS = [(0.121, 0.261), (0.385, 0.525), (0.648, 0.788), (0.902, 1.042), (1.159, 1.299),
         (1.349, 1.489), (1.468, 1.608), (1.687, 1.827), (1.887, 2.027)]
CLIPS = {
    **{f"step_{i}": [("fs/411148.mp3", a, b, 0.0)] for i, (a, b) in enumerate(STEPS)},
    "gallop": [("fs/461522.mp3", 0.26, 1.62, 0.0)],
    "jump": [("fs/320144.mp3", 0.30, 0.75, 0.0)],
    "land": [("fs/447922.mp3", 0.0, None, 0.0)],
    "thud": [("fs/504626.mp3", 0.38, 1.40, 0.0)],
    "gun": [("bsb/0397.mp3", 1.015, 2.615, 0.0)],
    "cannon": [("fs/448002.mp3", 0.12, 2.0, 0.0)],
    "explosion": [("lab/bomb3.mp3", 0.0, 2.6, 0.0)],
    "death": [("lab/blow8.mp3", 0.005, None, 0.0)],
    "ring": [("lab/mobile-phone-ringtone1.mp3", 0.052, 2.652, 0.0)],
    "bark": [("fs/420449.mp3", 0.038, None, 0.0)],
    "growl": [("fs/481642.mp3", 1.20, 2.60, 0.0)],
    "whoosh": [("bsb/0128.mp3", 0.099, None, 0.0)],
    "whoosh_short": [("fs/60013.mp3", 0.02, 0.30, 0.0)],
    "punch_heavy": [("lab/punch-heavy1.mp3", 0.053, None, 0.0)],
    "gate_slam": [("fs/841804.mp3", 0.0, 1.6, 0.0)],
    "latch": [("rpg/Audio/metalLatch.ogg", 0.0, None, 0.0)],
    "creak": [("fs/370877.mp3", 0.0, 1.6, 0.0, "left")],
    "spring": [("fs/383240.mp3", 0.20, 0.65, 0.0)],
    "catch": [("fs/450725.mp3", 0.0, 0.6, 0.0)],
    "soft_hit": [("impact/Audio/impactSoft_medium_000.ogg", 0.0, None, 0.0)],
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
    if name.startswith("bsb/"):
        title, page = BIGSOUNDBANK[name[4:].split(".")[0]]
        return f"Joseph SARDIN, \"{title}\" (CC0) -- https://bigsoundbank.com/{page}"
    if name.startswith("lab/"):
        title, page = LAB[name[4:].split(".")[0]]
        return f"効果音ラボ「{title}」 (free use, no redistribution) -- https://soundeffect-lab.info/sound/{page}"
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
    OUT_LAB.mkdir(parents=True, exist_ok=True)
    # Godot must not import them, and git must not carry them.
    (OUT_LAB / ".gdignore").write_text("")
    lines = ["# Trailer sound effects", "",
             "Recorded effects for the trailer's foley layer (tools/trailer_foley.gd,",
             "mixed by tools/trailer_mix.py). Cut by tools/import_trailer_sfx.py.",
             "Every source is CC0 (public domain): no attribution is required --",
             "except the 効果音ラボ (Sound Effect Lab) clips, which may be used in the",
             "trailer but not redistributed. Those are not in the repository: download",
             "each from the page given, into <downloads>/lab/<file>.mp3, and run the",
             "import; it writes them to tools/trailer_assets/sfx_lab/ (git-ignored).", "",
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
        lab = any(part[0].startswith("lab/") for part in parts)
        with wave.open(str((OUT_LAB if lab else OUT) / f"{name}.wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((mix * 32767.0).astype(np.int16).tobytes())
        print(f"{name}.wav  {len(mix) / RATE:.2f}s")
    (OUT / "SOURCES.md").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
