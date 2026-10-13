#!/usr/bin/env python3
"""Replace selected shots with native retakes, preserving frame and SFX timing."""
import argparse
import copy
import json
import os
import shutil
from pathlib import Path


def assemble(base: Path, retakes: Path, out: Path) -> None:
    original = json.loads((base / 'shots.json').read_text())
    replacement = json.loads((retakes / 'shots.json').read_text())
    assert original['fps'] == replacement['fps']
    assert original['size'] == replacement['size']
    fps = original['fps']
    by_name = {s['name']: s for s in replacement['shots']}
    (out / 'frames').mkdir(parents=True, exist_ok=True)
    selections = []
    for shot in original['shots']:
        new = by_name.get(shot['name'])
        source = retakes if new else base
        take = new or shot
        assert take['frames'] == shot['frames'], shot['name']
        selections.append((source, take, shot))
        for k in range(shot['frames']):
            src = source / 'frames' / f"{take['start'] + k:05}.png"
            dst = out / 'frames' / f"{shot['start'] + k:05}.png"
            if dst.exists():
                dst.unlink()
            try:
                os.link(src, dst)
            except OSError:
                shutil.copyfile(src, dst)

    def timed_entries(filename: str, field: str | None = None):
        entries = []
        cache = {}
        for source, take, destination in selections:
            if source not in cache:
                values = json.loads((source / filename).read_text())
                cache[source] = values[field] if field else values
            begin = take['start'] / fps
            end = (take['start'] + take['frames']) / fps
            shift = (destination['start'] - take['start']) / fps
            for value in cache[source]:
                if begin <= float(value['t']) < end:
                    entry = copy.deepcopy(value)
                    entry['t'] = round(float(value['t']) + shift, 3)
                    entries.append(entry)
        return sorted(entries, key=lambda e: e['t'])

    original['cues'] = timed_entries('shots.json', 'cues')
    original['retaken_shots'] = list(by_name)
    (out / 'shots.json').write_text(json.dumps(original, indent=2))
    (out / 'sfx.json').write_text(json.dumps(timed_entries('sfx.json'), indent=2))
    print(f"assembled {original['frames']} frames with {len(by_name)} retakes")


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('base', type=Path)
    p.add_argument('retakes', type=Path)
    p.add_argument('output', type=Path)
    a = p.parse_args()
    assemble(a.base, a.retakes, a.output)
