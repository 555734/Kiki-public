"""Reference-shaped 38 second edit, with a delayed score and eight digest shots."""
from __future__ import annotations
import json
import math
import os
import subprocess
import wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from edit_promo import atempo
import edit_promo_v2 as v2

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/v3"
FPS = 60
SR = 48000
FONT = "C:/Windows/Fonts/meiryob.ttc"
ENGLISH = os.environ.get("PROMO_LANG") == "en"
SUFFIX = "-en" if ENGLISH else ""
if ENGLISH: FONT = str(ROOT / "assets/fonts/Baloo2-Bold.ttf")

def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

def event(meta, take, name):
    return next(e for e in meta["events"] if e["take"] == take and e["event"] == name)

def text(text, size, at, color="#ffffff", align="center"):
    im = Image.new("RGBA", (1280, 720))
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, size)
    x, y = at
    if align == "center": x -= d.textlength(text, font=font) / 2
    d.text((x, y), text, font=font, fill=color, stroke_width=4, stroke_fill=(8, 16, 28, 230))
    return im

def overlays():
    layers = []
    def layer(name, im, start, end):
        path = OUT / f"overlay-{name}{SUFFIX}.png"
        im.save(path)
        layers.append((path, start, end))
    im = text("THIS IS YOU" if ENGLISH else "助けるのは、あなた。", 60, (785, 64), "#b1f7ff")
    d = ImageDraw.Draw(im)
    # Point at the actual native platform button, not an invented avatar.
    d.line([(480, 185), (300, 350), (205, 525)], fill="#b1f7ff", width=6)
    d.polygon([(205, 525), (211, 501), (225, 511)], fill="#b1f7ff")
    layer("role", im, 8.12, 10.02)
    layer("draw", text("DRAW THE WAY" if ENGLISH else "描いて、救え。", 57, (750, 62), "#b1f7ff"), 13.1, 15.4)
    layer("launch", text("LAUNCH YOUR FRIEND" if ENGLISH else "撃って、飛ばせ。", 54, (740, 62), "#ffda71"), 16.5, 18.3)
    legend = Image.new("RGBA", (1280, 720))
    d = ImageDraw.Draw(legend)
    for label, x, color in [("1P  走る", 38, "#ffda71"), ("2P  描く・撃つ", 986, "#b1f7ff")]:
        font = ImageFont.truetype(FONT, 25)
        w = d.textlength(label, font=font)
        d.rounded_rectangle((x, 20, x+w+28, 62), 11, fill=(8, 17, 30, 200))
        d.text((x+14, 24), label, font=font, fill=color)
    if not ENGLISH:
        layer("pair", legend, 18.35, 23.95)
        layer("timing", text("ふたりのタイミングで。", 45, (760, 70)), 22.1, 23.95)
    rgba = np.zeros((720, 1280, 4), dtype=np.uint8)
    rgba[:,:,:3] = (8, 17, 30)
    rgba[:,:,3] = np.clip(240*(1-np.arange(1280)/1250), 0, 240).astype(np.uint8)[None,:]
    card = Image.fromarray(rgba)
    d = ImageDraw.Draw(card)
    d.line((65, 232, 190, 232), fill="#b1f7ff", width=6)
    title_lines = [
        ("メロスゲーム", (60, 266), 90, "#ffffff"),
        ("描け。撃て。ふたりで越えろ。", (65, 407), 37, "#ffda71"),
        ("ふたりで遊ぼう。", (65, 490), 40, "#b1f7ff"),
    ]
    if ENGLISH:
        title_lines = [
            ("MELOS GAME", (60, 266), 96, "#ffffff"),
            ("DRAW. SHOOT. SAVE.", (65, 407), 43, "#ffda71"),
            ("BY Inoue & Sasabe", (65, 473), 32, "#ffffff"),
            ("PLAY TOGETHER", (65, 540), 39, "#b1f7ff"),
        ]
    for label, pos, size, color in title_lines:
        d.text(pos, label, font=ImageFont.truetype(FONT,size), fill=color)
    layer("title", card, 34.0, 38.0)
    return layers

