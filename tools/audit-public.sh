#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

mode="${1:-current}"
if [[ "$mode" != "current" && "$mode" != "--history" ]]; then
  echo "usage: tools/audit-public.sh [--history]" >&2
  exit 2
fi

fail=0

# File names that should never be tracked in a repository that may become public.
# ci/debug.keystore is the only deliberate exception; it is a public Android
# debug key documented in ci/README.md and cannot sign a Play Store release.
dangerous_name_re='(^|/)(\.env($|\.)|\.dev\.vars($|\.)|\.npmrc$|\.pypirc$|\.netrc$|secrets?(/|$)|credentials?(/|$))|\.(p8|p12|pem|key|cer|mobileprovision|provisionprofile|jks|keystore)$|(^|/)(GoogleService-Info\.plist|google-services\.json|service-account[^/]*\.json|credentials[^/]*\.json)$'

# High-signal secret formats. The audit script itself is excluded from content
# scanning so the patterns below do not match their own source text.
secret_re='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}'

allowed_name() {
  local path="$1"
  [[ "$path" == "ci/debug.keystore" ]] && return 0
  [[ "$path" == *.example ]] && return 0
  return 1
}

check_names() {
  local label="$1"
  local names="$2"
  local path
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ "$path" =~ $dangerous_name_re ]] && ! allowed_name "$path"; then
      echo "[FAIL] $label tracks secret-like file: $path" >&2
      fail=1
    fi
  done <<< "$names"
}

check_current() {
  check_names "current tree" "$(git ls-files)"

  local matches
  matches="$(git grep -I -n -E "$secret_re" -- . ':(exclude)tools/audit-public.sh' 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    echo "[FAIL] current tree contains secret-like content:" >&2
    echo "$matches" >&2
    fail=1
  fi
}

check_history() {
  local commit names matches
  while IFS= read -r commit; do
    names="$(git ls-tree -r --name-only "$commit")"
    check_names "$commit" "$names"

    matches="$(git grep -I -n -E "$secret_re" "$commit" -- . ':(exclude)tools/audit-public.sh' 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
      echo "[FAIL] $commit contains secret-like content:" >&2
      echo "$matches" >&2
      fail=1
    fi
  done < <(git rev-list --all)
}

check_current
if [[ "$mode" == "--history" ]]; then
  check_history
fi

if [[ "$fail" -ne 0 ]]; then
  echo >&2
  echo "Public audit FAILED. Do not change repository visibility until every finding is reviewed." >&2
  exit 1
fi

echo "Public audit passed (${mode#--})."
