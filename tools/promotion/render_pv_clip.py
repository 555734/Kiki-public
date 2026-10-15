#!/usr/bin/env python3
"""Cut a short test clip (some beats of the 1-10 PV) from a director recording.

    python3 tools/promotion/render_pv_clip.py OUT.mp4 FIRST LAST [takes.avi]

Takes beats FIRST..LAST (storyboard numbers) from build/promotion/stage-1-10/
pv/takes.avi with the game's own sound, joined in order, and writes OUT.mp4
plus OUT_sheet.png (every 10th frame). Used to judge one scene before the
whole PV is shot again.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_finale_pv as R  # noqa: E402


def main():
    out, first, last = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    movie = sys.argv[4] if len(sys.argv) > 4 else os.path.join(R.PV, "takes.avi")
    report = json.load(open(os.path.join(R.PV, "shots_report.json")))
    slate = R.find_slate(movie)
    offset = slate - int(report["slate_frame"])
    shots = [r for r in sorted(report["shots"], key=lambda r: r["shot"]) if first <= r["shot"] <= last]
    audio = R.movie_audio(movie)
    parts, labels, game = [], [], []
    for i, row in enumerate(shots):
        n = int(row.get("frames", R.CUT))
        f0 = int(row["first_frame"]) + offset
        parts.append("[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS[v%d]" % (f0, f0 + n, i))
        labels.append("[v%d]" % i)
        a0 = int(round(f0 / R.FPS * R.SR))
        length = int(round(n / R.FPS * R.SR))
        seg = audio[a0:a0 + length]
        game.append(np.pad(seg, (0, length - len(seg))))
    wav = out[:-4] + ".wav"
    R.write_wav(wav, np.concatenate(game))
    graph = ";".join(parts) + ";" + "".join(labels) + "concat=n=%d:v=1:a=0[out]" % len(shots)
    R.run(["ffmpeg", "-y", "-v", "error", "-i", movie, "-i", wav, "-filter_complex", graph, "-map", "[out]",
           "-map", "1:a", "-r", str(R.FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", out])
    os.remove(wav)
    raw = R.run(["ffmpeg", "-v", "error", "-i", out, "-vf", "select='not(mod(n\\,10))',scale=256:144", "-vsync", "0",
                 "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 144, 256, 3)
    cols = 8
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 256, rows * 144))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(frames):
        x, y = (i % cols) * 256, (i // cols) * 144
        sheet.paste(Image.fromarray(f), (x, y))
        d.text((x + 3, y + 2), "%.2fs" % (i * 10 / R.FPS), fill=(255, 255, 0))
    sheet.save(out[:-4] + "_sheet.png")
    for r in shots:
        print("beat %2d %-28s %3d frames  %s  runner %.1f%%%s" % (r["shot"], r["name"], int(r.get("frames", 60)), r["verdict"],
              100 * r["hero_frac_avg"], ("  " + "; ".join(r["why"])) if r.get("why") else ""))
    print("wrote", out)


if __name__ == "__main__":
    main()
