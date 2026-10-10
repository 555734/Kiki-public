"""Package the native preview and evidence; no image resampling or repainting."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion/stage-1-9/playable-v2"
GALLERY = ROOT / "build/promotion/stage-1-9/artbook-v2/playable"
NAMES = ["01-entrance", "02-backstage", "03-crossing", "04-accordion", "05-gallery", "06-finale"]
LABELS = ["False Entrance", "Backstage", "Parade Crossing", "Accordion Gap", "Spotlight Gallery", "Sky Wheel Finale"]

subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(OUT / "raw.avi"),
    "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(OUT / "preview.mp4")], check=True)
subprocess.run(["ffmpeg", "-v", "error", "-i", str(OUT / "preview.mp4"), "-f", "null", "-"], check=True)
video = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(OUT / "preview.mp4")]))
probe = json.loads((OUT / "probe.json").read_text(encoding="utf-8"))
refs = json.loads((ROOT / "docs/promotion/parade-artbook-v2/hero-reference-hashes.json").read_text(encoding="utf-8"))
heroes = all(hashlib.sha256((ROOT / row["source"]).read_bytes()).hexdigest() == row["sha256"] for row in refs)
takes = json.loads((OUT / "takes.json").read_text(encoding="utf-8"))
logs = {name: (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace") for name in ["scripts", "logic", "menu", "probe", "play-smoke", "import-final"]}
report = {"public_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "stage": "1-9", "acts": 6, "machine_kinds": 18, "cast_types": 12, "enemies": 89,
    "parade_checks": probe["checks"], "parade_failures": probe["failures"],
    "original_hero_files_unchanged": heroes, "hero_files_checked": len(refs),
    "scripts": re.search(r"script check: (\d+) files, (\d+) failed", logs["scripts"]).groups(),
    "logic": re.search(r"--- (\d+) checks, (\d+) failed", logs["logic"]).groups(),
    "menu_passed": "all checks passed" in logs["menu"],
    "play_controls_enabled": "input=true clock=true home=false" in logs["play-smoke"],
    "script_errors": {name: re.findall(r"SCRIPT ERROR:.*", log) for name, log in logs.items()},
    "takes": [{k: s[k] for k in ["name", "runner_alive", "runner_position"]} for s in takes["segments"]],
    "video": {"duration": video["format"]["duration"], "streams": [{k: s.get(k) for k in ["codec_name", "codec_type", "width", "height", "r_frame_rate"]} for s in video["streams"]]},
    "real_device_and_two_human_online_tested": False}
(OUT / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
if probe["failures"] or not heroes or any(report["script_errors"].values()): raise SystemExit("verification failed")
if report["scripts"][1] != "0" or report["logic"][1] != "0" or not report["menu_passed"] or not report["play_controls_enabled"]: raise SystemExit("regression or play smoke failed")

cards = "".join(f'<figure><img loading="lazy" src="{name}.png" alt="Native {label} stage"><figcaption>{i+1:02d} / {label}</figcaption></figure>' for i, (name, label) in enumerate(zip(NAMES, LABELS)))
page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MELOS / Playable Parade</title>
<style>*{box-sizing:border-box}body{margin:0;background:#151724;color:#f3e8d5;font:16px/1.6 system-ui}main{max-width:1260px;margin:auto;padding:30px}a{color:#74e0e6}h1{font-size:clamp(26px,5vw,52px);margin:.2em 0}p{max-width:850px;color:#c8c2bc}video{width:100%;border:1px solid #a7824b;border-radius:14px;background:#000}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:30px}figure{margin:0;background:#242534;border-radius:12px;overflow:hidden}img{display:block;width:100%}figcaption{padding:12px 18px;color:#edbc69}code{background:#242534;padding:.2em .4em}@media(max-width:760px){main{padding:16px}.grid{grid-template-columns:1fr}}</style>
<main><a href="../index.html">← Design artbook</a><p>STAGE 1-9 / PLAYABLE FIRST PASS</p><h1>The Trickster Parade</h1><p>The original Lira and Orion. Six acts, eighteen machines and twelve cast types. Real enemy physics, shot-triggered transformations, moving collision platforms and five retry checkpoints.</p>
<video controls preload="metadata" poster="01-entrance.png" src="preview.mp4"></video>
<p>A directed camera tour of the implemented game. Local play: run <code>tools/play_parade_v2.ps1</code>; A/D or arrows to move, Space to jump, mouse aim with 1 platform / 2 wall / 3 shot / 4 warp. Use <code>-Zone 2</code> through <code>-Zone 6</code> to inspect later acts.</p>
<div class="grid">''' + cards + '''</div><p>Prototype by Inoue and Sasabe. Full attack/run animation sets and human difficulty/pacing playtests are still pending. <a href="validation.json">Verification report</a></p></main></html>'''
(OUT / "index.html").write_text(page, encoding="utf-8")
GALLERY.mkdir(parents=True, exist_ok=True)
for name in ["index.html", "preview.mp4", "validation.json"] + [n + ".png" for n in NAMES]: shutil.copy2(OUT / name, GALLERY / name)
for p in [GALLERY.parent / "index.html"]:
    content = p.read_text(encoding="utf-8")
    if 'href="playable/index.html"' not in content:
        content = content.replace("<body>", '<body><a href="playable/index.html" style="display:block;padding:12px 24px;background:#132c38;color:#93e6eb;text-align:center;font-weight:700">View the playable implementation →</a>', 1)
    p.write_text(content, encoding="utf-8")
print(json.dumps({k: report[k] for k in ["parade_checks", "parade_failures", "original_hero_files_unchanged", "scripts", "logic", "menu_passed", "play_controls_enabled", "video"]}))
