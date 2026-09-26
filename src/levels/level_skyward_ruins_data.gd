extends RefCounted
## Stage 1-3 "THE SKYWARD RUINS" -- a bottom-to-top co-op climb.
##
## Five sections, each forking or timing-based: blink slabs that take turns
## existing, conveyors that reverse, rope bridges that give way, a warp perch
## that skips the relay, mines, sprouts and stone golems. Every moving part is
## a pure function of the stage clock, so both devices agree for free.
##
## World Y decreases as the team climbs.  Keeping the whole route between
## y=300 and y=7000 is deliberate: Snapshot keeps eighth-pixel Y precision in
## [-1024, 7167], so online play needs no wider packet or protocol change.

const STAGE_NAME := "THE SKYWARD RUINS"
const STAGE_NUMBER := "1-3"
const OBJECTIVE := "Reach the summit gate"
const START := Vector2(-180.0, 6334.0)
const KILL_Y := 7000.0
const ISLAND_T := 150.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

static func _island(x: float, top: float, width: float) -> Rect2:
	return Rect2(x, top, width, ISLAND_T)

static func ground() -> Array[Rect2]:
	return [
		# Start and pursuit read.
		_island(-520, 6380, 760),
		_island(500, 6030, 330),
		_island(-430, 5660, 360),

		# Rescue run: moving pieces cross the empty middle; these are rests.
		_island(360, 5280, 330),
		_island(-690, 4900, 390),
		_island(190, 4540, 360),

		# Two-slab relay. No wall is close enough to wall-kick up it.
		_island(-700, 4120, 300),
		_island(470, 3740, 300),
		_island(-360, 3360, 320),

		# Timed gate and lift.
		_island(240, 2980, 360),
		_island(-650, 2580, 360),
		_island(320, 2180, 340),

		# Summit: deliberately no catch floor below the final relay.
		_island(-610, 1780, 300),
		_island(430, 1370, 300),
		_island(-350, 970, 330),
		_island(-620, 520, 1240),
	]

static func solid_decor() -> Array[Rect2]:
	return []

static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(0, 6348), "size": Vector2(150, 42)},
		{"pos": Vector2(525, 2158), "size": Vector2(92, 42)},
	]

