#!/usr/bin/env bash
# The signalling and entitlement Worker's own tests, against a local worker.
#
#   tools/server-tests.sh
#
# entitlement.test.mjs drives the Durable Object directly and needs no worker.
# test.mjs (co-op rooms, rate limits, room expiry) and test4.mjs (the versus
# relay) need one, so `wrangler dev --local` is started here with a short
# ROOM_IDLE_MS -- the expiry check is skipped without it -- and stopped after.
set -euo pipefail
cd "$(dirname "$0")/../server/signaling"

PORT="${PORT:-8787}"
IDLE_MS=2000
LOG="$(mktemp)"
# Fresh Durable Object storage every run. The default (.wrangler/state) keeps
# the rate limiter's counts from the last run, and a few runs in a row are
# then refused as one client connecting too often.
STATE="$(mktemp -d)"

[ -d node_modules ] || npm ci --no-audit --no-fund

echo "== entitlement rules (no worker) =="
node entitlement.test.mjs

# A worker already on the port would answer the health check for ours and
# run the tests against the wrong configuration.
if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
	echo "something is already serving on port $PORT; stop it or set PORT"; exit 1
fi

# Its own process group: wrangler runs workerd as children, and stopping only
# the npx wrapper leaves them holding the port.
setsid npx wrangler dev --local --port "$PORT" --var "ROOM_IDLE_MS:$IDLE_MS" \
	--persist-to "$STATE" >"$LOG" 2>&1 &
WORKER=$!
stop_worker() {
	kill -- -"$WORKER" 2>/dev/null || true
	wait "$WORKER" 2>/dev/null || true
	rm -rf "$STATE"
}
trap stop_worker EXIT

for _ in $(seq 1 90); do
	curl -sf "http://localhost:$PORT/health" >/dev/null && break
	if ! kill -0 "$WORKER" 2>/dev/null; then
		echo "worker exited before it was ready:"; cat "$LOG"; exit 1
	fi
	sleep 1
done
curl -sf "http://localhost:$PORT/health" >/dev/null || { echo "worker never became healthy:"; cat "$LOG"; exit 1; }

export SIGNALLING_URL="http://localhost:$PORT"
echo "== co-op rooms =="
ROOM_IDLE_MS="$IDLE_MS" node test.mjs
echo "== versus relay =="
node test4.mjs
