#!/usr/bin/env python3
"""Vertical short PV (1080x1920, 30 fps) of MELOS GAME with narration.

The format of the Japanese "このゲームの名前は" shorts: a one-line premise
as the title (white on a red band / black), the gameplay large in the
middle (1080x1350, 70 % of the height), and a dry, matter-of-fact
narration -- the goal, the problem ("しかし"), the answer ("そこで…である"),
it escalates, "とにかく全力で", "ちなみにこのゲームの名前は" -- whose
subtitle changes phrase by phrase (one short phrase at a time, in step
with the voice). The voice is VOICEVOX (玄野武宏), synthesised per phrase
from a local engine (http://127.0.0.1:50021) and cached next to the
output; the voice credit sits at the bottom.

The pictures are recorded for the window, not cropped: the takes are shot
with a 1100x1375 view (`VIEW_W=1100 VIEW_H=1375` in record_take.sh, which
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
WIN_Y, WIN_H = 290, 1350              # the gameplay window (70 % of the height)
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
RED = (230, 20, 30)
ENGINE = "http://127.0.0.1:50021"
SPEAKER = 11                          # 玄野武宏 ノーマル
SPEED = 1.15
GAP = 0.06                            # silence between phrases
CREDIT = "VOICEVOX:玄野武宏"
TITLE_1 = "走って跳ぶだけの相棒を"
TITLE_2 = "死なせないゲーム"

# Source times (s) in the recordings.
MEADOW_RUN = 0.9       # the runner runs, jumps a saw
MEADOW_DRAW = 8.9      # YOU draws steps, the runner climbs them (the take ends at 12.6)
STORM = 4.9            # lightning strikes the tower
VOLCANO = 12.0         # the lava boulder rolls after the runner
GIANT = 23.4           # the giant's arm sweeps in
# In the rescue cut: the run 0-1.0, the leap 1.0, falls short 2.2, failure
# held 2.85, rewind 3.05-3.52, the call 3.6, the stroke 4.9, contact 5.28,
# the jump to the far bank 6.37, its end title 8.35.
RESCUE_END = 8.2


# ------------------------------------------------------------- narration
def _post(path, data=None):
    req = urllib.request.Request(ENGINE + path, data=data, method="POST",
                                 headers={"Content-Type": "application/json"})
    return urllib.request.urlopen(req).read()


def mono(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    return np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)


def voice(text, cache):
    """One phrase as float mono at SR (synthesised once, then cached)."""
    key = hashlib.sha1(("%s|%d|%.2f" % (text, SPEAKER, SPEED)).encode()).hexdigest()[:12]
    wav_p = os.path.join(cache, key + ".wav")
    if not os.path.exists(wav_p):
        q = json.loads(_post("/audio_query?" + urllib.parse.urlencode({"text": text, "speaker": SPEAKER})))
        q.update(speedScale=SPEED, prePhonemeLength=0.03, postPhonemeLength=0.05)
        with open(wav_p, "wb") as f:
            f.write(_post("/synthesis?speaker=%d" % SPEAKER, json.dumps(q).encode()))
    return mono(wav_p)


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
    while d.textlength(TITLE_1, font=f) > W - 80:
        f = font(f.size - 2)
    w1 = d.textlength(TITLE_1, font=f)
    d.rectangle((W / 2 - w1 / 2 - 20, 58, W / 2 + w1 / 2 + 20, 162), fill=RED)
    d.text((W / 2, 108), TITLE_1, font=f, fill="white", anchor="mm")
    d.text((W / 2, 222), TITLE_2, font=font(76), fill="black", anchor="mm")
    d.text((W - 30, H - 26), CREDIT, font=font(24), fill=(130, 130, 130), anchor="rm")
    return img


def subtitle(d, text):
    size = 86
    while d.textlength(text, font=font(size)) > W - 70:
        size -= 2
    d.text((W / 2, WIN_Y + WIN_H + 125), text, font=font(size), fill="black", anchor="mm")


# ------------------------------------------------------------------ edit
def build(rescue, stages, meadow, out):
    os.makedirs(out, exist_ok=True)
    cache = os.path.join(out, "voice")
    os.makedirs(cache, exist_ok=True)

    # The script: (phrase, earliest start in the edit or None = right after
    # the previous one). Starts are tied to the pictures below.
    phrases = []
    clock = [0.0]

    def say(text, at=None):
        """text: the phrase; "|" splits its subtitle into parts (not read)."""
        v = voice(text.replace("|", ""), cache)
        start = max(clock[0] + GAP, at if at is not None else 0.0)
        phrases.append(dict(text=text, at=round(start, 3), v=v))
        clock[0] = start + len(v) / SR
        return phrases[-1]

    shots = []

    def shot(movie, s0, out0, out1, name, hold_after=None):
        shots.append(dict(movie=movie, s0=s0, out0=round(out0, 3), dur=round(out1 - out0, 3), name=name,
                          hold_after=hold_after))

    # The goal -- over the meadow run.
    say("このゲームの目的は", 0.15)
    say("走って跳ぶことしか|できない相棒を")
    say("ゴールまで|送り届けること")
    r0 = clock[0] + 0.15                      # the rescue cut starts here (its source 0.0)
    shot(meadow, MEADOW_RUN, 0.0, r0, "meadow: the run")
    # The problem, the answer -- over the rescue.
    say("しかし相棒は", r0 + 0.1)
    say("無茶なジャンプを|するので")
    say("普通に谷へ落ちていく", r0 + 2.3)    # falls short at 2.2
    say("そこで通話である", r0 + 3.65)       # the call rings at 3.6
    say("急いで足場を描く", r0 + 4.75)       # the stroke 4.9, contact 5.28
    say("相棒はなんとか|向こう岸へ", r0 + 6.35)
    s1 = max(clock[0] + 0.1, r0 + RESCUE_END)
    shot(rescue, 0.0, r0, s1, "rescue: run, leap short, fall, rewind, call, finger, catch, far bank")
    # It escalates -- one stage per phrase, cut on the phrase.
    a = say("その後も雷が落ち", s1 + 0.1)
    b = say("岩が転がり")
    c = say("巨人が暴れるが")
    d = say("とにかく全力で|足場を描き", clock[0] + 0.25)
    shot(stages, STORM, s1, b["at"] - 0.05, "lightning")
    shot(stages, VOLCANO, b["at"] - 0.05, c["at"] - 0.05, "lava boulder")
    shot(stages, GIANT, c["at"] - 0.05, d["at"] - 0.05, "the giant")
    say("相棒をゴールまで|運ぶのだ")
    s2 = clock[0] + 0.3
    shot(meadow, MEADOW_DRAW, d["at"] - 0.05, s2, "meadow: YOU draws steps")
    # The name.
    say("ちなみに", s2 + 0.1)
    say("このゲームの名前は")
    name = say("メロスゲーム", clock[0] + 0.2)
    logo_at = name["at"] - 0.05
    total = name["at"] + len(name["v"]) / SR + 1.8
    shot(rescue, RESCUE_END - 0.3, s2, total, "end: far bank, the name", hold_after=0.25)
    end = shots[-1]
    shots.sort(key=lambda s: s["out0"])

    # ---------------------------------------------------------- sound
    n_total = int(round(total * SR))
    game = np.zeros(n_total)
    sources = {m: R.movie_audio(m) for m in (rescue, stages, meadow)}
    for s in shots:
        src = sources[s["movie"]]
        a0 = int(s["s0"] * SR)
        seg = src[a0:a0 + int(round(s["dur"] * SR))].copy()
        if s is end:
            seg *= np.clip(np.linspace(1.2, -0.5, len(seg)), 0, 1)
        fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / (0.01 * SR))
        E.place(game, s["out0"] * SR, seg * fade, 0.55)
    narration = np.zeros(n_total)
    talking = np.zeros(n_total)
    for p in phrases:
        E.place(narration, p["at"] * SR, p["v"], 1.0)
        E.place(talking, p["at"] * SR, np.ones(len(p["v"])), 1.0)
    music = mono(os.path.join(ROOT, "assets", "audio", "music_drive.wav"))
    music = np.tile(music, int(np.ceil(n_total / len(music))) + 1)[:n_total]
    k = int(0.3 * SR)
    duck = np.clip(np.convolve(np.clip(talking, 0, 1), np.ones(k) / k, mode="same"), 0, 1)
    mgain = 0.22 - 0.12 * duck
    tail = int(1.2 * SR)
    mgain[-tail:] *= np.linspace(1, 0, tail)
    mix = music * mgain + game * (1 - 0.4 * duck) + narration * 1.05
    wav = os.path.join(out, "_short.wav")
    R.write_wav(wav, E.limit(mix, 0.85))

    # ---------------------------------------------------------- picture
    base = page()
    subs = []   # each phrase stays until the next one starts (or a beat after it ends)
    for i, p in enumerate(phrases):
        end_t = p["at"] + len(p["v"]) / SR + 0.5
        if i + 1 < len(phrases):
            end_t = min(end_t, phrases[i + 1]["at"]) if phrases[i + 1]["at"] - p["at"] < 3 else end_t
        else:
            end_t = total
        # A split phrase shows its parts in turn, timed by their length.
        parts = p["text"].split("|")
        dur = len(p["v"]) / SR
        t0 = p["at"] - 0.03
        for k, part in enumerate(parts):
            t1 = end_t if k == len(parts) - 1 else p["at"] + dur * sum(map(len, parts[:k + 1])) / len(p["text"].replace("|", ""))
            subs.append((t0, t1, part))
            t0 = t1
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
        n = int(round((s["out0"] + s["dur"]) * FPS)) - fi
        for j, win in enumerate(frames(s["movie"], s["s0"], n / FPS)):
            now = fi / FPS
            if s["hold_after"] is not None:
                if j / FPS <= s["hold_after"]:
                    hold = win
                win = hold
                if now >= phrases[-2]["at"]:
                    k = min(1.0, (now - phrases[-2]["at"]) / 0.8)
                    win = win.filter(ImageFilter.GaussianBlur(10 * k))
                    win = Image.blend(win, Image.new("RGB", win.size, (20, 30, 50)), 0.3 * k)
                if now >= logo_at:
                    a = min(1.0, (now - logo_at) / 0.2)
                    lg = logo.copy()
                    lg.putalpha(lg.getchannel("A").point(lambda v: int(v * a)))
                    win = win.copy()
                    win.paste(lg, (W // 2 - lg.width // 2, WIN_H // 2 - lg.height // 2), lg)
            frame = base.copy()
            frame.paste(win, (0, WIN_Y))
            dr = ImageDraw.Draw(frame)
            for a, b, text in subs:
                if a <= now < b:
                    subtitle(dr, text)
                    break
            enc.stdin.write(frame.tobytes())
            fi += 1
    enc.stdin.close()
    enc.wait()
    os.remove(wav)
    with open(os.path.join(out, "short_timeline.json"), "w") as f:
        json.dump({"length_s": round(total, 2),
                   "shots": [{"name": s["name"], "source": os.path.basename(s["movie"]), "source_s": s["s0"],
                              "out_s": s["out0"], "dur_s": s["dur"]} for s in shots],
                   "narration": [{"at": p["at"], "len": round(len(p["v"]) / SR, 2), "text": p["text"].replace("|", "")}
                                 for p in phrases],
                   "logo_at": round(logo_at, 2)}, f, ensure_ascii=False, indent=1)
    print("length %.2f s, %d frames" % (total, fi))


if __name__ == "__main__":
    build(*sys.argv[1:5])
