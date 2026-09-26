extends RefCounted
## Stage 1-4 "THE SUNLIT COAST" -- the sea stage, rebuilt as a hard one.
##
## A shoreline run, left to right, drawn from the 1-4 sea art pack. The coast
## is all relief now: sea stacks, cliffs and drops of up to 560px, with open
## water under everything, so a miss is a fall. Nine beats:
##
##   A  beach start       -- two crabs, a spiked strip to hop, and the purple
##                           chaser waking early.
##   A2 dune steps        -- two 110px step-ups to warm the jump up, and a tide
##                           belt across the top that turns every 3.2s.
##   B  stepping rocks    -- rocks that rise and fall, then a cliff with a
##                           turret firing down at the climb.
##   C  crumbling pier    -- three planks that give way, then 560px of open
##                           water that NEEDS a guardian slab.
##   D  sea stacks        -- three pillars climbing 120px each, a sea breeze off
##                           the highest one that trades speed for height, then
##                           a 460px drop to a beach guarded by a turret.
##   E  the lift raft     -- a raft rising 300px up the face of a cliff.
##   F  blinking steps    -- three blink platforms over 700px of sea, out of
##                           phase, so the crossing is a rhythm.
##   G  the sea wall      -- a spring over a 280px wall, then 620px of water
##                           with seabirds over it: guardian.
##   H  falling bridge    -- a harbour gate whose switch only the rifle reaches,
##                           then three crumbling planks, the chaser closing.
##   I  last climb        -- two steps up and 650px of water: guardian, then a
##                           beacon sweeping the point, and the flag.
##
## Jumps are sized against the measured runner (B = 48): a jump rises 154px
## (184 at a sprint), a sprint jump carries ~300px, a spring ~307px. So every
## unassisted gap is <= 200px, every unassisted step-up <= 120px, and the three
## guardian crossings are 560..650px -- nothing sits in the unfair middle.
##
## Enemy vocabulary: crabs walk the sand (the walker, reskinned), seabirds own
## the air (the flyer, reskinned), turrets hold the cliff tops, and the purple
## chaser is the unkillable pressure from behind (the pursuer, reskinned).

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

## [x0, x1, top] for every beach, cliff and sea stack. Drawn down to
## GROUND_BASE, under the water, so each one reads as rock rising out of the sea.
const SLABS := [
	[-1600.0, 600.0, 400.0],    # A beach start
	[600.0, 900.0, 300.0],      # A2 dune step
	[900.0, 1200.0, 190.0],     # A2 dune top
	[2120.0, 2500.0, 120.0],    # B cliff (turret)
	[3600.0, 4000.0, 200.0],    # C landing after the guardian crossing
	[4150.0, 4300.0, 80.0],     # D sea stack 1
	[4450.0, 4600.0, -40.0],    # D sea stack 2
	[4750.0, 4900.0, -160.0],   # D sea stack 3, the high point
	[5100.0, 5600.0, 300.0],    # D beach below (turret)
	[5900.0, 6300.0, 0.0],      # E cliff the raft climbs to
	[7000.0, 7400.0, 180.0],    # F landing after the blink steps
	[7400.0, 8000.0, -100.0],   # G sea wall top (spring below)
	[8620.0, 9100.0, 120.0],    # G beach after the guardian crossing
	[9700.0, 10100.0, 60.0],    # H landing after the falling bridge
	[10100.0, 10350.0, -40.0],  # I step
	[10350.0, 10600.0, -140.0], # I step (turret)
	[11250.0, 12400.0, 100.0],  # I lighthouse point
]

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	for s in SLABS:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## Everything you can stand on that is not a beach: rocks and pier ends.
## The rect is the walkable slab; the painting is fitted to it by Decor, and
## reaches down into the water.
static func _footing() -> Array[Dictionary]:
	return [
		# B -- stepping rocks that go down, down, then up to the cliff.
		{"type": "sea_rock", "rect": Rect2(1330, 260, 120, 40)},
		{"type": "sea_rock", "rect": Rect2(1600, 330, 110, 40)},
		{"type": "sea_rock", "rect": Rect2(1860, 230, 110, 40)},
		# C -- the last sound piece of the pier, where the planks run out.
		{"type": "sea_pier", "rect": Rect2(2980, 150, 60, 30)},
	]

static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for f in _footing():
		out.append(f["rect"])
	return out

## A spiked strip washed up on the first beach. Everything else on this coast
## is dangerous because of what is under it; this is the one thing that is
## dangerous with both feet on the sand, and it is on the beach the stage gives
## you to get used to the controls on.
static func hazards() -> Array[Dictionary]:
	return [{"pos": Vector2(150, 384), "size": Vector2(130, 32)}]

