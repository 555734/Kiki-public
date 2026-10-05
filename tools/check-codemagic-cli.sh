#!/usr/bin/env bash
# Checks every codemagic-cli-tools invocation in tools/submit-ios-appstore.sh
# against the real
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
CLI_VERSION="$(sed -n 's/^ *CODEMAGIC_CLI_VERSION: \(.*\)$/\1/p' .github/workflows/ios.yml | head -1)"
if [ ! -x "$VENV/bin/app-store-connect" ]; then
	echo "== installing codemagic-cli-tools =="
	python3 -m venv "$VENV" >/dev/null
	"$VENV/bin/pip" install -q "codemagic-cli-tools==${CLI_VERSION}" || { echo "install failed"; exit 2; }
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

echo "== submit-ios-appstore.sh が使っているコマンドとフラグ =="
check "app-store-connect fetch-signing-files" --platform --type --strict-match-identifier --certificate-key --create
check "xcode-project use-profiles" --project
check "xcode-project build-ipa" --project --scheme --config
check "app-store-connect publish" --path --enable-package-validation --app-store \
	--version-string --release-type --cancel-previous-submissions \
	--max-build-processing-wait --whats-new
check "keychain initialize"
check "keychain add-certificates"

# Anything invoked in the script that is not checked above is a gap in this one.
echo "== スクリプトに出てくる呼び出し =="
grep -ohE "(app-store-connect|xcode-project|keychain) [a-z-]+( [a-z-]+)?" tools/submit-ios-appstore.sh \
	| sed 's/^ *//' | sort -u | sed 's/^/  /'

[ "$fail" -eq 0 ] && echo "全部実在します" || echo "実在しないものがあります"
exit "$fail"
