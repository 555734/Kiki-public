#!/usr/bin/env python3
"""Vertical short PV (1080x1920, 30 fps) of MELOS GAME with narration.

Layout of the usual Japanese "game introduction" short: white page, a
two-line hook title at the top (white on a red band / black), the gameplay
in a near-square window (1080x976), one subtitle phrase under it that
changes with the narration, the voice credit at the bottom. The narration
is VOICEVOX (玄野武宏), synthesised from a local engine
(http://127.0.0.1:50021) and cached next to the output.

The pictures are the recorded PV takes (16:9), cropped to the window:
  * the 1-10 rescue cut (`edit_rescue_versions.py` output, made with
    RESCUE_MUSIC_GAIN=0 so its sound is the game's own without music);
  * the 49 s PV (`finale_pv_49cuts.mp4`) and its game sound track
    (`pv_game_sound.wav`) for the other stages.

Usage:
  python3 tools/promotion/make_short_pv.py RESCUE.mp4 PV49.mp4 PV49_SOUND.wav OUT_DIR
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
CROP_W = int(round(720 * W / WIN_H))  # 16:9 source columns that fill it
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
RED = (230, 20, 30)
ENGINE = "http://127.0.0.1:50021"
SPEAKER = 11                          # 玄野武宏 ノーマル
CREDIT = "VOICEVOX:玄野武宏"
TITLE_1 = "落ちる相棒を指で救う"
TITLE_2 = "ふたり協力ゲーム"

# Narration: (text read, subtitle with {red} parts, speed).
LINES = [
    ("落ちていく相棒を、指一本で救う。", "落ちていく相棒を\n{指一本}で救う", 1.18),
    ("これは、ふたりで遊ぶ協力アクション。", "ふたりで遊ぶ\n{協力}アクション", 1.18),
    ("ひとりは走って、跳ぶ。", "ひとりは\n走って、跳ぶ", 1.18),
    ("でも、届かないと谷底へ。", "でも、届かないと\n{谷底}へ…", 1.18),
    ("そこで相棒を呼ぶと、", "そこで\n相棒を呼ぶと", 1.3),
    ("指で足場を描いて、", "{指}で足場を描いて", 1.3),
    ("受け止めてくれる！", "受け止めてくれる！", 1.2),
    ("嵐、火山、列車、巨人。", None, 1.18),
    ("ステージごとに、助け方が変わる。", "ステージごとに\n助け方が{変わる}", 1.18),
    ("離れた友達とも、合言葉ひとつで遊べる。", "離れた友達とも\n{合言葉}ひとつで遊べる", 1.18),
    ("このゲームの名前は、", "このゲームの\n名前は…", 1.15),
    ("メロスゲーム！", "{メロスゲーム}", 1.0),
]
MONTAGE_WORDS = ["嵐", "火山", "列車", "巨人"]


# ------------------------------------------------------------- narration
def _post(path, data=None):
    req = urllib.request.Request(ENGINE + path, data=data, method="POST",
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req).read()


def voice(text, speed, cache):
    """Float mono at SR, and the start time (s) of each accent phrase."""
    key = hashlib.sha1(("%s|%d|%.2f" % (text, SPEAKER, speed)).encode()).hexdigest()[:12]
    wav_p, js_p = os.path.join(cache, key + ".wav"), os.path.join(cache, key + ".json")
    if not os.path.exists(wav_p):
        q = json.loads(_post("/audio_query?" + urllib.parse.urlencode({"text": text, "speaker": SPEAKER})))
        q.update(speedScale=speed, intonationScale=1.25, prePhonemeLength=0.05, postPhonemeLength=0.08)
        if text.startswith("メロスゲーム"):
            q["intonationScale"] = 1.4
        with open(wav_p, "wb") as f:
            f.write(_post("/synthesis?speaker=%d" % SPEAKER, json.dumps(q).encode()))
        t, starts = q["prePhonemeLength"] / speed, []
        for ap in q["accent_phrases"]:
            starts.append(round(t, 3))
            for m in ap["moras"]:
                t += ((m["consonant_length"] or 0) + m["vowel_length"]) / speed
            if ap["pause_mora"]:
                t += ap["pause_mora"]["vowel_length"] / speed
        with open(js_p, "w") as f:
            json.dump({"text": text, "phrases": starts}, f, ensure_ascii=False)
    with wave.open(wav_p) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
    y = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    with open(js_p) as f:
        return y, json.load(f)["phrases"]


# ---------------------------------------------------------------- pictures
def smooth(a, b, t0, t1, t):
    k = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
    return a + (b - a) * k * k * (3 - 2 * k)


def rescue_crop(t):
    """Left edge of the crop (1280-wide source) for the rescue cut at source time t."""
    if t < 1.0:            # run
        return 120
    if t < 3.05:           # camera A: the take-off, then follow the fall down the middle
        return smooth(0, 240, 1.6, 2.5, t)
    if t < 3.52:           # the rewind: back the same way
        return smooth(240, 0, 3.05, 3.5, t)
    if t < 4.85:           # B1: the call card, then the runner sinking right
        return smooth(90, 140, 4.45, 4.85, t)
    if t < 6.37:           # B2: finger, platform, landing (the hand rises right)
        return 280
    return smooth(300, 420, 6.37, 8.3, t)   # C: towards the far bank


def frames(movie, start, dur):
    n = int(round(dur * FPS))
    cmd = ["ffmpeg", "-v", "error", "-ss", "%.3f" % start, "-i", movie, "-t", "%.3f" % (dur + 0.2),
           "-vf", "fps=%d" % FPS, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    size = 1280 * 720 * 3
    last = None
    for _ in range(n):
        buf = p.stdout.read(size)
        if len(buf) == size:
            last = Image.frombytes("RGB", (1280, 720), buf)
        yield last
    p.stdout.close()
    p.wait()


def window(img, x0):
    x0 = int(round(min(max(x0, 0), 1280 - CROP_W)))
    return img.crop((x0, 0, x0 + CROP_W, 720)).resize((W, WIN_H), Image.LANCZOS)


# ------------------------------------------------------------------- text
_fonts = {}


def font(size):
    if size not in _fonts:
        _fonts[size] = ImageFont.truetype(FONT, size, index=0)
    return _fonts[size]


def draw_rich(d, cx, y, line, size, fill=(0, 0, 0)):
    """One line centred on cx; {...} parts in red."""
    parts, red = [], False
    for chunk in line.replace("}", "{").split("{"):
        if chunk:
            parts.append((chunk, red))
        red = not red
    f = font(size)
    total = sum(d.textlength(c, font=f) for c, _ in parts)
    x = cx - total / 2
    for c, is_red in parts:
        d.text((x, y), c, font=f, fill=RED if is_red else fill)
        x += d.textlength(c, font=f)


def page():
    """The static page: white, hook title, credit."""
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f1, f2 = font(84), font(84)
    w1 = d.textlength(TITLE_1, font=f1)
    d.rectangle((W / 2 - w1 / 2 - 22, 250, W / 2 + w1 / 2 + 22, 366), fill=RED)
    d.text((W / 2, 306), TITLE_1, font=f1, fill="white", anchor="mm")
    d.text((W / 2, 420), TITLE_2, font=f2, fill="black", anchor="mm")
    d.text((W - 36, H - 60), CREDIT, font=font(30), fill=(120, 120, 120), anchor="rm")
    return img


def subtitle(d, text, scale=1.0):
    lines = text.split("\n")
    size = int(round((84 if len(lines) > 1 else 92) * scale))
    gap = int(size * 1.25)
    y0 = 1560 - gap * len(lines) / 2
    for i, ln in enumerate(lines):
        draw_rich(d, W / 2, y0 + i * gap, ln, size)


# ------------------------------------------------------------------ edit
def build(rescue, pv49, pv49_sound, out):
    os.makedirs(out, exist_ok=True)
    cache = os.path.join(out, "voice")
    os.makedirs(cache, exist_ok=True)
    vo = [voice(t, s, cache) for t, _, s in LINES]

    # Shots: (movie, source start, duration, crop: number or function of source time, sound)
    shots = []
    t = 0.0

    def shot(movie, s0, dur, crop, name):
        nonlocal t
        shots.append(dict(movie=movie, s0=s0, dur=dur, crop=crop, out0=t, name=name))
        t += dur
        return shots[-1]

    lines_at = {}
    hook = shot(pv49, 5.2, 2.6, 120, "hook: YOU draws steps under the runner")
    lines_at[0] = hook["out0"] + 0.2
    pair = shot(pv49, 2.6, 2.3, 150, "the leap, the call")
    lines_at[1] = pair["out0"] + 0.1
    resc = shot(rescue, 0.0, 7.4, rescue_crop, "rescue: run, fall short, rewind, call, finger, catch")
    r0 = resc["out0"]
    lines_at[2] = r0 + 0.1
    lines_at[3] = r0 + 1.75
    lines_at[4] = r0 + 3.62
    lines_at[5] = r0 + 4.62
    lines_at[6] = r0 + 5.55
    # The montage: one stage per word.
    m0 = t + 0.05
    lines_at[7] = m0
    ph = vo[7][1]
    cuts = [m0 + p - 0.04 for p in ph] + [m0 + len(vo[7][0]) / SR + 0.25]
    cuts[0] = t
    for (s0, crop, name), a, b in zip([(10.3, 0, "storm"), (17.0, 100, "volcano"),
                                       (20.5, 0, "train"), (31.0, 100, "giant")], cuts, cuts[1:]):
        shot(pv49, s0, round(b - a, 3), crop, name)
    bone = shot(pv49, 35.2, 2.4, 150, "bone canyon")
    lines_at[8] = bone["out0"] + 0.1
    meadow = shot(pv49, 7.6, 2.8, 100, "meadow")
    lines_at[9] = meadow["out0"] + 0.1
    end = shot(rescue, 7.4, 4.6, rescue_crop, "end: far bank, title")
    lines_at[10] = end["out0"] + 0.25
    logo_at = lines_at[10] + len(vo[10][0]) / SR + 0.15
    lines_at[11] = logo_at + 0.05
    total = t

    # ---------------------------------------------------------- sound
    n_total = int(round(total * SR))
    game = np.zeros(n_total)
    rescue_aud = R.movie_audio(rescue)
    with wave.open(pv49_sound) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    pv_aud = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    for s in shots:
        src = rescue_aud if s["movie"] == rescue else pv_aud
        a = int(s["s0"] * SR)
        n = int(round(s["dur"] * SR))
        seg = src[a:a + n]
        if s is end:   # the bank, then the title: the game sound fades out
            seg = seg * np.clip(np.linspace(1.5, -0.5, len(seg)), 0, 1)
        fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / (0.01 * SR))
        E.place(game, s["out0"] * SR, seg * fade, 0.6)
    narration = np.zeros(n_total)
    talking = np.zeros(n_total)
    for i, at in lines_at.items():
        E.place(narration, at * SR, vo[i][0], 1.0)
        E.place(talking, at * SR, np.ones(len(vo[i][0])), 1.0)
    # Music bed: the stage's drive theme, looped, ducked under the voice.
    with wave.open(os.path.join(ROOT, "assets", "audio", "music_drive.wav")) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    music = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    music = np.tile(music, int(np.ceil(n_total / len(music))) + 1)[:n_total]
    k = int(0.15 * SR)
    duck = np.convolve(np.clip(talking, 0, 1), np.ones(k) / k, mode="same")
    mgain = 0.30 - 0.17 * np.clip(duck, 0, 1)
    tail = int(1.2 * SR)
    mgain[-tail:] *= np.linspace(1, 0, tail)
    mix = music * mgain + game * (1 - 0.35 * np.clip(duck, 0, 1)) + narration * 1.05
    E.place(mix, logo_at * SR, E.arrive_chime(), 0.9)
    E.place(mix, logo_at * SR, E.impact(), 0.35)
    wav = os.path.join(out, "_short.wav")
    R.write_wav(wav, E.limit(mix, 0.85))

    # ---------------------------------------------------------- picture
    base = page()
    subs = []   # (from, to, text or callable)
    order = sorted(lines_at)
    for j, i in enumerate(order):
        a = lines_at[i] - 0.05
        b = lines_at[order[j + 1]] - 0.05 if j + 1 < len(order) else total
        b = min(b, lines_at[i] + len(vo[i][0]) / SR + 0.6) if i != 11 else total
        subs.append((a, b, i))
    logo = Image.open(os.path.join(ROOT, "assets", "promo", "title_melos_game.png")).convert("RGBA")
    logo_w = 860
    logo = logo.resize((logo_w, int(logo.height * logo_w / logo.width)), Image.LANCZOS)
    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
         "-r", str(FPS), "-i", "-", "-i", wav, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
         "-pix_fmt", "yuv420p", "-af", "loudnorm=I=-14:TP=-1.5:LRA=11", "-ar", "48000", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart",
         os.path.join(out, "melos_short.mp4")], stdin=subprocess.PIPE)
    fi = 0
    edl = []
    for s in shots:
        edl.append({k: (round(v, 3) if isinstance(v, float) else v) for k, v in s.items()
                    if k in ("name", "s0", "dur", "out0")})
        for j, img in enumerate(frames(s["movie"], s["s0"], s["dur"])):
            now = fi / FPS
            st = s["s0"] + j / FPS
            if s is end and st > 8.3:     # past the bank: hold the last game frame
                img = hold
            elif s is end:
                hold = img
            crop = s["crop"](min(st, 8.3)) if callable(s["crop"]) else s["crop"]
            win = window(img, crop)
            if s is end and now > lines_at[10]:
                k = min(1.0, (now - lines_at[10]) / 0.8)
                win = win.filter(ImageFilter.GaussianBlur(10 * k))
                win = Image.blend(win, Image.new("RGB", win.size, (20, 30, 50)), 0.25 * k)
            if now >= logo_at:
                u = now - logo_at
                sc = 1.0 + 0.12 * np.exp(-u * 9) * np.cos(u * 22) if u > 0.12 else 0.4 + 0.72 * (u / 0.12)
                lg = logo.resize((max(1, int(logo.width * sc)), max(1, int(logo.height * sc))), Image.LANCZOS)
                win.paste(lg, (W // 2 - lg.width // 2, WIN_H // 2 - lg.height // 2), lg)
            frame = base.copy()
            frame.paste(win, (0, WIN_Y))
            d = ImageDraw.Draw(frame)
            for a, b, i in subs:
                if a <= now < b:
                    if i == 7:   # the montage: the words come in with their cuts
                        shown = [wd for wd, c in zip(MONTAGE_WORDS, cuts) if now >= c - 0.02]
                        subtitle(d, "、".join(shown))
                    elif i == 11:
                        subtitle(d, LINES[i][1], 1.25)
                    else:
                        subtitle(d, LINES[i][1])
            enc.stdin.write(frame.tobytes())
            fi += 1
    enc.stdin.close()
    enc.wait()
    os.remove(wav)
    with open(os.path.join(out, "short_timeline.json"), "w") as f:
        json.dump({"length_s": round(total, 2), "shots": edl,
                   "narration": [{"at": round(lines_at[i], 2), "len": round(len(vo[i][0]) / SR, 2),
                                  "text": LINES[i][0]} for i in order],
                   "logo_at": round(logo_at, 2)}, f, ensure_ascii=False, indent=1)
    print("length %.2f s, %d frames" % (total, fi))


if __name__ == "__main__":
    build(*sys.argv[1:5])
