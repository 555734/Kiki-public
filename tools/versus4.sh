#!/usr/bin/env bash
# Four processes, one relay, one match.
#
#   tools/versus4.sh [path-to-godot]
#   GODOT=/path/to/godot tools/versus4.sh
#
# Starts a local relay if one is not already listening, launches four headless
# Godot processes into the same room -- a host, the other runner and both
# guardians -- and merges their output. Each asserts only what it can see.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
[ $# -gt 0 ] && GODOT="$1"
RELAY="${VERSUS_RELAY:-ws://localhost:8787}"
HEALTH="${RELAY/ws:/http:}"
HEALTH="${HEALTH/wss:/https:}"

started_relay=0
if ! curl -s --noproxy '*' "$HEALTH/health" 2>/dev/null | grep -q ok; then
	echo "starting a local relay"
	(cd server/signaling && npx wrangler dev --local --port 8787 \
		--var RATE_MAX:100000 >/tmp/versus-relay.log 2>&1 &)
	started_relay=1
	for _ in $(seq 1 40); do
		curl -s --noproxy '*' "$HEALTH/health" 2>/dev/null | grep -q ok && break
		sleep 2
	done
fi
curl -s --noproxy '*' "$HEALTH/health" 2>/dev/null | grep -q ok || {
	echo "no relay at $HEALTH; start one with: cd server/signaling && npm run dev"
	exit 2; }

CODE=$(tr -dc 'A-HJ-NP-Z2-9' </dev/urandom | head -c 6)
echo "room $CODE"

run_one() {
	NO_PROXY='*' no_proxy='*' HTTP_PROXY= HTTPS_PROXY= http_proxy= https_proxy= \
		"$GODOT" --headless --path . \
		res://test/versus_live_probe.tscn \
		-- "--live-role=$1" "--live-code=$CODE" "--live-relay=$RELAY" 2>&1 \
		| grep -vE '^Godot Engine|^$|ObjectDB|resources still|^ *at: '
}

# The host first, so it holds index 0. The relay hands them out by arrival.
run_one host & host_pid=$!
sleep 2
run_one runner & runner_pid=$!
sleep 1
run_one guardian & g1=$!
sleep 1
run_one guardian & g2=$!

fail=0
for pid in $host_pid $runner_pid $g1 $g2; do
	wait "$pid" || fail=1
done

[ "$started_relay" = "1" ] && echo "(the relay is still running; stop it yourself)"
if [ "$fail" -eq 0 ]; then printf '\n\033[32mfour machines played one match\033[0m\n'
else printf '\n\033[31mFAILURES\033[0m\n'; fi
exit "$fail"
