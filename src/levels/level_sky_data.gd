extends RefCounted
## Stage 1-S "THE OPEN SKY" -- the flight stage. See docs/stage-sky.md.
##
## The one stage where the runner cannot walk to the goal. Between the islands
## there is nothing, and the only thing that crosses nothing is a launch: the
## guardian's slab, with the runner standing on it, shot.
##
## Two tools that the level design had never once asked for carry this stage:
##
##   the launch   named in launch_trigger.gd as "the move the whole co-op idea
##                is for", and required by exactly two gaps in 1-C
##   the warp     ability slot 4, 22 gauge a gate, and not one stage's geometry
##                has ever needed a pair
##
## EVERY DISTANCE HERE IS AGAINST A MEASURED ARC, not against a constant.
## sky_probe re-flies all of them every run:
##
##   a sprint jump          301 across, 193 up
##   a launch, flat         ~665 across
##   a launch, +120 up      ~580 across
##   a launch, +200 up      ~531 across
##
## And one number that is not in Balance at all: a runner who pushes BACK during
## a launch loses their horizontal speed at RUNNER_AIR_TURN (2736 px/s^2), which
## kills 780px/s in 0.285s. So a launch is a MAXIMUM of ~665px and the runner
## chooses anything shorter. Section 2 is built entirely out of that fact, and
## it needed no new code -- only a gap that punishes overshooting.

const STAGE_NAME := "THE OPEN SKY"
const STAGE_NUMBER := "1-S"
const OBJECTIVE := "Reach the beacon"
const START := Vector2(-950, 340)

## How thick an island is. They are drawn as a slab from this top down, with a
## painted keel hanging under them (see decor) -- the whole stage rests on the
## runner believing there is nothing below.
const ISLAND_T := 120.0

## The lower road: the wreck of an older causeway, well below the islands.
##
## This is the stage's safety net, and it is the same idea as 1-V's rescue
## ledge: a fall in sections 1-4 costs SECONDS, not progress. It is broken into
## four disconnected stretches on purpose -- each one sits under one section and
## goes nowhere, so falling can never become a quieter route along the bottom.
## Section 5 has none, which is the whole of how that section gets its teeth.
const LOWER := 780.0
const KILL_Y := 1160.0

## The island tops, named because the rest of the file is written against them.
const EDGE := 420.0          ## the last real ground
const A := 420.0             ## section 1, flat: one launch, then another
const B := 380.0             ## section 2, narrow landings
const C1 := 300.0            ## section 3, the foot of the climb
const C2 := 0.0              ## ...and the top of it, 300px up
const D := 260.0             ## section 4, no islands between
const E := 200.0             ## section 5, the splinter
const GOAL_TOP := 140.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

## An island: a slab of the given width at the given top, ISLAND_T thick.
static func _isle(x: float, w: float, top: float) -> Rect2:
	return Rect2(x, top, w, ISLAND_T)

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	# ---- 0: the edge. The last place with anything under it ---------------
	g.append(Rect2(-1250.0, EDGE, 850.0, 400.0))

	# ---- 1: the launch is the road ----------------------------------------
	# Two flat hops. Wide landings, because the lesson here is the launch and
	# not the landing.
	g.append(_isle(180.0, 300.0, A))
	g.append(_isle(1010.0, 300.0, A))

	# ---- 2: the launch is a MAXIMUM ---------------------------------------
	# Narrow landings, closer than a full launch. Coast and you fly past them.
	g.append(_isle(1700.0, 170.0, B))
	g.append(_isle(2320.0, 170.0, B))

	# ---- 3: a climb no launch makes ---------------------------------------
	# C2 is 300px above C1 and 730 across, and BOTH numbers are the column's.
	# A plain launch carries 665 flat, so it passes under C2 at the height it
	# left and falls; a launch that climbs 300 carries only 370, so nothing
	# lands up there on its own.
	#
	# Through the column, the arc peaks 485 up and is still 300 up at 782
	# across in clear air -- but PLAYED, off this stage's own slab and through
	# this stage's own column, the runner comes down at 3,975. The difference is
	# where the column sits relative to the launch, and it is 150px; the landing
	# is placed against the played number and it is wide enough to absorb the
	# rest. Both numbers are in sky_probe, and the played one is the one that
	# decides.
	g.append(_isle(3000.0, 260.0, C1))
	g.append(_isle(3860.0, 360.0, C2))

	# ---- 4: no islands. The guardian's slabs are the road ------------------
	g.append(_isle(4620.0, 220.0, D))
	# ...nothing for 1,500px...
	g.append(_isle(6140.0, 260.0, D))

	# ---- 5: past the last checkpoint, nothing below ------------------------
	# One launch lands on this splinter; from there, and only from there, the
	# far lip is inside the guardian's placement range.
	g.append(_isle(6900.0, 260.0, E))
	g.append(_isle(8380.0, 900.0, GOAL_TOP))

	# ---- the lower road, in four disconnected stretches --------------------
	# Each one sits under one section and ends at a column that returns the
	# runner to THAT SECTION'S START. Returning them to its end would make
	# falling a way to skip the section, which is what the first layout did:
	# a single column at the far end of section 4 crossed its 1,500px gap for
	# free. Section 5 has no stretch at all.
	g.append(Rect2(-100.0, LOWER, 1540.0, 220.0))
	g.append(Rect2(1640.0, LOWER, 1140.0, 220.0))
	g.append(Rect2(2850.0, LOWER, 1400.0, 220.0))
	g.append(Rect2(4360.0, LOWER, 1940.0, 220.0))
	return g

