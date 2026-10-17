#!/usr/bin/env python3
"""Vertical short PV (1080x1920, 30 fps) of MELOS GAME with narration.

Layout: a compact two-line title at the top (white on a red band / black),
the gameplay large in the middle (1080x1350, 70 % of the height), one short
subtitle under it, the voice credit at the bottom. The narration is
VOICEVOX (玄野武宏), synthesised from a local engine
(http://127.0.0.1:50021) and cached next to the output.

Order (each part one clear event):
  0-2 s    the hook: the runner falls in, the finger strokes a platform, lands
  2-6 s    the rule again, elsewhere: YOU draws steps, the runner climbs them
  6-8 s    nobody helps: the leap falls short, into the gorge
  8-14 s   three dangers: lightning, the lava boulder, the giant
  14-17 s  the last one: the closing jaws
  17-20 s  the name

The pictures are recorded for the window, not cropped: the takes are shot
with a 1100x1375 view (`VIEW_W=1100 VIEW_H=1375 record_take.sh ...`, which
overrides the project's viewport size for the recording only).

  * RESCUE.mp4: the 1-10 rescue cut from those takes
    (`PV_SIZE=1100x1375 RESCUE_MUSIC_GAIN=0 edit_rescue_versions.py`, so
    its sound is the game's own without music);
  * STAGES.avi: a recording of the takes storm,volcano,giant,bone;
  * MEADOW.avi: the take title recorded with PV_NO_TITLE=1 (the meadow run
    without the in-game MELOS GAME title).

Usage:
  python3 tools/promotion/make_short_pv.py RESCUE.mp4 STAGES.avi MEADOW.avi OUT_DIR
"""
import hashlib
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edit_rescue_versions as E  # noqa: E402
import render_finale_pv as R  # noqa: E402

ROOT = E.ROOT
SR = R.SR
FPS = 30
W, H = 1080, 1920
WIN_Y, WIN_H = 290, 1350              # the gameplay window
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
RED = (230, 20, 30)
ENGINE = "http://127.0.0.1:50021"
SPEAKER = 11                          # 玄野武宏 ノーマル
SPEED = 1.15
CREDIT = "VOICEVOX:玄野武宏"
TITLE_1 = "落ちる相棒を足場で"
TITLE_2 = "助けるゲーム"

# Source times (s) in the recordings.
HOOK = 4.86            # rescue cut: the runner falls into the close shot, the finger strokes, lands (contact 5.28)
FAIL = 1.0             # rescue cut: the leap falls short (failure held 2.85, rewind 3.05)
MEADOW_DRAW = 8.9      # meadow: YOU draws steps, the runner climbs them (the take ends at 12.6)
STORM = 4.6            # stages: the lightning strike
VOLCANO = 12.0          # stages: the lava boulder rolls after the runner
GIANT = 23.4            # stages: the giant's sweep
JAWS = 36.0             # stages: the jaws close behind the runner


# ------------------------------------------------------------- narration
def _post(path, data=None):
    req = urllib.request.Request(ENGINE + path, data=data, method="POST",
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req).read()


def voice(text, cache):
    """The line as float mono at SR."""
    key = hashlib.sha1(("%s|%d|%.2f" % (text, SPEAKER, SPEED)).encode()).hexdigest()[:12]
    wav_p = os.path.join(cache, key + ".wav")
    if not os.path.exists(wav_p):
        q = json.loads(_post("/audio_query?" + urllib.parse.urlencode({"text": text, "speaker": SPEAKER})))
        q.update(speedScale=SPEED, prePhonemeLength=0.05, postPhonemeLength=0.08)
        with open(wav_p, "wb") as f:
            f.write(_post("/synthesis?speaker=%d" % SPEAKER, json.dumps(q).encode()))
    return mono(wav_p)


def mono(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    return np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)


# ---------------------------------------------------------------- pictures
def frames(movie, start, dur):
    """dur s of the movie from start, at FPS, as window-sized images."""
    n = int(round(dur * FPS))
    cmd = ["ffmpeg", "-v", "error", "-ss", "%.3f" % start, "-i", movie, "-t", "%.3f" % (dur + 0.2),
           "-vf", "fps=%d,scale=%d:%d:flags=lanczos" % (FPS, W, WIN_H), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    size = W * WIN_H * 3
    last = None
    for _ in range(n):
        buf = p.stdout.read(size)
        if len(buf) == size:
            last = Image.frombytes("RGB", (W, WIN_H), buf)
        yield last
    p.stdout.close()
    p.wait()


_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size, index=0)
    return _fonts[size]


