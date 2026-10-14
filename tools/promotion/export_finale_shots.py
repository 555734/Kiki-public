#!/usr/bin/env python3
"""Flatten the 1-10 PV capture report into docs: JSON copy + CSV table.

    python3 tools/promotion/export_finale_shots.py
"""
import csv
import json
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv", "shots_report.json")
DST = os.path.join(ROOT, "docs", "promotion", "stage-1-10")

def main():
    os.makedirs(DST, exist_ok=True)
    shutil.copy(SRC, os.path.join(DST, "shots_report.json"))
    report = json.load(open(SRC))
    with open(os.path.join(DST, "shots.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["shot", "seconds", "name", "area", "take", "runner_start", "setup", "camera_mode",
                    "camera_at", "zoom_from", "zoom_to", "camera_extra", "move", "phenomenon",
                    "success_check", "success_means", "verified", "runner_at_key_moment",
                    "camera_at_key_moment", "overlay_regions", "slow_motion", "still"])
        for r in report["shots"]:
            cam = r.get("camera", {})
            extra = {k: v for k, v in cam.items() if k not in ("mode", "at", "zoom")}
            w.writerow([r["shot"], "%s-%s" % tuple(r.get("t", ["", ""])), r["name"], r["area"], r["take"],
                        r.get("runner_start"), r.get("setup"), cam.get("mode"), cam.get("at"),
                        cam.get("zoom", [None, None])[0], cam.get("zoom", [None, None])[1], json.dumps(extra),
                        r.get("move"), r.get("phenomenon"), r["check"], r["means"],
                        "yes" if r["success"] else "NO", r.get("runner_world"), r.get("camera_world"),
                        json.dumps(r.get("overlay", {})), r.get("slow_motion", False), r.get("still")])
    print("exported", len(report["shots"]), "cuts;", report["passed"], "verified")

if __name__ == "__main__":
    main()
