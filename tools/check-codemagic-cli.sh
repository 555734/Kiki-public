#!/usr/bin/env bash
# Checks every codemagic-cli-tools invocation in codemagic.yaml against the real
# CLI, without a Mac and without spending a build.
#
#   tools/check-codemagic-cli.sh
#
# This exists because invented names kept reaching CI: `--yes`, which the tool
# has never had; `bundle-ids register`, where the subcommand is `create`; and in
# the yaml itself `ios_signing` and `enable_package_validation`, neither of which
# is a real field. Each cost a round trip, and the last one greyed out the Start
# build button entirely -- an invalid key makes the whole file unloadable.
#
# The CLI is a pip package, so its --help reads the same here as on the build
# machine. There was never a reason to guess at any of it. The yaml has no
# validator available, so the answer there is to keep its surface small and put
# everything else in scripts, which this checks.
set -uo pipefail
cd "$(dirname "$0")/.."

VENV="${VENV:-/tmp/cmtools}"
if [ ! -x "$VENV/bin/app-store-connect" ]; then
	echo "== installing codemagic-cli-tools =="
	python3 -m venv "$VENV" >/dev/null
	"$VENV/bin/pip" install -q codemagic-cli-tools || { echo "install failed"; exit 2; }
fi
BIN="$VENV/bin"

fail=0
# command..., then the flags it must accept.
check() {
	local cmd="$1"; shift
	local help
	help="$($BIN/$cmd --help 2>&1)" || { printf '  FAIL  %s (no such command)\n' "$cmd"; fail=1; return; }
	for flag in "$@"; do
		if printf '%s' "$help" | grep -q -- "$flag"; then
			printf '  ok    %s %s\n' "$cmd" "$flag"
		else
			printf '  FAIL  %s %s (not a real flag)\n' "$cmd" "$flag"
			fail=1
		fi
	done
}

echo "== codemagic.yaml が使っているコマンドとフラグ =="
check "app-store-connect bundle-ids list" --bundle-id-identifier
check "app-store-connect bundle-ids create" --name --platform
check "app-store-connect certificates list" --type
check "app-store-connect certificates delete" --ignore-not-found
check "app-store-connect fetch-signing-files" --platform --type --certificate-key --create
check "xcode-project use-profiles" --project
check "xcode-project build-ipa" --project --scheme --config
check "app-store-connect publish" --path --enable-package-validation
check "keychain initialize"
check "keychain add-certificates"

# Anything invoked in the yaml that is not checked above is a gap in this script.
echo "== yaml に出てくる呼び出し =="
grep -ohE "(app-store-connect|xcode-project|keychain) [a-z-]+( [a-z-]+)?" codemagic.yaml \
	| sed 's/^ *//' | sort -u | sed 's/^/  /'

[ "$fail" -eq 0 ] && echo "全部実在します" || echo "実在しないものがあります"
exit "$fail"
