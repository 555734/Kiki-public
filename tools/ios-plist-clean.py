#!/usr/bin/env python3
"""Fixes and checks the Info.plist Godot generates, before it costs an upload.

Every rule here was learned by having App Store Connect reject a build, which
takes a full CI round trip each time. They are cheap to check locally and there
was no reason to keep discovering them one at a time.

    tools/ios-plist-clean.py build/ios/xcode/side-sky/side-sky-Info.plist
"""
import plistlib
import sys

# Empty purpose strings. Godot writes these unconditionally; an empty one
# declares a privacy-sensitive capability and then declines to say why, which
# review flags. This game uses none of them.
DROP_IF_EMPTY = [
    "NSCameraUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSMicrophoneUsageDescription",
]

# Godot adds this for the Metal renderer. Apple rejects the upload outright --
# "incompatible with the MinimumOSVersion value of ..." -- and raising the
# minimum does not satisfy it; 14.0 and 16.0 were both refused. It is also
# simply wrong for this game: it declares that a 2D platformer requires a
# gaming-tier iPhone. Removing it costs nothing and the app runs everywhere the
# deployment target allows.
DROP_CAPABILITIES = ["iphone-performance-gaming-tier"]


def clean(path: str) -> int:
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)

    changed = []

    for key in DROP_IF_EMPTY:
        if key in plist and not str(plist[key]).strip():
            del plist[key]
            changed.append(key)

    caps = plist.get("UIRequiredDeviceCapabilities")
    if isinstance(caps, list):
        kept = [c for c in caps if c not in DROP_CAPABILITIES]
        if kept != caps:
            changed.append("UIRequiredDeviceCapabilities: %s"
                           % ", ".join(c for c in caps if c not in kept))
            if kept:
                plist["UIRequiredDeviceCapabilities"] = kept
            else:
                del plist["UIRequiredDeviceCapabilities"]

    if changed:
        with open(path, "wb") as handle:
            plistlib.dump(plist, handle)

    print("  removed: %s" % (", ".join(changed) if changed else "(nothing)"))
    return check(plist)


def check(plist: dict) -> int:
    """Refuses to hand Apple something it has already rejected once."""
    problems = []

    for cap in plist.get("UIRequiredDeviceCapabilities", []) or []:
        if cap in DROP_CAPABILITIES:
            problems.append("UIRequiredDeviceCapabilities still contains %r" % cap)

    for key in DROP_IF_EMPTY:
        if key in plist and not str(plist[key]).strip():
            problems.append("%s is present but empty" % key)

    if plist.get("ITSAppUsesNonExemptEncryption") is None:
        problems.append("ITSAppUsesNonExemptEncryption is missing "
                        "(TestFlight will ask about export compliance)")

    for problem in problems:
        print("  FAIL  %s" % problem)
    if not problems:
        print("  ok    App Store が一度拒否した条件には触れていません")
    return len(problems)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: ios-plist-clean.py <Info.plist>")
    raise SystemExit(1 if clean(sys.argv[1]) else 0)
