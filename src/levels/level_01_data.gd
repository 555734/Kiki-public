class_name Level01Data
extends RefCounted
## Stage 1-1 "Greenfield Plains", laid out as data rather than as a scene.
##
## Chapter 5's rules are the layout constraints: one question per screen, single
## ability before combined ones, and more than one valid answer wherever it is
## cheap to allow. Chapter 8's arc for stages 1-1 through 1-4 is compressed into
## four sections of one stage so the whole teaching curve fits in a single sitting.
##
## Every gap is sized against the simulated runner arc. The number that matters
## is the best the runner can do unaided: sprinting into a jump and spending the
## air dash clears 507px. The two gaps that exist to teach the platform are
## therefore 600px -- comfortably past that, and comfortably inside the ~796px a
## single platform makes reachable. They were 480px before the sprint went in,
## which the air dash alone had already brought within 40px of crossing.
##
## Keeping this as plain data means a balance pass is editing numbers in one
## file, which is what chapter 8's "P2: playtest iteration" phase needs.

const GROUND_TOP := 400.0
## Every slab is drawn down to this line rather than a fixed thickness, so a
## high ledge reads as a column of earth rather than a slab floating in the sky.
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(60, 320)
const STAGE_NAME := "GREENFIELD PLAINS"
const STAGE_NUMBER := "1-1"
const OBJECTIVE := "Find the Ancient Gate"

## Solid decor -- conduits and block rows -- as world-space rects. Used both by the
## renderer and by the collider builder, so the picture and the physics agree.
static func solid_decor() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in decor():
		match String(d.get("type", "")):
			"conduit":
				var size: Vector2 = d.get("size", Vector2(90, 76))
				var base: Vector2 = d["pos"]
				out.append(Rect2(base.x - size.x * 0.5, base.y - size.y, size.x, size.y))
			"blocks":
				var cell: float = float(d.get("cell", 46.0))
				var n: int = int(d.get("count", 3))
				var at: Vector2 = d["pos"]
				out.append(Rect2(at.x, at.y, cell * float(n), cell))
	return out

## Solid ground: Rect2(x, top_y, width, height).
static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	var slabs := [
		# ---- A: platform -------------------------------------------------
		[-1600.0, 780.0, 400.0],     # start plateau, runs well off-screen left
		[920.0, 1400.0, 400.0],      # after a 140px starter hop
		[1400.0, 1900.0, 340.0],     # 60px step up, walked into and jumped
		[2500.0, 3200.0, 340.0],     # after the 600px platform gap
		# ---- B: snipe ----------------------------------------------------
		[3200.0, 3700.0, 340.0],
		[4320.0, 4900.0, 340.0],     # the moving floor bridges 620px
		[4900.0, 5250.0, 280.0],     # climbing away from the turret
		[5250.0, 5600.0, 220.0],
		[5780.0, 6400.0, 220.0],
		# ---- C: wall -----------------------------------------------------
		[6400.0, 6900.0, 220.0],
		[7000.0, 7160.0, 260.0],     # three narrow ledges under burst fire
		[7280.0, 7440.0, 260.0],
		[7560.0, 7720.0, 260.0],
		[7840.0, 8500.0, 260.0],
		# ---- D: collapse, beam, gate --------------------------------------
		[8500.0, 8900.0, 260.0],
		[9480.0, 10700.0, 260.0],    # collapsing floors bridge 580px
		# ---- E: the climb -------------------------------------------------
		[10700.0, 11100.0, 260.0],
		[11300.0, 11700.0, 180.0],   # 200px gap, 80px rise: sprint and jump
		[11900.0, 12800.0, 40.0],    # 200px gap, 140px rise: needs a platform
		# ---- F: climax ----------------------------------------------------
		[12800.0, 13200.0, 40.0],
		[13350.0, 13800.0, 180.0],   # drop back down
		[14400.0, 15100.0, 180.0],   # collapsing run bridges 600px
		[15640.0, 16700.0, 180.0],   # after the last platform gap (540px)
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## Spike strips, drawn and lethal. Rect centres with a size.
static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(850, 600), "size": Vector2(140, 46)},
		{"pos": Vector2(2200, 640), "size": Vector2(600, 46)},
		{"pos": Vector2(4010, 620), "size": Vector2(620, 46)},
		{"pos": Vector2(5690, 500), "size": Vector2(180, 46)},
		{"pos": Vector2(7400, 560), "size": Vector2(900, 46)},
		{"pos": Vector2(9190, 620), "size": Vector2(580, 46)},
		{"pos": Vector2(11200, 560), "size": Vector2(200, 46)},
		{"pos": Vector2(11800, 460), "size": Vector2(200, 46)},
		{"pos": Vector2(13275, 480), "size": Vector2(150, 46)},
		{"pos": Vector2(14100, 520), "size": Vector2(600, 46)},
		{"pos": Vector2(15370, 500), "size": Vector2(540, 46)},
	]

