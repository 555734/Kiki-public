"""Validate the delivered movie, native action evidence, and preserved imports."""
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/v2"
MOVIE = OUT / "melos-promo-v2.mp4"


def verify() -> None:
    probe = subprocess.run([
        "ffprobe", "-v", "error", "-count_frames", "-show_entries",
        "format=duration,size:stream=codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,pix_fmt,color_range,color_space,sample_rate,channels",
        "-of", "json", str(MOVIE),
    ], check=True, capture_output=True, text=True)
    info = json.loads(probe.stdout)
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert abs(float(info["format"]["duration"]) - 16) < 0.02
    assert (video["width"], video["height"]) == (1280, 720)
    assert video["r_frame_rate"] == video["avg_frame_rate"] == "60/1"
    assert int(video["nb_read_frames"]) == 960
    assert video["pix_fmt"] == "yuv420p" and video["color_space"] == "bt709"
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == "48000" and audio["channels"] == 2
    decoded = subprocess.run([
        "ffmpeg", "-v", "error", "-i", str(MOVIE), "-f", "null", "NUL",
    ], check=True, capture_output=True, text=True)
    assert not decoded.stderr.strip(), decoded.stderr
    levels = subprocess.run([
        "ffmpeg", "-hide_banner", "-i", str(MOVIE), "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-vn", "-f", "null", "NUL",
    ], check=True, capture_output=True, text=True).stderr
    measurement = json.loads(levels[levels.rfind("{"):levels.rfind("}") + 1])
    assert float(measurement["input_tp"]) < -0.8
    capture_checks = json.loads((OUT / "capture-checks.json").read_text())
    assert all(capture_checks.values())
    timeline = json.loads((OUT / "edit-timeline.json").read_text())
    assert all(c["speed"] >= 1 for c in timeline)
    framing = json.loads((OUT / "framing-check.json").read_text())
    assert framing["fully_framed_fraction"] == 1
    baseline = json.loads((OUT / "import-baseline.json").read_text())
    assert all(hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == expected for p, expected in baseline.items())
    result = {
        "movie": str(MOVIE), "media": info, "loudness_measurement": measurement,
        "native_capture_checks": capture_checks, "framing": framing,
        "no_slow_motion": True, "full_decode": True,
        "preexisting_import_metadata_preserved": len(baseline),
        "audio_listening_review": "not performed",
    }
    (OUT / "export-info.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"verified": str(MOVIE), "seconds": 16, "frames": 960, "true_peak_dbtp": measurement["input_tp"]}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    verify()
