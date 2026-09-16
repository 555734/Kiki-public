#!/usr/bin/env python3
"""Fail if tracked files contain common credentials or private signing material.

This intentionally checks only tracked HEAD content. It cannot prove that old
Git history or another branch is clean; publication must account for those too.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

FORBIDDEN_SUFFIXES = {
    ".p8", ".p12", ".pfx", ".pem", ".key", ".jks", ".keystore",
    ".mobileprovision", ".provisionprofile",
}
FORBIDDEN_NAMES = {
    ".env", ".dev.vars", ".npmrc", ".pypirc", ".netrc",
    "google-services.json", "GoogleService-Info.plist",
}
TEXT_PATTERNS = [
    ("private key block", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    ("GitHub classic token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("GitHub fine-grained token", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,}\b")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b")),
]

# Documentation and source code may legitimately mention token prefixes or
# secret filenames. We scan for concrete token-shaped values, not words such as
# "password" or "secret" by themselves.

def tracked_files() -> list[Path]:
    out = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode("utf-8", errors="strict")
    return [ROOT / p for p in out.split("\0") if p]


def main() -> int:
    problems: list[str] = []
    for path in tracked_files():
        rel = path.relative_to(ROOT).as_posix()
        name = path.name
        suffix = path.suffix.lower()

        if suffix in FORBIDDEN_SUFFIXES:
            problems.append(f"tracked private/signing file: {rel}")
        if name in FORBIDDEN_NAMES or name.startswith(".env.") or name.startswith(".dev.vars."):
            if name not in {".env.example", ".dev.vars.example"}:
                problems.append(f"tracked credential/config file: {rel}")

        try:
            data = path.read_bytes()
        except OSError as exc:
            problems.append(f"cannot read tracked file {rel}: {exc}")
            continue
        if b"\0" in data:
            continue
        text = data.decode("utf-8", errors="ignore")
        for label, pattern in TEXT_PATTERNS:
            if pattern.search(text):
                problems.append(f"{label}: {rel}")

    if problems:
        print("PUBLIC-SAFETY CHECK FAILED", file=sys.stderr)
        for problem in sorted(set(problems)):
            print(f" - {problem}", file=sys.stderr)
        print(
            "\nDo not make the repository public. Remove/rotate credentials and "
            "check old history and every branch as well.",
            file=sys.stderr,
        )
        return 1

    print("PUBLIC-SAFETY CHECK PASSED for tracked files in the current checkout.")
    print("Reminder: old Git history and other branches require separate review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
