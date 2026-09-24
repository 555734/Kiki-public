extends RefCounted
## Stage 1-4 "THE SUNLIT COAST" -- the first sea stage.
##
## A bright shoreline run, left to right, drawn from the 1-4 sea art pack.
## Between the beaches is open water: falling in is a fall, so every crossing
## is a question of footing. Six beats:
##
##   A  beach start       -- read the crab, the purple chaser wakes behind.
##   B  stepping rocks    -- three mossy rocks, jumps anyone can make.
##   C  the old pier      -- 540px of missing planks NEEDS one guardian slab.
##   D  cliff island      -- a rock step, then 750px of open water: one slab
##                           placed well, or two placed safely.
##   E  drifting raft     -- a moving platform ferries the runner across.
##   F  rope bridge       -- a bridge and a plank that gives way.
##   G  last crossing     -- 650px of water with the chaser closing: guardian.
##   H  lighthouse point  -- the goal flag.
##
## Jumps are sized against the measured runner: a sprint jump carries ~301px
## across and ~193px up, so the rock and bridge gaps (80..180px) are free and
## the three water gaps (540, 650, 750px) are not.
##
## Enemy vocabulary: crabs walk the sand (the walker, reskinned), seabirds own
## the air (the flyer, reskinned), and the purple chaser is the unkillable
## pressure from behind (the pursuer, reskinned). Art resolves the skins.

const GROUND_BASE := 900.0
## The sea's surface. Everything below it is water, drawn by SeaWater.
const WATER_Y := 500.0
## Falling in is a fall. A little under the surface, so the splash reads first.
const KILL_Y := 600.0
const START := Vector2(-1000, 330)
const STAGE_NAME := "THE SUNLIT COAST"
const STAGE_NUMBER := "1-4"
const OBJECTIVE := "Reach the lighthouse flag"

static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

## [x0, x1, top] for every beach and cliff. Drawn down to GROUND_BASE, which
## is under the water, so a beach reads as sand running into the sea.
const SLABS := [
	[-1600.0, 880.0, 400.0],   # A beach start
	[1900.0, 2500.0, 380.0],   # B after the rocks
	[3700.0, 4300.0, 340.0],   # C after the pier
	[4700.0, 5300.0, 290.0],   # D cliff island
	[6050.0, 6500.0, 340.0],   # E raft landing
	[7250.0, 7900.0, 310.0],   # F bridge head
	[8450.0, 9050.0, 270.0],   # G last beach before the crossing
	[9700.0, 10950.0, 250.0],  # H lighthouse point
]

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	for s in SLABS:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## Everything you can stand on that is not a beach: rocks, piers and a bridge.
## The rect is the walkable slab; the painting is fitted to it by Decor, and
## reaches down into the water.
static func _footing() -> Array[Dictionary]:
	return [
		# B -- stepping rocks.
		{"type": "sea_rock", "rect": Rect2(1040, 405, 150, 40)},
		{"type": "sea_rock", "rect": Rect2(1370, 380, 150, 40)},
		{"type": "sea_rock", "rect": Rect2(1690, 365, 130, 40)},
		# C -- the old pier, with its middle gone.
		{"type": "sea_pier", "rect": Rect2(2600, 360, 360, 30)},
		{"type": "sea_bridge", "rect": Rect2(3500, 350, 200, 30)},
		# D -- one rock between the pier beach and the cliff.
		{"type": "sea_rock", "rect": Rect2(4440, 350, 130, 40)},
		# F -- the rope bridge's fixed half.
		{"type": "sea_pier", "rect": Rect2(7990, 305, 170, 26)},
	]

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for f in _footing():
		out.append(f["rect"])
	return out

static func hazards() -> Array[Dictionary]:
	return []