## Walker y values put the BOTTOM of their 42px box exactly on the ledge they
## stand on, not somewhere near it. They used to spawn 19px in the air (and one
## of them 21px inside the ground), so every checkpoint retry began with the
## enemies dropping out of the sky -- physics sorted it out within a few frames,
## which is exactly why it survived so long.
static func enemies() -> Array[Dictionary]:
	return [
		# A -- one stompable walker, so the runner learns they are not helpless.
		{"type": "walker", "pos": Vector2(1150, 379), "patrol": 190.0},
		{"type": "walker", "pos": Vector2(2800, 319), "patrol": 240.0},
		# B -- the first threats the runner cannot answer alone.
		# The only turret that is meant to be in the air: it hangs over the
		# crossing and fires DOWN at it, so there is no ledge under it. Every
		# other turret's y is its ledge top minus half TURRET_SIZE, which is
		# what puts its feet on the ground -- they were all 19px short of that,
		# and their bursts passed over the runner's head instead of into them.
		{"type": "turret", "pos": Vector2(3900, 90), "aim": Vector2.DOWN, "burst": 2},
		{"type": "flyer", "pos": Vector2(3980, 200), "patrol": 180.0},
		{"type": "walker", "pos": Vector2(4600, 319), "patrol": 200.0},
		{"type": "turret", "pos": Vector2(6320, 194), "aim": Vector2.LEFT, "burst": 2},
		{"type": "flyer", "pos": Vector2(5450, 120), "patrol": 150.0},
		# C -- the burst turret the wall exists for, firing down the ledges.
		{"type": "turret", "pos": Vector2(8000, 234), "aim": Vector2.LEFT, "burst": 3},
		{"type": "walker", "pos": Vector2(6700, 199), "patrol": 200.0},
		# D -- pressure while the floor is already going.
		{"type": "flyer", "pos": Vector2(9200, 150), "patrol": 240.0},
		{"type": "turret", "pos": Vector2(10620, 234), "aim": Vector2.LEFT, "burst": 3},
		{"type": "walker", "pos": Vector2(9900, 239), "patrol": 220.0, "skin": "walker_spiky"},
		# E -- the climb, harassed from above.
		{"type": "flyer", "pos": Vector2(11500, 60), "patrol": 200.0},
		{"type": "flyer", "pos": Vector2(12200, -40), "patrol": 220.0},
		{"type": "walker", "pos": Vector2(12500, 19), "patrol": 240.0, "skin": "walker_spiky"},
		# F -- everything at once.
		{"type": "turret", "pos": Vector2(13450, 154), "aim": Vector2.RIGHT, "burst": 3},
		{"type": "flyer", "pos": Vector2(14200, 60), "patrol": 260.0},
		{"type": "turret", "pos": Vector2(15040, 154), "aim": Vector2.LEFT, "burst": 3},
		{"type": "walker", "pos": Vector2(16100, 159), "patrol": 260.0, "skin": "walker_spiky"},
		{"type": "flyer", "pos": Vector2(15400, 40), "patrol": 240.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# B -- the crossing is a moving floor, so the guardian has to shoot while
		# the ground under the runner is still travelling.
		{"type": "moving_platform", "pos": Vector2(3840, 356),
			"span": Vector2(180, 26), "travel": Vector2(400, 0)},
		# C -- a beam across the narrow ledges: wall it, or dash the off phase.
		{"type": "laser", "pos": Vector2(7900, 190), "dir": Vector2.LEFT, "length": 520},
		# D -- three collapsing slabs. Chapter 5 shortens decision time here
		# rather than making anything tougher.
		{"type": "crumble", "pos": Vector2(9020, 280), "span": Vector2(140, 40)},
		{"type": "crumble", "pos": Vector2(9190, 280), "span": Vector2(140, 40)},
		{"type": "crumble", "pos": Vector2(9360, 280), "span": Vector2(140, 40)},
		# D -- snipe the switch, then get through before it closes.
		{"type": "laser", "pos": Vector2(10180, 190), "dir": Vector2.LEFT, "length": 460},
		{"type": "switch", "pos": Vector2(10380, 60), "id": "ancient_gate", "hold": 6.0},
		{"type": "gate", "pos": Vector2(10420, 165), "span": Vector2(40, 190), "id": "ancient_gate"},
		# E -- a lift to break up the climb, so it is not four identical jumps.
		{"type": "moving_platform", "pos": Vector2(11800, 193),
			"span": Vector2(150, 26), "travel": Vector2(0, -140)},
		# F -- a long collapsing run under fire, then the last gap.
		{"type": "crumble", "pos": Vector2(13940, 200), "span": Vector2(140, 40)},
		{"type": "crumble", "pos": Vector2(14110, 200), "span": Vector2(140, 40)},
		{"type": "crumble", "pos": Vector2(14280, 200), "span": Vector2(140, 40)},
		{"type": "switch", "pos": Vector2(14760, -20), "id": "final_gate", "hold": 7.0},
		{"type": "gate", "pos": Vector2(14900, 85), "span": Vector2(40, 190), "id": "final_gate"},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(3050, 266),    # after the platform lesson
		Vector2(6250, 146),    # after the snipe lesson
		Vector2(8350, 186),    # after the wall lesson
		Vector2(10600, 186),   # after the collapse, beam and gate
		Vector2(12700, -34),   # top of the climb
	]

static func goal() -> Vector2:
	return Vector2(16480, 85)

## Bounce pads, and the coins they exist to reach.
##
## Both are deliberately OFF the critical path. Every one of these sits on a
## ledge the runner already has, launching them up into air they otherwise have
## no reason to visit -- so a spring never answers one of the gaps the guardian
## is supposed to answer, and a coin is never simply on the way. What the runner
## gets for the detour is the guardian's gauge, which is the only currency in
## the game that flows the other way.
##
## The pad in section D used to sit beside the ancient gate, where a 270px
## bounce cleared the closed gate entirely and skipped the switch it exists to
## teach. It is past the gate now. A bounce pad is a movement tool, and every
## one of these had to be checked against what it lets the runner skip.
##
## Each y is a ledge top from ground(); a spring's origin is its base.
## The runner's half of the gauge. Placed in two kinds of place on purpose:
## some on the route everyone takes, so a pair who are just getting through
## still gets some back, and some a little off it where getting there is its own
## small problem -- which is where the interesting decisions are.
static func crystals() -> Array[Vector2]:
	return [
		Vector2(1500, 300),      # on the path: the first one is free, to teach it
		Vector2(2950, 180),      # above the platform lesson, one slab up
		Vector2(4350, 250),      # off to the side of the crossing
		Vector2(5800, 60),       # high over section B, needs a launch or a wall
		Vector2(7400, 140),      # past the beam, on the route
		Vector2(9450, 120),      # over the collapsing floor, a detour
		Vector2(10900, 120),     # after the gate, on the route
		Vector2(12300, -110),    # the top of the climb, off to one side
		Vector2(14000, 70),      # section F, on the route
		Vector2(15600, 60),      # the last detour before the goal
	]

static func springs() -> Array[Vector2]:
	return [
		Vector2(1780, 340),     # A, on the step-up ledge
		Vector2(5180, 280),     # B, clear of the block row overhead
		Vector2(8300, 260),     # C, after the beam
		Vector2(10800, 260),    # E, past the gate rather than beside it
		Vector2(16200, 180),    # F, before the goal
	]

## Derived from springs() rather than listed again: two copies of the same five
## positions is two chances for a coin arc to end up over a pad that moved.
## The pad's throw is Balance.SPRING_HEIGHT, and these arcs sit inside it. The
## height is the dial; quoting a pixel figure here is how this comment went
## stale the last time gravity moved.
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for base in springs():
		# Five in a shallow arc over the pad, the classic shape: it reads as one
		# path rather than as five separate decisions.
		for i in range(5):
			var t := (float(i) - 2.0) / 2.0
			out.append(base + Vector2(t * 62.0, -170.0 - (1.0 - t * t) * 62.0))
	# And a short row at the top of the climb, within an ordinary jump of the
	# ledge -- there is no pad up there, and a coin nothing can reach is worse
	# than no coin at all.
	for i in range(4):
		out.append(Vector2(12440 + float(i) * 54.0, -60.0))
	return out

## Scenery from the mockups.
##
## Pipes and blocks are SOLID -- `size` here is both what gets drawn and what
## gets a collider, so the two can never drift apart. Everything else (fences,
## trees, flowers) stays decoration with no collision: they sit at ankle height
## and would only trip the runner on obstacles they cannot see the point of.
##
## Every conduit is shorter than the runner's 100px jump apex, so all of them
## can be cleared from flat ground. _test_solid_decor() enforces that.
##
## The sizes are left exactly as they were when these were pipes: the rect is
## the collider, every one of them has been jumped over in a playtest at this
## size, and swapping what a thing looks like is not a reason to move the
## surfaces underneath it.
static func decor() -> Array[Dictionary]:
	return [
		# -- A --
		{"type": "tree", "pos": Vector2(-260, 400)},
		{"type": "signpost", "pos": Vector2(-60, 400)},
		{"type": "flowers", "pos": Vector2(180, 400)},
		{"type": "conduit", "pos": Vector2(470, 400), "size": Vector2(62, 88)},
		{"type": "blocks", "pos": Vector2(250, 258), "count": 3, "cell": 46.0},
		{"type": "fence", "pos": Vector2(1000, 400), "width": 190.0},
		{"type": "flowers", "pos": Vector2(1560, 340)},
		{"type": "blocks", "pos": Vector2(1620, 196), "count": 2, "cell": 46.0},
		{"type": "conduit", "pos": Vector2(2760, 340), "size": Vector2(58, 82)},
		{"type": "tree", "pos": Vector2(2620, 340)},
		# -- B --
		{"type": "signpost", "pos": Vector2(3300, 340)},
		{"type": "flowers", "pos": Vector2(3420, 340)},
		{"type": "fence", "pos": Vector2(4420, 340), "width": 200.0},
		{"type": "blocks", "pos": Vector2(5000, 140), "count": 3, "cell": 46.0},
		{"type": "tree", "pos": Vector2(6000, 220)},
		{"type": "flowers", "pos": Vector2(6180, 220)},
		# -- C --
		{"type": "signpost", "pos": Vector2(6470, 220)},
		{"type": "conduit", "pos": Vector2(6600, 220), "size": Vector2(62, 88)},
		{"type": "fence", "pos": Vector2(8060, 260), "width": 220.0},
		{"type": "flowers", "pos": Vector2(8300, 260)},
		# -- D --
		{"type": "blocks", "pos": Vector2(9600, 116), "count": 3, "cell": 46.0},
		{"type": "tree", "pos": Vector2(10000, 260)},
		{"type": "flowers", "pos": Vector2(10480, 260)},
		# -- E --
		{"type": "signpost", "pos": Vector2(10780, 260)},
		{"type": "conduit", "pos": Vector2(10900, 260), "size": Vector2(58, 82)},
		{"type": "flowers", "pos": Vector2(11450, 180)},
		{"type": "blocks", "pos": Vector2(12200, -104), "count": 2, "cell": 46.0},
		{"type": "tree", "pos": Vector2(12420, 40)},
		# -- F --
		{"type": "fence", "pos": Vector2(12900, 40), "width": 200.0},
		{"type": "flowers", "pos": Vector2(13500, 180)},
		{"type": "conduit", "pos": Vector2(14700, 180), "size": Vector2(62, 88)},
		{"type": "tree", "pos": Vector2(16000, 180)},
		{"type": "flowers", "pos": Vector2(16260, 180)},
		{"type": "fence", "pos": Vector2(15800, 180), "width": 180.0},
	]

## Section boundaries, used by the "is the guardian ever idle?" audit in
## test/test_stage_pacing.gd. Chapter 8 makes "the god player is never bored"
## an explicit success condition, so it is checked rather than assumed.
static func sections() -> Array[Dictionary]:
	return [
		{"name": "A - platform", "from": -1600.0, "to": 3200.0, "teaches": "platform"},
		{"name": "B - snipe", "from": 3200.0, "to": 6400.0, "teaches": "snipe"},
		{"name": "C - wall", "from": 6400.0, "to": 8500.0, "teaches": "wall"},
		{"name": "D - collapse and gate", "from": 8500.0, "to": 10700.0, "teaches": "all"},
		{"name": "E - the climb", "from": 10700.0, "to": 12800.0, "teaches": "platform"},
		{"name": "F - climax", "from": 12800.0, "to": 16700.0, "teaches": "all"},
	]

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
