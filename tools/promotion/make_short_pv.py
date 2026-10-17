#!/usr/bin/env python3
"""Vertical short PV (1080x1920, 30 fps) of MELOS GAME with narration.

Layout of the usual Japanese "game introduction" short: white page, a
two-line title at the top (white on a red band / black), the gameplay in a
near-square window (1080x976), one subtitle phrase under it that changes
with the narration, the voice credit at the bottom. The narration is
VOICEVOX (玄野武宏), synthesised from a local engine
(http://127.0.0.1:50021) and cached next to the output.

The pictures are recorded for the window, not cropped: the takes are shot
with a taller view (1280x1156, `VIEW_H=1156` in the take script, which
overrides the project's viewport height for the recording only), so every
shot keeps its full width and gains picture above and below.

  * RESCUE.mp4: the 1-10 rescue cut from those takes
    (`PV_SIZE=1280x1156 RESCUE_MUSIC_GAIN=0 edit_rescue_versions.py`, so
    its sound is the game's own without music);
  * STAGES.avi: a recording of the takes storm,volcano,rail,giant,bone;
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
WIN_Y, WIN_H = 472, 976               # the gameplay window
SRC_W, SRC_H = 1280, 1156             # the recordings
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
RED = (230, 20, 30)
ENGINE = "http://127.0.0.1:50021"
SPEAKER = 11                          # 玄野武宏 ノーマル
SPEED = 1.1
CREDIT = "VOICEVOX:玄野武宏"
TITLE_1 = "落ちる相棒を足場で"
TITLE_2 = "助けるゲーム"

# Narration: (text read, subtitle). Plain description of what happens on
# screen, no claims.
LINES = [
    ("ふたりで遊ぶアクションゲームです。", "ふたりで遊ぶ\nアクションゲーム"),
    ("ひとりが走って、もうひとりが、画面に足場を描きます。", "ひとりが走って\nもうひとりが足場を描く"),
    ("ジャンプが届かないと、", "ジャンプが届かないと"),
    ("谷に落ちてしまいますが、", "谷に落ちてしまうけど"),
    ("通話で呼ばれたら、", "通話で呼ばれたら"),
    ("足場を描いて、", "足場を描いて"),
    ("受け止めます。", "受け止める"),
    ("そのまま、向こう岸へ。", "そのまま向こう岸へ"),
    ("嵐、火山、列車、巨人など、", None),
    ("ステージはいろいろあります。", "ステージはいろいろ"),
    ("離れた友達とは、6文字の合言葉でつながります。", "離れた友達とは\n6文字の合言葉でつながる"),
    ("このゲームの名前は、", "このゲームの名前は"),
    ("メロスゲーム。", "メロスゲーム"),
]
MONTAGE_WORDS = ["嵐", "火山", "列車", "巨人"]

# Source times (s) in the recordings.
MEADOW_RUN = 0.9       # the runner runs, jumps a saw
MEADOW_DRAW = 8.9      # YOU draws steps, the runner climbs them (the take ends at 12.6)
STAGES = {
    "storm": 5.1,      # lightning on the bridge
    "volcano": 11.9,   # the rolling boulder
    "rail": 31.0,      # jumping between train roofs
    "giant": 37.2,     # the giant stands up
    "bone": 45.3,      # the bone bridge
    "friends": 25.6,   # running along the train (under the 合言葉 line)
}


# ------------------------------------------------------------- narration
def _post(path, data=None):
    req = urllib.request.Request(ENGINE + path, data=data, method="POST",
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req).read()


def voice(text, cache):
    """Float mono at SR, and the start time (s) of each accent phrase."""
    key = hashlib.sha1(("%s|%d|%.2f" % (text, SPEAKER, SPEED)).encode()).hexdigest()[:12]
    wav_p, js_p = os.path.join(cache, key + ".wav"), os.path.join(cache, key + ".json")
    if not os.path.exists(wav_p):
        q = json.loads(_post("/audio_query?" + urllib.parse.urlencode({"text": text, "speaker": SPEAKER})))
        q.update(speedScale=SPEED, prePhonemeLength=0.05, postPhonemeLength=0.08)
        with open(wav_p, "wb") as f:
            f.write(_post("/synthesis?speaker=%d" % SPEAKER, json.dumps(q).encode()))
        t, starts = q["prePhonemeLength"] / SPEED, []
        for ap in q["accent_phrases"]:
            starts.append(round(t, 3))
            for m in ap["moras"]:
                t += ((m["consonant_length"] or 0) + m["vowel_length"]) / SPEED
            if ap["pause_mora"]:
                t += ap["pause_mora"]["vowel_length"] / SPEED
        with open(js_p, "w") as f:
            json.dump({"text": text, "phrases": starts}, f, ensure_ascii=False)
    with wave.open(wav_p) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
    y = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    with open(js_p) as f:
        return y, json.load(f)["phrases"]


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


# ------------------------------------------------------------------- text
_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size, index=0)
    return _fonts[size]


def page():
    """The static page: white, title, credit."""
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f = font(84)
    w1 = d.textlength(TITLE_1, font=f)
    d.rectangle((W / 2 - w1 / 2 - 22, 250, W / 2 + w1 / 2 + 22, 366), fill=RED)
    d.text((W / 2, 306), TITLE_1, font=f, fill="white", anchor="mm")
    d.text((W / 2, 420), TITLE_2, font=f, fill="black", anchor="mm")
    d.text((W - 36, H - 60), CREDIT, font=font(30), fill=(120, 120, 120), anchor="rm")
    return img


def subtitle(d, text):
    lines = text.split("\n")
    size = 76 if len(lines) > 1 else 84
    while max(d.textlength(ln, font=font(size)) for ln in lines) > W - 80:
        size -= 2
    gap = int(size * 1.3)
    y0 = 1580 - gap * (len(lines) - 1) / 2
    for i, ln in enumerate(lines):
        d.text((W / 2, y0 + i * gap), ln, font=font(size), fill="black", anchor="mm")


def mono(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    return np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)


# ------------------------------------------------------------------ edit
def build(rescue, stages, meadow, out):
    os.makedirs(out, exist_ok=True)
    cache = os.path.join(out, "voice")
    os.makedirs(cache, exist_ok=True)
    vo = [voice(t, cache) for t, _ in LINES]
    vlen = [len(v[0]) / SR for v in vo]

    shots = []
    t = 0.0

    def shot(movie, s0, dur, name):
        nonlocal t
        shots.append(dict(movie=movie, s0=s0, dur=round(dur, 3), out0=t, name=name))
        t += round(dur, 3)
        return shots[-1]

    at = {}
    # The meadow: the runner runs; the guardian draws steps.
    s = shot(meadow, MEADOW_RUN, vlen[0] + 0.45, "meadow: the run")
    at[0] = s["out0"] + 0.2
    s = shot(meadow, MEADOW_DRAW, 3.6, "meadow: YOU draws steps")
    at[1] = s["out0"] + 0.1
    # The rescue (source times in the rescue cut).
    s = shot(rescue, 0.5, 7.7, "rescue: run, leap short, fall, rewind, call, finger, catch, far bank")
    r0 = s["out0"] - 0.5   # + source time
    at[2] = r0 + 1.0     # take-off
    at[3] = r0 + 2.25    # falling short
    at[4] = r0 + 3.6     # the call rings
    at[5] = r0 + 4.65    # the finger dives, the stroke
    at[6] = r0 + 5.68    # after the contact (5.28)
    at[7] = r0 + 6.5     # the jump to the far bank
    # The stages: one word, one cut.
    m0 = t + 0.05
    at[8] = m0
    cuts = [t] + [m0 + p - 0.04 for p in vo[8][1][1:]] + [m0 + vlen[8] + 0.2]
    for key, a, b in zip(["storm", "volcano", "rail", "giant"], cuts, cuts[1:]):
        shot(stages, STAGES[key], b - a, key)
    s = shot(stages, STAGES["bone"], vlen[9] + 0.6, "bone canyon")
    at[9] = s["out0"] + 0.1
    s = shot(stages, STAGES["friends"], vlen[10] + 0.6, "train")
    at[10] = s["out0"] + 0.15
    # The end: the far bank, softened; the logo comes in on the name.
    end = shot(rescue, 8.2, 4.0, "end: far bank, title")
    at[11] = end["out0"] + 0.2
    logo_at = at[11] + vlen[11] + 0.15
    at[12] = logo_at + 0.1
    total = t
    hold_from = 8.33  # source time in the rescue cut where its end title would begin

    # ---------------------------------------------------------- sound
    n_total = int(round(total * SR))
    game = np.zeros(n_total)
    sources = {m: R.movie_audio(m) for m in (rescue, stages, meadow)}
    for s in shots:
        src = sources[s["movie"]]
        a = int(s["s0"] * SR)
        seg = src[a:a + int(round(s["dur"] * SR))]
        if s is end:
            seg = seg * np.clip(np.linspace(1.5, -0.5, len(seg)), 0, 1)
        fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / (0.01 * SR))
        E.place(game, s["out0"] * SR, seg * fade, 0.55)
    narration = np.zeros(n_total)
    talking = np.zeros(n_total)
    for i, a in at.items():
        E.place(narration, a * SR, vo[i][0], 1.0)
        E.place(talking, a * SR, np.ones(len(vo[i][0])), 1.0)
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
    order = sorted(at)
    subs = []
    for j, i in enumerate(order):
        a = at[i] - 0.05
        b = at[order[j + 1]] - 0.05 if j + 1 < len(order) else total
        if i != order[-1]:
            b = min(b, at[i] + vlen[i] + 0.6)
        subs.append((a, b, i))
    logo = Image.open(os.path.join(ROOT, "assets", "promo", "title_melos_game.png")).convert("RGBA")
    logo = logo.resize((820, int(logo.height * 820 / logo.width)), Image.LANCZOS)
    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
         "-r", str(FPS), "-i", "-", "-i", wav, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
         "-pix_fmt", "yuv420p", "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-ar", "48000", "-c:a", "aac",
         "-b:a", "192k", "-shortest", "-movflags", "+faststart", os.path.join(out, "melos_short.mp4")],
        stdin=subprocess.PIPE)
    fi = 0
    hold = None
    for s in shots:
        for j, win in enumerate(frames(s["movie"], s["s0"], s["dur"])):
            now = fi / FPS
            if s is end:
                if s["s0"] + j / FPS < hold_from:
                    hold = win
                win = hold
                if now > at[11]:
                    k = min(1.0, (now - at[11]) / 0.8)
                    win = win.filter(ImageFilter.GaussianBlur(10 * k))
                    win = Image.blend(win, Image.new("RGB", win.size, (20, 30, 50)), 0.25 * k)
                if now >= logo_at:
                    a = min(1.0, (now - logo_at) / 0.25)
                    lg = logo.copy()
                    lg.putalpha(lg.getchannel("A").point(lambda v: int(v * a)))
                    win = win.copy()
                    win.paste(lg, (W // 2 - lg.width // 2, WIN_H // 2 - lg.height // 2), lg)
            frame = base.copy()
            frame.paste(win, (0, WIN_Y))
            d = ImageDraw.Draw(frame)
            for a, b, i in subs:
                if a <= now < b:
                    if i == 8:   # the stages: the words come in with their cuts
                        subtitle(d, "、".join(wd for wd, c in zip(MONTAGE_WORDS, cuts) if now >= c - 0.02))
                    else:
                        subtitle(d, LINES[i][1])
            enc.stdin.write(frame.tobytes())
            fi += 1
    enc.stdin.close()
    enc.wait()
    os.remove(wav)
    with open(os.path.join(out, "short_timeline.json"), "w") as f:
        json.dump({"length_s": round(total, 2),
                   "shots": [{"name": s["name"], "source": os.path.basename(s["movie"]), "source_s": s["s0"],
                              "out_s": round(s["out0"], 2), "dur_s": s["dur"]} for s in shots],
                   "narration": [{"at": round(at[i], 2), "len": round(vlen[i], 2), "text": LINES[i][0]} for i in order],
                   "logo_at": round(logo_at, 2)}, f, ensure_ascii=False, indent=1)
    print("length %.2f s, %d frames" % (total, fi))


if __name__ == "__main__":
    build(*sys.argv[1:5])
