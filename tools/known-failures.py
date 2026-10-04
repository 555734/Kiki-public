#!/usr/bin/env python3
"""Decides whether one verify.sh step failed in a NEW way.

    <step output> | tools/known-failures.py "<step title>" <exit status>

Run on every step, whatever its exit status: a test that prints FAIL and
still exits 0 is caught here, not trusted.

Checks that were failing when CI started gating on this suite are listed per
step in test/known_failures.txt, by their exact message. A script error is
listed the same way -- its message and where it was raised -- never as a
count, so a new error cannot hide behind an old one being fixed. Anything not
listed fails the step. A listed failure that has started passing is reported,
so the list only ever shrinks.

Values in parentheses are measurements ("x=5546", "0 attempts") and vary from
run to run, so FAIL lines are compared with them blanked out.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KNOWN = ROOT / "test" / "known_failures.txt"
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SCRIPT_ERROR = re.compile(r"(SCRIPT ERROR: .*|.*Failed to load.*|.*Parse Error.*)")
WHERE = re.compile(r"^\s*at: (.*)$")


def normalise(line: str) -> str:
    line = ANSI.sub("", line).strip()
    line = re.sub(r"^FAIL\s+", "FAIL  ", line)
    return re.sub(r"\([^()]*\)", "(…)", line)


def script_errors(output: str) -> list:
    """Each error as 'message @ location' (location from the next 'at:' line)."""
    lines = [ANSI.sub("", l) for l in output.splitlines()]
    found = []
    for i, line in enumerate(lines):
        m = SCRIPT_ERROR.search(line)
        if not m:
            continue
        where = ""
        for nxt in lines[i + 1:i + 3]:
            w = WHERE.match(nxt)
            if w:
                where = w.group(1).strip()
                break
        found.append(f"{m.group(1).strip()} @ {where}")
    return found


def load(step: str):
    fails, errors, section = set(), set(), None
    if not KNOWN.exists():
        return fails, errors
    for raw in KNOWN.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section == step and line.startswith("script_error:"):
            errors.add(line.split(":", 1)[1].strip())
        elif section == step:
            fails.add(normalise(line))
    return fails, errors


def main() -> int:
    step, status = sys.argv[1], int(sys.argv[2])
    output = sys.stdin.read()
    seen = {normalise(l) for l in output.splitlines()
            if re.match(r"^\s*FAIL\b", ANSI.sub("", l))}
    errors = script_errors(output)
    allowed, allowed_errors = load(step)

    ok = True
    for line in sorted(seen - allowed):
        print(f"  NEW   {line}")
        ok = False
    for err in sorted(set(errors) - allowed_errors):
        print(f"  NEW   {err}")
        ok = False
    if status != 0 and not seen and not errors:
        print(f"  exited {status} without saying which check failed")
        ok = False
    for line in sorted(allowed - seen):
        print(f"  note  now passing -- remove from test/known_failures.txt: {line}")
    for err in sorted(allowed_errors - set(errors)):
        print(f"  note  gone -- remove from test/known_failures.txt: script_error: {err}")
    if ok and (seen or errors):
        print(f"  known failures only ({len(seen)} checks, {len(errors)} script errors)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
