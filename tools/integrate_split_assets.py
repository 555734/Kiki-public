"""Import the owner's stage pack, trimming transparent padding only.

Usage: python tools/integrate_split_assets.py path/to/Kiki_assets_split.zip
"""
from pathlib import Path
from zipfile import ZipFile
import sys
from PIL import Image

root = Path(__file__).resolve().parents[1]
with ZipFile(sys.argv[1]) as archive:
    for entry in archive.infolist():
        if entry.is_dir():
            continue
        parts = entry.filename.split('/')[1:]
        if len(parts) != 3 or parts[0] not in ('1-2', '1-3', '1-4', '1-5') or '..' in parts:
            raise ValueError(f'Unexpected asset path: {entry.filename}')
        target = root / 'assets' / 'split' / Path(*parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.read(entry))
        if parts[1] != 'background':
            with Image.open(target) as source:
                image = source.convert('RGBA')
                bounds = image.getbbox()
                if bounds:
                    image.crop(bounds).save(target)
