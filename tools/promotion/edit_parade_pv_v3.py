"""PV v3: stage 1-9 trailer cut after the owner's reference structure.

Cold open -> role reveal ("THIS IS YOU") -> word-by-word captions over native
1-9 takes -> fast montage of stages 1-1..1-8 -> title drop -> tagline cards
over a running parade strip -> end card. Gameplay is native and at 1x speed.

Inputs (recorded with Godot's movie maker, see docs/promotion/pv-v3-ja.md):
  build/promotion/stage-1-9/pv-v2/raw-takes.avi + takes.json   (capture_parade_pv.tscn)
  build/promotion/stage-1-9/pv-v3/raw-montage.avi + montage-takes.json (capture_stage_montage.tscn)
"""
from __future__ import annotations
import json
import math
import subprocess
import wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
TAKES = ROOT / 'build/promotion/stage-1-9/pv-v2'
OUT = ROOT / 'build/promotion/stage-1-9/pv-v3'
W, H, FPS, SR = 1280, 720, 60, 48000
FONT = str(ROOT / 'assets/fonts/Baloo2-Bold.ttf')
BODY = str(ROOT / 'assets/fonts/Nunito-ExtraBold.ttf')
CREATOR = 'Inoue & Sasabe'
ACCENT = '#e7775e'
STAGES = [('1-1', 'GREENFIELD PLAINS', '#15cf8a'), ('1-2', 'THE HOLLOW OUTSKIRTS', '#4688ef'),
          ('1-3', 'THE SKYWARD RUINS', '#8659e8'), ('1-4', 'THE SUNLIT COAST', '#1fa7d8'),
          ('1-5', 'THE MOLTEN CROSSING', '#75b72b'), ('1-6', 'THE SANDGLASS RUINS', '#e6a44b'),
          ('1-7', 'THE CLOCKWORK TOWER', '#8c8a78'), ('1-8', 'THE UNDERGROVE', '#708797')]
TAGLINES = ['THE TWO-PLAYER RESCUE PLATFORMER', 'NEW STAGE 1-9\nTHE TRICKSTER PARADE', 'PLAY TOGETHER']
CARD, END = 1.85, 2.6


def font(size, path=FONT):
    return ImageFont.truetype(path, size)


def run(args):
    subprocess.run(args, cwd=ROOT, check=True)


def blank():
    return Image.new('RGBA', (W, H))


def encode(path, frames):
    """Pipe RGB frames to a lossless intermediate."""
    p = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
                          '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-crf', '10', '-preset', 'fast',
                          '-pix_fmt', 'yuv420p', str(path)], stdin=subprocess.PIPE)
    for im in frames:
        p.stdin.write(im.convert('RGB').tobytes())
    p.stdin.close()
    assert p.wait() == 0


