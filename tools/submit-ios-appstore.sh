#!/usr/bin/env bash
# Build, sign with an Apple Distribution certificate and App Store provisioning
# profile fetched through Codemagic CLI tools, then upload to App Store Connect.
# This intentionally mirrors the repository's proven Codemagic TestFlight path
# and does not use Xcode Cloud Signing.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
APP_VERSION="${APP_VERSION:-0.9.3}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_PRIVATE_KEY="${ASC_PRIVATE_KEY:-}"
IOS_CERTIFICATE_PRIVATE_KEY="${IOS_CERTIFICATE_PRIVATE_KEY:-}"
OUT="${OUT:-$PWD/build/ios}"
STAGE="$OUT/appstore"
IPA_DIR="$STAGE/ipa"
ARCHIVE_DIR="$STAGE/xcarchive"

[ -x "$GODOT" ] || { echo "GODOT is not executable: $GODOT"; exit 1; }
[ -n "$APPLE_TEAM_ID" ] || { echo "APPLE_TEAM_ID is not set"; exit 1; }
[ -n "$BUNDLE_ID" ] || { echo "BUNDLE_ID is not set"; exit 1; }
[ -n "$APP_VERSION" ] || { echo "APP_VERSION is not set"; exit 1; }
[ -n "$ASC_KEY_ID" ] || { echo "ASC_KEY_ID is not set"; exit 1; }
[ -n "$ASC_ISSUER_ID" ] || { echo "ASC_ISSUER_ID is not set"; exit 1; }
[ -n "$ASC_PRIVATE_KEY" ] || { echo "ASC_PRIVATE_KEY is not set"; exit 1; }
[ -n "$IOS_CERTIFICATE_PRIVATE_KEY" ] || { echo "IOS_CERTIFICATE_PRIVATE_KEY is not set"; exit 1; }
for cmd in app-store-connect keychain xcode-project; do
	command -v "$cmd" >/dev/null || { echo "$cmd is not installed"; exit 1; }
done

rm -rf "$STAGE"
mkdir -p "$STAGE" "$IPA_DIR" "$ARCHIVE_DIR"

# Codemagic CLI tools consume these standard environment variable names.
export APP_STORE_CONNECT_KEY_IDENTIFIER="$ASC_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="$ASC_ISSUER_ID"
export APP_STORE_CONNECT_PRIVATE_KEY="$ASC_PRIVATE_KEY"
export CERTIFICATE_PRIVATE_KEY="$IOS_CERTIFICATE_PRIVATE_KEY"

# The build number is minutes since 2026-01-01 UTC (~385000 in late 2026). It used
# to be 10000 + GITHUB_RUN_NUMBER, but the standalone iOS workflow and the
# Mobile Android + iOS workflow count their runs separately, so both reached
# run 38 and App Store Connect refused the second 10038. A timestamp only ever
# goes up whichever workflow uploads, is far above every earlier number, and
# stays a small plain integer.
# For manual/local invocation callers can still set BUILD_NUMBER explicitly.
if [ -z "${BUILD_NUMBER:-}" ]; then
	BUILD_NUMBER=$(( ($(date -u +%s) - 1767225600) / 60 ))
fi
export APPLE_TEAM_ID BUNDLE_ID APP_VERSION BUILD_NUMBER
bash tools/ios-identity.sh

echo "== prepare signing material =="
keychain initialize
app-store-connect fetch-signing-files "$BUNDLE_ID" \
	--platform IOS \
	--type IOS_APP_STORE \
	--strict-match-identifier \
	--certificate-key "@env:IOS_CERTIFICATE_PRIVATE_KEY" \
	--create
keychain add-certificates

echo "== import =="
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true

echo "== export Xcode project =="
"$GODOT" --headless --path . --export-release "iOS" "$STAGE/side-sky.ipa" 2>&1 \
	| grep -viE '^Godot Engine|^$' || true

PROJ="$(find "$STAGE" -maxdepth 2 -name '*.xcodeproj' -print -quit)"
if [ -z "$PROJ" ]; then
	echo "Godot did not produce an Xcode project"
	find "$STAGE" -maxdepth 3 | head -60
	exit 1
