extends Node
## Every tunable number in the game lives here.
##
## Design doc chapter 8 ("P2: playtest iteration") calls for tuning gauge cost,
## duration and enemy density repeatedly. Keeping the numbers in one autoload
## means a balance pass is a single-file edit, not a hunt through scenes.
##
## Values marked [DOC] come straight from the design proposal. The rest had no
## specified value and were chosen here.

# ---------------------------------------------------------------- guardian
## [DOC] Support gauge: max 100, +8 per second.
const GAUGE_MAX: float = 100.0
const GAUGE_REGEN_PER_SEC: float = 8.0

## [DOC] Ability costs. COST_WARP is with the rest of the warp block below.
const COST_SNIPE: float = 20.0
const COST_PLATFORM: float = 30.0
const COST_WALL: float = 25.0

## [DOC] "No rapid fire" -- expressed as a per-shot cooldown.
const SNIPE_COOLDOWN: float = 0.6
## Shots the current gauge can afford, capped for the HUD readout (mockup 3
## shows "3/3"). See docs/design-decisions.md for why ammo is gauge-derived.
const SNIPE_AMMO_DISPLAY_CAP: int = 3
const SNIPE_DAMAGE: int = 2

## [DOC] Platform: max 2 alive, 5 seconds each. Placing a 3rd removes the oldest.
const PLATFORM_LIFETIME: float = 5.0
const PLATFORM_MAX_ALIVE: int = 2
const PLATFORM_SIZE := Vector2(150.0, 26.0)

## [DOC] Wall: max 1 alive, 4 seconds. Blocks shots and charges.
const WALL_LIFETIME: float = 4.0
const WALL_MAX_ALIVE: int = 1
const WALL_SIZE := Vector2(26.0, 190.0)

## [DOC] Warp: a PAIR of gates, 9 seconds each, one gauge charge per gate.
##
## The gates are the guardian's only way to move the runner rather than to give
## them somewhere to stand, so the whole design is about keeping it expensive
## and short-lived. Two charges of 22 is 44 -- nearly half the gauge, and more
## than a platform and a wall together -- and each gate's clock starts when it
## is placed, so dithering over the second one eats the pair's working life.
## That is what stops the guardian from simply carrying the runner to the goal.
const COST_WARP: float = 22.0
const WARP_LIFETIME: float = 9.0
## A doorway, at the painted gate's own aspect so the art is not squashed.
const WARP_SIZE := Vector2(110.0, 136.0)
## After a trip, both mouths are inert for this long. Without it the runner
## arrives inside the far gate and is sent straight back, every frame.
## RUNNER_RUN_SPEED * this has to clear WARP_SIZE.x comfortably.
const WARP_COOLDOWN: float = 0.65

## [DOC-adjacent] Bounce pad. Written as a height, in blocks, for the same
## reason the jump is: a fixed velocity means the pad silently gets weaker every
## time gravity goes up, and the coins hanging above one end up out of reach
## without anybody changing the pad. That is exactly what happened -- a retune
## took the throw from 270px to 144px while the coins stayed at 216px.
const SPRING_HEIGHT: float = 5.6 * B
## Kept POSITIVE, as a magnitude: Runner.bounce takes absf() but the pad's own
## squash test compares against it directly, and flipping the sign there made
## every frame look like a bounce.
const SPRING_VELOCITY: float = sqrt(2.0 * RUNNER_GRAVITY * SPRING_HEIGHT)
## What a coin puts back into the shared gauge. A quarter of a platform: enough
## that a detour is worth making, not so much that the gauge stops being the
## constraint the whole design rests on.
const COIN_GAUGE: float = 8.0

