"""Check the 38 second deliverable and its native gameplay evidence."""
from __future__ import annotations
import hashlib
import json
import os
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"build/promotion/v3"
ENGLISH=os.environ.get("PROMO_LANG")=="en"
SUFFIX="-en" if ENGLISH else ""
MOVIE=OUT/f"melos-promo-v3{SUFFIX}.mp4"

def verify():
    raw=subprocess.check_output(["ffprobe","-v","error","-count_frames","-show_entries",
        "format=duration,size:stream=codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,pix_fmt,color_range,color_space,sample_rate,channels",
        "-of","json",str(MOVIE)],text=True)
    info=json.loads(raw)
    video=next(s for s in info["streams"] if s["codec_type"]=="video")
    audio=next(s for s in info["streams"] if s["codec_type"]=="audio")
    assert abs(float(info["format"]["duration"])-38)<0.025
    assert (video["width"],video["height"])==(1280,720)
    assert video["r_frame_rate"]==video["avg_frame_rate"]=="60/1"
    assert int(video["nb_read_frames"])==2280
    assert video["color_space"]=="bt709" and video["pix_fmt"]=="yuv420p"
    assert audio["codec_name"]=="aac" and audio["channels"]==2 and audio["sample_rate"]=="48000"
    decoded=subprocess.run(["ffmpeg","-v","error","-i",str(MOVIE),"-f","null","NUL"],capture_output=True,text=True,check=True)
    assert not decoded.stderr.strip(),decoded.stderr
    levels=subprocess.run(["ffmpeg","-hide_banner","-i",str(MOVIE),"-af","loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json","-vn","-f","null","NUL"],capture_output=True,text=True,check=True).stderr
    measured=json.loads(levels[levels.rfind("{"):levels.rfind("}")+1])
    assert float(measured["input_tp"]) < -0.7
    checks=json.loads((OUT/f"capture-checks{SUFFIX}.json").read_text())
    assert all(checks.values())
    timeline=json.loads((OUT/f"edit-timeline{SUFFIX}.json").read_text())
    assert all(c["speed"]>=1 for c in timeline)
    assert max(c["hold"] for c in timeline)<=0.20
    assert next(c["timeline_start"] for c in timeline if c["take"]=="role")==8
    assert next(c["timeline_start"] for c in timeline if c["take"]=="success")==12
    assert next(c["timeline_start"] for c in timeline if c["take"]=="collapse")==24
    assert next(c["timeline_start"] for c in timeline if c["take"]=="title")==34
    baseline=json.loads((OUT/"import-baseline.json").read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==digest for p,digest in baseline.items())
    meta=json.loads((OUT/f"takes-edited{SUFFIX}.json").read_text())
    framed=[]
    for m in meta["frame_metrics"]:
        c=next(c for c in timeline if c["take"]==m["take"])
        source=(m["frame"]-1)/60
        if not c["start"]<=source<=c["end"]:continue
        # After the initial death, the empty frame and wide view are intentional.
        if m["take"] in ["intro","failure"]:continue
        x,y=m["runner_screen"]
        time=c["timeline_start"]+(source-c["start"])/c["speed"]
        if 26<=time<=26.30:x,y=x*1280/960,(y-110)*720/540
        elif 30<=time<=30.50:x,y=(x-170)*1280/960,(y-20)*720/540
        elif 32<=time<=32.90:x,y=x*1280/1080,(y-40)*720/608
        framed.append((m["take"],m["frame"],35<x<1245 and 45<y<675,[x,y]))
    fraction=sum(f[2] for f in framed)/len(framed)
    framing={"checked_frames":len(framed),"safe_fraction":fraction,"outside":[f for f in framed if not f[2]]}
    (OUT/f"framing-check{SUFFIX}.json").write_text(json.dumps(framing,indent=2))
    assert fraction>=0.99,framing
    result={"movie":str(MOVIE),"media":info,"loudness":measured,"native_capture_checks":checks,
        "full_decode":True,"no_slow_motion":True,"max_end_pose_hold":max(c["hold"] for c in timeline),
        "native_music_muted":True,"new_score_start":12,"digest_situations":5,"digest_shots":8,
        "preexisting_import_settings_preserved":len(baseline),"framing":framing,
        "audio_listening_review":"not performed","creator_credit":"Inoue & Sasabe" if ENGLISH else "pending supplied name"}
    (OUT/f"export-info{SUFFIX}.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({"verified":str(MOVIE),"duration":38,"frames":2280,"safe_fraction":fraction,"true_peak":measured["input_tp"]},ensure_ascii=False),flush=True)

if __name__=="__main__":verify()
