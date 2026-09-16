#!/usr/bin/env bash
# Stamps the Apple identity into the iOS export preset from the environment.
#
#   APPLE_TEAM_ID=A1B2C3D4E5 BUNDLE_ID=com.you.sidesky tools/ios-identity.sh
#
# The repository keeps a placeholder team and an example bundle id on purpose.
# A real team id is not a secret, but a bundle id is a claim on a name in
# Apple's namespace and neither belongs hard-coded in a repository that also
# builds unsigned test copies. Passing them in at build time keeps one preset
# working for both.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${APPLE_TEAM_ID:-}"
BUNDLE="${BUNDLE_ID:-}"
VERSION="${APP_VERSION:-0.1.0}"
BUILD="${BUILD_NUMBER:-1}"

[ -n "$TEAM" ]   || { echo "APPLE_TEAM_ID is not set"; exit 1; }
[ -n "$BUNDLE" ] || { echo "BUNDLE_ID is not set"; exit 1; }

python3 - "$TEAM" "$BUNDLE" "$VERSION" "$BUILD" <<'PY'
import re, sys
team, bundle, version, build = sys.argv[1:5]
path = "export_presets.cfg"
text = open(path).read()

# Only the iOS preset. The Android ones have their own identifiers and must not
# be dragged along by a global replace.
start = text.index('name="iOS"')
end = text.index("[preset.2]", start)
head, body, tail = text[:start], text[start:end], text[end:]

def put(key, value, section):
    global body
    pattern = re.compile(r'^%s="[^"]*"$' % re.escape(key), re.M)
    replacement = '%s="%s"' % (key, value)
    if not pattern.search(section):
        raise SystemExit("%s not found in the iOS preset" % key)
    return pattern.sub(replacement, section, count=1)

body = put("application/app_store_team_id", team, body)
body = put("application/bundle_identifier", bundle, body)
body = put("application/short_version", version, body)
body = put("application/version", build, body)
open(path, "w").write(head + body + tail)
print("  team %s / bundle %s / version %s (%s)" % (team, bundle, version, build))
PY
