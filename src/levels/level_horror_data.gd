extends RefCounted
## Stage 1-2 "THE HOLLOW OUTSKIRTS".
##
## A survival-horror skin on the same co-op vocabulary as the other stages: the
## runner is chased through a drowned village while the guardian creates escape
## routes and briefly stuns the pursuer. Touching the pursuer, the thorns, or a
## pit resets immediately. The monster cannot be killed, so shooting buys time.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(-1000, 330)
const STAGE_NAME := "THE HOLLOW OUTSKIRTS"
const STAGE_NUMBER := "1-2"
const OBJECTIVE := "Reach the village gate"

const FLOOR := 400.0
const LOW := 320.0
const MID := 260.0
const HIGH := 40.0

# Getter functions let Stage preload this script directly instead of depending
# on Godot's generated global class cache. That matters after a plain git pull:
# a newly-added class_name may not exist in an older .godot cache yet.
static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

static func solid_decor() -> Array[Rect2]:
	return []

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		[-1600.0, 1000.0, FLOOR],
		[1560.0, 2500.0, FLOOR],
		[2500.0, 3300.0, LOW],
		[3300.0, 4050.0, HIGH],
		[4050.0, 4700.0, MID],
		[5300.0, 6300.0, MID],
		[6300.0, 7000.0, 200.0],
		[7000.0, 7550.0, 200.0],
		[7800.0, 8450.0, LOW],
		[8450.0, 9000.0, LOW],
		[9560.0, 10800.0, MID],
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(1280, 610), "size": Vector2(520, 46)},
		{"pos": Vector2(5000, 570), "size": Vector2(560, 46)},
		{"pos": Vector2(9280, 590), "size": Vector2(520, 46)},
	]

static func enemies() -> Array[Dictionary]:
	return [
		{
			"type": "sky_pursuer",
			"pos": Vector2(-1900, 335),
			"delay": 2.25,
			"speed": 220.0,
			"catchup": 520.0,
			"stun": 1.35,
		},
	]

static func gimmicks() -> Array[Dictionary]:
	return []

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(1700, FLOOR - 50.0),
		Vector2(4200, MID - 50.0),
		Vector2(5450, MID - 50.0),
		Vector2(7950, LOW - 50.0),
		Vector2(9700, MID - 50.0),
	]

static func goal() -> Vector2:
	return Vector2(10550, MID - 55.0)

static func crystals() -> Array[Vector2]:
	return [
		Vector2(-250, FLOOR - 65.0),
		Vector2(1850, FLOOR - 65.0),
		Vector2(2860, LOW - 140.0),
		Vector2(3650, HIGH - 80.0),
		Vector2(4450, MID - 65.0),
		Vector2(5900, MID - 220.0),
		Vector2(6650, 120.0),
		Vector2(8150, LOW - 70.0),
		Vector2(8800, LOW - 150.0),
		Vector2(10000, MID - 160.0),
	]

static func springs() -> Array[Vector2]:
	return []

static func coins() -> Array[Vector2]:
	return []

static func decor() -> Array[Dictionary]:
	return [
		{"type": "cart", "pos": Vector2(-1260, FLOOR), "flip": true},
		{"type": "lantern", "pos": Vector2(-980, FLOOR), "scale": 0.86},
		{"type": "fence", "pos": Vector2(-760, FLOOR), "width": 240.0},
		{"type": "puddle", "pos": Vector2(-360, FLOOR), "width": 250.0},
		{"type": "crate", "pos": Vector2(420, FLOOR), "scale": 0.92},
		{"type": "crow", "pos": Vector2(720, 322), "flip": false},
		{"type": "roots", "pos": Vector2(1690, FLOOR), "flip": false},
		{"type": "lantern", "pos": Vector2(1900, FLOOR), "scale": 0.72},
		{"type": "banner", "pos": Vector2(2240, FLOOR), "flip": false},
		{"type": "grave", "pos": Vector2(2440, FLOOR), "scale": 0.72},
		{"type": "fence", "pos": Vector2(2620, LOW), "width": 240.0},
		{"type": "crate", "pos": Vector2(3070, LOW), "scale": 0.84},
		{"type": "grave", "pos": Vector2(3450, HIGH), "scale": 0.82},
		{"type": "banner", "pos": Vector2(3890, HIGH), "flip": true},
		{"type": "crow", "pos": Vector2(3740, -22), "flip": true},
		{"type": "puddle", "pos": Vector2(4330, MID), "width": 210.0},
		{"type": "roots", "pos": Vector2(4590, MID), "flip": true},
		{"type": "cart", "pos": Vector2(5530, MID), "flip": false},
		{"type": "fence", "pos": Vector2(5780, MID), "width": 260.0},
		{"type": "crate", "pos": Vector2(6120, MID), "scale": 0.72},
		{"type": "lantern", "pos": Vector2(6500, 200.0), "scale": 0.82},
		{"type": "banner", "pos": Vector2(6880, 200.0), "flip": false},
		{"type": "puddle", "pos": Vector2(7240, 200.0), "width": 240.0},
		{"type": "roots", "pos": Vector2(7930, LOW), "flip": false},
		{"type": "grave", "pos": Vector2(8240, LOW), "scale": 0.78},
		{"type": "fence", "pos": Vector2(8520, LOW), "width": 250.0},
		{"type": "crow", "pos": Vector2(8900, 235), "flip": false},
		{"type": "lantern", "pos": Vector2(9780, MID), "scale": 0.92},
		{"type": "crate", "pos": Vector2(10120, MID), "scale": 0.9},
		{"type": "banner", "pos": Vector2(10370, MID), "flip": true},
	]

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