def read_frames(src, start, count):
    raw = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-ss', f'{start:.6f}', '-i', str(src),
                          '-frames:v', str(count), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         check=True, capture_output=True).stdout
    size = W * H * 3
    return [Image.frombytes('RGB', (W, H), raw[i * size:(i + 1) * size]) for i in range(len(raw) // size)]


def stroke_text(d, xy, words, f, fill='white', stroke=7, stroke_fill='#1a1220', anchor='la', shadow=None):
    if shadow:
        d.text((xy[0] + 5, xy[1] + 7), words, font=f, fill=shadow, stroke_width=stroke, stroke_fill=shadow, anchor=anchor)
    d.text(xy, words, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill, anchor=anchor)


# ---------- overlays ----------
def kinetic(words, y=72, size=78, fill='white'):
    """One image per word step: 'SHOOT' -> 'SHOOT THE TRICKS', centred like the reference."""
    out = []
    f = font(size)
    tokens = words.split(' ')
    full = ImageDraw.Draw(blank()).textlength(words, font=f)
    for n in range(1, len(tokens) + 1):
        im = blank()
        d = ImageDraw.Draw(im)
        stroke_text(d, ((W - full) / 2, y), ' '.join(tokens[:n]), f, fill=fill, shadow='#00000088')
        out.append(im)
    return out


def roles():
    im = blank()
    d = ImageDraw.Draw(im)
    for name, x, label, action, color in [('lira', 42, 'PLAYER 1', 'RUN', '#ffdf86'), ('orion', 938, 'PLAYER 2', 'DRAW & SHOOT', '#a4faff')]:
        portrait = Image.open(ROOT / f'assets/ui/portrait_{name}.png').convert('RGBA')
        portrait.thumbnail((104, 104), Image.Resampling.LANCZOS)
        d.rounded_rectangle((x, 28, x + 300, 150), radius=18, fill=(14, 25, 40, 205), outline=color, width=2)
        im.alpha_composite(portrait, (x + 6, 37))
        d.text((x + 116, 38), label, font=font(23), fill='white')
        d.text((x + 116, 76), action, font=font(35 if len(action) < 6 else 26), fill=color)
    return im


def this_is_you():
    """The reference's 'THIS IS YOU' pointer, aimed at the second player's native controls."""
    im = blank()
    d = ImageDraw.Draw(im)
    stroke_text(d, (250, 430), 'THIS IS YOU', font(46), stroke=5)
    # Hand-drawn style arrow toward the shot/platform buttons on the left edge.
    d.line([(248, 452), (196, 452)], fill='white', width=6)
    d.polygon([(178, 452), (204, 438), (204, 466)], fill='white')
    return im


def stage_label(number, name, color):
    im = blank()
    d = ImageDraw.Draw(im)
    f1, f2 = font(54), font(30)
    w = max(d.textlength(number, font=f1) + 24 + d.textlength(name, font=f2), 300)
    d.rounded_rectangle((36, 610, 36 + w + 52, 690), radius=14, fill=(12, 16, 26, 215))
    d.rectangle((36, 610, 46, 690), fill=color)
    d.text((66, 612), number, font=f1, fill=color)
    d.text((66 + d.textlength(number, font=f1) + 24, 630), name, font=f2, fill='white')
    return im


# ---------- generated sections ----------
def ease_out_back(t):
    c1, c3 = 1.70158, 2.70158
    t = min(max(t, 0), 1)
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2


def title_section(clip):
    """MELOS GAME letters drop one by one over the live goal shot."""
    frames = read_frames(TAKES / 'raw-takes.avi', clip['start'], round(clip['duration'] * FPS))
    letters = 'MELOS GAME'
    big = font(168)
    probe = ImageDraw.Draw(blank())
    widths = [probe.textlength(c, font=big) for c in letters]
    x0 = (W - sum(widths)) / 2
    shade = Image.new('RGBA', (W, H), (14, 10, 24, 0))
    a = np.zeros((H, W), dtype=np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    a = 0.48 + 0.3 * np.clip(((xx - W / 2) ** 2 / (W * 0.62) ** 2 + (yy - H / 2) ** 2 / (H * 0.7) ** 2), 0, 1)
    shade.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    out = []
    for i, base in enumerate(frames):
        t = i / FPS
        im = base.convert('RGBA')
        im.alpha_composite(shade)
        d = ImageDraw.Draw(im)
        x = x0
        for k, c in enumerate(letters):
            local = (t - 0.15 - k * 0.055) / 0.32
            if local > 0 and c != ' ':
                y = 190 - (1 - ease_out_back(local)) * 260
                stroke_text(d, (x, y), c, big, stroke=10, shadow=ACCENT)
            x += widths[k]
        if t > 1.0:
            alpha = int(255 * min(1, (t - 1.0) / 0.2))
            layer = blank()
            ld = ImageDraw.Draw(layer)
            ld.rounded_rectangle((W / 2 - 92, 404, W / 2 + 92, 446), radius=10, fill=ACCENT)
            ld.text((W / 2, 425), 'STAGE 1-9', font=font(30), fill='white', anchor='mm')
            stroke_text(ld, (W / 2, 492), 'THE TRICKSTER PARADE', font(58), fill='#ffdf86', stroke=6, anchor='mm')
            ld.text((W / 2, 556), f'BY {CREATOR}', font=font(30), fill='white', anchor='mm', stroke_width=4, stroke_fill='#1a1220')
            layer.putalpha(layer.getchannel('A').point(lambda v: v * alpha // 255))
            im.alpha_composite(layer)
        out.append(im)
    return out


def strip_section():
    """Tagline cards: Lira runs with the parade at her heels on a teal band."""
    sheet = Image.open(ROOT / 'assets/stage_1_9/gremlin_run.png').convert('RGBA')
    fw = sheet.width // 4
    gremlins = []
    for k in range(4):
        g = sheet.crop((k * fw, 0, (k + 1) * fw, sheet.height))
        g = g.crop(g.getbbox())
        g.thumbnail((200, 92), Image.Resampling.LANCZOS)
        gremlins.append(g)
    runner = []
    for n in ['run', 'dash']:
        r = Image.open(ROOT / f'assets/characters/runner_{n}.png').convert('RGBA')
        r = r.crop(r.getbbox())
        r = r.resize((round(r.width * 104 / r.height), 104), Image.Resampling.LANCZOS)
        runner.append(r)
    rng = np.random.default_rng(19)
    crowd = [(float(rng.uniform(0, 1700)), int(rng.integers(0, 4)), float(rng.uniform(-6, 6))) for _ in range(17)]
    ground = 300
    total = round(CARD * len(TAGLINES) * FPS)
    out = []
    for i in range(total):
        t = i / FPS
        im = Image.new('RGBA', (W, H), '#15100f')
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, W, ground), fill='#2aa39a')
        d.rectangle((0, ground, W, ground + 22), fill='#5b3a2c')
        for x in range(-((i * 6) % 64), W, 64):
            d.rectangle((x, ground, x + 30, ground + 6), fill='#6f4a37')
        speed = 240
        # Gremlins: endless loop of the parade, behind and around the runner.
        for x, phase, bob in sorted(crowd):
            gx = (x + t * speed) % 1700 - 300
            if 700 < gx < 950:
                continue  # leave Lira a gap to run in
            frame = gremlins[(int(t * 12) + phase) % 4]
            im.alpha_composite(frame, (int(gx), int(ground - frame.height + 4 + bob * math.sin(t * 9 + x))))
        r = runner[int(t * 10) % 2]
        im.alpha_composite(r, (820 + int(12 * math.sin(t * 3)), ground - r.height + 2 - int(abs(math.sin(t * 10)) * 6)))
        card = min(int(t / CARD), len(TAGLINES) - 1)
        lines = TAGLINES[card].split('\n')
        local = t - card * CARD
        alpha = min(1, local / 0.12, (CARD - local) / 0.12) if card < len(TAGLINES) - 1 else min(1, local / 0.12)
        layer = blank()
        ld = ImageDraw.Draw(layer)
        for n, line in enumerate(lines):
            ld.text((W / 2, 515 + (n - (len(lines) - 1) / 2) * 52), line, font=font(40), fill='white', anchor='mm')
        layer.putalpha(layer.getchannel('A').point(lambda v: int(v * max(0, alpha))))
        im.alpha_composite(layer)
        out.append(im)
    return out


def end_section():
    im = Image.new('RGBA', (W, H), 'black')
    d = ImageDraw.Draw(im)
    d.text((176, 70), 'MELOS', font=font(54), fill='white', anchor='mm')
    d.text((176, 118), 'GAME', font=font(54), fill='white', anchor='mm')
    d.text((176, 160), f'BY {CREATOR.upper()}', font=font(20), fill='white', anchor='mm')
    d.text((176, 200), 'STAGE 1-9  THE TRICKSTER PARADE', font=font(17), fill='#ffdf86', anchor='mm')
    return [im] * round(END * FPS)


# ---------- sound ----------
def score(total, music_at, hits, thuds, strip_at, end_at):
    """Original 150 BPM mechanical-carnival loop plus impact accents."""
    rng = np.random.default_rng(1909)
    a = np.zeros((round(total * SR), 2))

    def add(sig, at, gain, pan=0.0):
        pos = round(at * SR)
        if pos < 0 or pos >= len(a):
            return
        sig = sig[:len(a) - pos] * gain
        a[pos:pos + len(sig), 0] += sig * math.sqrt((1 - pan) / 2)
        a[pos:pos + len(sig), 1] += sig * math.sqrt((1 + pan) / 2)

    def tone(midi, length=.28, brass=False):
        t = np.arange(round(length * SR)) / SR
        f = 440 * 2 ** ((midi - 69) / 12)
        s = np.sin(2 * np.pi * f * t)
        for h in range(2, 7 if brass else 3):
            s += np.sin(2 * np.pi * h * f * t) * (0.45 ** (h - 1) if brass else .16)
        return s * (1 - np.exp(-180 * t)) * np.exp(-(7 if brass else 10) * t)

    t = np.arange(round(.24 * SR)) / SR
    kick = np.sin(2 * np.pi * (48 * t + 105 * (1 - np.exp(-35 * t)) / 35)) * np.exp(-18 * t)
    t = np.arange(round(.17 * SR)) / SR
    n = rng.standard_normal(len(t))
    snare = (n - np.convolve(n, np.ones(12) / 12, mode='same')) * np.exp(-35 * t)
    t = np.arange(round(.05 * SR)) / SR
    hat = rng.standard_normal(len(t)) * np.exp(-90 * t)
    t = np.arange(round(.9 * SR)) / SR
    boom = np.sin(2 * np.pi * (36 * t + 60 * (1 - np.exp(-12 * t)) / 12)) * np.exp(-5 * t) + rng.standard_normal(len(t)) * np.exp(-14 * t) * .25
    t = np.arange(round(.5 * SR)) / SR
    swish = np.convolve(rng.standard_normal(len(t)) * np.sin(np.pi * t / .5) ** 2, np.ones(6) / 6, mode='same')

    beat = .4
    roots = [38, 34, 43, 45]
    motif = [74, 77, 81, 77, 74, 72, 69, 73, 74, 77, 79, 81, 79, 77, 76, 73]
    # Cold open: a low drone and ticking, like the dark first seconds of the reference.
    for k in range(int(music_at / beat)):
        add(hat, k * beat, .05)
        add(tone(38, .5), k * beat, .05)
    i = 0
    while music_at + i * beat < end_at:
        at = music_at + i * beat
        drop = at >= strip_at  # sparser groove under the tagline cards
        add(kick, at, .26)
        add(tone(roots[(i // 4) % 4], .33), at, .15)
        if i % 4 in (1, 3):
            add(snare, at, .1)
        for j in range(4 if not drop else 2):
            add(hat, at + j * beat / (4 if not drop else 2), .028, .35 if j % 2 else -.35)
        add(tone(motif[i % 16], .3, True), at, .075, -.2)
        if i % 2 == 1:
            add(tone(motif[(i + 3) % 16] + 12, .17), at + .2, .035, .3)
        if i % 16 == 15:
            for j in range(3):
                add(snare, at + j * .1, .03 * (j + 1))
        i += 1
    for at, g in hits:
        add(boom, at, .5 * g)
        add(swish, at - .45, .1 * g)
    for at in thuds:
        add(kick, at, .35)
        add(snare, at, .05)
    # Resolve on the end card.
    start = round(end_at * SR)
    a[start:] *= .2
    for note in [50, 57, 62, 65, 69]:
        add(tone(note, 2.4, True), end_at, .06)
    tail = round(.4 * SR)
    a[-tail:] *= np.linspace(1, 0, tail)[:, None]
    with wave.open(str(OUT / 'score.wav'), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((np.clip(np.tanh(a) * .7, -1, 1) * 32767).astype('<i2').tobytes())


# ---------- edit ----------
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    meta = json.loads((TAKES / 'takes.json').read_text(encoding='utf-8'))
    seg = {s['name']: s for s in meta['segments']}
    montage = json.loads((OUT / 'montage-takes.json').read_text(encoding='utf-8'))
    mseg = {s['name']: s for s in montage['segments']}

    clips = []

    def take(name, head=0.0, tail=0.0):
        s = seg[name]
        start = (s['start_frame'] - 1) / FPS + head
        end = (s['end_frame'] - 1) / FPS - tail
        clips.append(dict(take=name, src=0, start=start, end=end, duration=round((end - start) * FPS) / FPS))

    for name in ['bite_reveal', 'partner_bridge', 'jaw_reversal', 'accordion', 'curtain', 'magnet', 'stilt',
                 'cannon', 'shadow', 'hound', 'wheel', 'final_rescue']:
        take(name, head={'curtain': .1, 'magnet': .25, 'hound': .2, 'wheel': .2}.get(name, 0.0))
    for number, _, _ in STAGES:
        s = mseg[number]
        start = (s['start_frame'] - 1) / FPS + .3
        clips.append(dict(take='montage-' + number, src=1, start=start, end=start + .75, duration=.75))
    s = seg['title']
    clips.append(dict(take='title', src=2, start=(s['start_frame'] - 1) / FPS, end=(s['end_frame'] - 1) / FPS,
                      duration=(s['end_frame'] - s['start_frame']) / FPS))
    clips.append(dict(take='taglines', src=3, start=0, end=CARD * len(TAGLINES), duration=CARD * len(TAGLINES)))
    clips.append(dict(take='end', src=4, start=0, end=END, duration=END))
    cursor = 0.0
    for c in clips:
        c['timeline_start'] = round(cursor, 6)
        cursor += c['duration']
    total = round(cursor * FPS) / FPS
    at = {c['take']: c['timeline_start'] for c in clips}

    def shot_time(take_name):
        """Timeline second of the first native shot in a take."""
        c = next(c for c in clips if c['take'] == take_name)
        e = next(e for e in meta['events'] if e['take'] == take_name and e['event'] == 'shot')
        return c['timeline_start'] + (e['frame'] - 1) / FPS - c['start']

    # Generated sections.
    encode(OUT / 'gen-title.mp4', title_section(next(c for c in clips if c['take'] == 'title')))
    encode(OUT / 'gen-taglines.mp4', strip_section())
    encode(OUT / 'gen-end.mp4', end_section())

    layers = []
    hits = []

    def layer(name, im, start, end):
        p = OUT / f'overlay-{name}.png'
        im.save(p)
        layers.append((p, start, end))

    def words(name, text, start, end, step=.32, **kw):
        imgs = kinetic(text, **kw)
        for k, im in enumerate(imgs):
            a = start + k * step
            b = start + (k + 1) * step if k < len(imgs) - 1 else end
            layer(f'{name}-{k}', im, a, b)
            hits.append((a, 1.0 if k == len(imgs) - 1 else .55))

    bridge = at['partner_bridge']
    layer('roles', roles(), bridge + .1, bridge + 3.3)
    layer('you', this_is_you(), bridge + .45, bridge + 3.3)
    hits.append((bridge + .45, .8))
    words('shoot', 'SHOOT THE TRICKS', at['jaw_reversal'] + .1, at['jaw_reversal'] + 1.9)
    words('fly', 'ONE SHOT. FOURTEEN FLY.', at['accordion'] + .3, at['accordion'] + 2.4, step=.45)
    words('acts', 'SIX ACTS. 18 MACHINES.', at['curtain'] + .15, at['magnet'] + 1.4, step=.4)
    words('cast', '12 TRICKSTERS', at['shadow'] + .1, at['hound'] + 1.4, step=.45)
    words('draw', 'DRAW. SHOOT. SOAR.', at['final_rescue'], at['montage-1-1'], step=.42)
    for number, name, color in STAGES:
        t0 = at['montage-' + number]
        layer('stage-' + number, stage_label(number, name, color), t0, t0 + .75)
    words('road', 'EIGHT STAGES BEFORE IT', at['montage-1-1'] + .05, at['montage-1-8'] + .75, step=.3, size=60, y=40)

    thuds = [at['title'] + .15 + k * .055 + .3 for k, c in enumerate('MELOS GAME') if c != ' ']
    thuds += [at['montage-' + n] for n, _, _ in STAGES]
    hits.append((at['title'] + 1.0, .7))
    hits.append((at['taglines'], .5))
    bite = next(e for e in meta['events'] if e['take'] == 'bite_reveal' and e['event'] == 'bite')
    hits.append(((bite['frame'] - 1) / FPS - clips[0]['start'], 1.2))
    score(total, bridge, hits, thuds, at['taglines'], at['end'])

    # Filter graph: concatenate clips with their native game sound, then overlays.
    inputs = [TAKES / 'raw-takes.avi', OUT / 'raw-montage.avi', OUT / 'gen-title.mp4', OUT / 'gen-taglines.mp4', OUT / 'gen-end.mp4']
    graph, pairs = [], []
    norm = 'fps=60,setsar=1,scale=1280:720,format=yuv420p'
    # Godot's movie maker writes full-range BT.601 MJPEG; convert like edit_parade_pv.py.
    mjpeg = ('fps=60,setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,'
             'format=yuv420p')
    for i, c in enumerate(clips):
        if c['src'] in (0, 1):
            graph.append(f"[{c['src']}:v]trim=start={c['start']:.6f}:duration={c['duration']:.6f},setpts=PTS-STARTPTS,{mjpeg}[v{i}]")
            graph.append(f"[{c['src']}:a]atrim=start={c['start']:.6f}:duration={c['duration']:.6f},asetpts=PTS-STARTPTS,apad,atrim=duration={c['duration']:.6f}[a{i}]")
        else:
            graph.append(f"[{c['src']}:v]trim=duration={c['duration']:.6f},setpts=PTS-STARTPTS,{norm}[v{i}]")
            graph.append(f"anullsrc=r=48000:cl=stereo,atrim=duration={c['duration']:.6f}[a{i}]")
        pairs.append(f'[v{i}][a{i}]')
    graph.append(''.join(pairs) + f'concat=n={len(clips)}:v=1:a=1[base][sfx]')
    last = 'base'
    first_layer = len(inputs) + 1
    for k, (_, a, b) in enumerate(layers):
        idx = first_layer + k
        graph.append(f'[{idx}:v]format=rgba,fade=t=in:st={a:.4f}:d=0.06:alpha=1,fade=t=out:st={b - .06:.4f}:d=0.06:alpha=1[g{k}]')
        graph.append(f"[{last}][g{k}]overlay=enable='between(t,{a:.4f},{b:.4f})':eof_action=repeat[o{k}]")
        last = f'o{k}'
    # A short white flash on each montage cut, like the reference's hard cuts.
    flashes = '+'.join(f"between(t,{at['montage-' + n]:.4f},{at['montage-' + n] + .05:.4f})" for n, _, _ in STAGES)
    graph.append(f"[{last}]eq=brightness=0.35:enable='{flashes}',fps=60,format=yuv420p[vout]")
    graph.append(f'[sfx]volume=.7[sounds]')
    graph.append(f'[{len(inputs)}:a]apad,atrim=duration={total}[music]')
    graph.append(f'[sounds][music]amix=inputs=2:duration=longest:normalize=0,atrim=duration={total},loudnorm=I=-16:TP=-2:LRA=11,aresample=48000,afade=t=out:st={total - .3}:d=0.3[aout]')
    (OUT / 'edit-filter.txt').write_text(';\n'.join(graph), encoding='utf-8')
    (OUT / 'edit-timeline.json').write_text(json.dumps(clips, indent=2), encoding='utf-8')
    movie = OUT / 'melos-trickster-parade-pv-v3.mp4'
    args = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y']
    for p in inputs:
        args += ['-i', str(p)]
    args += ['-i', str(OUT / 'score.wav')]
    for p, _, _ in layers:
        args += ['-loop', '1', '-framerate', '60', '-i', str(p)]
    args += ['-filter_complex_script', str(OUT / 'edit-filter.txt'), '-map', '[vout]', '-map', '[aout]', '-t', f'{total}',
             '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-r', '60',
             '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', str(movie)]
    run(args)
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(movie), '-vf', 'fps=1.5,scale=320:180,tile=8x9',
         '-frames:v', '1', str(OUT / 'contact.jpg')])
    print(json.dumps(dict(movie=str(movie), duration=total, clips=len(clips), overlays=len(layers))))


if __name__ == '__main__':
    main()