## [DOC-adjacent] Catching a falling runner, and how well.
##
## Until now a good guardian and an adequate one looked identical: the platform
## either went in the right place or it did not, and nothing on screen ever said
## "that was late, and you made it". A co-op game lives on the moment both
## players shout at once, and this game had no structural reason for that moment
## to exist.
##
## The grade is the platform's AGE when the runner hits it -- how long it had
## been sitting there. Younger is better, because younger means the guardian
## left it later. Measured from when the host received the placement, not from
## the backdated birth tick, so lag compensation cannot cost the guardian their
## grade (docs/netcode.md 5.4).
const RESCUE_MIN_FALL: float = 420.0
## Seconds of platform age for tier 1, 2 and 3. Anything older is not a rescue,
## it is a floor the runner happened to walk onto.
const RESCUE_TIERS := [1.6, 0.8, 0.35]
const RESCUE_NAMES := ["", "NICE!", "GREAT!", "PERFECT!"]
## Refunded gauge. Deliberately generous at the top: a guardian who keeps
## catching people late can afford to keep doing it, which is the skill curve.
const RESCUE_REFUND := [0.0, 6.0, 14.0, 24.0]

## Placement rules. A hologram may not be spawned inside solid terrain, and not
## on top of the runner (chapter 4 notes that blocking the runner is allowed as
## a gag, but only briefly -- so we forbid spawning *inside* them, not in front).
const PLACE_MAX_RANGE: float = 1400.0
const PLACE_FADE_IN: float = 0.12
## [DOC] Chapter 6: the runner sees a faint hologram 0.3-0.5s before it lands.
const PLACE_TELEGRAPH: float = 0.35

## Partial scope. Full-screen zoom would blind the runner on a shared tablet,
## so the magnified region is a ring and the outside is only dimmed.
## These are magnification factors *relative to the normal view*, which is what
## the "3.0x" readout in the mockups means, so the scope camera runs at
## CAMERA_ZOOM * step.
const SCOPE_ZOOM_STEPS: PackedFloat32Array = [2.0, 3.0, 4.0]
const SCOPE_ZOOM_DEFAULT_INDEX: int = 1
## Radius of the magnified circle. Sized against the painted bezel: that art is
## clear out to 52% of its half-width and solid from 55%, so a bezel drawn at
## 2.90x this radius puts its inner edge at 0.75 of the glass and vignettes the
## outer quarter -- which is what an optic does anyway. It came down from 190
## because 190 plus a real bezel wanted a 730px ring, and the whole point of the
## partial scope is that it does not take the screen away from the runner. The
## total footprint is unchanged; it is the split between glass and rim that
## moved.
const SCOPE_RADIUS: float = 150.0
const SCOPE_VIEWPORT_SIZE: int = 384
const SCOPE_TRANSITION: float = 0.18
## Hard ceiling on how dark the world outside the ring may get. Chapter 9 lists
## "the runner dies to things they cannot see" as a top risk.
const SCOPE_DIM_MAX_ALPHA: float = 0.35

# ------------------------------------------------------------------ runner
## [DOC] Two hits and the run is over.
##
## It was four. Two makes every enemy on screen a real threat rather than a
## nuisance the runner walks through, and -- the part that matters for a co-op
## game -- it makes the guardian's wall worth the gauge. With four hearts the
## runner could simply eat a turret burst; with two they cannot, so somebody has
## to do something about it.
const RUNNER_MAX_HP: int = 2

# --------------------------------------------------------------- the jump
#
# EVERY number below is written as a distance or a duration, and the physics
# constants are worked out FROM them. That is the whole point of this block.
#
# It used to be the other way round: gravity was 1500 and the jump velocity was
# -620 because those felt about right, and what they actually produced -- 133px
# of height over 0.41 seconds -- was something you had to run a test to find
# out. Nobody tunes a jump by choosing an acceleration. They choose how high it
# goes and how long it hangs there, and those two numbers have exactly one pair
# of physics constants that produce them:
#
#     gravity    = 2H / T^2
#     take-off   = 2H / T
#
# So H and T are the dials, and the constants below them are derived. Change a
# dial and test/run_tests.gd measures what actually happens, and test/
# stage_probe.gd re-measures every gap in 1-C against it and says which
# sections stopped working. Nothing here has to be kept in step by hand.

## One terrain block: the unit the rest of this block is written in.
##
## The runner is 46px tall, so they are a little shorter than a block -- the
## same relationship a certain plumber has to his. Distances quoted in B are
## easier to reason about against a stage than pixel counts are.
const B: float = 48.0

