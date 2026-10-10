"""Snapshot current import metadata and restore only movie/import side effects."""
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/promotion" / os.environ.get("PROMO_VERSION", "v3")
BASE = OUT / "import-baseline"

if sys.argv[1] == "save":
    OUT.mkdir(parents=True, exist_ok=True)
    tracked = subprocess.check_output(["git", "ls-files", "*.import"], cwd=ROOT, text=True).splitlines()
    manifest = {}
    for rel in tracked:
        dst = BASE / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, dst)
        manifest[rel] = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
    (OUT / "import-baseline.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Saved {len(manifest)} current import settings")
else:
    manifest = json.loads((OUT / "import-baseline.json").read_text())
    changed = []
    for rel, digest in manifest.items():
        if hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() != digest:
            shutil.copy2(BASE / rel, ROOT / rel)
            changed.append(rel)
    print(json.dumps({"restored": len(changed), "checked": len(manifest)}))
