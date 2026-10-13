#!/usr/bin/env python3
"""Estimate the music from a user-supplied reference PV, without changing pitch.

The input is a mixed soundtrack, not a clean music stem. Similar-frame median
filtering attenuates isolated effects; some reference effects can remain.
Requires NumPy, SciPy and FFmpeg. Never redistribute the reference separately.
"""
import argparse
import json
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy import signal

RATE = 44100
FRAME = 2048
HOP = 512


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--start', type=float, default=12.45)
    p.add_argument('--duration', type=float, default=37.0)
    a = p.parse_args()
    raw = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-ss', str(a.start),
        '-i', str(a.reference), '-t', str(a.duration), '-vn', '-ar', str(RATE),
        '-ac', '2', '-f', 'f32le', 'pipe:1'], check=True, stdout=subprocess.PIPE).stdout
    audio = np.frombuffer(raw, '<f4').reshape(-1, 2).copy()
    expected = round(a.duration * RATE)
    if len(audio) < expected:
        raise ValueError('The reference does not contain the requested duration')
    audio = audio[:expected]
    spectra = [signal.stft(audio[:, c], fs=RATE, nperseg=FRAME,
        noverlap=FRAME-HOP)[2] for c in range(2)]
    mag = np.mean([abs(x) for x in spectra], axis=0)
    features = np.sqrt(mag + 1e-10)
    features /= np.maximum(np.linalg.norm(features, axis=0, keepdims=True), 1e-8)
    similarity = (features.T @ features).astype(np.float32)
    count = mag.shape[1]
    gap = round(.8 * RATE / HOP)
    for i in range(count):
        similarity[i, max(0, i-gap):min(count, i+gap+1)] = -np.inf
    flux = np.sum(np.maximum(np.diff(mag, axis=1, prepend=mag[:, :1]), 0), axis=0)
    similarity[:, flux > np.quantile(flux, .85)] = -np.inf
    neighbours = 20
    indices = np.argpartition(-similarity, neighbours-1, axis=1)[:, :neighbours]
    background = np.minimum(mag, np.median(mag[:, indices], axis=2))
    residual = np.maximum(mag-background, 0)
    mask = background**2 / (background**2 + (.85*residual)**2 + 1e-12)
    # A shared stereo mask preserves the reference's pan and phase. Gentle
    # smoothing and a low floor avoid isolated holes and hard tonal artifacts.
    from scipy.ndimage import gaussian_filter
    mask = np.maximum(.08, gaussian_filter(mask, sigma=(.7, 1.0)))
    music = np.zeros_like(audio)
    for c, spectrum in enumerate(spectra):
        restored = signal.istft(spectrum*mask, fs=RATE, nperseg=FRAME,
            noverlap=FRAME-HOP)[1]
        music[:min(expected, len(restored)), c] = restored[:expected]
    music *= min(1.0, .9/max(1e-9, float(abs(music).max())))
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(a.output), 'wb') as w:
        w.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes(np.rint(music*32767).astype('<i2').tobytes())
    a.output.with_suffix('.json').write_text(json.dumps({
        'reference': a.reference.name, 'start': a.start, 'duration': a.duration,
        'method': 'similar-frame median with shared stereo soft mask',
        'pitch_and_tempo_changed': False, 'estimated_music': True,
        'limitation': 'Some reference sound effects may remain; this is not a clean stem.'
    }, indent=2))
    print(a.output)


if __name__ == '__main__':
    main()
