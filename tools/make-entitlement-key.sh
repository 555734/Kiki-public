#!/usr/bin/env bash
# Generate the entitlement signing pair.
#
#   tools/make-entitlement-key.sh
#
# Writes the PUBLIC half into entitlement_key.json (commit that) and prints the
# PRIVATE half to stdout ONCE (never commit that; paste it into
# `wrangler secret put ENTITLEMENT_SIGNING_KEY`).
#
# RSA-2048 with PKCS#1 v1.5 and SHA-256, because that is the only signature
# Godot's Crypto.verify() can check. Ed25519 would be the modern choice and the
# engine cannot read it.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
	-out "$tmp/private.pem" 2>/dev/null
openssl rsa -in "$tmp/private.pem" -pubout -out "$tmp/public.pem" 2>/dev/null

"${PYTHON:-python3}" - "$tmp/public.pem" <<'PY'
import json, sys, pathlib
pem = pathlib.Path(sys.argv[1]).read_text()
path = pathlib.Path("entitlement_key.json")
doc = json.loads(path.read_text())
doc["public_key_pem"] = pem
path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
print("entitlement_key.json updated with the new public key")
PY

echo
echo "=== PRIVATE KEY -- copy this into the Worker, then close this terminal ==="
echo "    wrangler secret put ENTITLEMENT_SIGNING_KEY"
echo
cat "$tmp/private.pem"
echo
echo "=== it is not stored anywhere; re-run this script to make a new pair ==="