## Base held-jump height before the narrow apex easing is applied.
const RUNNER_JUMP_HEIGHT: float = 3.2 * B

## Base time to apex before the narrow apex easing is applied.
const RUNNER_TIME_TO_APEX: float = 0.33

## Walking. 5.7 blocks a second: quick enough to cover ground, slow enough that
## a one-block ledge is a place you can stop.
const RUNNER_RUN_SPEED: float = 5.7 * B

## Sprinting, as a multiplier on the above. 8.6 blocks a second.
const RUNNER_SPRINT_MULTIPLIER: float = 1.5

## How long it takes to reach full speed, and to stop from it. Written as times
## because that is what a thumb feels; the accelerations follow.
const RUNNER_TIME_TO_TOP_SPEED: float = 0.15
const RUNNER_TIME_TO_STOP: float = 0.12

## Pressing the other way. Deliberately much harder than either of the above.
const RUNNER_TIME_TO_TURN: float = 0.07

## Air control is deliberately split into steer, reverse-brake and neutral drag.
## Steer is 0 -> normal run speed; brake is normal run speed -> 0; stop is the
## neutral normal run speed -> 0 time. Reverse braking keeps its old 2736 px/s².
const RUNNER_TIME_TO_AIR_STEER: float = 0.22
const RUNNER_AIR_BRAKE_TIME: float = 0.10
const RUNNER_TIME_TO_AIR_STOP: float = 0.24

## Horizontal speed at take-off continuously adds up to 20% height.
## A stationary player pressing sprint gets no free height bonus.
const RUNNER_SPRINT_JUMP_BONUS: float = 0.20
## Running multiple-jump timing. Keep dash intent, speed and direction and
## press jump again almost immediately after each landing.
const RUNNER_CHAIN_WINDOW: float = 0.13
const RUNNER_CHAIN_MIN_SPEED: float = RUNNER_RUN_SPEED * 1.05
const RUNNER_DOUBLE_HEIGHT: float = 1.20
const RUNNER_TRIPLE_HEIGHT: float = 1.46
const RUNNER_DOUBLE_FORWARD_BOOST: float = 1.03
const RUNNER_TRIPLE_FORWARD_BOOST: float = 1.10

const RUNNER_ACCEL: float = RUNNER_RUN_SPEED / RUNNER_TIME_TO_TOP_SPEED
const RUNNER_FRICTION: float = RUNNER_RUN_SPEED / RUNNER_TIME_TO_STOP
const RUNNER_TURN_BRAKE: float = RUNNER_RUN_SPEED / RUNNER_TIME_TO_TURN
const RUNNER_AIR_ACCEL: float = RUNNER_RUN_SPEED / RUNNER_TIME_TO_AIR_STEER
const RUNNER_AIR_TURN: float = RUNNER_RUN_SPEED / RUNNER_AIR_BRAKE_TIME
const RUNNER_AIR_RELEASE_BRAKE: float = RUNNER_RUN_SPEED / RUNNER_TIME_TO_AIR_STOP

## Ordinary running on the ground. These are deliberately separate from the
## four above: those still serve crouch slides, ground pounds, knockback and
## the first tick of an external launch, and a walk that shares its dials with
## a slide cannot be tuned without moving all of them.
##
## One acceleration curve covers walking and sprinting -- the sprint button
## raises the TARGET, never the push -- so a sprint no longer leaves the mark
## slower than a walk does. START gets a stopped runner moving in one frame;
## the push eases towards CRUISE as the speed climbs to a walk, and CRUISE is
## still above air steering, so the ground never feels looser than the air.
const RUNNER_GROUND_ACCEL_START: float = 1800.0
const RUNNER_GROUND_ACCEL_CRUISE: float = 1400.0
const RUNNER_GROUND_ACCEL_BLEND_SPEED: float = RUNNER_RUN_SPEED

## Easing off is its own answer rather than a side effect of the push: this is
## what a thumb coming back to neutral -- or off the sprint button, or onto a
## gentler angle -- actually gets. It matches the old stopping distance on
## purpose; weight is worth keeping.
const RUNNER_GROUND_DECEL: float = RUNNER_RUN_SPEED / 0.12

