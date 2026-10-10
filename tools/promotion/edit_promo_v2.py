"""Cut native V2 takes on a 150 BPM grid; never slow gameplay to fill time."""
from __future__ import annotations

import json
import math
import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from edit_promo import atempo

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/v2"
FONT = "C:/Windows/Fonts/meiryob.ttc"
SR = 48000
FPS = 60
BEAT = 0.4


def run(args: list[str]) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def music(duration: float, cuts: list[float], impacts: list[float]) -> None:
    rng = np.random.default_rng(7342)
    audio = np.zeros((round(duration * SR), 2), dtype=float)

    def add(signal: np.ndarray, at: float, gain: float, pan: float = 0) -> None:
        at_sample = round(at * SR)
        if at_sample < 0 or at_sample >= len(audio):
            return
        signal = signal[:len(audio) - at_sample] * gain
        audio[at_sample:at_sample + len(signal), 0] += signal * math.sqrt((1 - pan) / 2)
        audio[at_sample:at_sample + len(signal), 1] += signal * math.sqrt((1 + pan) / 2)

    def tone(midi: int, length: float, decay: float = 10) -> np.ndarray:
        t = np.arange(round(length * SR)) / SR
        f = 440 * 2 ** ((midi - 69) / 12)
        return (np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)) * (1 - np.exp(-700 * t)) * np.exp(-decay * t)

    t = np.arange(round(0.23 * SR)) / SR
    kick = np.sin(2 * np.pi * (48 * t + 105 * (1 - np.exp(-35 * t)) / 35)) * np.exp(-19 * t)
    t = np.arange(round(0.15 * SR)) / SR
    noise = rng.standard_normal(len(t))
    high = noise - np.convolve(noise, np.ones(10) / 10, mode="same")
    snare = (high * 0.7 + np.sin(2 * np.pi * 180 * t) * 0.2) * np.exp(-32 * t)
    t = np.arange(round(0.045 * SR)) / SR
    noise = rng.standard_normal(len(t))
    hat = (noise - np.convolve(noise, np.ones(5) / 5, mode="same")) * np.exp(-90 * t)
    roots = [40, 43, 36, 38]
    motif = [64, 67, 71, 74, 71, 67, 69, 62]
    for i in range(math.ceil(duration / BEAT)):
        at = i * BEAT
        root = roots[(i // 4) % 4]
        add(kick, at, 0.25)
        if i % 4 in (1, 3):
            add(snare, at, 0.1)
        add(tone(root, 0.32, 8), at, 0.13)
        for j in range(2 if at < 2.4 else 4):
            add(hat, at + j * BEAT / 4, 0.033, 0.3 if j % 2 else -0.3)
        if at >= 1.6:
            add(tone(motif[i % 8], 0.25), at, 0.075, -0.2)
        if 6.4 <= at < duration - 1.6:
            add(tone(motif[(i + 3) % 8] + 12, 0.18), at + 0.2, 0.04, 0.25)
        if i % 16 == 15:
            for j in range(3):
                add(snare, at + j * 0.1, 0.025 * (j + 1))
    for at in cuts:
        add(kick, at, 0.1)
    for at in impacts:
        start = max(0, round((at - 0.06) * SR))
        end = min(len(audio), round((at + 0.16) * SR))
        audio[start:end] *= 0.38
    end_start = duration - 1.6
    for note in [52, 59, 64, 67]:
        add(tone(note, 1.5, 3), end_start, 0.06)
    audio[-round(0.18 * SR):] *= np.linspace(1, 0, round(0.18 * SR))[:, None]
    audio = np.tanh(audio * 1.1) * 0.65
    with wave.open(str(OUT / "music-v2.wav"), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((audio * 32767).astype("<i2").tobytes())


def text_layer(text: str, size: int = 64, color: str = "#ffffff", y: int = 64) -> Image.Image:
    image = Image.new("RGBA", (1280, 720))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT, size)
    x = (1280 - draw.textlength(text, font=font)) / 2
    draw.text((x, y), text, font=font, fill=color, stroke_width=4, stroke_fill=(12, 22, 35, 225))
    return image


def graphics(clips: list[dict], events: list[dict]) -> list[tuple[Path, float, float]]:
    layers = []
    by_name = {c["take"]: c for c in clips}

    def layer(name: str, image: Image.Image, start: float, end: float) -> None:
        if end - start < 0.15:
            return
        path = OUT / f"overlay-{name}.png"
        image.save(path)
        layers.append((path, max(0, start), end))

    def moment(take: str, event: str) -> float:
        clip = by_name[take]
        frame = next(e["frame"] for e in events if e["take"] == take and e["event"] == event)
        return clip["timeline_start"] + (max(0, frame - 1) / FPS - clip["start"]) / clip["speed"]

    legend = Image.new("RGBA", (1280, 720))
    draw = ImageDraw.Draw(legend)
    font = ImageFont.truetype(FONT, 26)
    for x, text, color in [(32, "1P  走る", "#ffda71"), (930, "2P  描く・撃つ", "#b1f7ff")]:
        width = draw.textlength(text, font=font)
        draw.rounded_rectangle((x, 20, x + width + 32, 65), radius=12, fill=(12, 22, 35, 195))
        draw.text((x + 16, 24), text, font=font, fill=color)
    layer("roles", legend, moment("opening", "rescue"), by_name["bridge"]["timeline_start"] + by_name["bridge"]["duration"])
    opening = by_name["opening"]
    layer("reveal", text_layer("あなたは、走らない。", 62, "#b1f7ff", 76), moment("opening", "rescue"), opening["timeline_start"] + opening["duration"])
    c = by_name["chase"]
    layer("stop", text_layer("撃って、止めろ。", 64, "#ffffff", 76), moment("chase", "shot"), c["timeline_start"] + c["duration"])
    c = by_name["bridge"]
    layer("open", text_layer("撃って、開け。", 64, "#b1f7ff", 76), moment("bridge", "shot"), c["timeline_start"] + c["duration"])
    c = by_name["expiry"]
    layer("expire", text_layer("足場が、消える！", 56, "#ffda71"), c["timeline_start"] + 0.08, c["timeline_start"] + min(0.7, c["duration"]))
    # End card leaves the successful runner and goal visible on the right.
    card = Image.new("RGBA", (1280, 720))
    alpha = np.zeros((720, 1280, 4), dtype=np.uint8)
    alpha[:, :, :3] = (9, 20, 35)
    alpha[:, :, 3] = np.clip(235 * (1 - np.arange(1280) / 1150), 0, 235).astype(np.uint8)[None, :]
    card = Image.fromarray(alpha)
    d = ImageDraw.Draw(card)
    d.line((65, 248, 175, 248), fill="#b1f7ff", width=6)
    for text, x, y, size, color in [
        ("メロスゲーム", 60, 280, 91, "#ffffff"),
        ("描け。撃て。ふたりで越えろ。", 65, 420, 38, "#ffda71"),
        ("ふたりで遊ぶ協力アクション", 65, 505, 28, "#b1f7ff"),
    ]:
        d.text((x, y), text, font=ImageFont.truetype(FONT, size), fill=color)
    c = by_name["title"]
    layer("title", card, c["timeline_start"], c["timeline_start"] + c["duration"])
    return layers


def edit() -> None:
    meta = json.loads((OUT / "takes.json").read_text(encoding="utf-8"))
    takes = {s["name"]: s for s in meta["segments"]}
    events = meta["events"]
    checks = {
        "opening_rescue": any(e["take"] == "opening" and e["event"] == "rescue" and e["detail"].get("loaded") for e in events),
        "launch": any(e["event"] == "launch" and e["detail"].get("airborne") for e in events),
        "pursuer_stop": any(e["event"] == "pursuer_stopped" and e["detail"].get("stunned") for e in events),
        "bridge_open": any(e["event"] == "bridge_opened" and e["detail"].get("active") for e in events),
        "bridge_cross": any(e["event"] == "bridge_crossed" and e["detail"].get("x", 0) > 3080 and e["detail"].get("alive") for e in events),
        "expiry_rescue": any(e["event"] == "expiry_rescue" and e["detail"].get("grounded") and e["detail"].get("alive") for e in events),
        "hazards_passed": all(any(e["take"] == name and e["event"] == "hazard_passed" and all(e["detail"].get(k) for k in ["active_seen", "passed", "grounded", "loaded", "alive"]) for e in events) for name in ["eruption", "anchor"]),
        "cart_gear_rescued": all(any(e["event"] == name + "_rescue" and all(e["detail"].get(k) for k in ["grounded", "loaded", "alive"]) for e in events) for name in ["cart", "gear"]),
        "shots_hit_intended_target": all(e["detail"].get("target", "none") != "none" for e in events if e["event"] == "shot"),
        "goal": any(e["event"] == "goal" and e["detail"].get("cleared") for e in events),
        "all_takes_alive": all(s["runner_alive"] for s in takes.values()),
    }
    (OUT / "capture-checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError(f"Re-shoot required: {checks}")
    clips = []
    cursor = 0.0
    for name, desired in [("opening", 2.4), ("chase", 2.4), ("bridge", 2.4), ("expiry", 1.6), ("eruption", 2.0), ("anchor", 2.0), ("cart", 1.6), ("gear", 1.6), ("finale", 2.4), ("title", 1.6)]:
        take = takes[name]
        start = max(0, take["start_frame"] - 1) / FPS
        end = max(0, take["end_frame"] - 1) / FPS
        if name in ["eruption", "anchor", "bridge"]:
            payoff = "bridge_crossed" if name == "bridge" else "hazard_passed"
            last_action = next(e["frame"] for e in events if e["take"] == name and e["event"] == payoff)
            end = min(end, (last_action - 1) / FPS + 0.15)
        length = end - start
        # Short native takes shorten the film, instead of stretching movement.
        duration = max(BEAT / 2, min(desired, math.floor((length + 1e-6) / (BEAT / 2)) * (BEAT / 2)))
        speed = max(1.0, length / duration)
        assert speed >= 1 - 1e-6
        clips.append(dict(take=name, start=start, end=end, duration=duration, speed=speed, timeline_start=cursor))
        cursor += duration
    duration = round(cursor, 3)
    (OUT / "edit-timeline.json").write_text(json.dumps(clips, ensure_ascii=False, indent=2), encoding="utf-8")
    framed = []
    for metric in meta["frame_metrics"]:
        c = next(c for c in clips if c["take"] == metric["take"])
        if not c["start"] <= (metric["frame"] - 1) / FPS <= c["end"]:
            continue
        x, y = metric["runner_screen"]
        framed.append(35 < x < 1245 and 45 < y < 675)
    framing = {"frames": len(framed), "fully_framed_fraction": sum(framed) / len(framed)}
    (OUT / "framing-check.json").write_text(json.dumps(framing, indent=2), encoding="utf-8")
    if framing["fully_framed_fraction"] < 0.99:
        raise RuntimeError(f"Camera needs repair: {framing}")
    layers = graphics(clips, events)
    impacts = []
    for c in clips:
        impacts += [c["timeline_start"] + ((e["frame"] - 1) / FPS - c["start"]) / c["speed"] for e in events if e["take"] == c["take"] and e["event"] in ["shot", "rescue", "goal", "expiry_rescue"]]
    music(duration, [c["timeline_start"] for c in clips], impacts)
    graph = []
    concat = []
    for i, c in enumerate(clips):
        graph.append(f"[0:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=(PTS-STARTPTS)/{c['speed']:.9f},fps={FPS},setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setparams=range=limited:colorspace=bt709:color_primaries=bt709:color_trc=bt709[v{i}]")
        graph.append(f"[0:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,{atempo(c['speed'])},apad,atrim=duration={c['duration']:.9f}[a{i}]")
        concat.append(f"[v{i}][a{i}]")
    graph.append("".join(concat) + f"concat=n={len(clips)}:v=1:a=1[edited][sfx]")
    last = "edited"
    for i, (_, start, end) in enumerate(layers, start=2):
        graph.append(f"[{i}:v]format=rgba,fade=t=in:st={start:.6f}:d=0.08:alpha=1,fade=t=out:st={max(start,end-0.08):.6f}:d=0.08:alpha=1[g{i}]")
        name = f"overlay{i}"
        graph.append(f"[{last}][g{i}]overlay=0:0:enable='between(t,{start:.6f},{end:.6f})':eof_action=repeat[{name}]")
        last = name
    graph.append(f"[{last}]fps={FPS},format=yuv420p[final_video]")
    graph.append("[sfx]volume=1.0[effects]")
    graph.append("[1:a]volume=0.72[music]")
    graph.append(f"[effects][music]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=9,aresample=48000,afade=t=out:st={duration-0.15:.6f}:d=0.15[audio]")
    filter_file = OUT / "edit-filter.txt"
    filter_file.write_text(";\n".join(graph), encoding="utf-8")
    output = OUT / "melos-promo-v2.mp4"
    args = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", "-i", str(OUT / "raw-takes.avi"), "-i", str(OUT / "music-v2.wav")]
    for path, _, _ in layers:
        args += ["-loop", "1", "-framerate", str(FPS), "-i", str(path)]
    args += ["-filter_complex_threads", "2", "-filter_complex_script", str(filter_file), "-map", "[final_video]", "-map", "[audio]", "-t", str(duration), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS), "-fps_mode", "cfr", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(output)]
    run(args)
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(output), "-vf", "fps=1,scale=640:360,tile=4x5", "-frames:v", "1", str(OUT / "contact.jpg")])
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(output), "-t", "4", "-vf", "fps=4,scale=480:270,tile=4x4", "-frames:v", "1", str(OUT / "opening-contact.jpg")])
    print(json.dumps({"output": str(output), "duration": duration, "no_slow_motion": all(c["speed"] >= 1 - 1e-6 for c in clips), "framing": framing}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    edit()
