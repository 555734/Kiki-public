#!/usr/bin/env bash
# Restore the exact EOSG binaries used by メロスゲーム. The addon is deliberately
# not checked into git: Android+iOS binaries are roughly 75 MB compressed.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=2.3.1
REVISION=56238973e2cd7ac9ac99ca14f88934465f0a8997
BASE="https://github.com/3ddelano/epic-online-services-godot/releases/download/${VERSION}"

install_one() {
	platform="$1"
	case "$platform" in
		android) expected=c29489008369a6f695d261f2e378c79e67fbb9bedb45cda102c6949afe58f851 ;;
		ios) expected=a3b02efee7e94143be9f152d48190c2bb58d80af3780c4e70d90083f1b7a5a62 ;;
		linux) expected=76f7afcd01247abbba140d0f6f9d8d4e3524a20e84e08af0acd124238d2575d4 ;;
		macos) expected=9b61338266dd883f8ff05be72322e0c54e618078c1269bc8952220e4002c33f7 ;;
		*) echo "unsupported EOSG platform: $platform" >&2; exit 2 ;;
	esac
	name="epic-online-services-godot-${platform}-${REVISION}.zip"
	zip="${RUNNER_TEMP:-/tmp}/$name"
	curl --fail --location --silent --show-error "$BASE/$name" --output "$zip"
	actual=$(shasum -a 256 "$zip" | awk '{print $1}')
	[ "$actual" = "$expected" ] || {
		echo "EOSG checksum mismatch for $platform: $actual" >&2
		exit 1
	}
	# Release archives contain a top-level epic-online-services-godot/ folder.
	# Merge the contents below that folder into the project root so the addon
	# lands at res://addons/...; extracting directly would create a nested,
	# invisible project and leave every EOS autoload missing.
	unpack=$(mktemp -d "${TMPDIR:-/tmp}/side-sky-eosg.XXXXXX")
	unzip -q -o "$zip" -d "$unpack"
	test -f "$unpack/epic-online-services-godot/addons/epic-online-services-godot/plugin.cfg"
	cp -R "$unpack/epic-online-services-godot/." .
	rm -rf "$unpack"
}

[ "$#" -gt 0 ] || { echo "usage: $0 <host> <target>" >&2; exit 2; }
for platform in "$@"; do install_one "$platform"; done

# EOSG 2.3.1's helper deletes the stored Device ID on every startup. That
# changes the PUID and makes lobby rejoin/role recovery impossible. Keep the
# already-created ID; DuplicateNotAllowed is the normal subsequent-launch case.
python3 tools/patch-eosg-device-id.py

test -f addons/epic-online-services-godot/plugin.cfg
echo "EOSG ${VERSION} (${REVISION}) installed and patched"
