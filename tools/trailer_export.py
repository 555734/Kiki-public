#!/usr/bin/env python3
"""Hand the trailer over to an editor: every shot as its own clip, the audio
as separate stems, and the cut list that puts them back together.

    python3 tools/trailer_export.py <capture dir> <out dir>

Writes into <out dir>:
    shots/NN_<name>.mp4     each shot, high-quality H.264, 30 fps, no audio
    stems/*.wav             music, game sounds and designed sounds, unmixed
    soundtrack.wav          the mix the auto-cut uses
    cutlist.csv             shot, start, duration (seconds and frames)

The clips are cut from the same frames as the auto-cut, so an editor can
rebuild it exactly from the cut list and then change whatever they like.
"""
import csv
import json
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> None:
    cap = Path(sys.argv[1])
    out = Path(sys.argv[2])
    shots = json.loads((cap / "shots.json").read_text())
    fps = int(shots["fps"])
    (out / "shots").mkdir(parents=True, exist_ok=True)
    (out / "stems").mkdir(parents=True, exist_ok=True)
    rows = []
    for i, shot in enumerate(shots["shots"], 1):
        name = f"{i:02d}_{shot['name']}"
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-framerate", str(fps),
            "-start_number", str(shot["start"]), "-i", str(cap / "frames" / "%05d.png"),
            "-frames:v", str(shot["frames"]), "-c:v", "libx264", "-preset", "slow",
            "-crf", "12", "-pix_fmt", "yuv420p", str(out / "shots" / f"{name}.mp4"),
        ], check=True)
        rows.append([name, round(shot["start"] / fps, 3), round(shot["frames"] / fps, 3),
                     shot["start"], shot["frames"]])
    with open(out / "cutlist.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["shot", "start_s", "duration_s", "start_frame", "frames"])
        w.writerows(rows)
    for stem in (cap / "stems").glob("*.wav"):
        shutil.copy(stem, out / "stems" / stem.name)
    if (cap / "soundtrack.wav").exists():
        shutil.copy(cap / "soundtrack.wav", out / "soundtrack.wav")
    print(f"exported {len(rows)} shots, stems and cut list -> {out}")


if __name__ == "__main__":
    main()
