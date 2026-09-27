#!/usr/bin/env bash
# Reject Play bundles signed by any key other than the registered upload key.
set -euo pipefail
cd "$(dirname "$0")/.."

aab="${1:?usage: verify-play-aab-signature.sh path/to/app.aab}"
[ -s "$aab" ] || { echo "Missing or empty Play AAB: $aab" >&2; exit 1; }
command -v keytool >/dev/null 2>&1 || { echo "keytool is required" >&2; exit 1; }

expected=$(tr -d '[:space:]' < ci/play-upload-certificate.sha1 | tr '[:lower:]' '[:upper:]')
[[ "$expected" =~ ^([0-9A-F]{2}:){19}[0-9A-F]{2}$ ]] || {
	echo "Invalid expected Play upload certificate SHA-1" >&2
	exit 1
}

certificate=$(keytool -J-Duser.language=en -J-Duser.country=US -printcert -jarfile "$aab")
actual=$(printf '%s\n' "$certificate" | sed -n 's/^[[:space:]]*SHA1:[[:space:]]*//p' | sed -n '1p' | tr '[:lower:]' '[:upper:]' | tr -d '\r')
[ "$actual" = "$expected" ] || {
	echo "WRONG PLAY UPLOAD KEY: bundle SHA-1 ${actual:-unavailable}; expected $expected" >&2
	exit 1
}
echo "Play upload certificate SHA-1 verified: $actual"
