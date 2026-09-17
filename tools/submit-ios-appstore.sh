#!/usr/bin/env bash
# Build, cloud-sign, validate, and upload SIDE / SKY to App Store Connect.
#
# Required environment:
#   GODOT              path to Godot 4.4.1 executable
#   APPLE_TEAM_ID      Apple Developer Team ID
#   BUNDLE_ID          App Store bundle identifier
#   APP_VERSION        CFBundleShortVersionString, e.g. 0.2.3
#   ASC_KEY_ID         App Store Connect API key ID
#   ASC_ISSUER_ID      App Store Connect API issuer ID
#   ASC_PRIVATE_KEY    complete AuthKey_*.p8 contents
#
# No distribution certificate or provisioning profile is stored in GitHub.
# Xcode automatic signing + App Store Connect API-key authentication uses
# Apple's cloud signing service. The final IPA is validated and uploaded with
# altool. Xcode is allowed to manage the build number during distribution so a
# new CI run does not collide with an older TestFlight build number.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
BUNDLE_ID="${BUNDLE_ID:-}"
APP_VERSION="${APP_VERSION:-0.2.3}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_PRIVATE_KEY="${ASC_PRIVATE_KEY:-}"
OUT="${OUT:-$PWD/build/ios}"
STAGE="$OUT/appstore"
ARCHIVE="$STAGE/side-sky.xcarchive"
EXPORT_DIR="$STAGE/export"

[ -x "$GODOT" ] || { echo "GODOT is not executable: $GODOT"; exit 1; }
[ -n "$APPLE_TEAM_ID" ] || { echo "APPLE_TEAM_ID is not set"; exit 1; }
[ -n "$BUNDLE_ID" ] || { echo "BUNDLE_ID is not set"; exit 1; }
[ -n "$APP_VERSION" ] || { echo "APP_VERSION is not set"; exit 1; }
[ -n "$ASC_KEY_ID" ] || { echo "ASC_KEY_ID is not set"; exit 1; }
[ -n "$ASC_ISSUER_ID" ] || { echo "ASC_ISSUER_ID is not set"; exit 1; }
[ -n "$ASC_PRIVATE_KEY" ] || { echo "ASC_PRIVATE_KEY is not set"; exit 1; }

rm -rf "$STAGE"
mkdir -p "$STAGE" "$EXPORT_DIR"

# Both xcodebuild and altool can authenticate with the same App Store Connect
# API key. altool looks in this standard directory for AuthKey_<ID>.p8.
KEY_DIR="$HOME/.appstoreconnect/private_keys"
KEY_PATH="$KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"
mkdir -p "$KEY_DIR"
printf '%s\n' "$ASC_PRIVATE_KEY" | tr -d '\r' > "$KEY_PATH"
chmod 600 "$KEY_PATH"
cleanup() {
	rm -f "$KEY_PATH"
}
trap cleanup EXIT

# The archive only needs a syntactically valid build number. During App Store
# distribution Xcode's manageAppVersionAndBuildNumber option asks Apple for the
# appropriate next build number, avoiding collisions with earlier CI systems.
export APPLE_TEAM_ID BUNDLE_ID APP_VERSION
export BUILD_NUMBER="${BUILD_NUMBER:-1}"
bash tools/ios-identity.sh

echo "== import =="
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1 || true

echo "== export Xcode project =="
# Godot 4.4.1 attempts its own archive after writing the Xcode project. On a
# clean runner that attempt can fail before Xcode has authenticated. The project
# is the artifact we need here, so inspect it explicitly after the command.
"$GODOT" --headless --path . --export-release "iOS" "$STAGE/side-sky.ipa" 2>&1 \
	| grep -viE '^Godot Engine|^$' || true

PROJ="$(find "$STAGE" -maxdepth 2 -name '*.xcodeproj' -print -quit)"
if [ -z "$PROJ" ]; then
	echo "Godot did not produce an Xcode project"
	find "$STAGE" -maxdepth 3 | head -60
	exit 1
fi

# Godot-generated plist values occasionally need normalization before Xcode's
# distribution validation. Keep using the repository's existing cleaner.
INFO_PLIST="$(find "$STAGE" -maxdepth 3 -name '*-Info.plist' -print -quit)"
if [ -n "$INFO_PLIST" ]; then
	python3 tools/ios-plist-clean.py "$INFO_PLIST"
fi

echo "== inspect project =="
xcodebuild -list -project "$PROJ" | tee "$STAGE/xcodebuild-list.log"
SCHEME="$(awk '/Schemes:/{f=1;next} f&&NF{print $1;exit}' "$STAGE/xcodebuild-list.log")"
if [ -z "$SCHEME" ]; then
	echo "No shared Xcode scheme was found; cannot create a distributable archive"
	exit 1
fi
echo "   project: $PROJ"
echo "   scheme:  $SCHEME"
echo "   team:    $APPLE_TEAM_ID"
echo "   bundle:  $BUNDLE_ID"
echo "   version: $APP_VERSION"

echo "== archive with automatic cloud signing =="
# Godot's Xcode template carries a legacy explicit `iPhone Distribution`
# identity. That conflicts with CODE_SIGN_STYLE=Automatic before Xcode can use
# the API-key-backed cloud signing account. Override only the archive identity
# to Apple Development; the App Store export step re-signs the archive for
# distribution automatically.
if ! xcodebuild \
	-project "$PROJ" \
	-scheme "$SCHEME" \
	-configuration Release \
	-sdk iphoneos \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
	CODE_SIGN_STYLE=Automatic \
	CODE_SIGN_IDENTITY="Apple Development" \
	PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
	MARKETING_VERSION="$APP_VERSION" \
	archive > "$STAGE/archive.log" 2>&1; then
	echo "xcodebuild archive failed. Last 100 lines:"
	tail -100 "$STAGE/archive.log"
	exit 1
fi
tail -8 "$STAGE/archive.log"

cat > "$STAGE/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

echo "== export signed App Store IPA =="
if ! xcodebuild \
	-exportArchive \
	-archivePath "$ARCHIVE" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$STAGE/ExportOptions.plist" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	> "$STAGE/export.log" 2>&1; then
	echo "xcodebuild -exportArchive failed. Last 100 lines:"
	tail -100 "$STAGE/export.log"
	exit 1
fi
tail -8 "$STAGE/export.log"

IPA="$(find "$EXPORT_DIR" -maxdepth 2 -name '*.ipa' -print -quit)"
if [ -z "$IPA" ]; then
	echo "Xcode reported success but produced no IPA"
	find "$EXPORT_DIR" -maxdepth 3
	exit 1
fi

# Keep a predictable local path for diagnostics without publishing the signed
# App Store package as a public GitHub Release.
cp "$IPA" "$OUT/side-sky-appstore.ipa"
IPA="$OUT/side-sky-appstore.ipa"

echo "== validate with App Store Connect =="
xcrun altool --validate-app \
	-f "$IPA" -t ios \
	--apiKey "$ASC_KEY_ID" \
	--apiIssuer "$ASC_ISSUER_ID" \
	--output-format json | tee "$STAGE/altool-validate.log"

echo "== upload to App Store Connect =="
xcrun altool --upload-app \
	-f "$IPA" -t ios \
	--apiKey "$ASC_KEY_ID" \
	--apiIssuer "$ASC_ISSUER_ID" \
	--output-format json | tee "$STAGE/altool-upload.log"

echo "== submitted =="
echo "App Store Connect accepted the upload request. Apple will process the build before it appears in TestFlight/App Store Connect."
