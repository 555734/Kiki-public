#!/usr/bin/env python3
"""Cut the 1-10 PV from the director's recording.

Input: the Movie Maker recording of tools/promotion/capture_finale_pv.tscn
(godot --write-movie ... --fixed-fps 60) and that run's shots_report.json.
Every frame comes from the game; this script only cuts, mixes and checks.

    python3 tools/promotion/render_finale_pv.py [takes.avi] [--storyboard DIR]

Steps
  1. Find the director's one-frame magenta slate in the recording, which maps
     the report's process-frame numbers to movie frames.
  2. Take each beat's on-air frames (its own length; the 49 beats add up to
     2,940 frames), in storyboard order, with the game's own sound for exactly
     those frames, and join them (49 s). Beats recorded back to back are one
     continuous shot in the PV.
  3. Lay the project's own synthesized stage music (assets/audio/
     music_stage.wav, tools/make_audio.py) under the game sound.
  4. Check the soundtrack against the event log: every sound the game played
     on air must show an onset in the cut's audio at that moment.
  5. Write a 7x7 contact sheet (one frame per second, 0-48 s) and, with
     --storyboard, a storyboard-vs-PV comparison sheet per 8 cuts.

Writes next to the report: finale_pv_49cuts.mp4, pv_game_sound.wav,
audio_check.json, contact_sheet.png, compare_XX.png, and pv_frames per cut
back into shots_report.json. Requires ffmpeg, numpy and Pillow.
"""
import json
import os
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PV = os.path.join(ROOT, "build", "promotion", "stage-1-10", "pv")
MUSIC = os.path.join(ROOT, "assets", "audio", "music_stage.wav")
FONT = os.path.join(ROOT, "assets", "fonts", "Nunito-ExtraBold.ttf")
FPS = 60
CUT = 60
SR = 48000


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def find_slate(movie):
    """Index of the first all-magenta frame, read at 32x18."""
    raw = run(["ffmpeg", "-v", "error", "-i", movie, "-vf", "scale=32:18", "-f", "rawvideo",
               "-pix_fmt", "rgb24", "-frames:v", "1200", "-"], capture_output=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 18, 32, 3).astype(int)
    for i, f in enumerate(frames):
        r, g, b = f[..., 0].mean(), f[..., 1].mean(), f[..., 2].mean()
        if r > 200 and b > 200 and g < 60:
            return i
    raise SystemExit("slate frame not found in the first 1200 frames")


