"""Verify rendered media, native outcomes and preservation of prior imports."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/stage-1-9"

def verify():
    movie = OUT / "melos-stage-1-9.mp4"
    info = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-count_frames", "-show_streams", "-show_format", "-of", "json", str(movie)], text=True))
    (OUT / "export-info.json").write_text(json.dumps(info, indent=2))
    v = next(s for s in info["streams"] if s["codec_type"] == "video")
    a = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert (v["width"], v["height"], v["codec_name"], v["avg_frame_rate"]) == (1280, 720, "h264", "60/1")
    assert a["codec_name"] == "aac" and v["color_space"] == "bt709"
    plan = json.loads((OUT / "edit-plan.json").read_text())
    assert abs(float(info["format"]["duration"]) - plan["duration"]) < 0.025
    assert abs(int(v["nb_read_frames"]) - round(plan["duration"] * 60)) <= 1
    decoded = subprocess.run(["ffmpeg", "-hide_banner", "-v", "error", "-i", str(movie), "-f", "null", "-"], check=True, capture_output=True)
    assert not decoded.stderr, decoded.stderr
    probe = json.loads((OUT / "probe.json").read_text())
    assert not probe["failures"] and probe["checks"] >= 23
    checks = json.loads((OUT / "capture-checks.json").read_text())
    assert all(checks.values()) and len(checks) == 11
    takes = json.loads((OUT / "takes.json").read_text())
    framing = {}
    for row in takes["framing"]:
        p = row["runner_screen"]
        assert 32 <= p[0] <= 1248 and 32 <= p[1] <= 688, row
        framing[row["take"]] = framing.get(row["take"], 0) + 1
    assert framing and all(c["speed"] == 1.0 for c in json.loads((OUT / "edit-timeline.json").read_text()))
    baseline = json.loads((OUT / "import-baseline.json").read_text())
    changed = [rel for rel, digest in baseline.items() if hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() != digest]
    assert not changed, changed
    loud_log = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", str(movie), "-af", "loudnorm=I=-16:TP=-1:LRA=11:print_format=json", "-f", "null", "-"], check=True, capture_output=True, text=True).stderr
    loud = json.loads(re.findall(r'\{\s*"input_i".*?\}', loud_log, re.S)[-1])
    assert float(loud["input_tp"]) <= -0.7
    report = {"duration": float(info["format"]["duration"]), "frames": int(v["nb_read_frames"]),
        "stage_checks": probe["checks"], "capture_checks": len(checks), "framed_frames": sum(framing.values()),
        "imports_preserved": len(baseline), "true_peak_db": float(loud["input_tp"]), "lufs": float(loud["input_i"]),
        "full_decode": "passed", "english_only": plan["english_only"], "creator": plan["creator"]}
    (OUT / "verification.json").write_text(json.dumps(report, indent=2))
    (OUT / "loudness-check.json").write_text(json.dumps(loud, indent=2))
    print(json.dumps(report))

if __name__ == "__main__": verify()