## Pressing the other way brakes to a standstill at this rate, and only to a
## standstill: the remainder of that frame accelerates the other way at
## START, so the brake never doubles as a launch.
const RUNNER_GROUND_REVERSE_DECEL: float = RUNNER_RUN_SPEED / 0.08

## The ground reads the stick through its own curve. The deadzone is the one
## the runner already had; past it the input is re-normalised and bent towards
## its square, so a small lean is a slow walk rather than a step change into
## the nearest speed. The air keeps the raw axis.
const RUNNER_GROUND_INPUT_DEADZONE: float = 0.05
const RUNNER_GROUND_INPUT_CURVE: float = 0.50

## Derived world gravity and take-off velocity remain shared with launches,
## springs and knockback. Player-only variable-jump shaping lives below and
## never changes these shared constants.
const RUNNER_GRAVITY: float = 2.0 * RUNNER_JUMP_HEIGHT \
	/ (RUNNER_TIME_TO_APEX * RUNNER_TIME_TO_APEX)
const RUNNER_JUMP_VELOCITY: float = -2.0 * RUNNER_JUMP_HEIGHT / RUNNER_TIME_TO_APEX
const RUNNER_FALL_RATIO: float = 1.4
const RUNNER_FALL_GRAVITY: float = RUNNER_GRAVITY * RUNNER_FALL_RATIO
const RUNNER_TERMINAL_VELOCITY: float = 1100.0

## Player-jump shaping. Releasing is latched immediately, but the stronger
## upward deceleration waits until MIN_JUMP_TIME and blends in over two ticks.
## Apex easing is only for an unreleased player jump and has a hard time cap.
const RUNNER_MIN_JUMP_TIME: float = 0.06
const RUNNER_JUMP_RELEASE_GRAVITY_RATIO: float = 4.0
const RUNNER_JUMP_RELEASE_BLEND_TIME: float = 0.03
const RUNNER_APEX_SPEED: float = 180.0
const RUNNER_APEX_GRAVITY_RATIO: float = 0.65
const RUNNER_APEX_MAX_TIME: float = 0.18

## Which build this is, stamped by tools/build-android.sh (and the iOS export)
## from the commit it was built at. "dev" when running from source.
const BUILD_ID: String = "dev"

# ---------------------------------------------------------------- the launch
#
# Every construct the guardian places carries a trigger the guardian can SHOOT.
# The runner stands on it, the guardian shoots it, and the runner is thrown
# forward and up. Two people, two inputs, one move -- which is the whole reason
# it is here rather than as a fourth button.

## How high the launch throws, and how far it carries on the flat.
const LAUNCH_HEIGHT: float = 2.0 * RUNNER_JUMP_HEIGHT
const LAUNCH_RANGE: float = 14.0 * B

## The take-off, worked out from those two. Up is a plain rise; the forward
## speed is the range divided by how long the flight lasts -- the rise under
## RUNNER_GRAVITY plus the fall back under RUNNER_FALL_GRAVITY.
const LAUNCH_RISE_TIME: float = sqrt(2.0 * LAUNCH_HEIGHT / RUNNER_GRAVITY)
const LAUNCH_FALL_TIME: float = sqrt(2.0 * LAUNCH_HEIGHT / RUNNER_FALL_GRAVITY)
const LAUNCH_UP: float = sqrt(2.0 * RUNNER_GRAVITY * LAUNCH_HEIGHT)
const LAUNCH_FORWARD: float = LAUNCH_RANGE / (LAUNCH_RISE_TIME + LAUNCH_FALL_TIME)

## The trigger's radius, and how far above the slab it floats.
const LAUNCH_TRIGGER_RADIUS: float = 24.0
const LAUNCH_TRIGGER_LIFT: float = 30.0

## How close the runner's feet must be to the deck to count as standing on it.
const LAUNCH_FOOTING: float = 12.0

## Speed above the normal sprint limit coasts gently until the player asks to
## brake it. This preserves run-up and guardian-launch momentum.
const AIR_MOMENTUM_DRAG: float = 60.0

