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
APP_VERSION="${APP_VERSION:-0.9.0}"
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

# Reserve a higher build-number range than earlier Codemagic/TestFlight uploads
# (which have already reached 1037). For manual/local invocation callers can
# still set BUILD_NUMBER explicitly.
if [ -z "${BUILD_NUMBER:-}" ]; then
	if [[ "${GITHUB_RUN_NUMBER:-}" =~ ^[0-9]+$ ]]; then
		BUILD_NUMBER=$((10000 + GITHUB_RUN_NUMBER))
	else
		BUILD_NUMBER=1001
	fi
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

echo "== validate and upload to App Store Connect =="
app-store-connect publish \
	--path "$IPA" \
	--enable-package-validation

echo "== submitted =="
echo "App Store Connect accepted the signed upload. Apple will process it before it appears in TestFlight/App Store Connect."
