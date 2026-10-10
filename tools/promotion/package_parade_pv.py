"""Add a local screening page beside the artbook without replacing old films."""
import html
import json
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/promotion/stage-1-9/pv-v2'
DEST=ROOT/'build/promotion/stage-1-9/artbook-v2/pv'
DEST.mkdir(parents=True,exist_ok=True)
report=json.loads((OUT/'verification.json').read_text(encoding='utf-8'))
for name in ['melos-trickster-parade-pv.mp4','poster.jpg','verification.json','edit-timeline.json']:
    shutil.copy2(OUT/name,DEST/name)
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MELOS GAME / The Trickster Parade PV</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101722;color:#fff7e4;font:16px/1.6 system-ui}main{max-width:1320px;margin:auto;padding:24px}a{color:#a4faff}header{display:flex;justify-content:space-between;align-items:center;gap:24px}h1{font-size:clamp(22px,4vw,40px);margin:12px 0 18px}p{color:#c7c8cc}video{display:block;width:100%;aspect-ratio:16/9;background:#000;border:1px solid #b58a46;border-radius:12px}footer{display:flex;justify-content:space-between;gap:20px;flex-wrap:wrap;margin-top:16px}.tag{color:#ffdf86;font-size:13px;letter-spacing:2px}@media(max-width:640px){main{padding:12px}header{display:block}}</style>
<main><header><a href="../index.html">← Design artbook</a><span class="tag">STAGE 1-9 / GAMEPLAY TRAILER</span></header>
<h1>The Trickster Parade</h1><video controls playsinline preload="metadata" poster="poster.jpg" src="melos-trickster-parade-pv.mp4"></video>
<footer><span>By Inoue and Sasabe · 28 seconds · 720p / 60 fps</span><a download href="melos-trickster-parade-pv.mp4">Download MP4</a></footer>
<p>The original Lira and Orion. Native gameplay, directed camera and player inputs, original music. <a href="../playable/index.html">Playable prototype</a> · <a href="verification.json">Verification</a></p></main></html>'''
(DEST/'index.html').write_text(page,encoding='utf-8')
playable=DEST.parent/'playable/index.html'
contents=playable.read_text(encoding='utf-8')
banner='<p id="pv-link"><a href="../pv/index.html">Watch the 28-second PV →</a></p>'
if 'id="pv-link"' not in contents:
    contents=contents.replace('<video controls',banner+'\n<video controls',1)
    playable.write_text(contents,encoding='utf-8')
(OUT/'README.md').write_text('''# The Trickster Parade PV

28.15 seconds, 1280 × 720, 60 fps. English overlays, original music, credits: Inoue and Sasabe.

Native stage 1-9 footage; the director supplies camera moves and real player inputs. Each take starts from a separate setup, with the full cast running. The film is a montage, not a continuous full-stage completion recording.

- Capture: `tools/promotion/capture_parade_pv.tscn`
- Edit: `tools/promotion/edit_parade_pv.py`
- Verify: `tools/promotion/verify_parade_pv.py`
- Package: `tools/promotion/package_parade_pv.py`
- Media: `melos-trickster-parade-pv.mp4`
- Cut list: `edit-timeline.json`
- Runtime events: `takes.json`
- Evidence: `verification.json` and `capture-checks.json`

Original hero assets and current import metadata are unchanged. Earlier trailers and the playable preview are retained in their original folders.
''',encoding='utf-8')
print(json.dumps({'url':'http://127.0.0.1:8773/pv/index.html','movie':str(OUT/'melos-trickster-parade-pv.mp4'),'verified':report['full_decode']}))
