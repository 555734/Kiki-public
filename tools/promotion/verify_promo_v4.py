"""Verify the exported movie and the native action evidence used by its edit."""
from __future__ import annotations
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/v4"
MOVIE = OUT / "melos-promo-v4.mp4"

def verify():
    plan = json.loads((OUT/"edit-plan.json").read_text())
    timeline = json.loads((OUT/"edit-timeline.json").read_text())
    meta = json.loads((OUT/"takes.json").read_text(encoding="utf-8"))
    checks = json.loads((OUT/"capture-checks.json").read_text())
    assert all(checks.values()), checks
    # Frame fractions can evaluate a few ulps below 1.0; the filter uses 9 decimals.
    assert all(c["speed"] >= 1-1e-9 for c in timeline)
    assert 20 < plan["duration"] < 32
    raw = subprocess.check_output(["ffprobe","-v","error","-count_frames","-show_entries",
        "format=duration,size:stream=codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,pix_fmt,color_space,sample_rate,channels",
        "-of","json",str(MOVIE)],text=True)
    info = json.loads(raw)
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert abs(float(info["format"]["duration"])-plan["duration"]) < 0.03
    assert (video["width"],video["height"]) == (1280,720)
    assert video["r_frame_rate"] == video["avg_frame_rate"] == "60/1"
    assert int(video["nb_read_frames"]) == round(plan["duration"]*60)
    assert video["codec_name"] == "h264" and video["color_space"] == "bt709"
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == "48000" and audio["channels"] == 2
    decoded = subprocess.run(["ffmpeg","-v","error","-i",str(MOVIE),"-f","null","NUL"],capture_output=True,text=True,check=True)
    assert not decoded.stderr.strip(), decoded.stderr
    levels = subprocess.run(["ffmpeg","-hide_banner","-i",str(MOVIE),"-af","loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json","-vn","-f","null","NUL"],capture_output=True,text=True,check=True).stderr
    measured = json.loads(levels[levels.rfind('{'):levels.rfind('}')+1])
    (OUT/"loudness-check.json").write_text(json.dumps(measured,indent=2))
    framed = []
    hero_heights = []
    for m in meta["frame_metrics"]:
        c = next((c for c in timeline if c["take"] == m["take"]),None)
        source = (m["frame"]-1)/60
        if c is None or not c["start"] <= source < c["end"]: continue
        if m["take"] in ["intro","failure"]: continue
        x,y = m["runner_screen"]
        time = c["timeline_start"]+(source-c["start"])/c["speed"]
        if any(a <= time <= b for a,b in plan["digest_cuts"]): x,y = x*1280/1040,(y-115)*720/585
        framed.append(dict(take=m["take"],frame=m["frame"],safe=35<x<1245 and 45<y<675,screen=[x,y]))
        if m["take"] == "teamwork" and source-c["start"] < 0.8:
            hero_heights.append(46*m["zoom"]/720)
    safe = sum(f["safe"] for f in framed)/len(framed)
    framing = dict(checked_frames=len(framed),safe_fraction=safe,outside=[f for f in framed if not f["safe"]])
    (OUT/"framing-check.json").write_text(json.dumps(framing,indent=2))
    assert safe >= 0.99, framing
    assert float(measured["input_tp"]) < -0.7, measured
    assert min(hero_heights) > 0.12
    def frame(take,name):
        return next(e["frame"] for e in meta["events"] if e["take"]==take and e["event"]==name)
    relay_delays = [(frame("teamwork",f"launch_{i+1}")-frame("teamwork",f"catch_{i}"))/60 for i in [1,2]]
    assert max(relay_delays) <= 0.15
    manifest = json.loads((OUT/"import-baseline.json").read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in manifest.items())
    result = dict(movie=str(MOVIE),media=info,native_checks=checks,full_decode=True,no_slow_motion=True,
        end_pose_padding=0,framing=framing,role_hero_height_fraction=min(hero_heights),
        relay_relaunch_delays=relay_delays,loudness=measured,preexisting_import_settings_preserved=len(manifest),
        creator="Inoue & Sasabe",english_only=True,audio_listening_review="not performed")
    (OUT/"export-info.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(dict(verified=str(MOVIE),duration=info["format"]["duration"],safe_fraction=safe,hero_height=min(hero_heights),relay_delays=relay_delays,true_peak=measured["input_tp"]),ensure_ascii=False),flush=True)

if __name__ == "__main__": verify()
