#!/usr/bin/env python3
"""Cut the two versions of the PV's opening rescue from two recordings.

    python3 tools/promotion/edit_rescue_versions.py NOHELP_DIR HELP_DIR OUT_DIR

Each *_DIR holds a director recording of take_opening (capture_finale_pv.gd)
-- takes.avi + shots_report.json -- one shot with PV_RESCUE=nohelp (nobody
answers: the runner falls) and one without (the call, the platforms). Both
takes run the same inputs and camera up to the top of the leap, the
"branch" event, so their frames are identical up to there (checked here).

* rescue_direct.mp4  (Version B): the help take, from just before the hop
  over the enemy to the runner running on across the far bank.
* rescue_rewind.mp4  (Version A): the nohelp take from the same start
  through the fall into the gorge ("fail_end"), then those same frames
  played backwards (the fall and the camera retrace) to the branch frame,
  then the help take from the very next frame.

Sound: the game's own sounds from each recording; the stage music
(assets/audio/music_stage.wav, the game's own) as a low bed that runs
backwards with the picture during the rewind; and a few sounds made here
(numpy): wind on the fall, a failure note, the rewind whirr, a lift under
the platform's build, an arrival chime. Nothing licensed from outside.

Writes 1280x720 60 fps H.264/AAC, a contact sheet per second for each, and
timeline.json (segment boundaries in each output and the source frames).
"""
import json
import os
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_finale_pv as R  # noqa: E402

FPS = 60
SR = R.SR
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PRE_HOP = 24        # frames before the hop over the enemy where both clips start
TAIL = 4            # frames after "clip_end"
REWIND_SPEED = 1.3  # how much faster than the fall the rewind plays


# ------------------------------------------------------------------ inputs
def load(d):
    rep = json.load(open(os.path.join(d, "shots_report.json")))
    movie = os.path.join(d, "takes.avi")
    off = R.find_slate(movie) - int(rep["slate_frame"])
    ev = {}
    for e in rep["events"]:
        ev.setdefault(e["ev"], int(e["frame"]) + off)
    return {"movie": movie, "events": ev, "all": rep["events"], "off": off, "audio": R.movie_audio(movie)}


def frame_rgb(movie, n):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", movie, "-vf", "select=eq(n\\,%d)" % n, "-vsync", "0",
                          "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(720, 1280, 3)


# ------------------------------------------------------------------ sounds
def t(n):
    return np.arange(n) / SR


def envelope(n, a=0.005, d=0.3):
    x = t(n)
    return np.clip(x / a, 0, 1) * np.exp(-x / d)


def noise(n, seed):
    return np.random.default_rng(seed).uniform(-1, 1, n)


def lowpass(x, cut):
    k = np.exp(-2 * np.pi * cut / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - k) * x[i] + k * acc
        y[i] = acc
    return y


def glide(f0, f1, n):
    return f0 * (f1 / f0) ** np.linspace(0, 1, n)


def osc(freq, n):
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def wind(n):
    """Rising air rushing past a fall."""
    x = lowpass(noise(n, 3), 900.0) * 3.0
    return x * np.clip(t(n) / 0.35, 0, 1) * np.clip((t(n)[-1] - t(n)) / 0.15, 0, 1) * (0.5 + 0.5 * t(n) / t(n)[-1])