static func enemies() -> Array[Dictionary]:
	return [
		# The purple chaser: faster than it used to be, and awake sooner.
		{
			"type": "sky_pursuer",
			"pos": Vector2(-1900, 335),
			"delay": 2.5,
			"speed": 240.0,
			"catchup": 540.0,
			"stun": 1.3,
		},
		# Crabs walk the sand (walker, sea skin). y = ledge top - 21.
		{"type": "walker", "pos": Vector2(-300, 379), "patrol": 160.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(320, 379), "patrol": 140.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(2260, 99), "patrol": 90.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(3820, 179), "patrol": 120.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(5300, 279), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(7720, -121), "patrol": 180.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(8860, 99), "patrol": 150.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(11700, 79), "patrol": 220.0, "skin": "sea_crab"},
		# Turrets hold the cliff tops, firing back down the climb. y = top - 26.
		{"type": "turret", "pos": Vector2(2440, 94), "aim": Vector2.LEFT, "burst": 2},
		{"type": "turret", "pos": Vector2(5560, 274), "aim": Vector2.LEFT, "burst": 3},
		{"type": "turret", "pos": Vector2(10560, -166), "aim": Vector2.LEFT, "burst": 3},
		# Seabirds own the air over the water and the stacks (flyer, sea skin).
		{"type": "flyer", "pos": Vector2(1560, 120), "patrol": 170.0},
		{"type": "flyer", "pos": Vector2(3300, 20), "patrol": 220.0},
		{"type": "flyer", "pos": Vector2(4600, -230), "patrol": 160.0},
		{"type": "flyer", "pos": Vector2(6620, -120), "patrol": 200.0},
		{"type": "flyer", "pos": Vector2(8300, -200), "patrol": 200.0},
		{"type": "flyer", "pos": Vector2(9400, -40), "patrol": 170.0},
		{"type": "flyer", "pos": Vector2(10920, -150), "patrol": 220.0},
	]

## Eight kinds now, not three. The relief is what makes this coast hard -- the
## drops and the open water under everything -- and that does not change here;
## what changes is how many different questions it asks on the way down.
##
## Everything added is INSIDE a slab. The three guardian crossings (560, 620
## and 650px) are the spine of the stage and the probe allows no spare: a
## gimmick whose x-span touched one would read as bridging it, and the stage
## would quietly stop needing a second player for that crossing.
static func gimmicks() -> Array[Dictionary]:
	return [
		# A2 -- the tide over the wet top of the dune, turning every 3.2s. The
		# 130px hop off the end has not changed; what has changed is that
		# standing on the lip to line it up is now a decision.
		{"type": "conveyor", "pos": Vector2(1040, 177),
			"span": Vector2(240, 26), "speed": 120.0, "flip": 3.2, "dir": 1},
		# C -- the pier's planks, each gone a moment after it is stood on.
		{"type": "crumble", "pos": Vector2(2600, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2760, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2920, 165), "span": Vector2(110, 30)},
		# D -- a sea breeze off the highest stack. Height for nothing, paid for
		# in horizontal speed (Balance.UPDRAFT_DRAG), at the exact point where
		# the next thing is a 460px drop to a beach with a turret on it: ride
		# it and there had better be a plan, which is a sentence one of them
		# has to say out loud.
		{"type": "updraft", "pos": Vector2(4825, -160), "span": Vector2(140, 420)},
		# E -- a raft that rises up the cliff face and sinks back to the beach.
		{"type": "moving_platform", "pos": Vector2(5750, 250),
			"span": Vector2(140, 26), "travel": Vector2(0, -300)},
		# F -- three blink platforms, out of step with each other.
		{"type": "blink", "pos": Vector2(6420, 40), "span": Vector2(120, 26),
			"beat": 1.6, "colour": 0, "phase": 0.0},
		{"type": "blink", "pos": Vector2(6600, 80), "span": Vector2(120, 26),
			"beat": 1.6, "colour": 1, "phase": 0.55},
		{"type": "blink", "pos": Vector2(6780, 120), "span": Vector2(120, 26),
			"beat": 1.6, "colour": 0, "phase": 1.1},
		# G -- a harbour gate in front of the falling bridge. The switch hangs
		# where only the rifle reaches it, the gate is open for six seconds,
		# and the purple chaser is closing the whole time. The checkpoint is
		# right behind it, so getting this wrong costs seconds, not minutes.
		{"type": "switch", "pos": Vector2(8800, -30), "id": "coast_gate", "hold": 6.0},
		{"type": "gate", "pos": Vector2(9020, 25), "span": Vector2(44, 190),
			"id": "coast_gate", "wants": 0},
		# H -- the falling bridge.
		{"type": "crumble", "pos": Vector2(9220, 125), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(9380, 125), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(9540, 125), "span": Vector2(110, 30)},
		# I -- the lighthouse sweeps the last stretch of the point, 1.6s lit
		# and 1.4s dark. Run the dark, or have a wall put up in front of it --
		# and the last three coins are inside the beam, which is the choice.
		{"type": "laser", "pos": Vector2(12000, 70), "dir": Vector2.LEFT,
			"length": 560.0},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(960, 140),
		Vector2(2160, 70),
		Vector2(3660, 150),
		Vector2(5160, 250),
		Vector2(5960, -50),
		Vector2(7060, 130),
		Vector2(8680, 70),
		Vector2(9760, 10),
		Vector2(11320, 50),
	]

