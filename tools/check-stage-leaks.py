#!/usr/bin/env python3
"""Shared entities must not ask which stage they are in.

A gimmick that reads `Stage.is_cave()` changes behaviour for every stage that
places it, and each new stage adds another branch to every such gimmick. What
a piece is (one-way, its colours) is set on it by the builder from the stage
data instead.

The lines that still do this are counted per file below. The count may only go
down: a new read fails the check, and a file that drops under its number is
reported so the number can be lowered with it.

    tools/check-stage-leaks.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCOPE = ROOT / "src" / "entities"
PATTERN = re.compile(r"\bStage\.[a-z_]+\(")

# Theme and placement lookups that predate the rule. Lower these, never raise
# them: give the entity a field and let LevelBuilder fill it.
ALLOWED = {
    "src/entities/gimmicks/blink_block.gd": 2,
    "src/entities/gimmicks/conveyor.gd": 4,
    "src/entities/gimmicks/crumbling_floor.gd": 4,
    "src/entities/gimmicks/gate.gd": 3,
    "src/entities/gimmicks/goal.gd": 7,
    "src/entities/gimmicks/hazard.gd": 1,
    "src/entities/gimmicks/moving_platform.gd": 4,
    "src/entities/gimmicks/shootable_switch.gd": 2,
    "src/entities/gimmicks/spring.gd": 1,
    "src/entities/gimmicks/switch_bridge.gd": 2,
    "src/entities/gimmicks/trick_pad.gd": 1,
    "src/entities/gimmicks/updraft.gd": 2,
    "src/entities/gimmicks/warp_gate.gd": 2,
}


def main() -> int:
    failed = False
    seen = {}
    for path in sorted(SCOPE.rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        hits = [(n, line.strip()) for n, line in
                enumerate(path.read_text(encoding="utf-8").splitlines(), 1)
                if PATTERN.search(line) and not line.lstrip().startswith("#")]
        seen[rel] = len(hits)
        allowed = ALLOWED.get(rel, 0)
        if len(hits) > allowed:
            failed = True
            print(f"FAIL  {rel}: {len(hits)} Stage reads, {allowed} allowed")
            for n, text in hits:
                print(f"        {rel}:{n}: {text}")
        elif len(hits) < allowed:
            print(f"note  {rel}: down to {len(hits)} -- lower ALLOWED to match")
    for rel in ALLOWED:
        if rel not in seen:
            print(f"note  {rel}: gone -- remove it from ALLOWED")
    total = sum(seen.values())
    print(f"stage reads in shared entities: {total} "
          f"(ceiling {sum(ALLOWED.values())})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
