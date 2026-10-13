#!/usr/bin/env python3
"""Use a supplied licensed track over the captured game effects.

python3 tools/trailer_bgm.py CAPTURE BGM.mp3 soundtrack.wav
The recorded effects are rebuilt without the generated score. The supplied
track keeps its stereo image, fades with the film and ducks on strong effects.
"""
import argparse
import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('capture', type=Path)
    p.add_argument('bgm', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--offset', type=float, default=0.0)
    p.add_argument('--loudness', type=float, default=-21.0)
    a = p.parse_args()
    meta = json.loads((a.capture / 'shots.json').read_text())
    duration = meta['frames'] / meta['fps']
    sfx = a.capture / 'sfx-only.wav'
    subprocess.run([sys.executable, str(Path(__file__).with_name('trailer_mix.py')),
                    str(a.capture), str(sfx), '--no-music'], check=True)
    music = a.capture / 'stems' / 'licensed-music.wav'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', str(a.offset), '-i', str(a.bgm),
                    '-t', str(duration), '-af',
                    f'loudnorm=I={a.loudness}:TP=-3:LRA=9,afade=t=in:d=0.15,'
                    f'afade=t=out:st={duration-0.9}:d=0.9',
                    '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', str(music)], check=True)
    graph = (
        '[0:a]volume=0.78[fx0];[fx0]asplit=2[key][fx];'
        '[1:a][key]sidechaincompress=threshold=0.15:ratio=2:attack=15:release=220:makeup=1[bgm];'
        '[fx][bgm]amix=inputs=2:duration=first:normalize=0,'
        'alimiter=limit=0.93:level=0[out]'
    )
    a.output.parent.mkdir(parents=True, exist_ok=True)
    mixed = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(sfx), '-i', str(music),
                    '-filter_complex', graph, '-map', '[out]', '-t', str(duration),
                    '-ar', '44100', '-ac', '2', '-c:a', 'pcm_s16le', '-f', 's16le', 'pipe:1'],
                    check=True, stdout=subprocess.PIPE).stdout
    expected_bytes = round(duration * 44100) * 4
    if len(mixed) != expected_bytes:
        raise RuntimeError(f'Incomplete mix: {len(mixed)} bytes, expected {expected_bytes}')
    # AAC reconstruction can overshoot a sharp gate slam. Reserve another
    # decibel after the limiter while keeping the music/effects balance.
    mixed = np.rint(np.frombuffer(mixed, dtype='<i2').astype(np.float32) * 0.9).astype('<i2').tobytes()
    temporary = a.output.with_name(a.output.stem + '-writing.wav')
    with wave.open(str(temporary), 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(44100)
        w.writeframes(mixed)
    temporary.replace(a.output)
    (a.capture / 'bgm-edit.json').write_text(json.dumps({
        'source': a.bgm.name, 'offset': a.offset, 'loudness_lufs': a.loudness,
        'duration': duration, 'generated_score_disabled': True,
        'output_gain': 0.9,
    }, indent=2))
    print(a.output)


if __name__ == '__main__':
    main()
