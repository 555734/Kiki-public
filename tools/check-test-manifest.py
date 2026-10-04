#!/usr/bin/env python3
"""Every test scene is classified, and every gated one is actually run.

    tools/check-test-manifest.py

Reads test/manifest.txt. Fails when a test/ or tools/ scene is not listed,
when a listed one no longer exists, or when a scene marked gated / shots /
perf is not referenced by the script that is supposed to run it.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "test" / "manifest.txt"
RUNNERS = {
    "gated": ROOT / "tools" / "verify.sh",
    "shots": ROOT / "tools" / "verify.sh",
    "perf": ROOT / "tools" / "perf-gate.sh",
}
KINDS = set(RUNNERS) | {"live", "capture", "tool"}


def main() -> int:
    listed = {}
    for raw in MANIFEST.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 2)
        listed[parts[0]] = parts[1]
    scenes = {p.relative_to(ROOT).as_posix()
              for d in ("test", "tools") for p in (ROOT / d).glob("*.tscn")}
    problems = []
    for scene in sorted(scenes - set(listed)):
        problems.append(f"{scene}: not in test/manifest.txt -- say how it runs")
    for scene in sorted(set(listed) - scenes):
        problems.append(f"{scene}: listed but does not exist")
    for scene, kind in sorted(listed.items()):
        if kind not in KINDS:
            problems.append(f"{scene}: unknown kind '{kind}'")
        elif kind in RUNNERS and scene not in RUNNERS[kind].read_text(encoding="utf-8") \
                and pathlib.Path(scene).name not in RUNNERS[kind].read_text(encoding="utf-8"):
            problems.append(f"{scene}: marked {kind} but {RUNNERS[kind].name} does not run it")
    for p in problems:
        print("FAIL  " + p)
    counts = {}
    for kind in listed.values():
        counts[kind] = counts.get(kind, 0) + 1
    print("test manifest: %d scenes (%s)" % (len(listed),
          ", ".join(f"{n} {k}" for k, n in sorted(counts.items()))))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
