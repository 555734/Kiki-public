#!/usr/bin/env bash
# Two devices, one relay, one game.
#
#   tools/duet.sh [path-to-godot-binary]
#
# Starts a local relay, launches the game twice -- once as the runner's device
# and once as the guardian's -- and merges what the two of them say. Neither
# process is told what the other is doing: they agree by watching the world,
# which is the thing this is here to check.
#
# A disagreement shows up as one side failing while the other passes. That is
# the whole point of running two processes: a single process that replays a
# recording can only ever agree with itself.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
[ $# -gt 0 ] && GODOT="$1"
command -v "$GODOT" >/dev/null 2>&1 || [ -x "$GODOT" ] || {
	echo "godot not found: $GODOT  (pass the binary path or set \$GODOT)"; exit 2; }

PORT="${PORT:-8791}"
RELAY="${RELAY:-ws://localhost:$PORT}"
ROOM="${ROOM:-D$(date +%s | tail -c 4)}"
OUT="${OUT:-$(mktemp -d)}"
OWN_RELAY=0
RELAY_PID=""

cleanup() {
	[ -n "$RELAY_PID" ] && kill "$RELAY_PID" 2>/dev/null
	[ -n "${RUNNER_PID:-}" ] && kill "$RUNNER_PID" 2>/dev/null
	[ -n "${GUARDIAN_PID:-}" ] && kill "$GUARDIAN_PID" 2>/dev/null
	return 0
}
trap cleanup EXIT

# A relay already listening is used as-is; otherwise one is started here. The
# port is not the default 8787 so this never fights a hand-started one.
if ! curl -s -o /dev/null --max-time 2 "http://localhost:$PORT/" 2>/dev/null; then
	echo "== starting a relay on $PORT =="
	( cd server/signaling && npx --yes wrangler dev --local --port "$PORT" ) \
		>"$OUT/relay.log" 2>&1 &
	RELAY_PID=$!
	OWN_RELAY=1
	for _i in $(seq 1 60); do
		curl -s -o /dev/null --max-time 1 "http://localhost:$PORT/" 2>/dev/null && break
		sleep 1
	done
	curl -s -o /dev/null --max-time 2 "http://localhost:$PORT/" 2>/dev/null || {
		echo "the relay did not come up; see $OUT/relay.log"
		tail -20 "$OUT/relay.log"; exit 2; }
fi

echo "== room $ROOM on $RELAY =="
# NO --fixed-fps here, deliberately. It decouples game time from the clock on
# the wall -- frames run as fast as the CPU allows and each one still advances
# the world by 1/60s -- which is right for a deterministic replay and wrong for
# anything involving a second machine. With it, a platform's five-second life
# expired in a fraction of a real second while the packet that was going to fire
# it was still crossing the relay, and the launch missed a slab that was no
# longer there.
"$GODOT" --headless --path . res://test/duet_probe.tscn \
	++ --runner --room "$ROOM" --relay "$RELAY" --client-id duet-runner >"$OUT/runner.log" 2>&1 &
RUNNER_PID=$!
"$GODOT" --headless --path . res://test/duet_probe.tscn \
	++ --guardian --room "$ROOM" --relay "$RELAY" --client-id duet-guardian >"$OUT/guardian.log" 2>&1 &
GUARDIAN_PID=$!

wait "$RUNNER_PID"; runner_status=$?
wait "$GUARDIAN_PID"; guardian_status=$?

strip() { grep -vE "^Godot Engine|ObjectDB instances leaked|resources still in use|^ *at: |^$"; }
echo ""
echo "---- the runner's device ----"
strip <"$OUT/runner.log"
echo ""
echo "---- the guardian's device ----"
strip <"$OUT/guardian.log"

echo ""
if [ $runner_status -eq 0 ] && [ $guardian_status -eq 0 ]; then
	printf '\033[32mboth devices agree\033[0m\n'
	exit 0
fi
printf '\033[31mDISAGREEMENT (runner %d, guardian %d)\033[0m  logs in %s\n' \
	"$runner_status" "$guardian_status" "$OUT"
exit 1
