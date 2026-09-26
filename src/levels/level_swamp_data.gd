extends RefCounted
## Stage 1-5: bright poisonous marsh. The liquid is lethal on contact; dry
## moss and timber are safe. Three channels require the guardian's platforms,
## while the broad middle crossing uses a moving log raft.

const BASE := 900.0
const WATER_Y := 520.0
const KILL_Y := 620.0
const START := Vector2(-1050, 350)
const STAGE_NAME := "THE POISON MARSH"
const STAGE_NUMBER := "1-5"
const OBJECTIVE := "Cross the poison marsh"

static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

const SLABS := [
	[-1400.0, 500.0, 400.0],
	[1800.0, 2400.0, 380.0],
	[3450.0, 4050.0, 350.0],
	[5020.0, 5570.0, 330.0],
	[6200.0, 6800.0, 320.0],
	[7860.0, 8400.0, 300.0],
	[9050.0, 10100.0, 290.0],
]

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for slab in SLABS:
		out.append(Rect2(slab[0], slab[2], slab[1] - slab[0], BASE - slab[2]))
	return out

static func _stones() -> Array[Dictionary]:
	# Narrow, unevenly stacked footing. Every gap here sits between 152 and 190
	# pixels: a walking jump covers 182, so the wide ones only clear at a sprint
	# and the landings are barely wider than the runner.
	return [
		{"type": "swamp_stone", "rect": Rect2(676, 404, 112, 58)},
		{"type": "swamp_stone", "rect": Rect2(972, 384, 104, 78)},
		{"type": "swamp_stone", "rect": Rect2(1266, 396, 100, 66)},
		{"type": "swamp_stone", "rect": Rect2(1552, 372, 96, 90)},
		{"type": "swamp_bridge", "rect": Rect2(2550, 370, 170, 30)},
		{"type": "swamp_stone", "rect": Rect2(4238, 342, 98, 70)},
		{"type": "swamp_stone", "rect": Rect2(4526, 328, 94, 84)},
		{"type": "swamp_stone", "rect": Rect2(4806, 336, 94, 76)},
	]

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for item in _stones():
		out.append(item["rect"])
	return out

static func hazards() -> Array[Dictionary]:
	# A single surface sensor prevents a runner from surviving in the bright
	# green liquid until the off-screen pit catches them.
	return [{"pos": Vector2(4350, WATER_Y + 34),
		"size": Vector2(11600, 68), "draw_spikes": false}]

static func enemies() -> Array[Dictionary]:
	return [
		{"type": "walker", "pos": Vector2(-350, 379), "patrol": 210.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(2100, 359), "patrol": 190.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(3740, 329), "patrol": 200.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(5340, 309), "patrol": 170.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(6480, 299), "patrol": 190.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(8160, 279), "patrol": 190.0,
			"skin": "walker_spiky"},
		{"type": "walker", "pos": Vector2(9540, 269), "patrol": 170.0,
			"skin": "walker_spiky"},
		# Flyers now hang in the jump arcs rather than above them, so the
		# stepping stones and the raft need the guardian's rifle first.
		{"type": "flyer", "pos": Vector2(1300, 340), "patrol": 160.0},
		{"type": "flyer", "pos": Vector2(3200, 170), "patrol": 180.0},
		{"type": "flyer", "pos": Vector2(4560, 300), "patrol": 220.0},
		{"type": "flyer", "pos": Vector2(5900, 150), "patrol": 190.0},
		{"type": "flyer", "pos": Vector2(7250, 250), "patrol": 300.0},
		{"type": "flyer", "pos": Vector2(8750, 130), "patrol": 180.0},
	]

static func gimmicks() -> Array[Dictionary]:
	# The raft deck is narrower than the runner's landing margin used to be, and
	# it travels further, so boarding and leaving it are both timed hops.
	# Every crumbling slab sits inside one of the three guardian channels: it
	# offers 0.45s of floor, which turns each crossing into a two-step plan
	# instead of a single platform placed at leisure.
	return [
		{"type": "moving_platform", "pos": Vector2(6890, 315),
			"span": Vector2(130, 26), "travel": Vector2(800, 0)},
		{"type": "crumble", "pos": Vector2(2836, 370),
			"span": Vector2(92, 28)},
		{"type": "crumble", "pos": Vector2(3086, 360),
			"span": Vector2(92, 28)},
		{"type": "crumble", "pos": Vector2(5980, 330),
			"span": Vector2(92, 28)},
		{"type": "crumble", "pos": Vector2(8810, 305),
			"span": Vector2(92, 28)},
	]

static func checkpoints() -> Array[Vector2]:
	return [Vector2(1880, 330), Vector2(3530, 300), Vector2(5100, 280),
		Vector2(6280, 270), Vector2(7950, 250), Vector2(9130, 240)]

static func goal() -> Vector2:
	return Vector2(9840, 235)

static func coins() -> Array[Vector2]:
	return [
		Vector2(-760, 345), Vector2(-680, 325), Vector2(-600, 345),
		Vector2(732, 344), Vector2(1024, 324), Vector2(1316, 336),
		Vector2(1600, 312), Vector2(2010, 320), Vector2(2635, 300),
		Vector2(2970, 250), Vector2(3150, 230), Vector2(3330, 250),
		Vector2(4287, 282), Vector2(4573, 268), Vector2(4853, 276),
		Vector2(5740, 225), Vector2(5910, 205), Vector2(6080, 225),
		Vector2(7040, 250), Vector2(7260, 240), Vector2(7480, 250),
		Vector2(8560, 200), Vector2(8740, 180), Vector2(8920, 200),
		Vector2(9500, 220), Vector2(9580, 200), Vector2(9660, 220),
	]

static func crystals() -> Array[Vector2]:
	return [Vector2(2210, 310), Vector2(5310, 260), Vector2(8150, 225)]

static func springs() -> Array[Vector2]:
	return []

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "swamp_tree", "pos": Vector2(-1240, 400), "height": 280.0},
		{"type": "swamp_reeds", "pos": Vector2(-910, 400)},
		{"type": "swamp_mushroom", "pos": Vector2(-120, 400)},
		{"type": "swamp_reeds", "pos": Vector2(420, 400)},
		{"type": "swamp_mushroom", "pos": Vector2(1860, 380)},
		{"type": "swamp_tree", "pos": Vector2(2300, 380), "height": 230.0,
			"flip": true},
		{"type": "swamp_reeds", "pos": Vector2(3520, 350)},
		{"type": "swamp_boulder", "pos": Vector2(3960, 350)},
		{"type": "swamp_tree", "pos": Vector2(5160, 330), "height": 270.0},
		{"type": "swamp_mushroom", "pos": Vector2(5500, 330)},
		{"type": "swamp_reeds", "pos": Vector2(6260, 320)},
		{"type": "swamp_tree", "pos": Vector2(6720, 320), "height": 255.0,
			"flip": true},
		{"type": "swamp_mushroom", "pos": Vector2(7920, 300)},
		{"type": "swamp_boulder", "pos": Vector2(8340, 300)},
		{"type": "swamp_tree", "pos": Vector2(9190, 290), "height": 270.0},
		{"type": "swamp_reeds", "pos": Vector2(9510, 290)},
		{"type": "swamp_mushroom", "pos": Vector2(10000, 290)},
	]
	out.append_array(_stones())
	return out

static func veils() -> Array[Dictionary]:
	return []