static func goal() -> Vector2:
	return Vector2(12200, 45)

static func crystals() -> Array[Vector2]:
	return []

## G -- the spring at the foot of the sea wall. y is the ledge top.
static func springs() -> Array[Vector2]:
	return [Vector2(7330, 180)]

## Arcs over the jumps and the water, pointing at the intended landing.
static func coins() -> Array[Vector2]:
	return [
		Vector2(-700, 350), Vector2(-620, 330), Vector2(-540, 350),
		Vector2(620, 240), Vector2(920, 130),
		Vector2(1265, 200), Vector2(1390, 210), Vector2(1655, 270), Vector2(1915, 170),
		Vector2(2040, 100), Vector2(2600, 110), Vector2(2760, 110), Vector2(2920, 110),
		Vector2(3200, 90), Vector2(3350, 70), Vector2(3500, 110),
		Vector2(4225, 20), Vector2(4525, -100), Vector2(4825, -220),
		Vector2(5000, -60), Vector2(5750, 150), Vector2(5750, 0),
		Vector2(6420, -20), Vector2(6600, 20), Vector2(6780, 60),
		Vector2(7330, 40), Vector2(7400, -160),
		Vector2(8150, -150), Vector2(8310, -170), Vector2(8470, -120),
		Vector2(9220, 70), Vector2(9380, 70), Vector2(9540, 70),
		Vector2(10225, -100), Vector2(10475, -200),
		Vector2(10800, -180), Vector2(10950, -170), Vector2(11100, -110),
		Vector2(11900, 50), Vector2(11980, 30), Vector2(12060, 50),
	]

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# A -- beach start and dunes.
		{"type": "sea_palm", "pos": Vector2(-1420, 400), "height": 300.0},
		{"type": "sea_grass", "pos": Vector2(-1180, 400)},
		{"type": "sea_boulder", "pos": Vector2(-820, 400), "width": 150.0},
		{"type": "sea_palm_small", "pos": Vector2(-120, 400), "height": 190.0},
		{"type": "sea_grass", "pos": Vector2(760, 300)},
		{"type": "sea_seaweed", "pos": Vector2(1120, 190)},
		# B
		{"type": "sea_palm", "pos": Vector2(2180, 120), "height": 260.0, "flip": true},
		# C
		{"type": "sea_seaweed", "pos": Vector2(3660, 200)},
		{"type": "sea_boulder", "pos": Vector2(3930, 200), "width": 110.0},
		# D -- stacks and the beach below.
		{"type": "sea_grass", "pos": Vector2(4820, -160)},
		{"type": "sea_palm_small", "pos": Vector2(5180, 300), "height": 180.0},
		{"type": "sea_seaweed", "pos": Vector2(5450, 300)},
		# E
		{"type": "sea_palm", "pos": Vector2(6200, 0), "height": 280.0, "flip": true},
		# F
		{"type": "sea_grass", "pos": Vector2(7080, 180)},
		# G -- the sea wall.
		{"type": "sea_boulder", "pos": Vector2(7560, -100), "width": 120.0},
		{"type": "sea_palm_small", "pos": Vector2(7900, -100), "height": 190.0, "flip": true},
		{"type": "sea_seaweed", "pos": Vector2(9020, 120)},
		# H
		{"type": "sea_grass", "pos": Vector2(9800, 60)},
		# I -- lighthouse point.
		{"type": "sea_grass", "pos": Vector2(11320, 100)},
		{"type": "sea_palm_small", "pos": Vector2(11500, 100), "height": 200.0},
		{"type": "sea_boulder", "pos": Vector2(11950, 100), "width": 140.0},
		{"type": "sea_palm", "pos": Vector2(12330, 100), "height": 310.0, "flip": true},
	]
	out.append_array(_footing())
	return out

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