def capture_checks(meta):
    def detail(take, name): return event(meta, take, name)["detail"]
    checks = {
        "native_death_by_two_seconds": detail("intro","opening_death")["dead"] and detail("intro","opening_death")["elapsed"] <= 2.0,
        "fall_without_help": detail("failure","unassisted_fall")["distance"] > 150,
        "native_guardian_controls_reveal": detail("role","role_controls")["native_painter"],
        "matching_course_rescue": detail("success","assisted_landing")["loaded"],
        "lesson_launch_and_catch": detail("launch","lesson_launch")["airborne"] and detail("launch","lesson_catch")["loaded"],
        "pursuer_stunned": detail("timing","pursuer_stopped")["stunned"],
        "expiry_and_rescue": all(detail("timing","expiry_rescue")[k] for k in ["loaded","old_expired","alive"]),
        "digest_collapse_rescue": detail("collapse","digest_catch")["loaded"],
        "active_eruption_crossed": all(detail("eruption","hazard_passed")[k] for k in ["active_seen","passed","grounded","loaded","alive"]),
        "gear_cart_landings": all(detail(t,t+"_rescue")["loaded"] for t in ["gear","cart"]),
        "two_native_relay_launches": all(detail("relay",f"relay_launch_{i}")["airborne"] for i in [1,2]),
        "two_native_relay_catches": all(detail("relay",f"relay_catch_{i}")["loaded"] for i in [1,2]),
        "goal_reached": detail("relay","goal")["cleared"],
        "all_shots_hit_target": all(e["detail"]["target"] != "none" for e in meta["events"] if e["event"] == "shot"),
    }
    (OUT/f"capture-checks{SUFFIX}.json").write_text(json.dumps(checks, indent=2))
    if not all(checks.values()): raise RuntimeError(checks)

