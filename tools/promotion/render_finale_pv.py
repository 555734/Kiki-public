#!/usr/bin/env python3
"""Cut the 1-10 PV from a real-game recording into MP4s.

Input: the Movie Maker recording of tools/promotion/capture_finale_pv.tscn
(godot --write-movie ... --fixed-fps 60) and that run's shots_report.json.
Every frame comes from the game; this script only cuts and encodes.

    python3 tools/promotion/render_finale_pv.py build/promotion/stage-1-10/pv/takes.avi

Writes, next to the report:
  finale_pv_49cuts.mp4  one second per storyboard cut, in order (49 s), each
                        second chosen around the frame where that cut's
                        action was verified in game
  finale_pv_takes.mp4   the whole recording, every take uncut
Requires ffmpeg.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PV = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv")
FPS = 60
CUT = 60  # frames per storyboard second


def probe_frames(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v:0",
                          "-show_entries", "stream=nb_read_packets", "-of", "csv=p=0", path],
                         capture_output=True, text=True, check=True).stdout.strip()
    return int(out.split(",")[0])


def window(row, total):
    """60 frames inside the cut, around the moment its action happened."""
    start = int(row["start_frame"])
    end = start + int(row.get("frames", CUT))
    key = int(row["key_frame"]) if int(row.get("key_frame", -1)) >= 0 else (start + end) // 2
    # The verified moment sits a little after the middle: show the lead-up.
    first = key - int(CUT * 0.6)
    if end - start >= CUT:
        first = max(start, min(first, end - CUT))
    first = max(0, min(first, total - CUT))
    return first


def main():
    movie = sys.argv[1] if len(sys.argv) > 1 else os.path.join(PV, "takes.avi")
    report = json.load(open(os.path.join(PV, "shots_report.json")))
    total = probe_frames(movie)
    shots = sorted(report["shots"], key=lambda r: r["shot"])
    parts, labels = [], []
    for i, row in enumerate(shots):
        first = window(row, total)
        parts.append("[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS[v%d]" % (first, first + CUT, i))
        labels.append("[v%d]" % i)
        row["pv_frames"] = [first, first + CUT]
    graph = ";".join(parts) + ";" + "".join(labels) + "concat=n=%d:v=1:a=0[out]" % len(shots)
    cuts = os.path.join(PV, "finale_pv_49cuts.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", movie, "-filter_complex", graph, "-map", "[out]",
                    "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", cuts], check=True)
    takes = os.path.join(PV, "finale_pv_takes.mp4")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", movie, "-r", str(FPS), "-c:v", "libx264",
                    "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
                    "-movflags", "+faststart", takes], check=True)
    json.dump(report, open(os.path.join(PV, "shots_report.json"), "w"), indent=1)
    print("recording: %d frames (%.1fs)" % (total, total / FPS))
    print("wrote", cuts, "(%d cuts, %.0fs)" % (len(shots), len(shots) * CUT / FPS))
    print("wrote", takes)


if __name__ == "__main__":
    main()
