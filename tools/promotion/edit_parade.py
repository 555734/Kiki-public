"""Edit native stage 1-9 takes without altering gameplay speed."""
from __future__ import annotations
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import edit_promo_v2 as score

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/stage-1-9"
FPS = 60

def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

def edit():
    meta = json.loads((OUT / "takes.json").read_text(encoding="utf-8"))
    events = {(e["take"], e["event"]): e["detail"] for e in meta["events"]}
    checks = {
        "native_bite_before_2s": events["false_goal", "bite"]["dead"] and events["false_goal", "bite"]["seconds"] <= 2,
        "crowd_reveal": events["false_goal", "crowd_reveal"]["enemies"] >= 50,
        "first_mass_crush": events["crowd_crusher", "mass_crush"]["killed"] >= 12,
        "falling_floor": events["floor_rescue", "floor_betrayal"]["falling"],
        "real_rescue": all(events["floor_rescue", "catch"][key] for key in ["loaded", "alive"]),
        "rescue_launch": events.get(("floor_rescue", "rescue_launch"), {}).get("launched", False),
        "shot_opens_second_gate": all(events["second_mouth", "second_gate"].values()),
        "opposite_mass_crush": events["reverse_wave", "reverse_crush"]["killed"] >= 12,
        "final_launch": events["final_launch", "final_flight"]["airborne"],
        "real_goal": events["final_launch", "goal"]["cleared"],
        "all_recorded_shots_hit": all(e["detail"]["hit"] for e in meta["events"] if e["event"] == "shot"),
    }
    (OUT / "capture-checks.json").write_text(json.dumps(checks, indent=2))
    assert all(checks.values()), checks
    clips = []
    cursor = 0.0
    for take in meta["segments"]:
        duration = (take["end_frame"] - take["start_frame"]) / FPS
        clips.append({"take": take["name"], "start": (take["start_frame"] - 1) / FPS,
            "end": (take["end_frame"] - 1) / FPS, "duration": duration,
            "timeline_start": cursor, "speed": 1.0})
        cursor += duration
    total = round(cursor * FPS) / FPS
    timeline = {c["take"]: c for c in clips}
    music_at = timeline["crowd_crusher"]["timeline_start"]
    score.OUT = OUT
    score.music(total - music_at, [c["timeline_start"] - music_at for c in clips if c["timeline_start"] >= music_at], [])
    font_path = str(ROOT / "assets/fonts/Baloo2-Bold.ttf")
    layers = []
    def text_layer(name, words, start, end):
        im = Image.new("RGBA", (1280, 720))
        d = ImageDraw.Draw(im)
        font = ImageFont.truetype(font_path, 44)
        x = 1230 - d.textlength(words, font=font)
        d.text((x, 28), words, font=font, fill="#ffdf77", stroke_width=4, stroke_fill="#203340")
        p = OUT / ("overlay-" + name + ".png")
        im.save(p)
        layers.append((p, start, end))
    text_layer("shoot", "ONE SHOT. A WHOLE CROWD.", music_at, music_at + 2.0)
    text_layer("save", "DRAW. SHOOT. SAVE.", timeline["floor_rescue"]["timeline_start"], timeline["second_mouth"]["timeline_start"])
    rgba = np.zeros((720, 1280, 4), dtype=np.uint8)
    rgba[:, :, :3] = (15, 27, 43)
    rgba[:, :, 3] = np.clip(245 * (1 - np.arange(1280) / 1280), 0, 245).astype(np.uint8)[None, :]
    im = Image.fromarray(rgba)
    d = ImageDraw.Draw(im)
    for label, at, size, color in [
        ("MELOS GAME", (60, 210), 94, "#ffffff"),
        ("THE TRICKSTER PARADE", (65, 345), 42, "#ffdc73"),
        ("BY Inoue & Sasabe", (65, 415), 34, "#ffffff"),
        ("PLAY TOGETHER", (65, 500), 40, "#9dffff"),
    ]:
        d.text(at, label, font=ImageFont.truetype(font_path, size), fill=color)
    title = OUT / "overlay-title.png"
    im.save(title)
    layers.append((title, timeline["title"]["timeline_start"], total))
    graph, pairs = [], []
    for i, c in enumerate(clips):
        graph.append(f"[0:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=PTS-STARTPTS,fps=60,setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setparams=range=limited:colorspace=bt709:color_primaries=bt709:color_trc=bt709[v{i}]")
        graph.append(f"[0:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,apad,atrim=duration={c['duration']:.9f}[a{i}]")
        pairs.append(f"[v{i}][a{i}]")
    graph.append(''.join(pairs) + f"concat=n={len(clips)}:v=1:a=1[base][sfx]")
    last = "base"
    for i, (_, a, b) in enumerate(layers, start=2):
        graph.append(f"[{i}:v]format=rgba,fade=t=in:st={a:.6f}:d=0.08:alpha=1,fade=t=out:st={b - 0.08:.6f}:d=0.08:alpha=1[g{i}]")
        graph.append(f"[{last}][g{i}]overlay=enable='between(t,{a:.6f},{b:.6f})':eof_action=repeat[o{i}]")
        last = f"o{i}"
    graph.append(f"[{last}]fps=60,format=yuv420p[vout]")
    delay = round(music_at * 1000)
    graph.append(f"[1:a]adelay={delay}|{delay},apad,atrim=duration={total},volume=0.55[score]")
    graph.append(f"[sfx][score]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-4.5:LRA=11,aresample=48000,volume=0.85,afade=t=out:st={total - 0.3}:d=0.3[aout]")
    filt = OUT / "edit-filter.txt"
    filt.write_text(';\n'.join(graph), encoding="utf-8")
    (OUT / "edit-timeline.json").write_text(json.dumps(clips, indent=2))
    (OUT / "edit-plan.json").write_text(json.dumps({"duration": total, "english_only": True,
        "creator": "Inoue & Sasabe", "stage": "1-9", "music_start": music_at}, indent=2))
    movie = OUT / "melos-stage-1-9.mp4"
    args = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", "-i", str(OUT / "raw-takes.avi"), "-i", str(OUT / "music-v2.wav")]
    for p, _, _ in layers: args += ["-loop", "1", "-framerate", "60", "-i", str(p)]
    args += ["-filter_complex_threads", "2", "-filter_complex_script", str(filt), "-map", "[vout]", "-map", "[aout]", "-t", str(total),
        "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p", "-r", "60", "-fps_mode", "cfr", "-colorspace", "bt709",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(movie)]
    run(args)
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(movie), "-vf", "fps=2,scale=400:225,tile=6x8", "-frames:v", "1", str(OUT / "contact.jpg")])
    print(json.dumps({"movie": str(movie), "duration": total}))

if __name__ == "__main__": edit()
