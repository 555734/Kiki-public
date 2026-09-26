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
# --editor --quit quits on the first frame, which is BEFORE the filesystem
# scan finishes ("Scan thread aborted"), so on a fresh clone it leaves some
# images unimported -- and a preload of an unimported image is a parse error,
# which is how net_panel.gd came to fail the script check on a clean checkout.
# --import blocks until every asset is in, so it goes first.
"$GODOT" --headless --path . --import >/dev/null 2>&1
if command -v xvfb-run >/dev/null 2>&1; then
	xvfb-run -a "$GODOT" --headless --editor --quit --path . >/dev/null 2>&1
else
	"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1
fi
[ -f .godot/global_script_class_cache.cfg ] && echo "class cache generated" \
	|| { echo "class cache NOT generated"; fail=1; }

step "parse every script and shader"
run_checked "$GODOT" --headless --path . res://test/check_scripts.tscn

step "2.5D scene integration and camera alignment (not a visual-quality test)"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/three_view_probe.tscn

step "the gate key and the crows that guard the way round it"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/key_crow_probe.tscn

step "who may play which stage, and what a friend pass is worth"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/entitlement_probe.tscn

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

step "can two people get across the open sky"
# The flight stage. Its claims are arcs and it has more of them than any other
# stage: how far a launch carries, how far a BRAKED one carries, how high a
# column is worth, and where the arc through one actually comes down. Every
# section is then flown. The first layout of 1-S put section 3's landing 400px
# from where the runner lands, and this is what said so.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/sky_probe.tscn

step "can two people climb the Skyward Ruins"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/skyward_ruins_probe.tscn

step "can two people cross the Sunlit Coast"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/sea_stage_probe.tscn

step "can two people cross the poison marsh"
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/swamp_stage_probe.tscn

step "can two people beat the Keeper"
# The boss stage. Its claims are arcs too -- how long a jump keeps the runner
# above the charge, and how long the charge takes to pass under them -- so both
# halves of the dodge are flown here rather than integrated. The first version
# of 1-B failed this file on "the runner reaches cover inside the wind-up",
# having watched the runner sprint into the pillar they were meant to hide
# behind; the stage was redesigned around what it said.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/keeper_probe.tscn

step "can two people get through 1-C"
# The stage's design claims are arcs, and arcs are measured here rather than
# modelled: a closed form that skips air control got the launch wrong by a
# factor of two. Every section is then played the way it is meant to be played.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/stage_probe.tscn

step "does the coin battle's ledger hold"
# The whole of P0's gate. Seven coin IDs exist for a match; being dropped,
# blasted out, going stale and being recycled move a coin between states and
# none of them may create or destroy one -- asserted on EVERY tick of a
# randomised match, not at the whistle. A ledger that is wrong for two hundred
# ticks and right again by the end is still a ledger that showed somebody the
# wrong score.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/arena_rules_probe.tscn

step "does the arena's movement re-run the same way twice"
# The precondition for the prediction and correction in P2: the same terrain and
# the same inputs have to land in the same place from any save point. It also
# holds JumpMath against the runner's own vertical step, which is the only thing
# that can say the extraction was verbatim -- and which found two first-tick
# bugs the rules probe could not see.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/arena_motion_probe.tscn

step "boot the real stage headlessly"
run_checked "$GODOT" --headless --path . --quit-after 240

step "do the 1-1 coin match's rules hold"
# The ledger is the whole of it: coins are neither created nor destroyed, and
# the score is derived from who holds what rather than counted separately. Also
# measures the slice of 1-1 the mode is played on -- that both ends are open
# pits, that every coin point has a floor under it, and that neither runner
# starts nearer the middle coin than the other.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/versus_probe.tscn

step "does the 1-1 coin match actually play"
# The rules probe drives the rules with made-up observations and proves nothing
# about the scene you launch. This builds the real thing -- two real Runners on
# real 1-1 collision -- and walks one into the other. It caught three wiring
# bugs the rules probe could not see, including nobody being able to touch a
# coin for the first second of every match.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/versus_play_probe.tscn

step "do four machines agree about one match"
# No sockets and no second process: four worlds in one, joined by a loopback
# mesh that drops 6% of packets and reorders the rest. The claim under test is
# the one the whole design rests on -- the host decides the contest and the
# other three believe it -- so what is asserted is that every peer derives the
# host's score, on every tick they share, not merely that packets arrived.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/versus_net_probe.tscn

step "can both online runners move using real touch events"
# Separate viewports and actual input dispatch catch an unused hub stealing
# touches; writing intent fields directly cannot exercise that failure.
run_checked "$GODOT" --headless --path . --fixed-fps 60 res://test/versus_touch_probe.tscn

step "boot the coin battle headlessly"
# Not part of the cooperative launch path: run/main_scene is untouched and the
# menu does not reach this (P5). Booted anyway, because a scene that only ever
# runs by hand is a scene that is broken for a fortnight before anyone notices.
run_checked "$GODOT" --headless --path . --quit-after 300 res://src/arena/arena_main.tscn

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

# The two that need a relay are not part of this run, because a suite that
# depends on a server nobody started is a suite that cries wolf. Both are one
# command each:
#
#   cd server/signaling && npm run dev     # then, in another shell:
#   node server/signaling/test4.mjs        # the relay's four-peer room
#   tools/versus4.sh                       # four processes, one match
if [ "$fail" -eq 0 ]; then printf '\n\033[32mall checks passed\033[0m\n'
else printf '\n\033[31mFAILURES\033[0m\n'; fi
exit "$fail"