# ------------------------------------------------------------- the wall jump
## Off a solid wall, including ordinary terrain and guardian walls.
const WALL_JUMP_HEIGHT: float = 2.15 * B
const WALL_JUMP_UP: float = -sqrt(2.0 * RUNNER_GRAVITY * WALL_JUMP_HEIGHT)
const WALL_JUMP_OUT: float = 1.42 * RUNNER_RUN_SPEED
const WALL_KICK_LOCK: float = 0.10
const WALL_SLIDE_SPEED: float = 100.0
const WALL_COYOTE_TIME: float = 0.12
## Presentation-only window used to show a distinct kick pose after leaving a wall.
const WALL_KICK_VISUAL_TIME: float = 0.16

# ----------------------------------------------------------------- the sky
#
# Stage 1-S only. The one new thing that stage adds is a column of rising air,
# and every number here is written against what a launch already does -- see
# docs/stage-sky.md.

## Terminal rise speed inside a column, and how hard it pulls towards it.
##
## RISE is high, and that is the second thing this stage got wrong and measured.
## It started at 300px/s, which is a comfortable-looking number and completely
## useless: a runner crossing a column at 780px/s is inside it for a quarter of
## a second, and a quarter of a second at 300px/s is 68px of climb. sky_probe
## printed "straight through a column: 35px over a plain launch" and that was
## the end of the first design, in which the runner was meant to STOP inside a
## column and ride it.
##
## Stopping does not work either, and the reason is worth writing down: a runner
## with no horizontal speed who rises to the top of a column can only drift
## about 0.3px sideways per pixel they then fall, so they cannot get out of the
## column onto anything. A column has to be something the runner FLIES THROUGH.
##
## So: wide columns, and a rise fast enough that half a second in one is worth
## real height. The lift wins decisively over RUNNER_FALL_GRAVITY (4165), which
## is what makes a column grab a runner who arrives falling.
const UPDRAFT_RISE: float = 650.0
const UPDRAFT_ACCEL: float = 5200.0

## Horizontal drag inside a column.
##
## Small on purpose. Zero would be fine -- a column is a fixed thing in the
## world, so it can only extend a launch that was aimed at it, which is a thing
## the guardian had to do rather than a thing they got free. This is here to put
## a thumb on the scale: a runner who rides a long column arrives higher and a
## little shorter, so "through the draught" and "over the top of it" are two
## different landings rather than one strictly better one.
const UPDRAFT_DRAG: float = 120.0

## How far above the column's top edge the lift still reaches, so a runner who
## tops out is carried clear rather than clipped off at a line.
const UPDRAFT_SOFT_TOP: float = 40.0

# ------------------------------------------------------------------ the keeper
#
# Stage 1-B only. Every number here is written against something the runner can
# already do, because the whole fight is a footrace between a telegraph and a
# pair of legs -- see docs/stage-keeper.md.

## Six wounds, two per act. One wound per stagger, so the fight is exactly six
## openings however much gauge the guardian is sitting on.
const KEEPER_HP: int = 6

## Two sizes, and the gap between them is deliberate.
##
## HITBOX is the physics body: what it collides with, what a charge stops on,
## and what hurts the runner. SIZE is what is painted, and it overhangs, because
## the shape that reads as a siege beast is wider than the shape that should
## take a dodge away from somebody who jumped at the right moment.
##
## The height is the number the whole fight hangs on. A standing jump measures
## 162px, so the runner's feet are above 110 for about 0.30s while the Keeper
## takes (120+30)/760 = 0.20s to pass through them. That margin -- six frames --
## is the dodge, and keeper_probe measures both halves of it rather than
## trusting this paragraph.
const KEEPER_HITBOX := Vector2(120.0, 110.0)
const KEEPER_SIZE := Vector2(168.0, 134.0)

