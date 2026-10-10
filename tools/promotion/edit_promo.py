"""Edit deterministic Godot takes into the 30-second Japanese promo draft."""
from __future__ import annotations

import json
import math
import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion"
FONT = "C:/Windows/Fonts/meiryob.ttc"
SR = 48000


def run(args: list[str]) -> None:
    subprocess.run(args, check=True, cwd=ROOT)


def graphics() -> list[tuple[str, float, float]]:
    OUT.mkdir(parents=True, exist_ok=True)
    specs = [
        ("role", ["相棒の道は、", "あなたが描く。"], 59, "#b1f7ff", 2.1, 4.4),
        ("launch", ["撃って、飛ばせ。"], 76, "#ffdc71", 4.65, 6.9),
        ("stop", ["撃って、止めろ。"], 76, "#ffffff", 8.5, 10.9),
        ("expire", ["消える！"], 66, "#ffdd83", 11.65, 12.7),
    ]
    overlays = []
    for name, lines, size, color, start, end in specs:
        im = Image.new("RGBA", (1280, 720))
        d = ImageDraw.Draw(im)
        font = ImageFont.truetype(FONT, size)
        y = 42
        for line in lines:
            width = d.textlength(line, font=font)
            x = (1280 - width) / 2
            d.text((x + 3, y + 4), line, font=font, fill=(0, 0, 0, 210), stroke_width=6, stroke_fill=(0, 0, 0, 210))
            d.text((x, y), line, font=font, fill=color, stroke_width=3, stroke_fill=(19, 24, 37, 240))
            y += size * 1.15
        im.save(OUT / f"{name}.png")
        overlays.append((name, start, end))
    im = Image.new("RGBA", (1280, 720))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((120, 176, 1160, 542), radius=30, fill=(10, 17, 31, 206), outline=(119, 240, 244, 150), width=2)
    for text, y, size, color in [
        ("メロスゲーム", 210, 102, "#ffffff"),
        ("描け。撃て。ふたりで越えろ。", 365, 48, "#ffda71"),
        ("ふたりで遊ぶ協力アクション", 454, 29, "#b0dfe5"),
    ]:
        font = ImageFont.truetype(FONT, size)
        x = (1280 - d.textlength(text, font=font)) / 2
        d.text((x, y), text, font=font, fill=color)
    im.save(OUT / "title.png")
    overlays.append(("title", 28, 30))
    return overlays