static func solid_decor() -> Array[Rect2]:
	return []

## Nothing kills by touch. The only way to lose a heart in here is a flyer, and
## the only way to die is section 5, where there is no lower road.
static func hazards() -> Array[Dictionary]:
	return []

## Columns of rising air, and the first one is a rescue.
##
## The four at the end of each stretch of lower road are how a fall is undone:
## walk to the column, ride it back up to the islands. That is where the pair
## MEETS an updraft -- by falling into one -- which means section 3 can ask them
## to fly into one on purpose without ever having to explain it.
##
## Authored from the BOTTOM CENTRE, so the y here is the floor it rises from.
static func gimmicks() -> Array[Dictionary]:
	return [
		# --- the four rescue columns ----------------------------------------
		#
		# Two rules, and both were learned by watching the probe.
		#
		# Clear of the island ABOVE, because a column under a deck lifts the
		# runner into its underside and stops 200px short of anywhere useful.
		#
		# And clear of where a LAUNCH SLAB GOES -- which is just past an
		# island's right lip, because that is where the guardian puts one. Three
		# of these were sitting exactly there, so the runner would walk onto the
		# slab, be picked up off it by the column before the guardian could
		# shoot, and drift back down into the void. The trace read
		# "f24 x=4854 floor=true / f36 x=4909 floor=false" and nothing else in
		# the stage could have done that.
		#
		# So each one sits BEFORE the island it returns the runner to. They rise
		# alongside it and steer across on the way up, which is free: a column
		# takes about a second to climb and air control works the whole time.
		{"type": "updraft", "pos": Vector2(900.0, LOWER),
		 "span": Vector2(170.0, 560.0)},
		{"type": "updraft", "pos": Vector2(2200.0, LOWER),
		 "span": Vector2(170.0, 560.0)},
		{"type": "updraft", "pos": Vector2(2900.0, LOWER),
		 "span": Vector2(170.0, 560.0)},
		{"type": "updraft", "pos": Vector2(4480.0, LOWER),
		 "span": Vector2(170.0, 620.0)},

		# --- section 3: the column that is a ROUTE rather than a rescue ------
		#
		# Wide, and tall well past the landing it serves. Both are the same
		# lesson, learned the hard way: a runner crossing a 210px column at
		# 780px/s is inside it for a quarter of a second and gains 68px, which
		# is nothing. A column is worth something only to somebody who STOPS in
		# it, and its top has to stand clear of the deck it delivers to so
		# there is time to drift across on the way down.
		{"type": "updraft", "pos": Vector2(3500.0, 560.0),
		 "span": Vector2(240.0, 720.0)},

		# Section 4 has NO column, and that is a deletion rather than an
		# omission. One was put there "so the chain has a place to breathe",
		# and the probe found the runner sailing 1,209px off the first launch
		# and landing 11px short of the far island -- the column had turned the
		# crossing into a single flight and quietly made it section 3 again.
		# One idea per section: section 3 is the column, section 4 is the chain.
	]

## Flyers only, and every one of them sits ON a flight line.
##
## A turret would be wrong here: the guardian's answer to a turret is the wall,
## and a wall in this stage is a thing the runner flies into. A flyer is
## answered by shooting it BEFORE the launch, which is exactly the rhythm the
## stage wants -- clear the line, then fire.
static func enemies() -> Array[Dictionary]:
	return [
		{"type": "flyer", "pos": Vector2(760.0, A - 220.0), "patrol": 120.0},
		{"type": "flyer", "pos": Vector2(2100.0, B - 230.0), "patrol": 150.0},
		{"type": "flyer", "pos": Vector2(4450.0, C2 + 140.0), "patrol": 110.0},
		{"type": "flyer", "pos": Vector2(5600.0, D - 250.0), "patrol": 190.0},
	]

