#!/usr/bin/env bash
# Everything that must be true before a build is allowed near a store.
#
#   tools/release-check.sh
#
# Run by tools/verify.sh and by CI. None of this needs Godot, a device or a
# network -- it is all in the tree -- which is the point: each of these was
# either found by a store rejecting an upload, or would have shipped a build
# that takes money it cannot honour.
#
# ALLOW_PLACEHOLDER_KEY=1 downgrades the entitlement-key check to a warning.
# That is for a fresh fork with no key of its own, not for a release.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=1; }
warn() { printf '  \033[33mwarn\033[0m  %s\n' "$1"; }

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# ---------------------------------------------------------------- the key ---
# A build whose public key still says PLACEHOLDER fails closed: every player is
# FREE and no purchase can ever unlock anything. That is the right way round,
# and it is also completely silent -- the game looks fine, the paid stages just
# never open. src/autoload/entitlement.gd promised this check existed long
# before it did.
section "entitlement signing key"
KEY_PEM=$(sed -n 's/.*"public_key_pem": "\(.*\)",*$/\1/p' entitlement_key.json | head -1)
if [ -z "$KEY_PEM" ]; then
	bad "entitlement_key.json has no public_key_pem"
elif printf '%s' "$KEY_PEM" | grep -q PLACEHOLDER; then
	if [ "${ALLOW_PLACEHOLDER_KEY:-0}" = "1" ]; then
		warn "the entitlement key is still a placeholder (allowed by ALLOW_PLACEHOLDER_KEY)"
	else
		bad "the entitlement key is still a placeholder: every player would be FREE for ever"
	fi
elif command -v openssl >/dev/null 2>&1; then
	pem=$(printf '%b' "$KEY_PEM")
	bits=$(printf '%s' "$pem" | openssl rsa -pubin -noout -text 2>/dev/null \
		| sed -n 's/.*Public-Key: (\([0-9]*\) bit).*/\1/p')
	if [ "$bits" = "2048" ]; then
		fp=$(printf '%s' "$pem" | openssl rsa -pubin -outform DER 2>/dev/null | shasum -a 256 | awk '{print $1}')
		ok "RSA-2048 public key, sha256 ${fp:0:16}…"
	else
		bad "public_key_pem is not an RSA-2048 public key (openssl read: ${bits:-nothing})"
	fi
else
	ok "public key present (openssl absent; contents not checked)"
fi

# ------------------------------------------------------------- the version ---
# iOS shipped 0.2.3 while Play built 0.2.4 and nothing anywhere noticed. The
# number in project.godot is now the one true copy.
section "one version number"
VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot | head -1)
if [ -z "$VERSION" ]; then
	bad "project.godot has no config/version"
else
	ok "project.godot says $VERSION"
	while read -r found; do
		[ "$found" = "$VERSION" ] || bad "export_presets.cfg has version/name=\"$found\", not \"$VERSION\""
	done < <(sed -n 's/^version\/name="\(.*\)"$/\1/p' export_presets.cfg)

	ios_version=$(sed -n 's/^ *APP_VERSION: "\(.*\)"$/\1/p' .github/workflows/ios.yml | head -1)
	[ "$ios_version" = "$VERSION" ] \
		|| bad "ios.yml builds APP_VERSION $ios_version, not $VERSION"
	play_version=$(sed -n '/version_name:/,/type: string/s/^ *default: "\(.*\)"$/\1/p' \
		.github/workflows/android-play.yml | head -1)
	[ "$play_version" = "$VERSION" ] \
		|| bad "android-play.yml defaults to version_name $play_version, not $VERSION"

	codes=$(sed -n 's/^version\/code=\([0-9]*\)$/\1/p' export_presets.cfg | sort -u | tr '\n' ' ')
	case "$(echo "$codes" | wc -w)" in
		1) ok "android versionCode $codes" ;;
		*) bad "the Android presets disagree about versionCode: $codes" ;;
	esac
