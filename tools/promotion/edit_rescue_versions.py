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
  through the fall into the gorge ("fail_end"), a short hold on the failure
  (draining of colour), then those same frames played backwards to the
  branch frame (eased, with ghosts of the later frames, a cool tint, tape
  lines and a rewind mark, all fading out before the join), then the help
  take from the very next frame with a brief flash.

Sound: the game's own sounds from each recording; the stage music
(assets/audio/music_stage.wav, the game's own) as a low bed that runs
backwards with the picture during the rewind; and a few sounds made here
(numpy): wind on the fall, a failure note, the rewind whirr, a reversed
swell into the join and the click of time starting again, a lift under
each platform's build, an arrival chime; a soft limiter on the mix. Nothing
licensed from outside.

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
# Frame size of the recordings (PV_SIZE=WxH for takes recorded at another window size).
FW, FH = (int(v) for v in os.environ.get("PV_SIZE", "1280x720").split("x"))
SR = R.SR
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PRE_HOP = 24        # frames before the hop over the enemy where both clips start
TAIL = 4            # frames after "clip_end"
REWIND_SPEED = 1.5  # how much faster than the fall the rewind plays (on average; it is eased)
MIN_REWIND = 28     # frames
HOLD = 12           # frames the failure is held before the rewind
TITLE = 132         # frames of the end title (MELOS GAME over the last frame)
FLASH = 7           # frames of the flash as time starts again


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
    return np.frombuffer(raw, np.uint8).reshape(FH, FW, 3)


def read_frames(movie, f0, n):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", movie, "-vf", "trim=start_frame=%d:end_frame=%d" % (f0, f0 + n),
                          "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, FH, FW, 3)


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


def reverse_swell(n):
    """A reversed cymbal: noise swelling up to a sharp stop (time snaps back)."""
    x = lowpass(noise(n, 17), 6000.0) - lowpass(noise(n, 17), 600.0)
    e = (t(n) / t(n)[-1]) ** 3
    return x * e * 1.6


def resume_snap(n=int(0.18 * SR)):
    """The click of time starting again."""
    return (osc(glide(2400.0, 900.0, n), n) * 0.5 + noise(n, 21) * 0.3) * envelope(n, 0.001, 0.03)


def impact(n=int(0.45 * SR)):
    """The body hitting the platform: a low thump with a bright tick on top."""
    body = osc(glide(140.0, 48.0, n), n) * envelope(n, 0.002, 0.16)
    tick = lowpass(noise(n, 31), 5000.0) * envelope(n, 0.0005, 0.02) * 2.0
    return (body * 0.9 + tick * 0.5)


def swish(n=int(0.22 * SR)):
    """The finger rushing in: a short airy swish."""
    x = lowpass(noise(n, 41), 2500.0) - lowpass(noise(n, 41), 400.0)
    e = np.sin(np.pi * np.clip(t(n) / t(n)[-1], 0, 1)) ** 2
    return x * e * 2.2


def slow_down(n=int(0.6 * SR)):
    """Time thickening: a falling, muffled whoomp."""
    tone = osc(glide(520.0, 70.0, n), n) * 0.6 + osc(glide(260.0, 40.0, n), n) * 0.4
    air = lowpass(noise(n, 51), 900.0) * 2.0
    e = np.clip(t(n) / 0.02, 0, 1) * np.exp(-t(n) / 0.28)
    return (tone + air * 0.6) * e * 0.7


def speed_up(n=int(0.5 * SR)):
    """Back to full speed: a rising rush."""
    x = lowpass(noise(n, 61), 7000.0) - lowpass(noise(n, 61), 500.0)
    tone = osc(glide(180.0, 900.0, n), n) * 0.25
    e = np.clip(t(n) / 0.03, 0, 1) * np.clip((t(n)[-1] - t(n)) / 0.25, 0, 1)
    return (x * 1.8 + tone) * e


def muffle(x, a, b, cut=450.0, gain=0.4, fade=int(0.12 * SR)):
    """Low-pass and duck x between samples a and b, cross-faded at both ends."""
    a, b = int(a), int(b)
    lo = lowpass(x, cut) * gain
    w = np.zeros(len(x))
    w[a:b] = 1.0
    if fade:
        ramp = np.linspace(0, 1, fade)
        w[max(0, a - fade):a] = ramp[:len(w[max(0, a - fade):a])]
        w[b:b + fade] = ramp[::-1][:len(w[b:b + fade])]
    return x * (1 - w) + lo * w


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


def limit(x, ceiling=0.8):
    """Soft limiter: leaves everything under ~0.7 alone, rounds off peaks."""
    knee = 0.55
    y = x.copy()
    over = np.abs(y) > knee
    y[over] = np.sign(y[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(y[over]) - knee) / (ceiling - knee)))
    return y


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
    im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Two left-pointing triangles, top left: the universal rewind mark.
    for k in range(2):
        x = 70 + k * 46
        d.polygon([(x + 44, 48), (x + 44, 112), (x, 80)], fill=(255, 255, 255, 230))
    # Faint horizontal tape lines.
    for y in range(0, FH, 6):
        d.line([(0, y), (FW, y)], fill=(255, 255, 255, 14))
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