def edit():
    meta = json.loads((OUT/"takes.json").read_text(encoding="utf-8"))
    replacement_names = {"role","success","launch","timing"}
    lesson = json.loads((OUT/f"lesson-takes{SUFFIX}.json").read_text(encoding="utf-8"))
    for key in ["segments","events","frame_metrics"]:
        name_key = "name" if key=="segments" else "take"
        meta[key] = [row for row in meta[key] if row[name_key] not in replacement_names] + lesson[key]
    (OUT/f"takes-edited{SUFFIX}.json").write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding="utf-8")
    capture_checks(meta)
    takes = {t["name"]:t for t in meta["segments"]}
    clips=[]
    cursor=0.0
    for name, duration in [("intro",5), ("failure",3), ("role",4), ("success",4), ("launch",4), ("timing",4),
                           ("collapse",2.0), ("eruption",2.0), ("gear",2.0), ("cart",2.0), ("relay",2.0), ("title",4)]:
        take=takes[name]
        start=(take["start_frame"]-1)/FPS
        end=(take["end_frame"]-1)/FPS
        # Hold a successful landing for at most a short beat; never slow movement.
        if end-start < duration:
            # A longer take gives us room around the payoff. Reusable short takes
            # receive only a brief end-pose hold, recorded explicitly in the timeline.
            speed=1.0
            hold=duration-(end-start)
        else:
            speed=(end-start)/duration
            hold=0.0
        clips.append(dict(take=name,start=start,end=end,duration=duration,speed=speed,hold=hold,timeline_start=cursor))
        cursor+=duration
    assert abs(cursor-38)<1e-6
    (OUT/f"edit-timeline{SUFFIX}.json").write_text(json.dumps(clips,indent=2))
    v2.OUT=OUT
    # New arrangement of the original synth score, entering at 12 seconds.
    v2.music(26.0, [c["timeline_start"]-12 for c in clips if c["timeline_start"]>=12], [])
    t=np.arange(round(0.75*SR))/SR
    rng=np.random.default_rng(7343)
    rumble=(np.sin(2*np.pi*(38*t+16*t*t))*0.28 + rng.normal(0,0.03,len(t)))*np.sin(np.pi*np.minimum(t/0.75,1))**2
    cue=np.zeros((38*SR,2))
    cue[round(2.2*SR):round(2.2*SR)+len(t)] = rumble[:,None]
    with wave.open(str(OUT/"rumble.wav"),"wb") as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((cue*32767).astype("<i2").tobytes())
    layers=overlays()
    graph=[]
    pieces=[]
    for i,c in enumerate(clips):
        source=3+len(layers) if c["take"] in replacement_names else 0
        c["source"]=f"raw-lesson{SUFFIX}.avi" if source else "raw-takes-reshoot.avi"
        vf=f"[{source}:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=(PTS-STARTPTS)/{c['speed']:.9f},fps={FPS}"
        if c["hold"]>0: vf+=f",tpad=stop_mode=clone:stop_duration={c['hold']:.9f}"
        vf+=f",trim=duration={c['duration']:.9f},setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setparams=range=limited:colorspace=bt709:color_primaries=bt709:color_trc=bt709[v{i}]"
        graph.append(vf)
        graph.append(f"[{source}:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,{atempo(c['speed'])},apad,atrim=duration={c['duration']:.9f}[a{i}]")
        pieces.append(f"[v{i}][a{i}]")
    graph.append("".join(pieces)+f"concat=n={len(clips)}:v=1:a=1[edited][sfx]")
    # Eight digest shots: close/wide alternation within three of the five situations.
    graph.append("[edited]split=4[base][close1][close2][close3]")
    graph.append("[close1]crop=960:540:0:110,scale=1280:720[z1]")
    graph.append("[close2]crop=960:540:170:20,scale=1280:720[z2]")
    graph.append("[close3]crop=1080:608:0:40,scale=1280:720[z3]")
    graph.append("[base][z1]overlay=enable='between(t,26.0,26.30)'[d1]")
    graph.append("[d1][z2]overlay=enable='between(t,30.0,30.50)'[d2]")
    graph.append("[d2][z3]overlay=enable='between(t,32.0,32.90)'[digest]")
    last="digest"
    for i,(_,start,end) in enumerate(layers,start=3):
        graph.append(f"[{i}:v]format=rgba,fade=t=in:st={start:.6f}:d=0.10:alpha=1,fade=t=out:st={end-0.10:.6f}:d=0.10:alpha=1[g{i}]")
        graph.append(f"[{last}][g{i}]overlay=enable='between(t,{start:.6f},{end:.6f})':eof_action=repeat[o{i}]")
        last=f"o{i}"
    graph.append(f"[{last}]fps=60,format=yuv420p[vout]")
    graph.append("[1:a]adelay=12000|12000,apad,atrim=duration=38,volume=0.63[score]")
    graph.append("[2:a]volume=0.40[cue]")
    graph.append("[sfx][score][cue]amix=inputs=3:duration=first:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,afade=t=out:st=37.6:d=0.4[aout]")
    filt=OUT/f"edit-filter{SUFFIX}.txt"
    filt.write_text(";\n".join(graph),encoding="utf-8")
    movie=OUT/f"melos-promo-v3{SUFFIX}.mp4"
    args=["ffmpeg","-hide_banner","-loglevel","warning","-y","-i",str(OUT/"raw-takes-reshoot.avi"),"-i",str(OUT/"music-v2.wav"),"-i",str(OUT/"rumble.wav")]
    for path,_,_ in layers: args += ["-loop","1","-framerate","60","-i",str(path)]
    args += ["-i",str(OUT/f"raw-lesson{SUFFIX}.avi")]
    (OUT/f"edit-timeline{SUFFIX}.json").write_text(json.dumps(clips,indent=2))
    args += ["-filter_complex_threads","2","-filter_complex_script",str(filt),"-map","[vout]","-map","[aout]","-t","38","-c:v","libx264","-preset","medium","-crf","18","-pix_fmt","yuv420p","-r","60","-fps_mode","cfr","-colorspace","bt709","-color_primaries","bt709","-color_trc","bt709","-c:a","aac","-b:a","192k","-movflags","+faststart",str(movie)]
    run(args)
    for name,length,fps,tile in [("opening-contact",10,2,"4x5"),("contact",38,1,"5x8"),("digest-contact",10,4,"5x8")]:
        args=["ffmpeg","-hide_banner","-loglevel","error","-y"]
        if name=="digest-contact": args += ["-ss","24"]
        args += ["-i",str(movie),"-t",str(length),"-vf",f"fps={fps},scale=480:270,tile={tile}","-frames:v","1",str(OUT/(name+SUFFIX+".jpg"))]
        run(args)
    print(json.dumps({"movie":str(movie),"duration":38,"music_start":12,"digest_situations":5,"digest_shots":8,"max_landing_hold":max(c["hold"] for c in clips)},ensure_ascii=False),flush=True)

if __name__=="__main__": edit()