fi

# -------------------------------------------------------------- identities ---
section "store identities"
if grep -q 'com\.example\.' export_presets.cfg; then
	# The iOS preset keeps a placeholder on purpose -- tools/ios-identity.sh
	# stamps the real one at build time -- but an Android preset does not get
	# stamped by anything, so com.example there is what gets installed.
	grep -n 'package/unique_name="com\.example\.' export_presets.cfg >/dev/null \
		&& bad "an Android preset still has a com.example package id" \
		|| ok "no Android preset carries a com.example package id"
else
	ok "no com.example identity anywhere in the presets"
fi
ios_bundle=$(sed -n 's/^ *BUNDLE_ID: "\(.*\)"$/\1/p' .github/workflows/ios.yml | head -1)
case "$ios_bundle" in
	""|com.example.*) bad "ios.yml does not supply a real BUNDLE_ID (got '${ios_bundle:-nothing}')" ;;
	*) ok "iOS bundle $ios_bundle" ;;
esac

# ------------------------------------------------------------------ icons ---
section "icons"
for key in main_192x192 adaptive_foreground_432x432 adaptive_background_432x432; do
	paths=$(sed -n "s/^launcher_icons\/$key=\"\(.*\)\"$/\1/p" export_presets.cfg | sort -u)
	if [ -z "$paths" ] || printf '%s' "$paths" | grep -q '^$'; then
		bad "launcher_icons/$key is empty in at least one Android preset"
		continue
	fi
	missing=0
	for p in $paths; do
		f="${p#res://}"
		[ -f "$f" ] || { bad "launcher_icons/$key points at $p, which does not exist"; missing=1; }
	done
	[ "$missing" = "0" ] && ok "launcher_icons/$key -> $paths"
done
# Apple rejects an App Store icon with an alpha channel. PNG colour type 6 and
# 4 carry one; 2 and 0 do not. Byte 25 of a PNG is the colour type.
for f in assets/ui/appicon_1024.png; do
	if [ -f "$f" ]; then
		ct=$(od -An -tu1 -j25 -N1 "$f" | tr -d ' ')
		case "$ct" in
			2|0) ok "$f has no alpha channel" ;;
			*)   bad "$f has an alpha channel (PNG colour type $ct); App Store Connect refuses it" ;;
		esac
	else
		bad "$f is missing"
	fi
done

# -------------------------------------------------------------- the store ---
section "in-app purchase plugins"
android_sha=$(sed -n 's/^ANDROID_SHA256="\(.*\)"$/\1/p' tools/install-iap-plugins.sh | head -1)
[ -n "$android_sha" ] \
	&& ok "the Play Billing archive is pinned (${android_sha:0:16}…)" \
	|| bad "ANDROID_SHA256 is empty: tools/install-iap-plugins.sh android would refuse to run"
ios_commit=$(sed -n 's/^IOS_PLUGIN_COMMIT="\(.*\)"$/\1/p' tools/install-iap-plugins.sh | head -1)
[ -n "$ios_commit" ] \
	&& ok "the StoreKit plugin is pinned to ${ios_commit:0:12}" \
	|| bad "IOS_PLUGIN_COMMIT is empty: the iOS build would have no StoreKit"
grep -q 'IAP_PLUGINS: "1"' .github/workflows/android.yml \
	&& ok "android.yml builds with billing" \
	|| warn "android.yml builds without billing (IAP_PLUGINS is not 1)"

# --------------------------------------------------------------- the store ---
section "store paperwork present in the tree"
for f in docs/privacy-policy.md docs/store-listing.md; do
	[ -f "$f" ] && ok "$f" || bad "$f is missing"
done

printf '\n'
if [ "$fail" -eq 0 ]; then printf '\033[32mrelease checks passed\033[0m\n'
else printf '\033[31mRELEASE CHECKS FAILED\033[0m -- this tree must not be uploaded to a store\n'; fi
exit "$fail"
