#!/usr/bin/env python3
"""Switch an addon on in project.godot's [editor_plugins] list, idempotently.

Used by tools/install-iap-plugins.sh at the moment the addon's files actually
arrive. Enabling it permanently in the committed project.godot would make every
checkout that has not run that script complain about a missing addon on every
editor launch -- including the ones the automated tests run in.
"""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main(addon: str) -> int:
    entry = f"res://addons/{addon}/plugin.cfg"
    path = ROOT / "project.godot"
    text = path.read_text(encoding="utf-8")
    marker = "enabled=PackedStringArray("
    try:
        at = text.index(marker) + len(marker)
        end = text.index(")", at)
    except ValueError:
        print("project.godot has no [editor_plugins] enabled list", file=sys.stderr)
        return 1
    if entry in text[at:end]:
        print(f"{entry} already enabled")
        return 0
    inner = text[at:end]
    joined = inner + (", " if inner.strip() else "") + f'"{entry}"'
    path.write_text(text[:at] + joined + text[end:], encoding="utf-8")
    print(f"enabled {entry}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: enable-editor-plugin.py <AddonFolderName>", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
