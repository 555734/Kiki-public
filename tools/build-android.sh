#!/usr/bin/env bash
# Builds the Google Play AAB plus both Android APKs: the Vulkan (mobile
# renderer) build and the GLES3 (compatibility renderer) fallback.
#
#   GODOT=/path/to/godot ANDROID_HOME=/path/to/sdk tools/build-android.sh
#
# Requires: the matching Godot export templates installed, the Android SDK with
# build-tools (apksigner, zipalign) and platform-tools, and a JDK.
#
# Which renderer a build uses is a project setting rather than a preset option,
# so this flips project.godot between the two exports and puts it back.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
KEYSTORE="${KEYSTORE:-${HOME}/.android/side-sky-debug.keystore}"
KEYSTORE_USER="${KEYSTORE_USER:-androiddebugkey}"
KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-android}"
OUT="${OUT:-$PWD/build/android}"
mkdir -p "$OUT"
# Never mistake an earlier package for the result of a failed export.
rm -f "$OUT/side-sky-play.aab" "$OUT/side-sky-vulkan.apk" \
	"$OUT/side-sky-motorola-vulkan.apk" "$OUT/side-sky-gles3.apk"

# A reusable private key must never live in the repository. For local testing,
# create one under the current user's home directory and keep using it on that
# machine so APK upgrades still install cleanly. CI may point KEYSTORE at a
# runner-temporary path; those builds intentionally do not share a signing key.
if [ ! -f "$KEYSTORE" ]; then
	command -v keytool >/dev/null 2>&1 || {
		echo "keytool not found; install a JDK or set KEYSTORE to an existing test keystore" >&2
		exit 1
	}
	mkdir -p "$(dirname "$KEYSTORE")"
	keytool -genkeypair -noprompt \
		-keystore "$KEYSTORE" \
		-storepass "$KEYSTORE_PASSWORD" \
		-keypass "$KEYSTORE_PASSWORD" \
		-alias "$KEYSTORE_USER" \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=SIDE SKY Local Debug,O=Local Development,C=JP" >/dev/null
	chmod 600 "$KEYSTORE" 2>/dev/null || true
	echo "Created local test signing key: $KEYSTORE"
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEYSTORE_USER"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASSWORD"

# Godot's editor mode wants a display even with --headless on some builds, so
# use xvfb when it is available and fall back cleanly when it is not.
if command -v xvfb-run >/dev/null 2>&1; then
	godot_run() { xvfb-run -a "$GODOT" "$@" 2>&1; }
else
	godot_run() { "$GODOT" "$@" 2>&1; }
fi

# Cleanup helpers are used from an EXIT trap. They must always return success;
# otherwise `set -e` can turn a successful APK build into a failed CI job when
# a backup has already been restored earlier in the script.
restore() {
	if [ -f project.godot.bak ]; then
		mv project.godot.bak project.godot
	fi
	return 0
}
trap restore EXIT

# Stamp the build id, and put it back afterwards: a working tree that differs
# from HEAD only because a build ran is a trap for the next commit.
STAMP="${BUILD_STAMP:-$(git rev-parse --short HEAD 2>/dev/null || echo unknown)-$(date -u +%Y%m%d)}"
cp src/autoload/balance.gd /tmp/balance.pre-stamp
sed -i "s/^const BUILD_ID: String = \"dev\"/const BUILD_ID: String = \"$STAMP\"/" src/autoload/balance.gd
restore_stamp() {
	if [ -f /tmp/balance.pre-stamp ]; then
		mv /tmp/balance.pre-stamp src/autoload/balance.gd
	fi
	return 0
}
trap 'restore; restore_stamp' EXIT
echo "== build $STAMP =="

echo "== install and configure Android Gradle template for EOSG =="
bash tools/install-android-template.sh
python3 tools/configure-eosg-android.py

cp project.godot project.godot.bak
sed -E -i 's#renderer/rendering_method.mobile="(mobile|gl_compatibility)"#renderer/rendering_method.mobile="mobile"#' project.godot
echo "== Vulkan import =="
godot_run --headless --editor --import --path . >/dev/null

echo "== Vulkan build (mobile renderer) =="
godot_run --headless --path . --export-release "Android" "$OUT/side-sky-vulkan.apk" \
	| tee "$OUT/export.log"
cp "$OUT/side-sky-vulkan.apk" "$OUT/side-sky-motorola-vulkan.apk"

echo "== Google Play AAB build (mobile renderer) =="
godot_run --headless --path . --export-release "Android Play" "$OUT/side-sky-play.aab" \
	| tee -a "$OUT/export.log"

echo "== GLES3 build (compatibility renderer) =="
sed -E -i 's#renderer/rendering_method.mobile="(mobile|gl_compatibility)"#renderer/rendering_method.mobile="gl_compatibility"#' project.godot
godot_run --headless --editor --import --path . >/dev/null
godot_run --headless --path . --export-release "Android GLES3" "$OUT/side-sky-gles3.apk" \
	| tee "$OUT/export.log"
restore
godot_run --headless --editor --import --path . >/dev/null

echo "== verify =="
APKSIGNER="$(ls "${ANDROID_HOME:?set ANDROID_HOME}"/build-tools/*/apksigner | tail -1)"
for f in "$OUT"/side-sky-*.apk; do
	[ -f "$f" ] || { echo "MISSING: $f"; exit 1; }
	"$APKSIGNER" verify "$f" >/dev/null 2>&1 || { echo "UNSIGNED: $f"; exit 1; }
	# Not `| grep -q`: with pipefail set, grep exiting early SIGPIPEs unzip and
	# the pipeline reports failure even on a match.
	entries=$(unzip -l "$f" | grep -c "assets/\.godot" || true)
	[ "$entries" -gt 0 ] || { echo "NO GAME DATA: $f"; exit 1; }
	printf '  %-28s %s  signed, %s game files\n' "$(basename "$f")" "$(du -h "$f" | cut -f1)" "$entries"
done

AAB="$OUT/side-sky-play.aab"
[ -f "$AAB" ] || { echo "MISSING: $AAB"; exit 1; }
command -v jarsigner >/dev/null 2>&1 || {
	echo "jarsigner not found; install a JDK to verify the Play AAB" >&2
	exit 1
}
jarsigner -verify "$AAB" >/dev/null 2>&1 || { echo "UNSIGNED: $AAB"; exit 1; }
aab_entries=$(unzip -l "$AAB" | grep -c "assets/\.godot" || true)
[ "$aab_entries" -gt 0 ] || { echo "NO GAME DATA: $AAB"; exit 1; }
printf '  %-28s %s  signed, %s game files\n' "$(basename "$AAB")" "$(du -h "$AAB" | cut -f1)" "$aab_entries"

exit 0