def page():
    """The static page: white, title, credit."""
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f = font(76)
    w1 = d.textlength(TITLE_1, font=f)
    d.rectangle((W / 2 - w1 / 2 - 20, 58, W / 2 + w1 / 2 + 20, 162), fill=RED)
    d.text((W / 2, 108), TITLE_1, font=f, fill="white", anchor="mm")
    d.text((W / 2, 222), TITLE_2, font=f, fill="black", anchor="mm")
    d.text((W - 30, H - 34), CREDIT, font=font(26), fill=(130, 130, 130), anchor="rm")
    return img


def subtitle(d, text, pop):
    """One short line under the picture; it pops in (pop 0..1)."""
    size = int(104 * (0.85 + 0.15 * min(1.0, pop)))
    while d.textlength(text, font=font(size)) > W - 60:
        size -= 2
    d.text((W / 2, WIN_Y + WIN_H + 135), text, font=font(size), fill="black", anchor="mm")


# ------------------------------------------------------------------ edit
def build(rescue, stages, meadow, out):
    os.makedirs(out, exist_ok=True)
    cache = os.path.join(out, "voice")
    os.makedirs(cache, exist_ok=True)

    shots = []
    t = 0.0

    def shot(movie, s0, dur, name, hold_after=None):
        nonlocal t
        shots.append(dict(movie=movie, s0=s0, dur=dur, out0=round(t, 3), name=name, hold_after=hold_after))
        t += dur
        return shots[-1]

    hook = shot(rescue, HOOK, 2.0, "hook: the finger, the platform, the landing")
    draw = shot(meadow, MEADOW_DRAW, 3.6, "meadow: YOU draws steps")
    fail = shot(rescue, FAIL, 2.05, "nobody helps: the leap falls short")
    storm = shot(stages, STORM, 1.6, "lightning")
    volcano = shot(stages, VOLCANO, 1.9, "lava boulder")
    giant = shot(stages, GIANT, 2.3, "the giant")
    jaws = shot(stages, JAWS, 3.4, "the jaws")
    end = shot(stages, JAWS + 3.4, 3.4, "end: the name", hold_after=0.3)
    total = t

    # Narration: (text, out time).
    lines = [
        ("落ちる相棒を、足場で助けるゲーム。", hook["out0"] + 0.1),
        ("ひとりが走って、もうひとりが、足場を描く。", draw["out0"] + 0.5),
        ("間に合わないと、落ちてしまう。", fail["out0"] + 0.45),
        ("雷。", storm["out0"] + 0.25),
        ("溶岩の岩。", volcano["out0"] + 0.2),
        ("巨人。", giant["out0"] + 0.2),
        ("このゲームの名前は、", end["out0"] + 0.15),
    ]
    vo = [voice(text, cache) for text, _ in lines]
    name_v = voice("メロスゲーム。", cache)
    logo_at = lines[-1][1] + len(vo[-1]) / SR + 0.15
    lines.append(("メロスゲーム。", logo_at + 0.1))
    vo.append(name_v)
    # Subtitles: (from, to, text) -- a reaction, not a description.
    subs = [
        (0.0, 0.42, "落ちる！"),           # contact at 0.42
        (0.42, hook["out0"] + 2.0, "足場で助ける"),
        (draw["out0"], draw["out0"] + 3.6, "ふたりで協力"),
        (fail["out0"] + 1.0, fail["out0"] + 2.05, "届かない…"),
        (storm["out0"], storm["out0"] + 1.6, "雷！"),
        (volcano["out0"], volcano["out0"] + 1.9, "岩が来る！"),
        (giant["out0"], giant["out0"] + 2.3, "巨人！？"),
        (jaws["out0"] + 0.3, jaws["out0"] + 3.4, "間に合え！"),
        (logo_at, total, "メロスゲーム"),
    ]

    # ---------------------------------------------------------- sound
    n_total = int(round(total * SR))
    game = np.zeros(n_total)
    sources = {m: R.movie_audio(m) for m in (rescue, stages, meadow)}
    for s in shots:
        src = sources[s["movie"]]
        a = int(s["s0"] * SR)
        seg = src[a:a + int(round(s["dur"] * SR))].copy()
        if s is end:
            seg *= np.clip(np.linspace(1.5, -0.5, len(seg)), 0, 1)
        fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / (0.01 * SR))
        E.place(game, s["out0"] * SR, seg * fade, 0.6)
    narration = np.zeros(n_total)
    talking = np.zeros(n_total)
    for (_, at), v in zip(lines, vo):
        E.place(narration, at * SR, v, 1.0)
        E.place(talking, at * SR, np.ones(len(v)), 1.0)
    music = mono(os.path.join(ROOT, "assets", "audio", "music_drive.wav"))
    music = np.tile(music, int(np.ceil(n_total / len(music))) + 1)[:n_total]
    k = int(0.15 * SR)
    duck = np.clip(np.convolve(np.clip(talking, 0, 1), np.ones(k) / k, mode="same"), 0, 1)
    mgain = 0.26 - 0.15 * duck
    tail = int(1.2 * SR)
    mgain[-tail:] *= np.linspace(1, 0, tail)
    mix = music * mgain + game * (1 - 0.35 * duck) + narration * 1.05
    E.place(mix, logo_at * SR, E.arrive_chime(), 0.7)
    wav = os.path.join(out, "_short.wav")
    R.write_wav(wav, E.limit(mix, 0.85))

    # ---------------------------------------------------------- picture
    base = page()
    logo = Image.open(os.path.join(ROOT, "assets", "promo", "title_melos_game.png")).convert("RGBA")
    logo = logo.resize((860, int(logo.height * 860 / logo.width)), Image.LANCZOS)
    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
         "-r", str(FPS), "-i", "-", "-i", wav, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
         "-pix_fmt", "yuv420p", "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-ar", "48000", "-c:a", "aac",
         "-b:a", "192k", "-shortest", "-movflags", "+faststart", os.path.join(out, "melos_short.mp4")],
        stdin=subprocess.PIPE)
    fi = 0
    for s in shots:
        hold = None
        for j, win in enumerate(frames(s["movie"], s["s0"], s["dur"])):
            now = fi / FPS
            if s["hold_after"] is not None:
                if j / FPS <= s["hold_after"]:
                    hold = win
                win = hold
                k = min(1.0, max(0.0, (now - s["out0"] - s["hold_after"]) / 0.8))
                win = win.filter(ImageFilter.GaussianBlur(10 * k))
                win = Image.blend(win, Image.new("RGB", win.size, (20, 30, 50)), 0.3 * k)
                if now >= logo_at:
                    a = min(1.0, (now - logo_at) / 0.25)
                    lg = logo.copy()
                    lg.putalpha(lg.getchannel("A").point(lambda v: int(v * a)))
                    win = win.copy()
                    win.paste(lg, (W // 2 - lg.width // 2, WIN_H // 2 - lg.height // 2), lg)
            frame = base.copy()
            frame.paste(win, (0, WIN_Y))
            d = ImageDraw.Draw(frame)
            for a, b, text in subs:
                if a <= now < b:
                    subtitle(d, text, (now - a) / 0.12)
            enc.stdin.write(frame.tobytes())
            fi += 1
    enc.stdin.close()
    enc.wait()
    os.remove(wav)
    with open(os.path.join(out, "short_timeline.json"), "w") as f:
        json.dump({"length_s": round(total, 2),
                   "shots": [{"name": s["name"], "source": os.path.basename(s["movie"]), "source_s": s["s0"],
                              "out_s": s["out0"], "dur_s": s["dur"]} for s in shots],
                   "narration": [{"at": round(a, 2), "len": round(len(v) / SR, 2), "text": text}
                                 for (text, a), v in zip(lines, vo)],
                   "subtitles": [{"from": round(a, 2), "to": round(b, 2), "text": x} for a, b, x in subs],
                   "logo_at": round(logo_at, 2)}, f, ensure_ascii=False, indent=1)
    print("length %.2f s, %d frames" % (total, fi))


if __name__ == "__main__":
    build(*sys.argv[1:5])
