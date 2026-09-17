extends RefCounted
## Stage 1-B "THE KEEPER" -- the boss arena. See docs/stage-keeper.md.
##
## Set inside the gate that 1-2 spends ten thousand pixels walking towards, so
## the art is that stage's night and that stage's stone. One room, sealed both
## ends, and a fight that is six openings long.
##
## The geometry is doing three jobs and they are all measured against what the
## runner can actually do (measured, not modelled -- stage_probe re-flies these
## arcs every run: sprint jump 301 across and 193 up, standing jump 162 up):
##
##   the arena is 1,450 wide     so the pair can see most of it at once and the
##                               guardian is not panning blind mid-charge
##   barricades are 128 tall     taller than the Keeper's 110px hitbox, so a
##                               charge cannot ride over one -- and under a
##                               162px jump, so the runner hops it without
##                               thinking
##   barricades are 600 apart    far enough that "which one am I backing onto"
##                               is a decision, close enough that the answer is
##                               never "neither"

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
## No pit and no spikes. The only things in here that can hurt anybody are the
## Keeper and its shockwave, so every death in this stage is the fight's.
const KILL_Y := 1100.0
const START := Vector2(-940, 330)
const STAGE_NAME := "THE KEEPER"
const STAGE_NUMBER := "1-B"
const OBJECTIVE := "Bring the Keeper down"

const FLOOR := GROUND_TOP
## The arena proper. The approach is everything left of ARENA_LEFT.
const ARENA_LEFT := -200.0
const ARENA_RIGHT := 1250.0
const BARRICADE_A := 180.0
const BARRICADE_B := 780.0
const GATE_ID := "keeper_gate"

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	# One floor, from the approach to past the gate. Flat on purpose: a boss
	# fight where the runner also has to read the terrain is two problems at
	# once, and the one this stage is about is the telegraph.
	g.append(Rect2(-1060.0, FLOOR, 2480.0, GROUND_BASE - FLOOR))
	return g

## The walls that make it a room rather than a corridor.
##
## The right-hand pair is the point: a lintel that nothing can get over, and a
## gap under it that only the gate fills. Without the lintel the guardian could
## put a platform above the gate and walk the runner out of the fight, which
## would make the whole stage optional.
static func solid_decor() -> Array[Rect2]:
	return [
		Rect2(-1120.0, -420.0, 60.0, 820.0),      # the way back, shut
		Rect2(ARENA_RIGHT - 28.0, -520.0, 56.0, 500.0),   # the lintel over the gate
	]

static func hazards() -> Array[Dictionary]:
	return []

## One enemy in the whole stage.
static func enemies() -> Array[Dictionary]:
	return [
		{
			"type": "keeper",
			"pos": Vector2(1000.0, FLOOR - Balance.KEEPER_HITBOX.y * 0.5),
			"home": Vector2(ARENA_LEFT + Balance.KEEPER_HITBOX.x * 0.5,
				ARENA_RIGHT - Balance.KEEPER_HITBOX.x * 0.5),
			"gate": GATE_ID,
		},
	]

## Two barricades and the gate they are standing in for.
##
## `act` is the last act a barricade survives, and Keeper.barricades_for_act is
## the same statement from the other side. Act one has both, act two has the far
## one, act three has neither and the guardian's wall is the only cover left.
static func gimmicks() -> Array[Dictionary]:
	return [
		{"type": "barricade",
		 "pos": Vector2(BARRICADE_A, FLOOR - Balance.BARRICADE_SIZE.y * 0.5), "act": 1},
		{"type": "barricade",
		 "pos": Vector2(BARRICADE_B, FLOOR - Balance.BARRICADE_SIZE.y * 0.5), "act": 2},
		{"type": "gate", "id": GATE_ID, "pos": Vector2(ARENA_RIGHT, FLOOR - 210.0),
		 "span": Vector2(56.0, 420.0), "wants": 0},
	]

## Three, and every one of them is on the floor of the arena -- which is to say
## on the charge lane. The gauge the guardian needs for act three is lying in
## the one place the runner cannot stand still in.
static func crystals() -> Array[Vector2]:
	return [
		Vector2(420.0, FLOOR - 60.0),
		Vector2(950.0, FLOOR - 60.0),
		Vector2(-60.0, FLOOR - 60.0),
	]

## One on the way in, one inside the door. Dying puts the runner back at the
## arena's edge with the act intact (GameState.boss_hp), never back down the
## approach corridor: walking in again is not part of the lesson.
static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(-700.0, FLOOR - 40.0),
		Vector2(ARENA_LEFT - 60.0, FLOOR - 40.0),
	]

static func goal() -> Vector2:
	return Vector2(1360.0, FLOOR - 55.0)

static func coins() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

## Both players see the same arena. The asymmetry in this stage is in what the
## two of them can DO, not in what they can see -- see 1-V for the other kind.
static func veils() -> Array[Dictionary]:
	return []

## The approach is dressed, the arena is nearly bare.
##
## Not an oversight. Everything standing in the arena is either cover or it is
## a lie about cover, and in a fight whose whole question is "is there something
## between us" a decorative barrel is a cruel joke. So the scenery stops at the
## threshold, and what is inside is braziers (which light the floor), rubble
## (which is flat) and banners (which are on the wall).
static func decor() -> Array[Dictionary]:
	return [
		{"type": "cart", "pos": Vector2(-1000.0, FLOOR), "flip": true},
		{"type": "lantern", "pos": Vector2(-820.0, FLOOR), "scale": 0.8},
		{"type": "fence", "pos": Vector2(-640.0, FLOOR), "width": 220.0},
		{"type": "grave", "pos": Vector2(-430.0, FLOOR), "scale": 0.74},
		{"type": "roots", "pos": Vector2(-300.0, FLOOR), "flip": false},
		{"type": "brazier", "pos": Vector2(ARENA_LEFT + 40.0, FLOOR), "scale": 1.0},
		{"type": "rubble", "pos": Vector2(400.0, FLOOR), "scale": 0.9},
		{"type": "banner", "pos": Vector2(560.0, FLOOR), "flip": false},
		{"type": "rubble", "pos": Vector2(930.0, FLOOR), "scale": 0.68},
		{"type": "banner", "pos": Vector2(1080.0, FLOOR), "flip": true},
		{"type": "brazier", "pos": Vector2(ARENA_RIGHT - 90.0, FLOOR), "scale": 1.0},
		{"type": "lantern", "pos": Vector2(1330.0, FLOOR), "scale": 0.9},
	]
