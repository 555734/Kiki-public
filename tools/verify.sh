#!/usr/bin/env bash
# Everything that can be checked without a device.
#
#   tools/verify.sh [path-to-godot-binary]
#   GODOT=/path/to/godot tools/verify.sh
#
# Add --shots to also render the stage under a virtual display and write
# screenshots to the user data directory (needs xvfb).
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
[ $# -gt 0 ] && [ "${1:-}" != "--shots" ] && { GODOT="$1"; shift; }
SHOTS=0
[ "${1:-}" = "--shots" ] && SHOTS=1

command -v "$GODOT" >/dev/null 2>&1 || [ -x "$GODOT" ] || {
	echo "godot not found: $GODOT  (pass the binary path or set \$GODOT)"; exit 2; }

fail=0
step() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
# Godot reports script problems on stderr and still exits 0, so every step
# greps the output as well as checking the status.
run_checked() {
	local out status
	out=$("$@" 2>&1); status=$?
	echo "$out" | grep -vE '^Godot Engine|^$|ObjectDB instances leaked|resources still in use|RID allocations|^ *at: '
	if [ $status -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|Failed to load|Parse Error"; then
		fail=1
	fi
}

step "import pass (registers class_name globals)"
if command -v xvfb-run >/dev/null 2>&1; then
	xvfb-run -a "$GODOT" --headless --editor --quit --path . >/dev/null 2>&1
else
	"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1
fi
[ -f .godot/global_script_class_cache.cfg ] && echo "class cache generated" \
	|| { echo "class cache NOT generated"; fail=1; }

step "parse every script and shader"
run_checked "$GODOT" --headless --path . res://test/check_scripts.tscn

step "logic tests"
run_checked "$GODOT" --headless --path . res://test/run_tests.tscn

step "how the runner comes to rest after a jump"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/landing_probe.tscn

step "do the two devices agree about the world"
# The one thing the logic tests structurally cannot see. Every check in them is
# true of a single device in isolation; each bug the playtest found on the
# guardian's side was only wrong when the two devices were put side by side.
# --fixed-fps pins one physics frame to one loop, so the replay lines its
# frames up with the recording's ticks.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/agreement_probe.tscn

step "touch input precision and intentional actions"
run_checked "$GODOT" --headless --path . res://test/touch_feel_probe.tscn

step "speed-sensitive jumps, air steering and movement combinations"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/movement_probe.tscn

step "getting to the jump: running, stopping and turning round on flat ground"
# The other movement checks all start from a run-up and measure an arc. These
# measure the run-up itself -- first stride, stopping distance, the turn, and
# what the slow end of the stick is worth -- because that is what a thumb on a
# one-block ledge is actually using.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/ground_movement_probe.tscn

step "what one player is not shown"
# The asymmetric stage, and the invariant the whole idea rests on: the same
# input replayed through runner eyes and guardian eyes has to move the runner
# to the same places. A veil that could change the simulation would mean the
# two players are no longer in the same world.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/veil_probe.tscn

step "the shapes that are not open ground"
# Every other check measures the runner on a flat plateau, which is the one
# place a platformer cannot go wrong. This walks the seams, steps, corners, low
# ceilings and moving floors that it can.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/workshop_probe.tscn

step "can two people get through 1-C"
# The stage's design claims are arcs, and arcs are measured here rather than
# modelled: a closed form that skips air control got the launch wrong by a
# factor of two. Every section is then played the way it is meant to be played.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/stage_probe.tscn

step "boot the real stage headlessly"
run_checked "$GODOT" --headless --path . --quit-after 240

if [ "$SHOTS" = "1" ]; then
	if command -v xvfb-run >/dev/null 2>&1; then
		# The connect screen has to be driven under a real display. Headless has
		# no GUI picking at all -- a synthetic click on a button does nothing --
		# so the fact that every button on it was dead on Android could not have
		# been caught by the headless suite however many checks it grew.
		step "connect screen under a real display"
		run_checked xvfb-run -a -s "-screen 0 1400x900x24" "$GODOT" --path . \
			--rendering-method gl_compatibility --rendering-driver opengl3 \
			--resolution 1280x720 res://test/ui_probe.tscn

		step "how everything sits on the ground"
		run_checked xvfb-run -a -s "-screen 0 1400x900x24" "$GODOT" --path . \
			--rendering-method gl_compatibility --rendering-driver opengl3 \
			--resolution 1280x720 res://test/seating_probe.tscn

		step "render screenshots"
		run_checked xvfb-run -a -s "-screen 0 1400x900x24" "$GODOT" --path . \
			--rendering-method gl_compatibility --rendering-driver opengl3 \
			--resolution 1280x720 res://test/capture_shots.tscn
	else
		echo "xvfb-run not available; skipping"
	fi
fi

if [ "$fail" -eq 0 ]; then printf '\n\033[32mall checks passed\033[0m\n'
else printf '\n\033[31mFAILURES\033[0m\n'; fi
exit "$fail"