def ease_io(x):
    return x * x * (3 - 2 * x)


def rewind_look(img, k, ghosts):
    """The rewind treatment at strength k (0..1): cooler, a little flatter,
    a colour fringe, tape lines, the previous (later) frames as ghosts --
    light enough that the runner stays plain."""
    f = img.astype(np.float32)
    for g, w in ghosts:
        f = f * (1 - w * k) + g.astype(np.float32) * (w * k)
    grey = f.mean(axis=2, keepdims=True)
    f = grey + (f - grey) * (1 - 0.35 * k)
    f = f * (1 + np.array([-0.06, 0.02, 0.12], np.float32) * k) + np.array([0, 2, 10], np.float32) * k
    sh = int(round(4 * k))
    if sh:
        f[:, sh:, 0] = f[:, :-sh, 0]
        f[:, :-sh, 2] = f[:, sh:, 2]
    f[::4] *= 1 - 0.10 * k
    return np.clip(f, 0, 255).astype(np.uint8)


def icon_layer():
    im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for k in range(2):
        x = 64 + k * 50
        d.polygon([(x + 48, 44), (x + 48, 116), (x, 80)], fill=(255, 255, 255, 235), outline=(30, 40, 80, 255))
    a = np.asarray(im).astype(np.float32)
    return a[..., :3], a[..., 3:] / 255.0


def write_frames(out, wav, frames):
    p = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (FW, FH), "-r", str(FPS),
                          "-i", "-", "-i", wav, "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
                          "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", out],
                         stdin=subprocess.PIPE)
    for fr in frames:
        p.stdin.write(np.ascontiguousarray(fr).tobytes())
    p.stdin.close()
    p.wait()


