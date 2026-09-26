#!/usr/bin/env bash
# Restore the in-app-purchase plugins, the way tools/install-eosg.sh restores
# EOSG: fetched at build time, checksum-verified, never committed.
#
#   tools/install-iap-plugins.sh android
#   tools/install-iap-plugins.sh ios
#
# Android is a pinned release archive. iOS is not: godot-sdk-integrations'
# last BINARY release is 3.5-stable from 2022 and there has never been a
# prebuilt Godot 4 one, so the iOS half is built from a pinned commit on a
# macOS runner. That is the only way to get this plugin for Godot 4, and
# finding it out cost a round trip -- hence this note rather than a URL that
# looks plausible and 404s.
#
# A build without these plugins is a build where Iap.available() is false: the
# game plays, the store does not exist, and nothing silently half-works.
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Android: pinned release ----------------------------------------------
# The 3.x line is the Godot 4.2+ one (the 1.x line is Godot 3 maintenance --
# 1.4.0 is NEWER than 3.3.0 by date and is the wrong plugin for this project).
# The tag has no "v" and the asset is not named after the version; both were
# guessed wrong once already.
ANDROID_VERSION="3.3.0"
ANDROID_URL="https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/${ANDROID_VERSION}/godot-google-play-billing.zip"
ANDROID_SHA256="20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568"

# ---- iOS: pinned source ----------------------------------------------------
# master @ 2026-07-10. Built against the engine's own headers at the version
# this project ships, because an iOS plugin is a static library linked into
# the exported app and its symbols have to be the engine's.
IOS_PLUGIN_REPO="https://github.com/godot-sdk-integrations/godot-ios-plugins"
IOS_PLUGIN_COMMIT="caafb2c7fbfb5c72a64f163c76449274fa49abaa"
IOS_GODOT_TAG="${IOS_GODOT_TAG:-4.7.2-stable}"
# ----------------------------------------------------------------------------

fetch() {
	name="$1"; url="$2"; expected="$3"; marker="$4"; into="$5"
	if [ -z "$expected" ]; then
		echo "install-iap-plugins: $name is not pinned yet." >&2
		echo "  1. download: $url" >&2
		echo "  2. shasum -a 256 <the file>" >&2
		echo "  3. paste the digest into ${name^^}_SHA256 in this script" >&2
		exit 3
	fi
	zip="${RUNNER_TEMP:-/tmp}/iap-${name}.zip"
	curl --fail --location --silent --show-error "$url" --output "$zip"
	actual=$(shasum -a 256 "$zip" | awk '{print $1}')
	if [ "$actual" != "$expected" ]; then
		echo "$name checksum mismatch: $actual" >&2
		exit 1
	fi
	mkdir -p "$into"
	unzip -q -o "$zip" -d "$into"
	test -e "$marker" || { echo "$name: $marker missing after install" >&2; exit 1; }
	echo "$name plugin installed"
}

[ "$#" -gt 0 ] || { echo "usage: $0 <android|ios>..." >&2; exit 2; }
for target in "$@"; do
	case "$target" in
		android)
			# The archive's top level is GodotGooglePlayBilling/, not addons/,
			# so it unpacks INTO addons rather than over the project root.
			fetch android "$ANDROID_URL" "$ANDROID_SHA256" \
				"addons/GodotGooglePlayBilling/BillingClient.gd" "addons"
			# The plugin ships an EditorExportPlugin, which only runs when the
			# addon is enabled in project.godot. Switched on here, at the
			# moment the files exist, rather than committed -- see the script.
			"${PYTHON:-python3}" tools/enable-editor-plugin.py GodotGooglePlayBilling ;;
		ios)
			IOS_PLUGIN_REPO="$IOS_PLUGIN_REPO" \
			IOS_PLUGIN_COMMIT="$IOS_PLUGIN_COMMIT" \
			IOS_GODOT_TAG="$IOS_GODOT_TAG" \
				bash tools/build-ios-iap-plugin.sh
			test -e "ios/plugins/inappstore.gdip" \
				|| { echo "ios: ios/plugins/inappstore.gdip missing after build" >&2; exit 1; }
			echo "ios plugin installed" ;;
		*) echo "unsupported target: $target" >&2; exit 2 ;;
	esac
done