def fail_note(n=int(0.55 * SR)):
    """A short falling two-note: it did not work."""
    a = osc(glide(392.0, 330.0, n // 2), n // 2) * envelope(n // 2, 0.004, 0.18)
    b = osc(glide(294.0, 220.0, n - n // 2), n - n // 2) * envelope(n - n // 2, 0.004, 0.3)
    sq = np.sign(np.concatenate([a, b])) * 0.25 + np.concatenate([a, b]) * 0.75
    return sq * 0.5


def rewind_whirr(n):
    """Tape spooling backwards: a pitch rising then easing, with flutter."""
    f = glide(180.0, 900.0, n) * (1 + 0.06 * np.sin(2 * np.pi * 22 * t(n)))
    tone = osc(f, n) * 0.35 + osc(f * 2.01, n) * 0.15
    hiss = lowpass(noise(n, 9), 3000.0) * 0.5
    e = np.clip(t(n) / 0.05, 0, 1) * np.clip((t(n)[-1] - t(n)) / 0.12, 0, 1)
    return (tone + hiss) * e * 0.6


def build_lift(n=int(0.5 * SR)):
    """A soft rising sparkle under the platform's blocks building."""
    out = np.zeros(n)
    for i, f in enumerate([660, 880, 990, 1320, 1760]):
        s = int(i * n / 6)
        m = n - s
        out[s:] += osc(np.full(m, f), m) * envelope(m, 0.003, 0.08) * 0.25
    return out


def arrive_chime(n=int(0.8 * SR)):
    out = np.zeros(n)
    for i, f in enumerate([784, 988, 1175, 1568]):
        s = int(i * 0.07 * SR)
        m = n - s
        out[s:] += osc(np.full(m, f), m) * envelope(m, 0.003, 0.25) * 0.22
    return out


def place(buf, at, x, gain=1.0):
    at = int(at)
    if at >= len(buf):
        return
    x = x[: len(buf) - at]
    buf[at:at + len(x)] += x * gain


def music_bed():
    with wave.open(os.path.join(ROOT, "assets", "audio", "music_stage.wav")) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(axis=1)
    # Resample to SR and loop a few times.
    idx = np.arange(int(len(x) * SR / sr)) * sr / SR
    y = np.interp(idx, np.arange(len(x)), x)
    return np.tile(y, 4)


# ------------------------------------------------------------------- video
REWIND_ICON = None


def rewind_icon(path):
    im = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Two left-pointing triangles, top left: the universal rewind mark.
    for k in range(2):
        x = 70 + k * 46
        d.polygon([(x + 44, 48), (x + 44, 112), (x, 80)], fill=(255, 255, 255, 230))
    # Faint horizontal tape lines.
    for y in range(0, 720, 6):
        d.line([(0, y), (1280, y)], fill=(255, 255, 255, 14))
    im.save(path)


def segments_to_mp4(segs, out, wav):
    """segs: list of (movie, first_frame, n_frames, mode) mode in
    'fwd' | ('rev', speed). One ffmpeg filter graph, then the audio."""
    inputs = []
    parts = []
    labels = []
    movies = []
    for s in segs:
        if s[0] not in movies:
            movies.append(s[0])
    for m in movies:
        inputs += ["-i", m]
    icon = os.path.join(os.path.dirname(out), "_rewind_icon.png")
    rewind_icon(icon)
    inputs += ["-i", icon]
    icon_idx = len(movies)
    for i, (movie, f0, n, mode) in enumerate(segs):
        src = movies.index(movie)
        if mode == "fwd":
            parts.append("[%d:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS[v%d]" % (src, f0, f0 + n, i))
        else:
            speed = mode[1]
            parts.append(("[%d:v]trim=start_frame=%d:end_frame=%d,setpts=PTS-STARTPTS,reverse,setpts=PTS/%.4f,fps=%d,"
                          "eq=saturation=0.55:contrast=1.08,colorbalance=bs=0.12:bm=0.06,rgbashift=rh=-5:bh=5,"
                          "noise=alls=10:allf=t[r%d];[r%d][%d:v]overlay=0:0[v%d]")
                         % (src, f0, f0 + n, speed, FPS, i, i, icon_idx, i))
        labels.append("[v%d]" % i)
    graph = ";".join(parts) + ";" + "".join(labels) + "concat=n=%d:v=1:a=0,fps=%d,format=yuv420p[out]" % (len(segs), FPS)
    R.run(["ffmpeg", "-y", "-v", "error"] + inputs + ["-i", wav, "-filter_complex", graph, "-map", "[out]", "-map",
           "%d:a" % (len(movies) + 1), "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "17",
           "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", out])
    os.remove(icon)


def contact_sheet(mp4, out, notes):
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", mp4],
                               capture_output=True, text=True).stdout)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    times = [s + 0.5 for s in range(int(np.ceil(dur)))]
    times = [min(x, dur - 0.05) for x in times]
    tiles = []
    for x in times:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", "%.3f" % x, "-i", mp4, "-frames:v", "1", "-vf", "scale=426:240",
                              "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
        im = Image.fromarray(np.frombuffer(raw, np.uint8).reshape(240, 426, 3).copy())
        d = ImageDraw.Draw(im)
        note = ""
        for (a, b, text) in notes:
            if a <= x < b:
                note = text
        d.rectangle([0, 0, 426, 20], fill=(0, 0, 0))
        d.text((4, 2), "%d-%ds  %s" % (int(x), int(x) + 1, note), fill=(255, 255, 0), font=font)
        tiles.append(im)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 426, rows * 240), (20, 20, 24))
    for i, im in enumerate(tiles):
        sheet.paste(im, ((i % cols) * 426, (i // cols) * 240))
    sheet.save(out, quality=88)


def secs(frames):
    return round(frames / FPS, 2)


def main():
    nh, hp, out = load(sys.argv[1]), load(sys.argv[2]), sys.argv[3]
    os.makedirs(out, exist_ok=True)
    E, H = nh["events"], hp["events"]
    # Both clips start the same number of frames before the hop.
    a0, h0 = E["hop_enemy"] - PRE_HOP, H["hop_enemy"] - PRE_HOP
    # The last frame both takes share: the one before the branch (on the
    # branch frame itself the help take's call and slow-down begin).
    nb, hb = E["branch"] - 1, H["branch"] - 1
    assert nb - a0 == hb - h0, "takes out of step before the branch (%d vs %d)" % (nb - a0, hb - h0)
    diff = np.abs(frame_rgb(nh["movie"], nb).astype(int) - frame_rgb(hp["movie"], hb).astype(int))
    match = {"branch_frame_mean_abs_diff": round(float(diff.mean()), 3), "max": int(diff.max()),
             "pixels_differing": int((diff.max(axis=2) > 8).sum())}
    print("branch frames:", match)
    fail_end = E["fail_end"]
    h_end = H["clip_end"] + TAIL
    fall_n = fail_end - nb
    rewind_n = int(round(fall_n / REWIND_SPEED))
    music = music_bed()
    mgain = 0.16

    def game_audio(src, f0, n):
        a0s = int(round(f0 / FPS * SR))
        seg = src["audio"][a0s:a0s + int(round(n / FPS * SR))]
        return np.pad(seg, (0, int(round(n / FPS * SR)) - len(seg)))

    timeline = {"branch_match": match}
    # ---------------------------------------------------------- Version B
    nb_frames = h_end - h0
    segs = [(hp["movie"], h0, nb_frames, "fwd")]
    aud = game_audio(hp, h0, nb_frames)
    aud = aud + music[:len(aud)] * mgain
    place(aud, (H["platform_1"] - h0) / FPS * SR, build_lift(), 0.7)
    place(aud, (H["platform_2"] - h0) / FPS * SR, build_lift(), 0.5)
    place(aud, (H["bank"] - h0) / FPS * SR, arrive_chime(), 0.8)
    wav = os.path.join(out, "_b.wav")
    R.write_wav(wav, aud)
    segments_to_mp4(segs, os.path.join(out, "rescue_direct.mp4"), wav)
    os.remove(wav)
    tb = {k: secs(v - h0) for k, v in H.items() if v >= h0 and v <= h_end}
    timeline["rescue_direct"] = {"source": "help take frames %d..%d" % (h0, h_end), "length_s": secs(nb_frames), "events_s": tb}
    # ---------------------------------------------------------- Version A
    first = fail_end - a0
    segs = [(nh["movie"], a0, first, "fwd"),
            (nh["movie"], nb, fall_n, ("rev", REWIND_SPEED)),
            (hp["movie"], hb + 1, h_end - hb - 1, "fwd")]
    # (the reversed run ends on frame nb == hb; the help take goes on from hb + 1)
    pre = game_audio(nh, a0, first)
    fall_audio = game_audio(nh, nb, fall_n)[::-1]
    idx = np.linspace(0, len(fall_audio) - 1, int(round(rewind_n / FPS * SR)))
    rew = np.interp(idx, np.arange(len(fall_audio)), fall_audio)
    post = game_audio(hp, hb + 1, h_end - hb - 1)
    aud = np.concatenate([pre, rew * 0.8, post])
    # Music: forward to the failure, backwards through the rewind, then on
    # from the branch again.
    m_pre = music[:len(pre)]
    m_branch = int(round((nb - a0) / FPS * SR))
    m_rev = music[m_branch:len(pre)][::-1]
    m_rev = np.interp(np.linspace(0, len(m_rev) - 1, len(rew)), np.arange(len(m_rev)), m_rev)
    m_post = music[m_branch:m_branch + len(post)]
    aud = aud + np.concatenate([m_pre, m_rev, m_post]) * mgain
    fall_at = (nb - a0) / FPS * SR
    place(aud, fall_at, wind(int((fail_end - nb) / FPS * SR)), 0.35)
    place(aud, len(pre) - int(0.3 * SR), fail_note(), 0.9)
    place(aud, len(pre), rewind_whirr(len(rew)), 0.9)
    post0 = len(pre) + len(rew)
    place(aud, post0 + (H["platform_1"] - hb - 1) / FPS * SR, build_lift(), 0.7)
    place(aud, post0 + (H["platform_2"] - hb - 1) / FPS * SR, build_lift(), 0.5)
    place(aud, post0 + (H["bank"] - hb - 1) / FPS * SR, arrive_chime(), 0.8)
    wav = os.path.join(out, "_a.wav")
    R.write_wav(wav, aud)
    segments_to_mp4(segs, os.path.join(out, "rescue_rewind.mp4"), wav)
    os.remove(wav)
    ta = {("fail:" + k): secs(v - a0) for k, v in E.items() if a0 <= v <= fail_end}
    ta["rewind_start"] = secs(first)
    ta["rewind_end"] = secs(first + rewind_n)
    for k, v in H.items():
        if hb < v <= h_end:
            ta["help:" + k] = secs(first + rewind_n + v - hb - 1)
    timeline["rescue_rewind"] = {"source": "nohelp frames %d..%d, the same reversed (%d -> %d frames, x%.1f), help frames %d..%d"
                                 % (a0, fail_end, fall_n, rewind_n, REWIND_SPEED, hb + 1, h_end),
                                 "length_s": secs(first + rewind_n + h_end - hb - 1), "events_s": ta}
    json.dump(timeline, open(os.path.join(out, "timeline.json"), "w"), indent=1)
    print(json.dumps(timeline, indent=1))


if __name__ == "__main__":
    main()
