#!/usr/bin/env python3
"""Print the current version's release notes from docs/store-listing.md.

The listing marks them with <!-- release-notes:ja --> followed by a fenced
block, under a heading that names the version in project.godot. Both stores'
submissions read them from here, so there is one copy to edit.
"""
import re
import sys

lang = sys.argv[1] if len(sys.argv) > 1 else "ja"
version = re.search(r'^config/version="(.*)"$', open("project.godot").read(), re.M).group(1)
text = open("docs/store-listing.md").read()
match = re.search(r"リリースノート（" + re.escape(version) + r"）\*\*\s*\n\s*<!-- release-notes:"
                  + re.escape(lang) + r" -->\s*\n```\n(.*?)\n```", text, re.S)
if not match:
    sys.exit(f"no release notes for {version} ({lang}) in docs/store-listing.md")
print(match.group(1).strip())
