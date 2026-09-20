class_name ArenaRules
## Every tuning number the coin battle has, in one place.
##
## Deliberately NOT in Balance. docs/coin-battle-plan.md section 7.1: tuning the
## arena must never move a cooperative value, and the cooperative modes have
## eight stages of measured arcs resting on Balance. The one thing the arena
## does read from Balance is MOVEMENT -- the whole point of the mode is that it
## uses the run and the jump the game already has (section 4.1), so borrowing
## those constants is the intent rather than a shortcut.
##
## The numbers here are the plan's initial hypotheses. They are not measurements
## of a match that has been played, and the plan says so: "数値は初期仮説であり、
## 対戦の実機測定結果ではない".

# ------------------------------------------------------------------ the match
## 180 seconds at 60Hz (section 3.1).
const MATCH_TICKS: int = 10800
const COUNTDOWN_TICKS: int = 180
## Overtime runs at most 30s, and is won by holding a sole lead for 2s.
const OVERTIME_TICKS: int = 1800
const OVERTIME_LEAD_TICKS: int = 120

## Seven coin IDs exist for the whole match. Releasing and respawning one does
## not make an eighth (section 3.2).
const COIN_COUNT: int = 7

## When new coins enter play, as ticks from the start of PLAYING, and how many.
## Fixed rather than random so early matches can be compared (section 3.2).
const SPAWN_SCHEDULE: Array = [
	{"tick": 0, "count": 1},
	{"tick": 2400, "count": 2},
	{"tick": 4800, "count": 2},
	{"tick": 7200, "count": 2},
]
## Shown to everyone this far ahead.
const SPAWN_WARNING_TICKS: int = 120

# ------------------------------------------------------------------ the coins
## Distance from a coin's centre to a fighter's body for a pickup (section 3.2).
const PICKUP_RADIUS: float = 18.0
## Nobody may take a coin for this long after it enters the world.
const PICKUP_LOCKOUT_TICKS: int = 12
## After a drop: nobody for 18, and the fighter who lost it for 45. Stops a
## held attack button from farming the same coin back (section 3.3).
const DROP_LOCKOUT_TICKS: int = 18
const DROP_OWNER_LOCKOUT_TICKS: int = 45

## A dropped coin leaves towards the attacker and upwards.
const DROP_SPEED_X: float = 160.0
const DROP_SPEED_Y: float = 280.0
const COIN_GRAVITY: float = 1200.0
const COIN_TERMINAL: float = 600.0
const COIN_BOUNCE: float = 0.25
const COIN_MAX_BOUNCES: int = 2

## A world coin nobody takes goes back into circulation (section 3.4).
const COIN_STALE_TICKS: int = 480
const COIN_BLINK_TICKS: int = 60
const RECYCLE_TICKS: int = 60

# ---------------------------------------------------------------- the fighter
const BODY_SIZE := Vector2(30.0, 46.0)

## One attack: wind-up, active, recovery (section 4.2).
const ATTACK_STARTUP_TICKS: int = 8
const ATTACK_ACTIVE_TICKS: int = 4
const ATTACK_RECOVERY_TICKS: int = 14
const ATTACK_TOTAL_TICKS: int = ATTACK_STARTUP_TICKS + ATTACK_ACTIVE_TICKS \
	+ ATTACK_RECOVERY_TICKS

## The hitbox, from the fighter's centre, in the direction the attack was aimed.
const ATTACK_REACH: float = 38.0
const ATTACK_RISE: float = 4.0
const ATTACK_SIZE := Vector2(54.0, 44.0)
## Below this the attack uses the facing instead of the stick.
const ATTACK_AIM_DEADZONE: float = 0.15

## Knockback grows with accumulated pressure, which is not HP and is not the
## coin count (section 4.2).
const PRESSURE_MAX: float = 100.0
const PRESSURE_PER_HIT: float = 20.0
const KNOCKBACK_BASE_X: float = 300.0
const KNOCKBACK_PER_PRESSURE_X: float = 2.5
const KNOCKBACK_BASE_Y: float = 210.0
const KNOCKBACK_PER_PRESSURE_Y: float = 1.8

const HITSTUN_TICKS: int = 10
const HIT_INVULN_TICKS: int = 36
## Horizontal drag towards zero during hitstun, px/s per second.
const HITSTUN_DRAG: float = 300.0

# --------------------------------------------------------------- the respawn
const RESPAWN_TICKS: int = 60
const RESPAWN_INVULN_TICKS: int = 72
## A respawn point has to be this far from a living enemy, and from any hitbox
## that is live this tick (section 5).
const RESPAWN_ENEMY_CLEARANCE: float = 160.0
const RESPAWN_ATTACK_CLEARANCE: float = 120.0
## If every candidate is crowded, wait this long and then take the best of the
## two furthest rather than waiting forever.
const RESPAWN_MAX_WAIT_TICKS: int = 60

## A safe place to drop coins: inside the arena, clear of terrain, with a floor
## within this distance below (section 3.4).
const SAFE_DROP_FLOOR_PROBE: float = 80.0

# ------------------------------------------------------------------ movement
## Borrowed, on purpose. Section 4.1: the arena starts from the movement the
## game already has rather than inventing a second feel.
static func run_speed() -> float:
	return Balance.RUNNER_RUN_SPEED

static func sprint_multiplier() -> float:
	return Balance.RUNNER_SPRINT_MULTIPLIER

static func jump_velocity() -> float:
	return Balance.RUNNER_JUMP_VELOCITY

## Coyote time and jump buffering survive into the arena; the triple jump, wall
## kick, crouch, slide, pound, ledge hang, dash, warp and moving platforms do
## not (section 4.1).
##
## Borrowed rather than restated. Writing 0.10 and 0.12 here would have been two
## invented numbers quietly competing with the 0.08 and 0.10 the game's feel was
## tuned around -- the exact thing "継承する操作感" rules out.
static func coyote_time() -> float:
	return Balance.RUNNER_COYOTE_TIME

static func jump_buffer_time() -> float:
	return Balance.RUNNER_JUMP_BUFFER

# --------------------------------------------------------------------- colour
## Team A and Team B, wherever either is drawn.
##
## A colour is not a tuning number, so this sits a little oddly in a file about
## ticks and pixels. It is here because two files paint fighters -- the arena
## root and the HUD -- and they have to agree; the alternative was one reaching
## into the other's constants, which typechecks only by accident. Balance is not
## the place: its palette belongs to the cooperative stages (7.1).
##
## Far apart in hue and different in lightness, so the teams are told apart
## without relying on red against green.
const TEAM_COLOURS: Array = [Color(0.30, 0.74, 1.0), Color(1.0, 0.55, 0.26)]

## The two members of a team differ in trim, not in body colour, so a glance
## reads the team first and the person second.
const MATE_TRIM: Array = [Color(1.0, 1.0, 1.0, 0.92), Color(0.08, 0.10, 0.14, 0.92)]

## Everyone sprints all the time here. There is no sprint button to hold, which
## is what keeps the touch layout down to two buttons (section 4.1).
const ALWAYS_SPRINT: bool = true
