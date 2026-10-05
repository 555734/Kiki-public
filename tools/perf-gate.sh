#!/usr/bin/env bash
# Every co-op stage against its draw-call and object budget.
#
#   tools/perf-gate.sh [path-to-godot-binary]
#
# Needs a display: run under xvfb-run on a machine without one. Frame times are
# printed for reference but not judged -- a CI runner's GPU is not a phone's.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-${1:-godot}}"
fail=0
for stage in 1-1 1-2 1-3 1-4 1-5 1-6 1-7 1-8; do
	out=$("$GODOT" --path . --rendering-method gl_compatibility --rendering-driver opengl3 \
		--resolution 1280x720 tools/perf_probe.tscn -- --ci-skip-eos --stage "$stage" --budget 2>&1)
	status=$?
	echo "$out" | grep -E "^frames=|^draw_calls=|^peak_|^BUDGET"
	if [ $status -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
		echo "  $stage: over budget or failed to run"
		fail=1
	fi
done
exit $fail
