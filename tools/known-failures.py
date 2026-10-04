#!/usr/bin/env python3
"""Decides whether one verify.sh step failed in a NEW way.

    <step output> | tools/known-failures.py "<step title>" <exit status>

Some checks were already failing when CI started gating on this suite --
stale tests for removed controls, a crossing in 1-S, a retired gauge. They are
listed per step in test/known_failures.txt. A step passes when every FAIL line
it printed is on that list and it raised no more script errors than the list
allows. Anything new fails it. A listed failure that has started passing is
reported, so the list only ever shrinks.

Values in parentheses are measurements ("x=5546", "0 attempts") and vary from
run to run, so lines are compared with them blanked out.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KNOWN = ROOT / "test" / "known_failures.txt"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SCRIPT_ERROR = re.compile(r"SCRIPT ERROR|Failed to load|Parse Error")


def normalise(line: str) -> str:
    line = ANSI.sub("", line).strip()
    line = re.sub(r"^FAIL\s+", "FAIL  ", line)
    return re.sub(r"\([^()]*\)", "(…)", line)


def load(step: str):
    allowed, errors, section = set(), 0, None
    if not KNOWN.exists():
        return allowed, errors
    for raw in KNOWN.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section == step and line.startswith("script_errors"):
            errors = int(line.split("=", 1)[1])
        elif section == step:
            allowed.add(normalise(line))
    return allowed, errors


def main() -> int:
    step, status = sys.argv[1], int(sys.argv[2])
    output = sys.stdin.read()
    seen = {normalise(l) for l in output.splitlines()
            if re.match(r"^\s*FAIL\b", ANSI.sub("", l))}
    errors = len(SCRIPT_ERROR.findall(output))
    allowed, allowed_errors = load(step)

    new = sorted(seen - allowed)
    fixed = sorted(allowed - seen)
    ok = True
    for line in new:
        print(f"  NEW   {line}")
        ok = False
    if errors > allowed_errors:
        print(f"  NEW   {errors} script errors, {allowed_errors} known")
        ok = False
    if status != 0 and not seen and errors == 0:
        print(f"  exited {status} without saying which check failed")
        ok = False
    for line in fixed:
        print(f"  note  now passing -- remove from test/known_failures.txt: {line}")
    if errors < allowed_errors:
        print(f"  note  {errors} script errors, {allowed_errors} known -- lower the count")
    if ok and (seen or errors):
        print(f"  known failures only ({len(seen)} checks, {errors} script errors)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