## Every enemy below moves as a pure function of the stage clock, so the guest
## draws them where the host has them without a snapshot entry.
static func enemies() -> Array[Dictionary]:
	return [
		# No wake-up grace: gameplay is frozen by the home screen, then this
		# begins moving on the first live physics tick.
		{"type": "sky_pursuer", "pos": Vector2(-180, 6750), "delay": 0.0,
		 "speed": 205.0, "catchup": 475.0, "stun": 1.45,
		 "direction": Vector2.UP},
		# 1: the fork. A bird over the crumbling left climb, a sprout
		# weaving across the right-hand blink stairs.
		{"type": "flyer", "pos": Vector2(-560, 5950), "patrol": 110.0},
		{"type": "seedling", "pos": Vector2(400, 6080), "reach": Vector2(80, 40),
		 "period": 4.5},
		# 2: moving decks, the conveyor detour and the warp perch.
		{"type": "flyer", "pos": Vector2(80, 5420), "patrol": 150.0},
		{"type": "mine", "pos": Vector2(-60, 4930), "bob": Vector2(0, 40),
		 "period": 3.4},
		# 3: the relay gap is patrolled; the golem owns the far island.
		{"type": "flyer", "pos": Vector2(-80, 4270), "patrol": 170.0},
		{"type": "seedling", "pos": Vector2(0, 3960), "reach": Vector2(230, 80),
		 "period": 6.0, "phase": 1.3},
		{"type": "golem", "pos": Vector2(620, 3705), "patrol": 85.0, "period": 5.5},
		# 4: the gate, with a mine waiting at the warp's exit.
		{"type": "turret", "pos": Vector2(420, 2925), "aim": Vector2.LEFT, "burst": 2},
		{"type": "mine", "pos": Vector2(250, 2860), "bob": Vector2(40, 0), "period": 2.8},
		{"type": "turret", "pos": Vector2(-620, 2375), "aim": Vector2.RIGHT, "burst": 2},
		# 5: the mine field, then the summit's stone guardian.
		{"type": "flyer", "pos": Vector2(70, 1910), "patrol": 180.0},
		{"type": "mine", "pos": Vector2(0, 1620), "bob": Vector2(0, 70), "period": 3.0},
		{"type": "mine", "pos": Vector2(250, 1480), "bob": Vector2(0, 60), "period": 3.0,
		 "phase": 1.5},
		{"type": "mine", "pos": Vector2(-160, 1180), "bob": Vector2(60, 0), "period": 2.6,
		 "phase": 0.7},
		{"type": "mine", "pos": Vector2(120, 1080), "bob": Vector2(0, 50), "period": 3.2,
		 "phase": 2.2},
		{"type": "turret", "pos": Vector2(-180, 915), "aim": Vector2.RIGHT, "burst": 2},
		{"type": "mine", "pos": Vector2(-590, 780), "bob": Vector2(0, 40), "period": 3.0,
		 "phase": 1.0},
		{"type": "golem", "pos": Vector2(-300, 485), "patrol": 130.0, "period": 6.5,
		 "phase": 1.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# 1, left fork: two rope bridges that give way, then a slow lift.
		{"type": "crumble", "pos": Vector2(-590, 6290), "span": Vector2(120, 40)},
		{"type": "crumble", "pos": Vector2(-470, 6180), "span": Vector2(120, 40)},
		{"type": "moving_platform", "pos": Vector2(-640, 6063),
		 "span": Vector2(150, 26), "travel": Vector2(0, -400), "speed": 60.0},
		# 1, right fork: blue and purple slabs take turns existing.
		{"type": "blink", "pos": Vector2(300, 6283), "span": Vector2(140, 26),
		 "beat": 1.6, "colour": 0},
		{"type": "blink", "pos": Vector2(420, 6163), "span": Vector2(140, 26),
		 "beat": 1.6, "colour": 1},

		# 2: the runner commits before the moving deck arrives; a missed
		# landing is recoverable only through a guardian catch.
		{"type": "moving_platform", "pos": Vector2(20, 5480),
		 "span": Vector2(150, 26), "travel": Vector2(520, -120), "phase": 0.8},
		{"type": "moving_platform", "pos": Vector2(-40, 4740),
		 "span": Vector2(150, 26), "travel": Vector2(-500, -90), "phase": 2.1},
		# 2, detour: a belt that turns round every three seconds, then a slab.
		{"type": "conveyor", "pos": Vector2(150, 5163), "span": Vector2(240, 26),
		 "speed": 160.0, "flip": 3.0, "dir": -1},
		{"type": "blink", "pos": Vector2(-200, 5043), "span": Vector2(140, 26),
		 "beat": 1.8, "colour": 1},
		# 2, the warp: a perch only a chained jump reaches sends the runner
		# past the whole relay to the gate section, straight into a mine.
		{"type": "warp", "pos": Vector2(-600, 4640), "size": Vector2(90, 120),
		 "exit": Vector2(330, 2890)},
		{"type": "warp_exit", "pos": Vector2(330, 2890), "size": Vector2(90, 120)},

		# 3: a rope bridge back across from the golem's island.
		{"type": "crumble", "pos": Vector2(330, 3640), "span": Vector2(120, 40)},
		{"type": "crumble", "pos": Vector2(110, 3520), "span": Vector2(120, 40)},

		# 4: six seconds from shot to gate close, shared by both peers.
		{"type": "switch", "pos": Vector2(500, 2905), "id": "skyward_gate",
		 "hold": 6.0, "sigil": 2},
		{"type": "gate", "pos": Vector2(-300, 2485), "span": Vector2(46, 190),
		 "id": "skyward_gate", "wants": 2},
		{"type": "moving_platform", "pos": Vector2(-40, 2780),
		 "span": Vector2(140, 26), "travel": Vector2(-360, -310)},
		# 4, past the gate: belt, then a purple-blue pair to the far ledge.
		{"type": "conveyor", "pos": Vector2(-140, 2483), "span": Vector2(240, 26),
		 "speed": 170.0, "flip": 2.6, "dir": 1},
		{"type": "blink", "pos": Vector2(170, 2373), "span": Vector2(140, 26),
		 "beat": 1.4, "colour": 1},
		{"type": "blink", "pos": Vector2(250, 2273), "span": Vector2(140, 26),
		 "beat": 1.4, "colour": 0},

		# 5: a deck through the mine field, then the blink stairs to the top.
		{"type": "moving_platform", "pos": Vector2(-100, 1683),
		 "span": Vector2(150, 26), "travel": Vector2(430, -200), "speed": 80.0,
		 "phase": 2.0},
		{"type": "blink", "pos": Vector2(-440, 873), "span": Vector2(140, 26),
		 "beat": 1.5, "colour": 0},
		{"type": "blink", "pos": Vector2(-300, 763), "span": Vector2(140, 26),
		 "beat": 1.5, "colour": 1},
		{"type": "blink", "pos": Vector2(-450, 653), "span": Vector2(140, 26),
		 "beat": 1.5, "colour": 0},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(-260, 5610),
		Vector2(300, 4490),
		Vector2(-250, 3310),
		Vector2(430, 2130),
	]

static func goal() -> Vector2:
	return Vector2(0, 425)

## Fuel sits on the compulsory line. A platform launch costs 50; regeneration
## remains the guaranteed retry path after a crystal has already been banked.
static func crystals() -> Array[Vector2]:
	return [
		Vector2(560, 5900), Vector2(-320, 5530),
		Vector2(410, 5150), Vector2(-560, 4770), Vector2(250, 4410),
		Vector2(-590, 3990), Vector2(560, 3610), Vector2(-250, 3230),
		Vector2(330, 2850), Vector2(-540, 2450), Vector2(400, 2050),
		Vector2(-500, 1650), Vector2(510, 1240), Vector2(-240, 840),
	]

static func springs() -> Array[Vector2]:
	return []

## Short arcs of three, laid along every route including both forks, so the
## coins also say "this way works".
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var route := [
		# fork: left bridges and lift / right blink stairs
		Vector2(-590, 6220), Vector2(-640, 5860), Vector2(300, 6210), Vector2(430, 6090),
		Vector2(180, 5840), Vector2(-120, 5460), Vector2(210, 5080),
		Vector2(140, 5100), Vector2(-200, 4980), Vector2(-600, 4560),
		Vector2(-250, 4700), Vector2(120, 4320),
		Vector2(-260, 3920), Vector2(220, 3540), Vector2(330, 3570), Vector2(-110, 3160),
		Vector2(160, 2760), Vector2(-140, 2420), Vector2(210, 2210),
		Vector2(-220, 2360), Vector2(180, 1960),
		Vector2(-180, 1560), Vector2(230, 1150), Vector2(-80, 760),
		Vector2(-300, 700), Vector2(-450, 590),
	]
	for p in route:
		out.append(p + Vector2(-52, 18))
		out.append(p)
		out.append(p + Vector2(52, -18))
	return out

## pos is the foot of each piece on its island; waterfalls hang from pos.
static func decor() -> Array[Dictionary]:
	return [
		# start
		{"type": "tree", "pos": Vector2(-420, 6380), "size": Vector2(200, 230)},
		{"type": "flowers", "pos": Vector2(-280, 6380), "size": Vector2(70, 55)},
		{"type": "sign", "pos": Vector2(-110, 6380), "size": Vector2(80, 90)},
		{"type": "bush", "pos": Vector2(120, 6380), "size": Vector2(80, 60)},
		{"type": "waterfall", "pos": Vector2(-300, 6450), "size": Vector2(130, 420)},
		{"type": "ruin_column", "pos": Vector2(780, 6030), "size": Vector2(70, 190)},
		{"type": "bush", "pos": Vector2(560, 6030), "size": Vector2(70, 50)},
		{"type": "arch", "pos": Vector2(-250, 5660), "size": Vector2(200, 200)},
		{"type": "grass", "pos": Vector2(-110, 5660), "size": Vector2(50, 40)},
		# moving decks
		{"type": "tree_tall", "pos": Vector2(640, 5280), "size": Vector2(100, 200)},
		{"type": "flowers", "pos": Vector2(420, 5280), "size": Vector2(70, 50)},
		{"type": "waterfall", "pos": Vector2(520, 5350), "size": Vector2(110, 380)},
		{"type": "ruin_pile", "pos": Vector2(-450, 4900), "size": Vector2(150, 120)},
		{"type": "pillar", "pos": Vector2(-330, 4900), "size": Vector2(70, 180)},
		{"type": "tree", "pos": Vector2(480, 4540), "size": Vector2(200, 220)},
		{"type": "bush", "pos": Vector2(240, 4540), "size": Vector2(70, 50)},
		# relay
		{"type": "arch", "pos": Vector2(-550, 4120), "size": Vector2(210, 210)},
		{"type": "waterfall", "pos": Vector2(-600, 4190), "size": Vector2(120, 420)},
		{"type": "pillar_broken", "pos": Vector2(740, 3740), "size": Vector2(90, 150)},
		{"type": "cloud_bank", "pos": Vector2(0, 3300), "size": Vector2(1100, 210)},
		{"type": "ruin_stairs", "pos": Vector2(-120, 3360), "size": Vector2(150, 120)},
		{"type": "tree_tall", "pos": Vector2(-330, 3360), "size": Vector2(100, 190)},
		# gate
		{"type": "ruin_column", "pos": Vector2(580, 2980), "size": Vector2(70, 190)},
		{"type": "stone_wall", "pos": Vector2(-560, 2580), "size": Vector2(140, 90)},
		{"type": "waterfall", "pos": Vector2(-480, 2650), "size": Vector2(130, 450)},
		{"type": "arch", "pos": Vector2(560, 2180), "size": Vector2(200, 200)},
		# summit climb
		{"type": "tree", "pos": Vector2(-560, 1780), "size": Vector2(200, 220)},
		{"type": "flowers", "pos": Vector2(-380, 1780), "size": Vector2(60, 45)},
		{"type": "cloud_bank", "pos": Vector2(0, 1420), "size": Vector2(1200, 240)},
		{"type": "pillar", "pos": Vector2(700, 1370), "size": Vector2(70, 180)},
		{"type": "waterfall", "pos": Vector2(600, 1440), "size": Vector2(110, 380)},
		{"type": "ruin_pile", "pos": Vector2(-60, 970), "size": Vector2(120, 90)},
		# summit: the broken tower behind the gate
		{"type": "ruin_tower", "pos": Vector2(320, 520), "size": Vector2(400, 380)},
		{"type": "ruin_column", "pos": Vector2(-570, 520), "size": Vector2(70, 190)},
		{"type": "ruin_column", "pos": Vector2(570, 520), "size": Vector2(70, 190)},
		{"type": "tree", "pos": Vector2(-470, 520), "size": Vector2(200, 230)},
		{"type": "bush", "pos": Vector2(170, 520), "size": Vector2(80, 60)},
		{"type": "flowers", "pos": Vector2(-120, 520), "size": Vector2(60, 50)},
	]

static func veils() -> Array[Dictionary]:
	return []
