#!/usr/bin/env bash
# Download one Godot release file and check it against tools/godot-sha512.txt.
#
#   tools/godot-download.sh Godot_v4.7.2-stable_linux.x86_64.zip /tmp/godot.zip
#
# The build workflows hand the engine signing keys and store credentials, so
# what they run is pinned to the bytes, not just to a version name.
set -euo pipefail
name="$1"; out="$2"
here="$(cd "$(dirname "$0")" && pwd)"
want="$(awk -v n="$name" '$2 == n { print $1 }' "$here/godot-sha512.txt")"
[ -n "$want" ] || { echo "no pinned SHA-512 for $name in tools/godot-sha512.txt" >&2; exit 1; }
version="$(echo "$name" | sed -E 's/^Godot_v([0-9.]+-[a-z0-9]+)_.*/\1/')"
curl -sSLf -o "$out" "https://github.com/godotengine/godot-builds/releases/download/$version/$name"
if command -v sha512sum >/dev/null 2>&1; then
	got="$(sha512sum "$out" | awk '{print $1}')"
else
	got="$(shasum -a 512 "$out" | awk '{print $1}')"
fi
if [ "$got" != "$want" ]; then
	echo "SHA-512 mismatch for $name" >&2
	echo "  want $want" >&2
	echo "  got  $got" >&2
	rm -f "$out"
	exit 1
fi
echo "verified $name"