## Walking, and charging. The charge is well above sprint speed (410px/s) on
## purpose: outrunning it must not be an answer, so the answer has to be the
## one thing the runner has that the Keeper does not, which is air.
const KEEPER_WALK_SPEED: float = 95.0
const KEEPER_CHARGE_SPEED: float = 760.0
## How far one charge carries before it runs out of legs, and how close the
## runner has to be for it to start. The second number is what keeps the Keeper
## walking in rather than charging across an empty arena.
const KEEPER_CHARGE_DISTANCE: float = 820.0
const KEEPER_CHARGE_RANGE: float = 760.0

## Per act: the telegraph, the stagger, and how long it takes to get up from a
## charge that hit nothing. Index 0 is act one.
##
## The telegraph is the runner's whole budget for getting behind cover, so it is
## quoted as a distance too: 0.85s of sprint is 349px, 0.70s is 287px, 0.55s is
## 226px. The acts get harder by taking that distance away, not by adding rules.
const KEEPER_TELEGRAPH := [0.85, 0.70, 0.55]
const KEEPER_STAGGER := [2.6, 2.2, 1.8]
const KEEPER_RECOVER: float = 1.1
## Between one thing and the next. Without it the Keeper telegraphs again on the
## frame it stands up, which reads as the game cheating rather than as pressure.
const KEEPER_BEAT: float = 0.65

## The core on its back: where it sits relative to the body's middle, and how
## big a target it is. Kept high on the silhouette because a target low on the
## screen can end up under the ability buttons (docs/status.md 4).
const KEEPER_CORE_OFFSET := Vector2(48.0, -34.0)
const KEEPER_CORE_RADIUS: float = 20.0

## Contact. A heart and a shove, the same as any other enemy: the Keeper is
## enormous but it is not an instant death, because the fight is long and a
## one-touch boss would be a memory test.
const KEEPER_CONTACT_KNOCKBACK := Vector2(320.0, -300.0)

## The ground wave a spent charge throws off, from act two. Low enough that a
## standing jump (162px) clears it with room, so the skill is noticing rather
## than timing to the frame.
const SHOCKWAVE_SPEED: float = 420.0
const SHOCKWAVE_FAST_SPEED: float = 520.0
const SHOCKWAVE_RANGE: float = 900.0
## Wider and taller than the first pass (70x34), which measured fine and read as
## a smudge: in a 1280x720 capture it was a thumbnail-sized wedge that nobody
## would jump in time. Still comfortably under half a jump, which is the check
## keeper_probe makes.
const SHOCKWAVE_SIZE := Vector2(110.0, 48.0)

## The arena's barricades: broken half-walls the Keeper brains itself on.
##
## Taller than the Keeper's hitbox, so a charge cannot ride over one, and low
## enough that the runner hops it without thinking (110 against a 162px jump) --
## because a barricade the runner cannot cross is not cover, it is a wall that
## cuts the arena in half. That is not a hypothetical: the first version of this
## stage used floor-to-sky pillars and keeper_probe failed on the line "the
## runner reaches cover inside the wind-up", having watched the runner sprint
## straight into the thing they were supposed to get behind.
const BARRICADE_SIZE := Vector2(70.0, 128.0)

## The layer barricades live on, and nothing else does.
##
## They are NOT terrain. A walking Keeper steps over one -- a four-legged siege
## engine picking its feet up -- and only a charge, head down at 760px/s, is
## stopped by it. That is one line (the mask changes when the charge starts) and
## it is what lets the boss own the whole arena while the barricades still mean
## something. The runner's mask includes it so they can stand on one.
const LAYER_BARRICADE: int = 128

# ------------------------------------------------------------ the shield-bearer
const SHIELDBEARER_HP: int = 3
const SHIELDBEARER_SIZE := Vector2(34.0, 46.0)
const SHIELD_PLATE_SIZE := Vector2(14.0, 52.0)
const WEAK_POINT_RADIUS: float = 11.0
const SHIELDBEARER_TURN_TIME: float = 0.55
const SHIELDBEARER_OPEN_TIME: float = 1.8

# -------------------------------------------------------------------- crystals
const CRYSTAL_GAUGE: float = 34.0