def movie_audio(movie):
    """The recording's audio as float mono at SR."""
    raw = run(["ffmpeg", "-v", "error", "-i", movie, "-vn", "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
              capture_output=True).stdout
    return np.frombuffer(raw, "<i2").astype(np.float32) / 32768.0


def write_wav(path, x):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def music_bed(n):
    with wave.open(MUSIC) as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
    # Resample to SR by linear interpolation; loop to length.
    t = np.arange(int(len(x) * SR / rate)) * rate / SR
    x = np.interp(t, np.arange(len(x)), x)
    reps = int(np.ceil(n / len(x)))
    bed = np.tile(x, reps)[:n]
    fade = np.ones(n)
    fade[:int(0.4 * SR)] = np.linspace(0, 1, int(0.4 * SR))
    fade[-int(1.2 * SR):] = np.linspace(1, 0, int(1.2 * SR))
    return bed * fade


SWELL = {"whoosh": 0.32, "rumble": 0.3}


def onset_check(game, events, cut_start_s):
    """For each sound event, look for an energy rise within 60 ms after it."""
    win = int(0.010 * SR)
    env = np.sqrt(np.convolve(game ** 2, np.ones(win) / win, mode="same"))
    out = []
    for ev in events:
        t = ev["pv_time"]
        i = int(t * SR)
        before = env[max(0, i - int(0.08 * SR)):max(1, i - int(0.005 * SR))]
        # Swelling sounds (a whoosh, a rumble) reach their level later.
        after = env[i:i + int(SWELL.get(ev["detail"], 0.06) * SR)]
        base = float(np.median(before)) if len(before) else 0.0
        peak = float(after.max()) if len(after) else 0.0
        # Right after a cut the "before" window belongs to the previous cut,
        # so there only the level itself is judged.
        at_joint = ev.get("at_joint", False)
        heard = peak > 0.01 if at_joint else (peak > 0.004 and peak > base * 1.25)
        out.append({"t": round(t, 3), "sound": ev["detail"], "cut": ev["cut"],
                    "rise_db": round(20 * np.log10((peak + 1e-5) / (base + 1e-5)), 1),
                    "peak_dbfs": round(20 * np.log10(peak + 1e-6), 1),
                    "at_cut_start": bool(at_joint), "heard": bool(heard),
                    # Playing, loud, but on top of a louder sound already
                    # ringing (a land under a boom): no onset to measure.
                    "masked": bool(not heard and peak > 0.1)})
    return out


def label_font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def contact_sheet(mp4, out_path):
    raw = run(["ffmpeg", "-v", "error", "-i", mp4, "-vf", "select='eq(mod(n\\,60)\\,30)',scale=320:180",
               "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, 180, 320, 3)
    sheet = Image.new("RGB", (7 * 320, 7 * 180), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    font = label_font(18)
    for i, f in enumerate(frames[:49]):
        x, y = (i % 7) * 320, (i // 7) * 180
        sheet.paste(Image.fromarray(f), (x, y))
        d.rectangle([x, y, x + 74, y + 24], fill=(0, 0, 0))
        d.text((x + 4, y + 2), "%02d  %ds" % (i + 1, i), font=font, fill=(255, 220, 0))
    sheet.save(out_path)
    return frames


def beat_frames(mp4, shots):
    """The middle frame of every beat, at 320x180."""
    mids = []
    t = 0
    for r in shots:
        n = int(r.get("frames", CUT))
        mids.append(t + n // 2)
        t += n
    expr = "+".join("eq(n\\,%d)" % m for m in mids)
    raw = run(["ffmpeg", "-v", "error", "-i", mp4, "-vf", "select='%s',scale=320:180" % expr,
               "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, 180, 320, 3)


def compare_sheets(frames, storyboard, rows):
    font = label_font(20)
    files = sorted(f for f in os.listdir(storyboard) if f.startswith("Shot_") and f.endswith(".jpg"))
    by_shot = {int(r["shot"]): r for r in rows}
    for page in range(0, 49, 8):
        sheet = Image.new("RGB", (4 * 480, 2 * 540), (0, 0, 0))
        d = ImageDraw.Draw(sheet)
        for j, i in enumerate(range(page, min(page + 8, 49))):
            x, y = (j % 4) * 480, (j // 4) * 540
            sb = Image.open(os.path.join(storyboard, files[i])).convert("RGB").resize((480, 270))
            sheet.paste(sb, (x, y))
            if i < len(frames):
                sheet.paste(Image.fromarray(frames[i]).resize((480, 270)), (x, y + 270))
            rw = by_shot.get(i + 1, {})
            tag = "%02d %s  %s" % (i + 1, rw.get("verdict", "?"), rw.get("name", ""))
            d.rectangle([x, y + 270, x + 480, y + 296], fill=(0, 0, 0))
            d.text((x + 6, y + 272), tag, font=font, fill=(120, 255, 120) if rw.get("verdict") == "PASS" else (255, 90, 90))
        sheet.save(os.path.join(PV, "compare_%02d.png" % (page // 8)))


def main():
    args = sys.argv[1:]
    storyboard = None
    if "--storyboard" in args:
        k = args.index("--storyboard")
        storyboard = args[k + 1]
        del args[k:k + 2]
    movie = args[0] if args else os.path.join(PV, "takes.avi")
    report_path = os.path.join(PV, "shots_report.json")
    report = json.load(open(report_path))
    slate = find_slate(movie)
    offset = slate - int(report["slate_frame"])
    shots = sorted(report["shots"], key=lambda r: r["shot"])
    print("slate at movie frame %d (process frame %d): offset %+d" % (slate, report["slate_frame"], offset))

    audio = movie_audio(movie)
    parts, labels, game = [], [], []
    starts = []          # each beat's start on the PV timeline (frames)
    t = 0
    for i, row in enumerate(shots):
        n = int(row.get("frames", CUT))
        first = int(row["first_frame"]) + offset
        row["pv_frames"] = [first, first + n]
        row["pv_start"] = round(t / FPS, 3)
        starts.append(t)
        t += n
        parts.append("[0:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS[v%d]" % (first, first + n, i))
        labels.append("[v%d]" % i)
        a0 = int(round(first / FPS * SR))
        length = int(round(n / FPS * SR))
        seg = audio[a0:a0 + length]
        game.append(np.pad(seg, (0, length - len(seg))))
    if t != 49 * FPS:
        raise SystemExit("beats add up to %d frames, not %d" % (t, 49 * FPS))
    game = np.concatenate(game)
    # A 4 ms fade at each hard joint so cuts do not click (a joint inside a
    # continuous shot is contiguous in the recording and needs none).
    ramp = int(0.004 * SR)
    for k in range(1, len(shots)):
        if int(shots[k]["first_frame"]) == int(shots[k - 1]["first_frame"]) + int(shots[k - 1].get("frames", CUT)):
            continue
        j = int(round(starts[k] / FPS * SR))
        game[j - ramp:j] *= np.linspace(1, 0, ramp)
        game[j:j + ramp] *= np.linspace(0, 1, ramp)
    # The bed ducks under the game's own sounds (up to -8 dB, 40 ms attack,
    # 250 ms release) so every jump, crash and chime stays on top.
    win = int(0.04 * SR)
    level = np.sqrt(np.convolve(game ** 2, np.ones(win) / win, mode="same"))
    duck = 1.0 - 0.6 * np.clip(level / 0.15, 0.0, 1.0)
    rel = int(0.25 * SR)
    smooth = np.copy(duck)
    k = 1.0 / rel
    for i in range(1, len(smooth)):
        if smooth[i] > smooth[i - 1]:
            smooth[i] = smooth[i - 1] + (smooth[i] - smooth[i - 1]) * k
    bed = music_bed(len(game)) * 0.28 * smooth
    mix = game * 0.95 + bed
    peak = float(np.max(np.abs(mix)))
    if peak > 0.98:
        mix *= 0.98 / peak
    game_wav = os.path.join(PV, "pv_game_sound.wav")
    mix_wav = os.path.join(PV, "pv_mix.wav")
    write_wav(game_wav, game)
    write_wav(mix_wav, mix)

    graph = ";".join(parts) + ";" + "".join(labels) + "concat=n=%d:v=1:a=0[out]" % len(shots)
    out = os.path.join(PV, "finale_pv_49cuts.mp4")
    run(["ffmpeg", "-y", "-v", "error", "-i", movie, "-i", mix_wav, "-filter_complex", graph,
         "-map", "[out]", "-map", "1:a", "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "17",
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-ar", str(SR), "-shortest",
         "-movflags", "+faststart", out])

    # Sound events that fired on air, placed on the PV timeline.
    order = {int(r["shot"]): i for i, r in enumerate(shots)}
    sounds = []
    for ev in report.get("events", []):
        if ev["ev"] == "sound" and int(ev["cut"]) in order and int(ev["cut_frame"]) >= 0:
            ev = dict(ev)
            ev["pv_time"] = starts[order[int(ev["cut"])]] / FPS + int(ev["cut_frame"]) / FPS
            k = order[int(ev["cut"])]
            hard = k == 0 or int(shots[k]["first_frame"]) != int(shots[k - 1]["first_frame"]) + int(shots[k - 1].get("frames", CUT))
            ev["at_joint"] = hard and int(ev["cut_frame"]) < 5
            sounds.append(ev)
    checks = onset_check(game, sounds, None)
    heard = sum(1 for c in checks if c["heard"])
    rms = [round(20 * np.log10(np.sqrt(np.mean(mix[i * SR:(i + 1) * SR] ** 2)) + 1e-6), 1) for i in range(49)]
    masked = sum(1 for c in checks if c["masked"])
    json.dump({"sound_events_on_air": len(checks), "heard": heard, "masked": masked,
               "missing": len(checks) - heard - masked, "events": checks,
               "mix_rms_dbfs_per_second": rms, "music": "assets/audio/music_stage.wav (project-synthesized)"},
              open(os.path.join(PV, "audio_check.json"), "w"), indent=1)
    frames = contact_sheet(out, os.path.join(PV, "contact_sheet.png"))
    if storyboard:
        mids = beat_frames(out, shots)
        compare_sheets(mids, storyboard, shots)
    json.dump(report, open(report_path, "w"), indent=1)
    probe = run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,width,height,r_frame_rate:format=duration",
                 "-of", "compact", out], capture_output=True, text=True).stdout
    print(probe.strip())
    print("wrote", out)
    print("sound events on air: %d, onsets found: %d, masked by a louder sound: %d, missing: %d"
          % (len(checks), heard, masked, len(checks) - heard - masked))
    print("cuts passing in game: %d / %d" % (sum(1 for r in shots if r.get("verdict") == "PASS"), len(shots)))


if __name__ == "__main__":
    main()
