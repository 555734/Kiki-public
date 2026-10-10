"""Action-driven edit: keep native movement, remove waiting, explain through rescue."""
from __future__ import annotations
import json
import subprocess
import wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from edit_promo import atempo
import edit_promo_v2 as score

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/v4"
FPS = 60
SR = 48000
FONT = str(ROOT / "assets/fonts/Baloo2-Bold.ttf")

def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

def edit():
    meta = json.loads((OUT / "takes.json").read_text(encoding="utf-8"))
    takes = {c["name"]: c for c in meta["segments"]}
    def detail(take, event):
        return next(e["detail"] for e in meta["events"] if e["take"] == take and e["event"] == event)
    checks = {
        "opening_native_death_under_two_seconds": detail("intro", "opening_death")["dead"] and detail("intro", "opening_death")["elapsed"] <= 2,
        "moving_course_reveal": detail("intro", "moving_course_reveal")["moving_lift"],
        "unassisted_fall": detail("failure", "unassisted_fall")["distance"] > 150,
        "actual_guardian_controls": detail("teamwork", "role_controls")["native_painter"],
        "matching_course_rescue": detail("teamwork", "rescue")["loaded"],
        "three_native_launches": all(detail("teamwork", f"launch_{i}")["airborne"] for i in [1, 2, 3]),
        "two_immediate_relay_landings": all(detail("teamwork", f"catch_{i}")["loaded"] for i in [1, 2]),
        "custom_course_goal": detail("teamwork", "goal")["cleared"],
        "moving_enemy_stopped": detail("pressure", "enemy_stopped")["stunned"],
        "rescue_under_pressure": detail("pressure", "pressure_rescue")["loaded"] and detail("pressure", "pressure_launch")["airborne"],
        "native_hazards_crossed": all(all(detail(t, "hazard_passed")[k] for k in ["active_seen", "passed", "loaded", "alive"]) for t in ["eruption", "anchor"]),
        "gear_cart_landings": all(detail(t, t + "_rescue")["loaded"] for t in ["gear", "cart"]),
        "final_relay_goal": detail("relay", "goal")["cleared"],
        "all_shots_hit": all(e["detail"]["target"] != "none" for e in meta["events"] if e["event"] == "shot"),
    }
    (OUT / "capture-checks.json").write_text(json.dumps(checks, indent=2))
    assert all(checks.values()), checks
    clips = []
    cursor = 0.0
    order = ["intro", "failure", "teamwork", "pressure", "eruption", "anchor", "gear", "cart", "relay", "title"]
    for name in order:
        c = takes[name]
        start = (c["start_frame"] - 1) / FPS
        end = (c["end_frame"] - 1) / FPS
        if name == "title": end = start + 3
        native = end - start
        duration = min(native, 2) if name in ["eruption", "anchor", "gear", "cart", "relay"] else native
        duration = round(duration * FPS) / FPS
        clips.append(dict(take=name, start=start, end=end, duration=duration, speed=max(1.0,native/duration), timeline_start=cursor))
        cursor += duration
    total = round(cursor * FPS) / FPS
    timeline = {c["take"]: c for c in clips}
    def moment(take, name):
        e = next(e for e in meta["events"] if e["take"] == take and e["event"] == name)
        c = timeline[take]
        return c["timeline_start"] + ((e["frame"] - 1) / FPS - c["start"]) / c["speed"]
    music_start = moment("teamwork", "rescue")
    score.OUT = OUT
    score.music(total - music_start, [c["timeline_start"] - music_start for c in clips if c["timeline_start"] >= music_start], [])
    cue = np.zeros((round(total * SR), 2))
    rng = np.random.default_rng(7444)
    def add_cue(at, duration, gain, sweep=False):
        t = np.arange(round(duration * SR)) / SR
        env = np.sin(np.pi * np.minimum(t / duration, 1)) ** 2
        sound = (np.sin(2*np.pi*(38*t + 18*t*t)) + rng.normal(0, 0.08, len(t))) * env * gain
        if sweep: sound = rng.normal(0, 0.13, len(t)) * env * gain
        n = round(at * SR)
        sound = sound[:len(cue)-n]
        cue[n:n+len(sound)] += sound[:, None]
    add_cue(moment("intro", "opening_death"), 0.25, 0.20)
    add_cue(moment("intro", "pullback"), 0.7, 0.25, True)
    with wave.open(str(OUT / "cues.wav"), "wb") as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((cue * 32767).astype("<i2").tobytes())
    layers = []
    def add_text(name, label, start, end, color="#b1f7ff"):
        im = Image.new("RGBA", (1280,720))
        d = ImageDraw.Draw(im)
        font = ImageFont.truetype(FONT, 49)
        x = 1230 - d.textlength(label, font=font)
        d.text((x, 24), label, font=font, fill=color, stroke_width=4, stroke_fill="#132236")
        path = OUT / f"overlay-{name}.png"
        im.save(path)
        layers.append((path, start, end))
    role_at = timeline["teamwork"]["timeline_start"]
    add_text("role", "YOU DRAW. THEY RUN.", role_at + 0.15, moment("teamwork", "launch_1") + 0.3)
    add_text("launch", "SHOOT TO LAUNCH", moment("teamwork", "launch_1") + 0.33, moment("teamwork", "catch_2"), "#ffda71")
    # Titles leave the right side open for the native goal celebration.
    rgba = np.zeros((720,1280,4), dtype=np.uint8)
    rgba[:,:,:3] = (8,17,30)
    rgba[:,:,3] = np.clip(235*(1-np.arange(1280)/1250),0,235).astype(np.uint8)[None,:]
    card = Image.fromarray(rgba)
    d = ImageDraw.Draw(card)
    for label, at, size, color in [
        ("MELOS GAME", (60,235), 96, "#ffffff"),
        ("DRAW. SHOOT. SAVE.", (65,375), 43, "#ffda71"),
        ("BY Inoue & Sasabe", (65,446), 32, "#ffffff"),
        ("PLAY TOGETHER", (65,520), 39, "#b1f7ff"),
    ]:
        d.text(at, label, font=ImageFont.truetype(FONT,size),fill=color)
    path = OUT / "overlay-title.png"
    card.save(path)
    layers.append((path,timeline["title"]["timeline_start"],total))
    graph = []
    pairs = []
    for i,c in enumerate(clips):
        graph.append(f"[0:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=(PTS-STARTPTS)/{c['speed']:.9f},fps=60,setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setparams=range=limited:colorspace=bt709:color_primaries=bt709:color_trc=bt709[v{i}]")
        graph.append(f"[0:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,{atempo(c['speed'])},apad,atrim=duration={c['duration']:.9f}[a{i}]")
        pairs.append(f"[v{i}][a{i}]")
    graph.append(''.join(pairs) + f"concat=n={len(clips)}:v=1:a=1[edited][sfx]")
    # Three quick close/wide changes inside the five native digest situations.
    digest_cuts = [(timeline[n]["timeline_start"],timeline[n]["timeline_start"]+0.30) for n in ["eruption","gear","cart"]]
    graph.append("[edited]split=2[base][close]")
    graph.append("[close]crop=1040:585:0:115,scale=1280:720[z]")
    enable = '+'.join(f"between(t,{a:.6f},{b:.6f})" for a,b in digest_cuts)
    graph.append(f"[base][z]overlay=enable='{enable}'[digest]")
    last = "digest"
    for i,(_,start,end) in enumerate(layers,start=3):
        graph.append(f"[{i}:v]format=rgba,fade=t=in:st={start:.6f}:d=0.08:alpha=1,fade=t=out:st={end-0.08:.6f}:d=0.08:alpha=1[g{i}]")
        graph.append(f"[{last}][g{i}]overlay=enable='between(t,{start:.6f},{end:.6f})':eof_action=repeat[o{i}]")
        last = f"o{i}"
    graph.append(f"[{last}]fps=60,format=yuv420p[vout]")
    delay = round(music_start*1000)
    graph.append(f"[1:a]adelay={delay}|{delay},apad,atrim=duration={total:.9f},volume=0.60[score]")
    graph.append("[2:a]volume=0.60[cue]")
    # Leave headroom for AAC's inter-sample overshoot on the sharp native effects.
    graph.append(f"[sfx][score][cue]amix=inputs=3:duration=first:normalize=0,loudnorm=I=-16:TP=-4.5:LRA=11,aresample=48000,volume=0.85,afade=t=out:st={total-0.3:.6f}:d=0.3[aout]")
    filt = OUT / "edit-filter.txt"
    filt.write_text(';\n'.join(graph),encoding="utf-8")
    (OUT / "edit-timeline.json").write_text(json.dumps(clips,indent=2))
    plan = dict(duration=total,music_start=music_start,digest_start=timeline["eruption"]["timeline_start"],title_start=timeline["title"]["timeline_start"],digest_cuts=digest_cuts,english_only=True,creator="Inoue & Sasabe")
    (OUT / "edit-plan.json").write_text(json.dumps(plan,indent=2))
    movie = OUT / "melos-promo-v4.mp4"
    args = ["ffmpeg","-hide_banner","-loglevel","warning","-y","-i",str(OUT/"raw-takes.avi"),"-i",str(OUT/"music-v2.wav"),"-i",str(OUT/"cues.wav")]
    for path,_,_ in layers: args += ["-loop","1","-framerate","60","-i",str(path)]
    args += ["-filter_complex_threads","2","-filter_complex_script",str(filt),"-map","[vout]","-map","[aout]","-t",str(total),"-c:v","libx264","-preset","medium","-crf","18","-pix_fmt","yuv420p","-r","60","-fps_mode","cfr","-colorspace","bt709","-color_primaries","bt709","-color_trc","bt709","-c:a","aac","-b:a","192k","-movflags","+faststart",str(movie)]
    run(args)
    run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",str(movie),"-vf","fps=2,scale=400:225,tile=6x10","-frames:v","1",str(OUT/"contact.jpg")])
    print(json.dumps({"movie":str(movie),**plan},ensure_ascii=False),flush=True)

if __name__ == "__main__": edit()
