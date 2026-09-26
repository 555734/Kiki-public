#!/usr/bin/env bash
# Restore the in-app-purchase plugins, the way tools/install-eosg.sh restores
# EOSG: fetched at build time, checksum-verified, never committed.
#
#   tools/install-iap-plugins.sh android
#   tools/install-iap-plugins.sh ios
#
# UNPINNED ON PURPOSE. The two SHA256 lines below are empty because nobody has
# chosen a release yet, and a checksum invented by somebody who never saw the
# file is worse than none: it would be checked, it would pass, and it would
# mean nothing. Filling them in is the last step before the first store build,
# and docs/monetization.md has the two commands.
#
# Until they are filled in this script refuses to run, and the CI step that
# calls it is opt-in (IAP_PLUGINS=1). A build without these plugins is a build
# where Iap.available() is false: the game plays, the store does not exist, and
# nothing silently half-works.
set -euo pipefail
cd "$(dirname "$0")/.."

# ---- pin these two ---------------------------------------------------------
ANDROID_VERSION="3.3.0"
ANDROID_URL="https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/v${ANDROID_VERSION}/GodotGooglePlayBilling-${ANDROID_VERSION}.zip"
ANDROID_SHA256=""

IOS_VERSION=""
IOS_URL=""
IOS_SHA256=""
# ----------------------------------------------------------------------------

fetch() {
	name="$1"; url="$2"; expected="$3"; marker="$4"
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
	unpack=$(mktemp -d "${TMPDIR:-/tmp}/side-sky-iap.XXXXXX")
	unzip -q -o "$zip" -d "$unpack"
	# Release archives wrap the addon in one top-level folder, the same shape
	# EOSG uses; merging its contents puts the addon at res://addons/.
	if [ -d "$unpack/addons" ]; then
		cp -R "$unpack/." .
	else
		inner=$(find "$unpack" -maxdepth 2 -type d -name addons | head -1)
		[ -n "$inner" ] || { echo "$name: no addons/ in the archive" >&2; exit 1; }
		cp -R "$(dirname "$inner")/." .
	fi
	rm -rf "$unpack"
	test -e "$marker" || { echo "$name: $marker missing after install" >&2; exit 1; }
	echo "$name plugin installed"
}

[ "$#" -gt 0 ] || { echo "usage: $0 <android|ios>..." >&2; exit 2; }
for target in "$@"; do
	case "$target" in
		android)
			fetch android "$ANDROID_URL" "$ANDROID_SHA256" \
				"addons/GodotGooglePlayBilling/BillingClient.gd"
			# The plugin ships an EditorExportPlugin, which only runs when the
			# addon is enabled in project.godot. Switched on here, at the
			# moment the files exist, rather than committed -- see the script.
			python3 tools/enable-editor-plugin.py GodotGooglePlayBilling ;;
		ios) fetch ios "$IOS_URL" "$IOS_SHA256" \
			"ios/plugins/inappstore.gdip" ;;
		*) echo "unsupported target: $target" >&2; exit 2 ;;
	esac
done
