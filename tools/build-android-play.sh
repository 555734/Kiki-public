#!/usr/bin/env bash
# Produces the one Google Play submission artifact: a signed Vulkan/mobile AAB.
# A stable upload keystore is mandatory; this script never creates one.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
OUT="${OUT:-$PWD/build/android}"
VERSION_CODE="${VERSION_CODE:-24}"
VERSION_NAME="${VERSION_NAME:-0.2.4}"

: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the stable Play upload keystore path}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?set the Play upload key alias}"
: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set the Play upload key password}"

case "$VERSION_CODE" in
	''|*[!0-9]*) echo "VERSION_CODE must be a positive integer" >&2; exit 1 ;;
esac
[ "$VERSION_CODE" -gt 0 ] || { echo "VERSION_CODE must be greater than zero" >&2; exit 1; }
[ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ] || {
	echo "Play upload keystore not found" >&2
	exit 1
}

mkdir -p "$OUT"
rm -f "$OUT/side-sky-play.aab"

if command -v xvfb-run >/dev/null 2>&1; then
	godot_run() { xvfb-run -a "$GODOT" "$@" 2>&1; }
else
	godot_run() { "$GODOT" "$@" 2>&1; }
fi

cp project.godot project.godot.play.bak
cp export_presets.cfg export_presets.cfg.play.bak
cp src/autoload/balance.gd src/autoload/balance.gd.play.bak
restore() {
	[ ! -f project.godot.play.bak ] || mv project.godot.play.bak project.godot
	[ ! -f export_presets.cfg.play.bak ] || mv export_presets.cfg.play.bak export_presets.cfg
	[ ! -f src/autoload/balance.gd.play.bak ] || mv src/autoload/balance.gd.play.bak src/autoload/balance.gd
	return 0
}
trap restore EXIT

# Play requires a monotonically increasing version code. The caller supplies it
# explicitly because only Play Console knows the last accepted value.
sed -E -i "/^\[preset\.3\.options\]/,/^\[preset\./ s/^version\/code=.*/version\/code=$VERSION_CODE/" export_presets.cfg
sed -E -i "/^\[preset\.3\.options\]/,/^\[preset\./ s/^version\/name=.*/version\/name=\"$VERSION_NAME\"/" export_presets.cfg
sed -E -i 's#renderer/rendering_method.mobile="(mobile|gl_compatibility)"#renderer/rendering_method.mobile="mobile"#' project.godot
STAMP="${BUILD_STAMP:-play-${VERSION_CODE}}"
sed -i "s/^const BUILD_ID: String = \"dev\"/const BUILD_ID: String = \"$STAMP\"/" src/autoload/balance.gd

echo "== install Android Gradle template =="
bash tools/install-android-template.sh
python3 tools/configure-eosg-android.py
echo "== import Vulkan/mobile project =="
godot_run --headless --editor --import --path . >/dev/null
echo "== build signed Google Play AAB ($VERSION_NAME / $VERSION_CODE) =="
godot_run --headless --path . --export-release "Android Play" "$OUT/side-sky-play.aab" \
	| tee "$OUT/export-play.log"

[ -s "$OUT/side-sky-play.aab" ] || { echo "MISSING: side-sky-play.aab" >&2; exit 1; }
jarsigner -verify "$OUT/side-sky-play.aab" >/dev/null 2>&1 || {
	echo "INVALID OR UNSIGNED: side-sky-play.aab" >&2
	exit 1
}
unzip -tq "$OUT/side-sky-play.aab" >/dev/null
echo "Store artifact: $OUT/side-sky-play.aab"