# ---------------------------------------------------------------- the ledge
const LEDGE_HANG_TIME: float = 3.0
const LEDGE_HAND_HEIGHT: float = 10.0
const LEDGE_MIN_FALL_SPEED: float = 0.28 * absf(RUNNER_JUMP_VELOCITY)
const LEDGE_CATCH_WINDOW: float = 0.11
const LEDGE_REACH: float = RUNNER_RUN_SPEED * LEDGE_CATCH_WINDOW
const LEDGE_HEAD_ROOM: float = LEDGE_MIN_FALL_SPEED * LEDGE_CATCH_WINDOW * 1.7

## Leaving the ground and pressing jump a moment later still jumps.
const RUNNER_COYOTE_TIME: float = 0.08
## Pressing jump a moment BEFORE landing still jumps, on landing.
const RUNNER_JUMP_BUFFER: float = 0.10

## Sprint. Holding the button on the ground or in the air is a speed modifier;
## it never invokes the reserved burst state by itself.
const RUNNER_SPRINT_ACCEL: float = RUNNER_RUN_SPEED / 0.21

## Reserved scripted burst values. Normal sprint input does not invoke this
## ability; its enum slot is retained for snapshot compatibility.
const RUNNER_DASH_SPEED: float = 620.0
const RUNNER_DASH_TIME: float = 0.16
const RUNNER_DASH_COOLDOWN: float = 0.35
const RUNNER_AIR_DASHES: int = 1

## Legacy stomp helpers remain isolated; normal enemy contact still damages.
const RUNNER_STOMP_HIGH_HEIGHT: float = RUNNER_JUMP_HEIGHT * 1.15
const RUNNER_STOMP_HEIGHT: float = 1.1 * B
const RUNNER_STOMP_BOUNCE: float = -sqrt(2.0 * RUNNER_GRAVITY * RUNNER_STOMP_HEIGHT)
const RUNNER_HURT_INVULN: float = 1.2
const RUNNER_HURT_KNOCKBACK := Vector2(180.0, -260.0)

const RUNNER_SIZE := Vector2(30.0, 46.0)

## Compact stance keeps the same foot position, including during a crouch jump.
const RUNNER_CROUCH_HEIGHT: float = 28.0
const RUNNER_CROUCH_SPEED: float = RUNNER_RUN_SPEED * 0.28
const RUNNER_SLIDE_FRICTION: float = RUNNER_FRICTION * 0.40
const RUNNER_SLOPE_ACCEL: float = 1000.0
const RUNNER_SLIDE_MAX_SPEED: float = RUNNER_RUN_SPEED * 1.7
const RUNNER_POUND_WINDUP: float = 0.10
const RUNNER_POUND_SPEED: float = 1400.0
const RUNNER_POUND_STEER_SPEED: float = RUNNER_RUN_SPEED * 0.25
## Keep the old 2280 px/s² ground-pound steering while ordinary air steering
## becomes gentler.
const RUNNER_POUND_STEER_ACCEL: float = RUNNER_RUN_SPEED / 0.12

# ------------------------------------------------------------------ enemies
const WALKER_SPEED: float = 60.0
const WALKER_HP: int = 1
const WALKER_SIZE := Vector2(44.0, 42.0)

const FLYER_SPEED: float = 95.0
const FLYER_HP: int = 1
const FLYER_AMPLITUDE: float = 70.0
const FLYER_SIZE := Vector2(46.0, 34.0)

const TURRET_HP: int = 3
const TURRET_FIRE_INTERVAL: float = 2.2
const TURRET_BURST_INTERVAL: float = 0.55
const TURRET_RANGE: float = 900.0
const TURRET_SIZE := Vector2(52.0, 52.0)

const PROJECTILE_SPEED: float = 340.0
const PROJECTILE_RADIUS: float = 9.0
const PROJECTILE_LIFETIME: float = 5.0

# ----------------------------------------------------------------- gimmicks
const MOVING_PLATFORM_SPEED: float = 70.0
const CRUMBLE_DELAY: float = 0.45
const CRUMBLE_RESPAWN: float = 3.0
const LASER_ON_TIME: float = 1.6
const LASER_OFF_TIME: float = 1.4
const LASER_WIDTH: float = 14.0