## The fuel, strung along the arcs.
##
## One hop costs 50 (a platform at 30, the shot that fires it at 20) and the
## gauge refills at 8 a second, so a pair who only wait can hop every 6.25s.
## A crystal is 34. Two on an arc turn a good launch into a profit and a bad one
## into a wait, which is the whole economy of this stage: the guardian aims the
## line and the runner flies it.
##
## Heights are set against the arc: a launch rises ~307px over its first 364px
## of travel, so a crystal ~200px up and ~250px along sits near the climb, and
## one ~260px up and ~430px along sits near the apex.
static func crystals() -> Array[Vector2]:
	# THREE to an arc, seventy pixels apart, hung where the arc is flattest.
	#
	# A single crystal per arc does not work and the reason is worth keeping: a
	# crystal's radius is 30px, a slab is 150 wide, and LaunchTrigger.loaded()
	# accepts the runner anywhere along it -- so where a launch STARTS varies by
	# ±75px depending on how far the runner walked before the shot. One crystal
	# threads a 30px needle from an unknown start; sky_probe flew the line and
	# collected nothing at all. A short string of them is caught by anybody
	# roughly on the line and missed entirely by anybody who is not.
	#
	# The heights are the arc's own, measured: 225px up at 180 across, 294 at
	# 380, apex 296. The offsets below are from the runner's middle while they
	# stand on the slab, which is the island top less 23.
	return [
		# 1: the two flat hops
		Vector2(-80.0, A - 280.0), Vector2(10.0, A - 308.0), Vector2(100.0, A - 318.0),
		Vector2(800.0, A - 280.0), Vector2(890.0, A - 308.0), Vector2(980.0, A - 318.0),
		# 2: the narrow landings. These sit SHORT, on the braked line -- a
		# runner who coasts to the apex here has already flown past the island.
		Vector2(1540.0, A - 223.0), Vector2(1610.0, A - 268.0), Vector2(1680.0, A - 298.0),
		Vector2(2100.0, B - 223.0), Vector2(2170.0, B - 268.0), Vector2(2240.0, B - 298.0),
		# 3: up through the column
		Vector2(3430.0, C1 - 170.0), Vector2(3600.0, C1 - 380.0),
		Vector2(3780.0, C1 - 420.0),
		# 4: one string per link of the chain
		Vector2(5160.0, D - 280.0), Vector2(5250.0, D - 308.0), Vector2(5340.0, D - 318.0),
		Vector2(5800.0, D - 280.0), Vector2(5890.0, D - 308.0),
		# 5: the last two crossings
		Vector2(6720.0, D - 280.0), Vector2(6810.0, D - 308.0), Vector2(6900.0, D - 318.0),
		Vector2(7700.0, E - 150.0), Vector2(8100.0, E - 150.0),
	]

## Before each section, and one past the long gap.
##
## The last one is the important one: a fall in section 5 is the only real death
## in the stage, and it must not put the pair back through section 4.
static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(-700.0, EDGE - 40.0),
		Vector2(1120.0, A - 40.0),
		Vector2(2400.0, B - 40.0),
		Vector2(4060.0, C2 - 40.0),
		Vector2(6240.0, D - 40.0),
	]

static func goal() -> Vector2:
	return Vector2(8900.0, GOAL_TOP - 55.0)

static func coins() -> Array[Vector2]:
	return []

## No springs. A spring is ground-based height, and this stage's answer to
## height is the column -- two ways to do the same thing would make neither of
## them mean anything.
static func springs() -> Array[Vector2]:
	return []

## Both players see the same sky. See 1-V for the other kind of stage.
static func veils() -> Array[Dictionary]:
	return []

## Keels under every island, and landmarks the pair can NAME.
##
## The keels are load-bearing, not decoration: an island drawn as a slab with
## nothing under it reads as a platform in a blue room. The taper is what says
## "this is floating, and there is nothing below you".
##
## The arches and streamers are 1-V's landmark rule (implementation-plan.md
## 6.1) applied to a stage with no landmarks of its own: unevenly spaced, so
## "the second arch" and "the third" can be told apart out loud.
static func decor() -> Array[Dictionary]:
	return [
		{"type": "arch", "pos": Vector2(-1050.0, EDGE), "scale": 1.0},
		{"type": "streamer", "pos": Vector2(-520.0, EDGE), "scale": 1.0},

		{"type": "keel", "pos": Vector2(330.0, A + ISLAND_T), "width": 300.0},
		{"type": "streamer", "pos": Vector2(250.0, A), "scale": 0.86},
		{"type": "keel", "pos": Vector2(1160.0, A + ISLAND_T), "width": 300.0},
		{"type": "arch", "pos": Vector2(1180.0, A), "scale": 0.82},

		{"type": "keel", "pos": Vector2(1785.0, B + ISLAND_T), "width": 170.0},
		{"type": "keel", "pos": Vector2(2405.0, B + ISLAND_T), "width": 170.0},
		{"type": "streamer", "pos": Vector2(2360.0, B), "scale": 0.8},

		{"type": "keel", "pos": Vector2(3130.0, C1 + ISLAND_T), "width": 260.0},
		{"type": "arch", "pos": Vector2(3070.0, C1), "scale": 0.9},
		{"type": "keel", "pos": Vector2(4040.0, C2 + ISLAND_T), "width": 360.0},
		{"type": "streamer", "pos": Vector2(4180.0, C2), "scale": 0.92},

		{"type": "keel", "pos": Vector2(4730.0, D + ISLAND_T), "width": 220.0},
		{"type": "keel", "pos": Vector2(6270.0, D + ISLAND_T), "width": 260.0},
		{"type": "arch", "pos": Vector2(6330.0, D), "scale": 0.86},

		{"type": "keel", "pos": Vector2(7030.0, E + ISLAND_T), "width": 260.0},
		{"type": "keel", "pos": Vector2(8830.0, GOAL_TOP + ISLAND_T), "width": 900.0},
		{"type": "streamer", "pos": Vector2(8500.0, GOAL_TOP), "scale": 1.0},
	]