def rewind_frames(nh_movie, hp_movie, a0, nb, fail_end, hb, h_end, hold_n, rewind_n, flash_n, title_n=0):
    """The picture of Version A, frame by frame: the fall (forward), a held
    beat on the failure, the fall played backwards (eased: it lurches off,
    races, settles onto the branch frame), then the help take with a brief
    flash as time starts again."""
    for fr in read_frames(nh_movie, a0, fail_end - a0 + 1):
        yield fr
    fall = read_frames(nh_movie, nb, fail_end - nb + 1)   # fall[0] = branch-1 ... fall[-1] = fail_end
    last = fall[-1].astype(np.float32)
    for i in range(hold_n):
        # The failure lands: the frame holds, draining of colour, a dark edge.
        k = (i + 1) / hold_n
        grey = last.mean(axis=2, keepdims=True)
        f = grey + (last - grey) * (1 - 0.6 * k)
        f = f * (1 - 0.25 * k * VIGNETTE[..., None])
        yield np.clip(f, 0, 255).astype(np.uint8)
    icon_rgb, icon_a = icon_layer()
    m = len(fall) - 1
    for i in range(rewind_n):
        u = (i + 1) / rewind_n
        pos = m * (1 - ease_io(u))
        j = int(np.floor(pos))
        w = pos - j
        img = fall[j] if w < 1e-3 or j >= m else (fall[j] * (1 - w) + fall[j + 1] * w).astype(np.uint8)
        ghosts = [(fall[min(m, j + 3)], 0.22), (fall[min(m, j + 6)], 0.12)]
        k = min(1.0, 4 * u, 4 * (1 - u) + 0.15) if u < 1 else 0.0
        out = rewind_look(img, max(0.0, min(1.0, k)), ghosts).astype(np.float32)
        ia = icon_a * min(1.0, 5 * (1 - u) + 0.0) * min(1.0, 6 * u)
        out = out * (1 - ia) + icon_rgb * ia
        yield np.clip(out, 0, 255).astype(np.uint8)
    last = None
    for i, fr in enumerate(read_frames(hp_movie, hb + 1, h_end - hb - 1)):
        if i < flash_n:
            k = 0.45 * (1 - i / flash_n) ** 2
            fr = np.clip(fr.astype(np.float32) * (1 - k) + 255 * k, 0, 255).astype(np.uint8)
        last = fr
        yield fr
    if title_n and last is not None:
        yield from title_frames(last, title_n)