static func enemies() -> Array[Dictionary]:
	return [
		# The purple chaser: permanent pressure from behind, a little gentler
		# than 1-2's because the water gaps already ask for the guardian.
		{
			"type": "sky_pursuer",
			"pos": Vector2(-1900, 335),
			"delay": 3.0,
			"speed": 200.0,
			"catchup": 480.0,
			"stun": 1.5,
		},
		# Crabs walk the sand (walker, sea skin). y = ledge top - 21.
		{"type": "walker", "pos": Vector2(-300, 379), "patrol": 160.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(2200, 359), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(4000, 319), "patrol": 140.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(5000, 269), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(7600, 289), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(8750, 249), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(10250, 229), "patrol": 200.0, "skin": "sea_crab"},
		# Seabirds own the air over the water (flyer, sea skin).
		{"type": "flyer", "pos": Vector2(1300, 230), "patrol": 160.0},
		{"type": "flyer", "pos": Vector2(3230, 210), "patrol": 200.0},
		{"type": "flyer", "pos": Vector2(5680, 170), "patrol": 180.0},
		{"type": "flyer", "pos": Vector2(6880, 160), "patrol": 160.0},
		{"type": "flyer", "pos": Vector2(9380, 130), "patrol": 170.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# E -- a raft that ferries the runner over the channel.
		{"type": "moving_platform", "pos": Vector2(6680, 300),
			"span": Vector2(140, 26), "travel": Vector2(380, 0)},
		# F -- the rope bridge's loose plank.
		{"type": "crumble", "pos": Vector2(8300, 305), "span": Vector2(110, 30)},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(1960, 330),
		Vector2(3760, 290),
		Vector2(4760, 240),
		Vector2(6110, 290),
		Vector2(7310, 260),
		Vector2(8510, 220),
		Vector2(9780, 200),
	]

static func goal() -> Vector2:
	return Vector2(10700, 195)

static func crystals() -> Array[Vector2]:
	return []

static func springs() -> Array[Vector2]:
	return []

## Arcs over the jumps and the water, pointing at the intended landing.
static func coins() -> Array[Vector2]:
	return [
		Vector2(-700, 350), Vector2(-620, 330), Vector2(-540, 350),
		Vector2(960, 330), Vector2(1115, 340), Vector2(1280, 310),
		Vector2(1445, 315), Vector2(1600, 300), Vector2(1755, 300),
		Vector2(2560, 310), Vector2(2780, 300),
		Vector2(3080, 250), Vector2(3230, 230), Vector2(3380, 250),
		Vector2(4370, 290), Vector2(4505, 300), Vector2(4640, 260),
		Vector2(5460, 200), Vector2(5680, 175), Vector2(5900, 200),
		Vector2(6600, 250), Vector2(6800, 240), Vector2(7000, 240), Vector2(7180, 260),
		Vector2(7950, 250), Vector2(8200, 245), Vector2(8400, 235),
		Vector2(9200, 180), Vector2(9375, 160), Vector2(9550, 180),
		Vector2(10100, 200), Vector2(10180, 180), Vector2(10260, 200),
	]

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# A -- beach start.
		{"type": "sea_palm", "pos": Vector2(-1420, 400), "height": 300.0},
		{"type": "sea_grass", "pos": Vector2(-1180, 400)},
		{"type": "sea_boulder", "pos": Vector2(-820, 400), "width": 150.0},
		{"type": "sea_palm_small", "pos": Vector2(-120, 400), "height": 190.0},
		{"type": "sea_grass", "pos": Vector2(300, 400)},
		{"type": "sea_seaweed", "pos": Vector2(780, 400)},
		# B
		{"type": "sea_grass", "pos": Vector2(1980, 380)},
		{"type": "sea_palm", "pos": Vector2(2380, 380), "height": 280.0, "flip": true},
		# C
		{"type": "sea_seaweed", "pos": Vector2(3760, 340)},
		{"type": "sea_boulder", "pos": Vector2(4190, 340), "width": 130.0},
		# D -- cliff island.
		{"type": "sea_palm", "pos": Vector2(4820, 290), "height": 290.0},
		{"type": "sea_grass", "pos": Vector2(5200, 290)},
		# E
		{"type": "sea_palm_small", "pos": Vector2(6150, 340), "height": 180.0, "flip": true},
		{"type": "sea_seaweed", "pos": Vector2(6420, 340)},
		# F
		{"type": "sea_grass", "pos": Vector2(7300, 310)},
		{"type": "sea_boulder", "pos": Vector2(7820, 310), "width": 120.0},
		# G
		{"type": "sea_palm", "pos": Vector2(8560, 270), "height": 280.0, "flip": true},
		{"type": "sea_seaweed", "pos": Vector2(8980, 270)},
		# H -- lighthouse point.
		{"type": "sea_grass", "pos": Vector2(9780, 250)},
		{"type": "sea_palm_small", "pos": Vector2(10000, 250), "height": 200.0},
		{"type": "sea_boulder", "pos": Vector2(10450, 250), "width": 140.0},
		{"type": "sea_palm", "pos": Vector2(10880, 250), "height": 310.0, "flip": true},
	]
	out.append_array(_footing())
	return out

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