def soundtrack() -> None:
    """Original synth track; no audio from the reference movie is used."""
    rng = np.random.default_rng(734)
    track = np.zeros((SR * 30, 2), dtype=np.float64)
    beat = 0.4  # 150 BPM

    def add(sound: np.ndarray, at: float, gain: float, pan: float = 0) -> None:
        offset = round(at * SR)
        if offset < 0 or offset >= len(track):
            return
        sound = sound[:len(track) - offset] * gain
        track[offset:offset + len(sound), 0] += sound * math.sqrt((1 - pan) / 2)
        track[offset:offset + len(sound), 1] += sound * math.sqrt((1 + pan) / 2)

    def note(midi: int, duration: float, kind: str) -> np.ndarray:
        t = np.arange(round(duration * SR)) / SR
        f = 440 * 2 ** ((midi - 69) / 12)
        if kind == "bass":
            signal = np.sin(2 * np.pi * f * t) + 0.22 * np.sin(4 * np.pi * f * t)
            envelope = (1 - np.exp(-t * 350)) * np.exp(-t * 8)
        else:
            signal = np.sin(2 * np.pi * f * t) + 0.32 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
            envelope = (1 - np.exp(-t * 700)) * np.exp(-t * 12)
        return signal * envelope

    t = np.arange(round(0.25 * SR)) / SR
    kick = np.sin(2 * np.pi * (48 * t + 95 * (1 - np.exp(-t * 32)) / 32)) * np.exp(-t * 17)
    t2 = np.arange(round(0.16 * SR)) / SR
    noise = rng.standard_normal(len(t2))
    high = noise - np.convolve(noise, np.ones(12) / 12, mode="same")
    snare = (0.75 * high + 0.3 * np.sin(2 * np.pi * 185 * t2)) * np.exp(-t2 * 32)
    ht = np.arange(round(0.045 * SR)) / SR
    hn = rng.standard_normal(len(ht))
    hat = (hn - np.convolve(hn, np.ones(5) / 5, mode="same")) * np.exp(-ht * 95)
    roots = [40, 43, 36, 38]
    melody = [64, 67, 71, 69, 67, 64, 62, 67, 64, 71, 74, 71, 69, 67, 62, 59]
    for i in range(75):
        at = i * beat
        gain = 0.78 if at < 15 else 1.0
        add(kick, at, 0.28 * gain)
        if i % 4 in (1, 3):
            add(snare, at, 0.11 * gain)
        root = roots[(i // 4) % 4]
        add(note(root, 0.3, "bass"), at, 0.14)
        add(note(root + (7 if i % 2 else 12), 0.2, "bass"), at + beat / 2, 0.07)
        for j in range(4):
            add(hat, at + j * beat / 4, 0.025 if j % 2 else 0.045, -0.25 if j % 2 else 0.25)
        if 2 <= at < 28:
            add(note(melody[i % len(melody)], 0.3, "pluck"), at, 0.10, -0.15)
            if at >= 15:
                add(note(melody[(i + 5) % len(melody)] + 12, 0.18, "pluck"), at + beat / 2, 0.047, 0.22)
    for at in [0, 7, 11.5, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 28]:
        add(kick, at, 0.15)
    envelope = np.ones(len(track))
    envelope[int(26.35 * SR):int(26.6 * SR)] = 0.28
    envelope[int(28 * SR):] *= 0.72
    envelope[-int(0.35 * SR):] *= np.linspace(1, 0, int(0.35 * SR))
    track *= envelope[:, None]
    track = np.tanh(track * 1.25) * 0.65
    pcm = (track * 32767).astype("<i2")
    with wave.open(str(OUT / "promo-music.wav"), "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def atempo(speed: float) -> str:
    factors = []
    while speed < 0.5:
        factors.append(0.5)
        speed /= 0.5
    while speed > 2:
        factors.append(2)
        speed /= 2
    factors.append(speed)
    return ",".join(f"atempo={x:.9f}" for x in factors)


def edit() -> None:
    meta = json.loads((OUT / "takes.json").read_text(encoding="utf-8"))
    fps = meta["fps"]
    takes = {s["name"]: s for s in meta["segments"]}
    events = meta["events"]
    checks = {
        "opening_platform_landing": any(e["event"] == "rescue" and e["detail"].get("loaded") for e in events),
        "platform_launch": any(e["event"] == "launch" and e["detail"].get("airborne") for e in events),
        "pursuer_stopped": any(e["event"] == "pursuer_stopped" and e["detail"].get("stunned") for e in events),
        "expiry_rescue": any(e["event"] == "expiry_rescue" and e["detail"].get("grounded") and e["detail"].get("alive") for e in events),
        "goal_reached": any(e["event"] == "goal" and e["detail"].get("cleared") for e in events),
        "all_takes_alive": all(s.get("runner_alive") for s in takes.values()),
    }
    (OUT / "capture-checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError(f"Capture needs repair: {checks}")
    overlays = graphics()
    soundtrack()
    clips = []

    def clip(name: str, target: float, *, offset=0.0, length=None, crop=None, tail=False) -> None:
        s = takes[name]
        start = max(0, s["start_frame"] - 1) / fps + offset
        end = max(0, s["end_frame"] - 1) / fps
        if tail:
            start = max(start, end - (length or 0.7))
        elif length:
            end = min(end, start + length)
        clips.append({"take": name, "start": start, "end": end, "duration": target, "crop": crop})

    clip("opening", 7.0)
    clip("chase", 4.5)
    clip("expiry", 3.5)
    for name in ["anchor", "surge", "eruption", "gear", "cart", "wind"]:
        clip(name, 1.0, offset=0.12, length=1.35)
    clip("opening", 1.0, length=0.8, tail=True)
    clip("anchor", 1.0, offset=0.4, length=1.2, crop="crop=1000:562:140:65,scale=1280:720")
    clip("eruption", 1.0, offset=0.4, length=1.2, crop="crop=1000:562:140:65,scale=1280:720")
    clip("finale", 4.0)
    clip("finale", 2.0, length=0.9, tail=True)
    assert math.isclose(sum(c["duration"] for c in clips), 30)
    graph = []
    concat = []
    cursor = 0.0
    for i, c in enumerate(clips):
        length = c["end"] - c["start"]
        speed = length / c["duration"]
        crop = f",{c['crop']}" if c["crop"] else ""
        graph.append(f"[0:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=(PTS-STARTPTS)/{speed:.9f}{crop},fps=30,setsar=1,scale=1280:720:out_range=tv,format=yuv420p,setparams=range=limited[v{i}]")
        graph.append(f"[0:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,{atempo(speed)},apad,atrim=duration={c['duration']:.9f}[a{i}]")
        concat.append(f"[v{i}][a{i}]")
        c["timeline_start"] = cursor
        cursor += c["duration"]
    graph.append("".join(concat) + f"concat=n={len(clips)}:v=1:a=1[edited][sfx]")
    last = "edited"
    for i, (name, start, end) in enumerate(overlays, start=2):
        output = f"overlay{i}"
        graph.append(f"[{last}][{i}:v]overlay=0:0:enable='between(t,{start},{end})':eof_action=repeat[{output}]")
        last = output
    graph.append("[sfx]volume=1.15[effects]")
    graph.append("[1:a]volume=0.80[music]")
    graph.append("[effects][music]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.88:level=0,volume=0.75[audio]")
    filter_file = OUT / "edit-filter.txt"
    filter_file.write_text(";\n".join(graph), encoding="utf-8")
    args = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", "-i", str(OUT / "raw-takes.avi"), "-i", str(OUT / "promo-music.wav")]
    for name, _, _ in overlays:
        args.extend(["-loop", "1", "-framerate", "30", "-i", str(OUT / f"{name}.png")])
    args.extend(["-filter_complex_threads", "2", "-filter_complex_script", str(filter_file), "-map", f"[{last}]", "-map", "[audio]", "-t", "30", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(OUT / "melos-promo-draft-v1.mp4")])
    run(args)
    (OUT / "edit-timeline.json").write_text(json.dumps(clips, ensure_ascii=False, indent=2), encoding="utf-8")
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(OUT / "melos-promo-draft-v1.mp4"), "-vf", "fps=1/2,scale=426:240,tile=3x5", "-frames:v", "1", str(OUT / "storyboard-contact.jpg")])
    print("Created", OUT / "melos-promo-draft-v1.mp4", flush=True)


if __name__ == "__main__":
    edit()