# -------------------------------------------------------------------- flow
## Chapter 3 asks for a retry under 3 seconds. We respawn instantly and only
## spend time on a short flash so the player can see where they came back.
const RESPAWN_DELAY: float = 1.5
const CAMERA_LOOKAHEAD: float = 130.0
const CAMERA_SMOOTH: float = 6.0
const CAMERA_ZOOM: float = 1.5

## How high a step ahead of a grounded runner an auto-placed platform sits.
const RUNNER_REACH_STEP: float = 96.0

const GUARDIAN_PAN_MAX: float = 420.0
const GUARDIAN_PAN_MARGIN: float = 150.0
const GUARDIAN_PAN_SPEED: float = 620.0
const GUARDIAN_PAN_RETURN: float = 2.6

# --------------------------------------------------------------------- art
const ENABLE_BLOOM: bool = true
## Presentation switch for regression comparisons; no gameplay code reads it.
const USE_3D: bool = true
const MAX_PARTICLE_BURSTS: int = 8

## Online play. ENet over UDP on this port; nothing else needs to be reachable.
const NET_PORT: int = 24680
const DEFAULT_RELAY := "https://side-sky-signalling.a3506124.workers.dev"

const USE_TEXTURES: bool = true
const RUNNER_SPRITE_H: float = 60.0
const RUNNER_POSE_HEADROOM: float = 1.0625
const WALKER_SPRITE_H: float = 60.0
const FLYER_SPRITE_H: float = 44.0
const TURRET_SPRITE_H: float = 66.0
const GRASS_TILE_H: float = 46.0
const GRASS_LIP: float = GRASS_TILE_H * 0.25
const DIRT_TILE_H: float = 66.0

# ------------------------------------------------------------------ palette
# Sampled from the supplied mockups so the drawing code has one source of truth.
const C_SKY_TOP := Color("2f8fd8")
const C_SKY_BOTTOM := Color("a9dcff")
const C_CLOUD := Color("ffffff")
const C_HILL_FAR := Color("7fc95f")
const C_HILL_NEAR := Color("5cb03a")
const C_GRASS := Color("62c22e")
const C_GRASS_DARK := Color("3f9420")
const C_DIRT := Color("b5702f")
const C_DIRT_DARK := Color("8e5321")
const C_DIRT_LIGHT := Color("c98a4a")
const C_PIPE := Color("2fa82f")
const C_PIPE_DARK := Color("1b7a24")
const C_BRICK := Color("b5651d")
const C_QBLOCK := Color("f2b32c")
const C_SPIKE := Color("b9c2cc")
const C_SPIKE_DARK := Color("7b8794")
const C_HOLO := Color("35d6ff")
const C_HOLO_DIM := Color("1b7fa8")
const C_ENEMY_BODY := Color("8b5a2b")
const C_ENEMY_DARK := Color("5e3a18")
const C_SCARF := Color("d63b3b")
const C_HAIR := Color("6b4423")
const C_SKIN := Color("f0c090")
const C_HEART := Color("e8354f")
const C_PANEL := Color("0d1b2acc")
const C_ACCENT := Color("4fd8ff")

# ------------------------------------------------------- the dawn palette
# Stage 1-S. Its own colours, because the vector fallback for a stage set on
# floating rock above a cloud sea cannot be the 1-1 set: those are meadow green
# and warm dirt with a mushroom castle on the skyline, and a sky stage wearing
# them is not "art pending", it is wrong -- the same argument that gave 1-B the
# night set to fall back to. 1-S has no other stage to borrow from, so the
# fallback is these.
const C_DAWN_TOP := Color("1d3b6b")
const C_DAWN_MID := Color("5f7fb8")
const C_DAWN_LOW := Color("f0b489")
const C_CLOUD_SEA := Color("cfd8ea")
const C_CLOUD_SEA_DARK := Color("9aa8c4")
const C_SKY_STONE := Color("8e97a6")
const C_SKY_STONE_DARK := Color("616b7d")
const C_SKY_STONE_LIGHT := Color("b3bbc7")
const C_SKY_MOSS := Color("9fb08a")
const C_SKY_MOSS_DARK := Color("6f8062")
