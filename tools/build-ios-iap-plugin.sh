#!/usr/bin/env bash
# Build the StoreKit plugin (godot-ios-plugins' inappstore) for this project.
#
#   tools/build-ios-iap-plugin.sh
#
# Called by tools/install-iap-plugins.sh ios. Needs macOS with Xcode, scons and
# python3; it is not runnable anywhere else and says so rather than failing
# halfway through.
#
# WHY FROM SOURCE. The plugin's last binary release is 3.5-stable (2022) and is
# a Godot 3 build. There is no prebuilt Godot 4 artifact anywhere, so a
# checksum-pinned zip -- which is what the Android half gets -- does not exist
# to pin. What is pinned instead is the exact commit of the plugin repository
# and the exact engine tag its headers come from, which is the same promise by
# other means: the same two inputs produce the same plugin.
#
# An iOS plugin is a static library that is LINKED INTO the exported app, so it
# must be compiled against the headers of the engine version that app is built
# with. Building against 4.0 headers and shipping on 4.7 is how a plugin
# becomes a link error, or worse, a crash on a device and not in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
PROJECT="$PWD"

REPO="${IOS_PLUGIN_REPO:-https://github.com/godot-sdk-integrations/godot-ios-plugins}"
COMMIT="${IOS_PLUGIN_COMMIT:?IOS_PLUGIN_COMMIT is not set}"
GODOT_TAG="${IOS_GODOT_TAG:-4.7.2-stable}"
WORK="${IOS_PLUGIN_WORKDIR:-${RUNNER_TEMP:-/tmp}/godot-ios-plugins}"

[ "$(uname -s)" = "Darwin" ] || { echo "the iOS plugin can only be built on macOS" >&2; exit 2; }
for cmd in git scons xcodebuild lipo; do
	command -v "$cmd" >/dev/null || { echo "$cmd is required" >&2; exit 2; }
done

echo "== fetch the plugin source @ ${COMMIT:0:12} =="
rm -rf "$WORK"
mkdir -p "$WORK"
git -C "$WORK" init -q
git -C "$WORK" remote add origin "$REPO"
git -C "$WORK" fetch -q --depth 1 origin "$COMMIT"
git -C "$WORK" checkout -q FETCH_HEAD

echo "== fetch the engine headers @ $GODOT_TAG =="
# The build only reads headers out of this tree; nothing in it is compiled.
# A tag-depth-1 clone is about a tenth of the full history.
git clone -q --depth 1 --branch "$GODOT_TAG" \
	https://github.com/godotengine/godot.git "$WORK/godot"

echo "== compile inappstore (device + both simulators, release and debug) =="
cd "$WORK"
# `version=4.0` is the SConstruct's name for "the Godot 4 API", not a claim
# about which 4.x this is; the headers above decide that.
./scripts/generate_xcframework.sh inappstore release 4.0
./scripts/generate_xcframework.sh inappstore release_debug 4.0
mv ./bin/inappstore.release_debug.xcframework ./bin/inappstore.debug.xcframework

echo "== install into the project =="
# res://ios/plugins is where Godot looks. The .gdip names
# binary="inappstore.xcframework" and the engine resolves that to the
# .debug/.release pair beside it, which is the layout the plugin's own
# release script produces.
DEST="$PROJECT/ios/plugins"
rm -rf "$DEST/inappstore.release.xcframework" "$DEST/inappstore.debug.xcframework"
mkdir -p "$DEST"
cp -R ./bin/inappstore.release.xcframework "$DEST/"
cp -R ./bin/inappstore.debug.xcframework "$DEST/"
cp ./plugins/inappstore/inappstore.gdip "$DEST/"

echo "   $(ls "$DEST" | tr '\n' ' ')"