fi

# The StoreKit plugin is linked only when the preset turns it on; a project
# without it builds and uploads fine and has no store at all (0.9.2 build
# 398118 shipped that way). Refuse to go on without it.
if ! grep -q 'inappstore' "$PROJ/project.pbxproj"; then
	echo "the exported Xcode project does not link the StoreKit plugin (inappstore)" >&2
	exit 1
fi
echo "   StoreKit plugin linked: yes"

INFO_PLIST="$(find "$STAGE" -maxdepth 3 -name '*-Info.plist' -print -quit)"
if [ -n "$INFO_PLIST" ]; then
	python3 tools/ios-plist-clean.py "$INFO_PLIST"
fi

xcodebuild -list -project "$PROJ" | tee "$STAGE/xcodebuild-list.log"
SCHEME="$(awk '/Schemes:/{f=1;next} f&&NF{print $1;exit}' "$STAGE/xcodebuild-list.log")"
if [ -z "$SCHEME" ]; then
	echo "No shared Xcode scheme was found"
	exit 1
fi

echo "   project: $PROJ"
echo "   scheme:  $SCHEME"
echo "   team:    $APPLE_TEAM_ID"
echo "   bundle:  $BUNDLE_ID"
echo "   version: $APP_VERSION ($BUILD_NUMBER)"

echo "== apply App Store provisioning profile =="
xcode-project use-profiles --project "$PROJ"

echo "== build signed App Store IPA =="
xcode-project build-ipa \
	--project "$PROJ" \
	--scheme "$SCHEME" \
	--config Release \
	--archive-directory "$ARCHIVE_DIR" \
	--ipa-directory "$IPA_DIR" \
	--disable-xcpretty

IPA="$(find "$IPA_DIR" -maxdepth 2 -name '*.ipa' -print -quit)"
if [ -z "$IPA" ]; then
	echo "Signed build completed without an IPA"
	find "$STAGE" -maxdepth 4
	exit 1
fi

cp "$IPA" "$OUT/side-sky-appstore.ipa"
IPA="$OUT/side-sky-appstore.ipa"

# The same check on what was actually built: the singleton's name is a string
# literal in the plugin, so a binary without it has no StoreKit.
CHECK_DIR="$(mktemp -d)"
unzip -q "$IPA" 'Payload/*' -d "$CHECK_DIR"
APP_BIN="$(find "$CHECK_DIR/Payload" -maxdepth 2 -type f -perm -u+x ! -name '*.dylib' | head -1)"
if ! grep -aq 'InAppStore' "$APP_BIN"; then
	echo "the signed app binary has no InAppStore singleton" >&2
	exit 1
fi
echo "   InAppStore in the app binary: yes"
rm -rf "$CHECK_DIR"

# A rehearsal proves everything up to here -- StoreKit, the certificate and
# profile, signing, the App Store export -- and stops before anything leaves
# the runner. See .github/workflows/store-rehearsal.yml.
if [ "${SKIP_UPLOAD:-0}" = "1" ]; then
	echo "== rehearsal: signed App Store IPA built, not uploaded =="
	ls -l "$IPA"
	exit 0
fi

echo "== validate and upload to App Store Connect =="
if [ "${SUBMIT_FOR_REVIEW:-false}" = "true" ]; then
	# What's New comes from the listing, the one place release notes are kept.
	NOTES="$STAGE/whats-new.txt"
	python3 tools/release-notes.py ja > "$NOTES"
	[ -s "$NOTES" ] || { echo "docs/store-listing.md has no release notes for this version" >&2; exit 1; }
	app-store-connect publish \
		--path "$IPA" \
		--enable-package-validation \
		--app-store \
		--version-string "$APP_VERSION" \
		--release-type AFTER_APPROVAL \
		--cancel-previous-submissions \
		--max-build-processing-wait 90 \
		--whats-new "@file:$NOTES"
else
	app-store-connect publish \
		--path "$IPA" \
		--enable-package-validation
fi

echo "== submitted =="
echo "App Store Connect accepted the signed upload. Apple will process it before it appears in TestFlight/App Store Connect."
