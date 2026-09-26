extends RefCounted
## Stage 1-4 "THE SUNLIT COAST" -- the first sea stage.
##
## A bright shoreline run, left to right, drawn from the 1-4 sea art pack.
## Between the beaches is open water: falling in is a fall, so every crossing
## is a question of footing. Eight beats:
##
##   A  beach start       -- read the crab, hop the spikes, the purple chaser
##                           wakes behind. A spring and its coins off to one side.
##   B  stepping rocks    -- three mossy rocks, jumps anyone can make, with a
##                           small raft drifting across the last of them.
##   C  the old pier      -- a tide belt over the deck that turns every 3.2s,
##                           then 540px of missing planks: one guardian slab.
##   D  cliff island      -- a rock step and a sea breeze that trades speed for
##                           height, then 750px of open water: one slab placed
##                           well, or two placed safely.
##   E  drifting raft     -- a moving platform ferries the runner across, and a
##                           second one beside it is lifted by the tide.
##   F  rope bridge       -- a bridge and two planks that give way.
##   G  last crossing     -- a harbour gate whose switch only the rifle reaches,
##                           then 650px of water with the chaser closing.
##   H  lighthouse point  -- a beacon sweeps the approach, 1.6s lit and 1.4s
##                           dark, and then the goal flag.
##
## Jumps are sized against the measured runner: a sprint jump carries ~301px
## across and ~193px up, so the rock and bridge gaps (80..180px) are free and
## the three water gaps (540, 650, 750px) are not.
##
## The three water gaps are the stage, so nothing added to it is allowed
## inside one: every gimmick here sits over a beach, a pier or a rock and
## changes how a beat is crossed, never whether the guardian is needed for it.
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
	# A spiked strip washed up on the first beach. Everything else on 1-4 is
	# dangerous because of where it is not -- this is the one thing that is
	# dangerous while both of the runner's feet are on the sand, and it is on
	# the beach you are given to get used to the controls on.
	return [{"pos": Vector2(180, 384), "size": Vector2(130, 32)}]

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

## Nine pieces now, spread one or two to a beat, and none of them inside the
## three water channels: those stay the guardian's to answer, which is the
## whole shape of the stage. Everything added here sits over a beach, a pier
## or a rock, where it changes how a beat is crossed rather than whether it
## needs crossing.
static func gimmicks() -> Array[Dictionary]:
	return [
		# B -- a small raft drifting between the last two stepping rocks. The
		# first moving footing in the stage, over a gap a sprint clears anyway,
		# so the ferry at E is not also the lesson in how a raft behaves.
		{"type": "moving_platform", "pos": Vector2(1560, 392),
			"span": Vector2(96, 22), "travel": Vector2(120, 0), "speed": 55.0},
		# C -- the tide running over what is left of the pier deck, turning
		# every 3.2s. The 540px of missing planks after it has not changed;
		# what has changed is that standing on the end of the pier to talk
		# about it is now a decision.
		{"type": "conveyor", "pos": Vector2(2760, 347),
			"span": Vector2(300, 26), "speed": 120.0, "flip": 3.2, "dir": 1},
		# D -- a sea breeze off the cliff. Height for nothing, paid for in
		# horizontal speed (Balance.UPDRAFT_DRAG), right where the runner is
		# about to need all of it: ride it and there had better be something
		# up there, which is a sentence one of them has to say out loud.
		{"type": "updraft", "pos": Vector2(5220, 290), "span": Vector2(140, 380)},
		# E -- the ferry that carries the runner over the channel, unchanged.
		{"type": "moving_platform", "pos": Vector2(6680, 300),
			"span": Vector2(140, 26), "travel": Vector2(380, 0)},
		# ...and beside it a raft the tide lifts rather than carries. The one
		# piece of vertical travel on the coast, and the only way to the coins
		# over the landing.
		{"type": "moving_platform", "pos": Vector2(6260, 300),
			"span": Vector2(120, 24), "travel": Vector2(0, -130), "speed": 55.0},
		# F -- the rope bridge's loose plank, and a second one on the pier stub
		# past it, so the bridge is two commitments instead of one.
		{"type": "crumble", "pos": Vector2(8080, 320), "span": Vector2(100, 30)},
		{"type": "crumble", "pos": Vector2(8300, 305), "span": Vector2(110, 30)},
		# G -- a harbour gate in front of the last crossing. The switch hangs
		# where only the rifle reaches it, the gate is open for six seconds,
		# and the purple chaser is closing the whole time.
		{"type": "switch", "pos": Vector2(8720, 140), "id": "coast_gate", "hold": 6.0},
		{"type": "gate", "pos": Vector2(8900, 175), "span": Vector2(44, 190),
			"id": "coast_gate", "wants": 0},
		# H -- a beacon sweeps the last stretch of the point, under the painted
		# lighthouse in the backdrop. 1.6s lit, 1.4s dark: run the dark, or
		# have a wall put up in front of it.
		{"type": "laser", "pos": Vector2(10560, 220), "dir": Vector2.LEFT,
			"length": 560.0},
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

## Deliberately clear of the three water gaps: a pad that crossed one would
## answer the question the stage exists to ask. These are under coin arcs.
static func springs() -> Array[Vector2]:
	return [Vector2(600, 400), Vector2(9880, 250)]

## Arcs over the jumps and the water, pointing at the intended landing.
static func coins() -> Array[Vector2]:
	return [
		Vector2(-700, 350), Vector2(-620, 330), Vector2(-540, 350),
		# over the first spring
		Vector2(538, 230), Vector2(569, 184), Vector2(600, 168),
		Vector2(631, 184), Vector2(662, 230),
		Vector2(960, 330), Vector2(1115, 340), Vector2(1280, 310),
		Vector2(1445, 315), Vector2(1600, 300), Vector2(1755, 300),
		Vector2(2560, 310), Vector2(2780, 300),
		Vector2(3080, 250), Vector2(3230, 230), Vector2(3380, 250),
		Vector2(4370, 290), Vector2(4505, 300), Vector2(4640, 260),
		Vector2(5460, 200), Vector2(5680, 175), Vector2(5900, 200),
		# at the top of the tide lift, reachable no other way
		Vector2(6200, 182), Vector2(6260, 162), Vector2(6320, 182),
		Vector2(6600, 250), Vector2(6800, 240), Vector2(7000, 240), Vector2(7180, 260),
		Vector2(7950, 250), Vector2(8200, 245), Vector2(8400, 235),
		Vector2(9200, 180), Vector2(9375, 160), Vector2(9550, 180),
		# over the lighthouse spring, before the beam
		Vector2(9820, 140), Vector2(9850, 110), Vector2(9880, 98),
		Vector2(9910, 110), Vector2(9940, 140),
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