def title_frames(last, n):
    """The end title: the last picture softens and dims, the game's logo
    eases in over it, holds, and everything fades out."""
    from PIL import ImageFilter
    logo = Image.open(os.path.join(ROOT, "assets", "promo", "title_melos_game.png")).convert("RGBA")
    base = Image.fromarray(last)
    blurred = np.asarray(base.filter(ImageFilter.GaussianBlur(6))).astype(np.float32)
    sharp = last.astype(np.float32)
    for i in range(n):
        k = ease_io(min(1.0, i / 24.0))
        bg = sharp * (1 - k) + blurred * k
        bg = bg * (1 - 0.42 * k) + np.array([10, 14, 34], np.float32) * (0.42 * k)
        a = ease_io(min(1.0, max(0.0, (i - 6) / 22.0)))
        sc = 0.56 + 0.06 * a + 0.02 * (i / n)
        w, h = int(logo.width * sc), int(logo.height * sc)
        lg = logo.resize((w, h), Image.LANCZOS)
        frame = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8)).convert("RGBA")
        layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
        la = np.asarray(lg).astype(np.float32)
        la[..., 3] *= a
        layer.paste(Image.fromarray(la.astype(np.uint8)), ((FW - w) // 2, (FH - h) // 2 - 10))
        out = np.asarray(Image.alpha_composite(frame, layer).convert("RGB")).astype(np.float32)
        fade = min(1.0, max(0.0, (n - 1 - i) / 14.0))
        yield np.clip(out * fade, 0, 255).astype(np.uint8)


_yy, _xx = np.mgrid[0:FH, 0:FW]
VIGNETTE = np.clip(np.hypot((_xx - FW / 2) / (FW / 2), (_yy - FH / 2) / (FH / 2)) - 0.55, 0, 1) / 0.85


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


def camera_timeline(nh, hp, nh_dir, hp_dir, a0, nb, fail_end, hb, h_end, rewind_n, path):
    """One row per frame of rescue_rewind.mp4: which recording and frame it
    shows, the game camera's centre and zoom there, and the runner."""
    import csv

    def rows(d, variant, src):
        out = {}
        for r in csv.DictReader(open(os.path.join(d, "rescue_trace_%s.csv" % variant))):
            out[int(r["process_frame"]) + src["off"]] = r
        return out
    N, Hr = rows(nh_dir, "nohelp", nh), rows(hp_dir, "help", hp)
    plan = [("nohelp", f, "fall") for f in range(a0, fail_end + 1)]
    plan += [("nohelp", fail_end, "failure held")] * HOLD
    m = fail_end - nb
    for i in range(rewind_n):
        u = (i + 1) / rewind_n
        plan.append(("nohelp", int(round(nb + m * (1 - ease_io(u)))), "rewind (reversed)"))
    plan += [("help", f, "rescue") for f in range(hb + 1, h_end)]
    with open(path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["t_s", "segment", "source", "source_frame", "cam_x", "cam_y", "cam_zoom", "runner_x", "runner_y", "runner_vy", "on_floor", "time_scale", "events"])
        for k, (src, f, seg) in enumerate(plan):
            r = (N if src == "nohelp" else Hr).get(f)
            if r is None:
                w.writerow(["%.3f" % (k / FPS), seg, src, f] + [""] * 9)
                continue
            w.writerow(["%.3f" % (k / FPS), seg, src, f, r["cam_x"], r["cam_y"], r["cam_zoom"], r["x"], r["y"], r["vy"], r["on_floor"],
                        r["time_scale"] if seg not in ("failure held", "rewind (reversed)") else "0",
                        r["events"] if seg != "failure held" else ""])


def timing_report(cam_csv, ev, path):
    """One row per section of rescue_rewind: output times, source frames and
    recording times, the game's speed (game seconds per output second: the
    engine time scale, or the edit's reverse speed), its curve, how far the
    runner moved in the game and on screen, and when full speed returns."""
    import csv
    rows = list(csv.DictReader(open(cam_csv)))
    # Game time of every output frame: forward sections add the time scale
    # of their source frame; the rewind walks the fall's game time back.
    gt = []
    clock = 0.0
    for r in rows:
        ts = float(r.get("time_scale") or 1.0)
        gt.append(clock)
        clock += ts / FPS
    secs_of = lambda k: ev[k]
    marks = [("run, hop the enemy", 0.0, secs_of("fail:wide")),
             ("wide, take-off, air jump", secs_of("fail:wide"), secs_of("fail:branch")),
             ("rises, tops out short, falls into the gorge (failure)", secs_of("fail:branch"), secs_of("fail_hold")),
             ("failure held", secs_of("fail_hold"), secs_of("rewind_start")),
             ("rewind (the fall reversed)", secs_of("rewind_start"), secs_of("rewind_end")),
             ("slow motion: rising, top of the arc, falling again", secs_of("rewind_end"), secs_of("help:call")),
             ("slow motion: Discord call (UI real time)", secs_of("help:call"), secs_of("help:call_answered")),
             ("slow motion: YOU answers and rushes in (cursor real time)", secs_of("help:call_answered"), secs_of("help:stroke_start")),
             ("slow motion: stroke, platform builds, runner comes down", secs_of("help:stroke_start"), secs_of("help:contact_1")),
             ("contact: hit stop, back to full speed", secs_of("help:contact_1"), secs_of("help:normal_speed")),
             ("caught: a beat on platform 1, platform 2 added", secs_of("help:normal_speed"), secs_of("help:jump_to_step")),
             ("hop to platform 2, jump + air jump to the bank", secs_of("help:jump_to_step"), secs_of("help:bank")),
             ("on the far bank, running on", secs_of("help:bank"), len(rows) / FPS)]
    with open(path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["section", "out_start_s", "out_end_s", "out_len_s", "source", "source_frames", "source_rec_s",
                    "game_speed_x", "speed_curve", "runner_moved_world_px", "runner_moved_screen_px_per_s", "full_speed_returns_s"])
        for name, t0, t1 in marks:
            i0, i1 = int(round(t0 * FPS)), min(len(rows) - 1, int(round(t1 * FPS)))
            if i1 <= i0:
                continue
            seg = rows[i0:i1 + 1]
            src = sorted(set(r["source"] for r in seg))
            f0, f1 = int(seg[0]["source_frame"]), int(seg[-1]["source_frame"])
            tss = [float(r.get("time_scale") or 1.0) for r in (seg[:-1] if len(seg) > 1 else seg)]
            if "rewind" in name:
                speed = -abs(f1 - f0) / max(1, len(seg) - 1)
                curve = "reversed, eased in/out (mean %.2fx)" % speed
            else:
                speed = (f1 - f0) / max(1, len(seg) - 1) * (sum(tss) / len(tss)) if f1 != f0 else 0.0
                lo, hi = min(tss), max(tss)
                curve = ("constant %.2fx" % lo) if hi - lo < 0.02 else ("%.2fx -> %.2fx" % (tss[0], tss[-1])) + (" (min %.2f, max %.2f)" % (lo, hi))
                if "held" in name:
                    curve, speed = "frozen frame", 0.0
            pts = [(float(r["runner_x"]), float(r["runner_y"])) for r in seg if r["runner_x"]]
            dist = sum(((pts[k][0] - pts[k - 1][0]) ** 2 + (pts[k][1] - pts[k - 1][1]) ** 2) ** 0.5 for k in range(1, len(pts)))
            zooms = [float(r["cam_zoom"]) for r in seg if r["cam_zoom"]]
            scr = dist * (sum(zooms) / len(zooms)) / max(1e-6, (len(seg) - 1) / FPS) if zooms else 0.0
            back = ""
            if "contact" in name:
                back = "%.2f" % t1
            w.writerow([name, "%.2f" % t0, "%.2f" % t1, "%.2f" % (t1 - t0), "+".join(src), "%d..%d" % (f0, f1),
                        "%.2f..%.2f" % (f0 / FPS, f1 / FPS), "%.3f" % speed, curve, "%.0f" % dist, "%.0f" % scr, back])


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
    rewind_n = max(MIN_REWIND, int(round(fall_n / REWIND_SPEED)))
    music = music_bed()
    mgain = float(os.environ.get("RESCUE_MUSIC_GAIN", "0.16"))

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
    place(aud, (H["aim_1"] - h0) / FPS * SR, swish(), 0.6)
    place(aud, (H["platform_1"] - h0) / FPS * SR, build_lift(), 0.7)
    place(aud, (H["contact_1"] - h0) / FPS * SR, impact(), 0.9)
    place(aud, (H["platform_2"] - h0) / FPS * SR, build_lift(), 0.5)
    place(aud, (H["bank"] - h0) / FPS * SR, arrive_chime(), 0.8)
    wav = os.path.join(out, "_b.wav")
    R.write_wav(wav, limit(aud))
    segments_to_mp4(segs, os.path.join(out, "rescue_direct.mp4"), wav)
    os.remove(wav)
    tb = {k: secs(v - h0) for k, v in H.items() if v >= h0 and v <= h_end}
    timeline["rescue_direct"] = {"source": "help take frames %d..%d" % (h0, h_end), "length_s": secs(nb_frames), "events_s": tb}
    # ---------------------------------------------------------- Version A
    first = fail_end - a0 + 1
    pre = game_audio(nh, a0, first)
    hold_aud = np.zeros(int(round(HOLD / FPS * SR)))
    fall_audio = game_audio(nh, nb, fall_n)[::-1]
    idx = np.linspace(0, len(fall_audio) - 1, int(round(rewind_n / FPS * SR)))
    rew = np.interp(idx, np.arange(len(fall_audio)), fall_audio)
    post = game_audio(hp, hb + 1, h_end - hb - 1)
    aud = np.concatenate([pre, hold_aud, rew * 0.8, post])
    # Music: forward to the failure, cut on the held beat, backwards through
    # the rewind, then on from the branch again.
    m_pre = music[:len(pre)]
    m_branch = int(round((nb - a0) / FPS * SR))
    m_rev = music[m_branch:len(pre)][::-1]
    m_rev = np.interp(np.linspace(0, len(m_rev) - 1, len(rew)), np.arange(len(m_rev)), m_rev)
    m_post = music[m_branch:m_branch + len(post)]
    bed = np.concatenate([m_pre, hold_aud, m_rev, m_post]) * mgain
    # The slow motion: from the join (time slows at once) to the contact
    # (+ the hit stop): the bed goes dull and quiet, so the call, the
    # finger and the build stand out; it comes back bright at full speed.
    post_start = len(pre) + len(hold_aud) + len(rew)
    slow_a = post_start
    slow_b = post_start + (H.get("normal_speed", H["contact_1"]) - hb - 1) / FPS * SR
    bed = muffle(bed, slow_a, slow_b)
    aud = aud + bed
    fall_at = (nb - a0) / FPS * SR
    place(aud, fall_at, wind(int((fail_end - nb) / FPS * SR)), 0.6)
    place(aud, len(pre) - int(0.12 * SR), fail_note(), 0.9)
    r0 = len(pre) + len(hold_aud)
    place(aud, r0, rewind_whirr(len(rew)), 0.9)
    post0 = r0 + len(rew)
    sw = reverse_swell(int(0.35 * SR))
    place(aud, post0 - len(sw), sw, 0.5)
    place(aud, post0, resume_snap(), 0.8)
    place(aud, post0 + int(0.02 * SR), slow_down(), 0.8)
    place(aud, post0 + (H["contact_1"] - hb - 1) / FPS * SR + int(0.07 * SR), speed_up(), 0.55)
    place(aud, post0 + (H["aim_1"] - hb - 1) / FPS * SR, swish(), 0.7)
    place(aud, post0 + (H["platform_1"] - hb - 1) / FPS * SR, build_lift(), 0.7)
    place(aud, post0 + (H["contact_1"] - hb - 1) / FPS * SR, impact(), 0.9)
    place(aud, post0 + (H["platform_2"] - hb - 1) / FPS * SR, build_lift(), 0.5)
    place(aud, post0 + (H["bank"] - hb - 1) / FPS * SR, arrive_chime(), 0.8)
    # The end title: the music bed runs on under it and fades out; a chime
    # as the logo comes in.
    t_n = int(round(TITLE / FPS * SR))
    tail = music[m_branch + len(post):m_branch + len(post) + t_n] * mgain
    tail = np.pad(tail, (0, t_n - len(tail))) * np.clip(np.linspace(1.6, 0.0, t_n), 0, 1)
    title0 = len(aud)
    aud = np.concatenate([aud, tail])
    place(aud, title0 + int(0.1 * SR), arrive_chime(), 0.7)
    wav = os.path.join(out, "_a.wav")
    R.write_wav(wav, limit(aud))
    write_frames(os.path.join(out, "rescue_rewind.mp4"), wav,
                 rewind_frames(nh["movie"], hp["movie"], a0, nb, fail_end, hb, h_end, HOLD, rewind_n, FLASH, TITLE))
    os.remove(wav)
    ta = {("fail:" + k): secs(v - a0) for k, v in E.items() if a0 <= v <= fail_end}
    ta["fail_hold"] = secs(first)
    ta["rewind_start"] = secs(first + HOLD)
    ta["rewind_end"] = secs(first + HOLD + rewind_n)
    for k, v in H.items():
        if hb < v <= h_end:
            ta["help:" + k] = secs(first + HOLD + rewind_n + v - hb - 1)
    timeline["rescue_rewind"] = {"source": "nohelp frames %d..%d, held %d frames, frames %d..%d reversed (eased, %d frames), help frames %d..%d"
                                 % (a0, fail_end, HOLD, nb, fail_end, rewind_n, hb + 1, h_end),
                                 "length_s": secs(first + HOLD + rewind_n + h_end - hb - 1), "events_s": ta}
    json.dump(timeline, open(os.path.join(out, "timeline.json"), "w"), indent=1)
    camera_timeline(nh, hp, sys.argv[1], sys.argv[2], a0, nb, fail_end, hb, h_end, rewind_n, os.path.join(out, "rescue_camera_timeline.csv"))
    timing_report(os.path.join(out, "rescue_camera_timeline.csv"), ta, os.path.join(out, "timing_report.csv"))
    print(json.dumps(timeline, indent=1))


if __name__ == "__main__":
    main()
