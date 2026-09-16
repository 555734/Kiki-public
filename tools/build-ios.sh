#!/usr/bin/env bash
# Builds an UNSIGNED iOS .ipa. Runs on macOS only -- Xcode is required.
#
#   GODOT=/path/to/godot tools/build-ios.sh
#
# Godot is asked for an Xcode project rather than a finished app, because
# signing needs an Apple developer identity that neither CI nor a fresh
# checkout has. xcodebuild then compiles it with signing switched off, and the
# .app is zipped into the Payload/ layout an .ipa expects.
#
# NOT YET VERIFIED ON HARDWARE. No macOS machine has run this. It is written to
# fail loudly and keep its logs for that reason -- see the log handling below.
#
# The result cannot be installed by tapping it. Sideload it with AltStore or
# Sideloadly, which re-sign it with your own Apple ID -- a free account works
# and gives a build that runs for seven days. With a paid account, open the
# generated Xcode project instead and build to the device directly.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
OUT="${OUT:-$PWD/build/ios}"
STAGE="$OUT/xcode"
rm -rf "$STAGE" && mkdir -p "$STAGE"

echo "== import =="
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true

# On macOS, Godot does not stop at writing the project: it goes on to archive it
# with xcodebuild, and that archive fails. The project Godot generates uses
# automatic signing with a placeholder team, and a build machine has no Apple
# account to satisfy it. application/export_project_only=true does not prevent
# this in 4.4.1 -- the option exists in the binary but the archive is attempted
# regardless.
#
# That failure is expected and is NOT this build's failure. The Xcode project is
# written before the archive is attempted, so it survives; the real build happens
# below with signing switched off entirely. The only thing that matters is
# whether the project is there, which is what the next block checks.
echo "== export Xcode project (Godot's own archive attempt is expected to fail) =="
"$GODOT" --headless --path . --export-release "iOS" "$STAGE/side-sky.ipa" 2>&1 \
	| grep -viE "^Godot Engine|^$" || true

PROJ="$(find "$STAGE" -maxdepth 2 -name '*.xcodeproj' -print -quit)"
if [ -z "$PROJ" ]; then
	echo "no Xcode project produced -- so Godot failed BEFORE writing it, which is"
	echo "a real failure rather than the expected archive one. Check the preset."
	echo "what Godot did write:"
	find "$STAGE" -maxdepth 3 | head -40
	exit 1
fi

# Ask the project what it actually contains rather than assuming the scheme is
# named after the file. A generated project's schemes are not always shared, and
# `-scheme` on a name that is not there fails with a message that reads like a
# build error. Falling back to -target keeps the first run from dying on this.
echo "== inspect project =="
xcodebuild -list -project "$PROJ" | tee "$STAGE/xcodebuild-list.log" || true
SCHEME="$(awk '/Schemes:/{f=1;next} f&&NF{print $1;exit}' "$STAGE/xcodebuild-list.log")"
TARGET="$(awk '/Targets:/{f=1;next} f&&NF{print $1;exit}' "$STAGE/xcodebuild-list.log")"
if [ -n "$SCHEME" ]; then
	SELECTOR=(-scheme "$SCHEME")
	echo "   project: $PROJ  (scheme $SCHEME)"
elif [ -n "$TARGET" ]; then
	SELECTOR=(-target "$TARGET")
	echo "   project: $PROJ  (no shared scheme; building target $TARGET)"
else
	SELECTOR=(-target "$(basename "$PROJ" .xcodeproj)")
	echo "   project: $PROJ  (falling back to the project name as the target)"
fi

# The full log is kept. This script has never run on real hardware here, so the
# first person to run it should get the actual error rather than the last five
# lines of a build that failed somewhere in the middle.
echo "== xcodebuild (unsigned) =="
# CODE_SIGN_STYLE=Manual matters as much as the ALLOWED=NO flags. Godot writes
# the project with automatic signing and a DEVELOPMENT_TEAM, and automatic
# signing makes Xcode go looking for an account and a provisioning profile for
# the bundle id -- which fails on a build machine that has neither, even when
# signing is switched off. Forcing manual with everything blanked stops it
# looking at all. The entitlements file is cleared for the same reason.
if ! xcodebuild -project "$PROJ" "${SELECTOR[@]}" -configuration Release \
		-sdk iphoneos -derivedDataPath "$STAGE/dd" \
		CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" CODE_SIGN_ENTITLEMENTS="" \
		CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
		build > "$STAGE/xcodebuild.log" 2>&1; then
	echo "xcodebuild failed. Last 60 lines (full log at $STAGE/xcodebuild.log):"
	tail -60 "$STAGE/xcodebuild.log"
	exit 1
fi
tail -3 "$STAGE/xcodebuild.log"

APP="$(find "$STAGE/dd/Build/Products" -maxdepth 2 -name '*.app' -print -quit)"
if [ -z "$APP" ]; then
	echo "xcodebuild reported success but produced no .app. Products tree:"
	find "$STAGE/dd/Build/Products" -maxdepth 3 2>/dev/null | head -30
	exit 1
fi

echo "== package =="
rm -rf "$OUT/Payload" && mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
(cd "$OUT" && rm -f side-sky-unsigned.ipa && zip -qr side-sky-unsigned.ipa Payload)
rm -rf "$OUT/Payload"

echo "== verify =="
# NOT `| grep -q`. With pipefail set, grep exits on the first match, SIGPIPEs
# unzip, and the pipeline reports failure *because* it matched -- so a correct
# .ipa fails the check. build-android.sh already carries a comment about this
# exact trap; it was fixed there and missed here, and it cost a build.
entries=$(unzip -l "$OUT/side-sky-unsigned.ipa" | grep -c "Payload/.*\.app/" || true)
[ "$entries" -gt 0 ] || { echo "the .ipa has no app payload"; exit 1; }
BYTES=$(unzip -l "$OUT/side-sky-unsigned.ipa" | tail -1 | awk '{print $1}')
printf '  side-sky-unsigned.ipa  %s  (%s bytes of payload)\n' \
	"$(du -h "$OUT/side-sky-unsigned.ipa" | cut -f1)" "$BYTES"
