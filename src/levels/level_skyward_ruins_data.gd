extends RefCounted
## Stage 1-3 "THE SKYWARD RUINS" -- a bottom-to-top co-op climb.
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

static func enemies() -> Array[Dictionary]:
	return [
		# No wake-up grace: gameplay is frozen by the home screen, then this
		# begins moving on the first live physics tick.
		{"type": "sky_pursuer", "pos": Vector2(-180, 6750), "delay": 0.0,
		 "speed": 205.0, "catchup": 475.0, "stun": 1.45,
		 "direction": Vector2.UP},
		{"type": "flyer", "pos": Vector2(80, 5420), "patrol": 150.0},
		{"type": "flyer", "pos": Vector2(-80, 4270), "patrol": 170.0},
		{"type": "turret", "pos": Vector2(420, 2925), "aim": Vector2.LEFT, "burst": 2},
		{"type": "flyer", "pos": Vector2(70, 1910), "patrol": 180.0},
		{"type": "turret", "pos": Vector2(-180, 915), "aim": Vector2.RIGHT, "burst": 2},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# Section 2: the runner commits before the moving deck arrives; a missed
		# landing is recoverable only through a guardian catch.
		{"type": "moving_platform", "pos": Vector2(20, 5480),
		 "span": Vector2(150, 26), "travel": Vector2(520, -120)},
		{"type": "moving_platform", "pos": Vector2(-40, 4740),
		 "span": Vector2(150, 26), "travel": Vector2(-500, -90)},

		# Section 4: six seconds from shot to gate close, shared by both peers.
		{"type": "switch", "pos": Vector2(500, 2905), "id": "skyward_gate",
		 "hold": 6.0, "sigil": 2},
		{"type": "gate", "pos": Vector2(-300, 2485), "span": Vector2(46, 190),
		 "id": "skyward_gate", "wants": 2},
		{"type": "moving_platform", "pos": Vector2(-40, 2780),
		 "span": Vector2(140, 26), "travel": Vector2(-360, -310)},
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

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var route := [
		Vector2(420, 6140), Vector2(180, 5840), Vector2(-120, 5460),
		Vector2(210, 5080), Vector2(-250, 4700), Vector2(120, 4320),
		Vector2(-260, 3920), Vector2(220, 3540), Vector2(-110, 3160),
		Vector2(160, 2760), Vector2(-220, 2360), Vector2(180, 1960),
		Vector2(-180, 1560), Vector2(230, 1150), Vector2(-80, 760),
	]
	for p in route:
		out.append(p + Vector2(-52, 18))
		out.append(p)
		out.append(p + Vector2(52, -18))
	return out

static func decor() -> Array[Dictionary]:
	return [
		{"type": "waterfall", "pos": Vector2(-430, 6380), "size": Vector2(150, 430)},
		{"type": "ruin_column", "pos": Vector2(710, 6030), "size": Vector2(70, 210)},
		{"type": "keel", "pos": Vector2(665, 6180), "size": Vector2(330, 210)},
		{"type": "tree", "pos": Vector2(-540, 4900), "size": Vector2(150, 190)},
		{"type": "waterfall", "pos": Vector2(520, 4540), "size": Vector2(120, 520)},
		{"type": "arch", "pos": Vector2(-540, 4120), "size": Vector2(190, 240)},
		{"type": "ruin_column", "pos": Vector2(580, 3740), "size": Vector2(78, 250)},
		{"type": "cloud_bank", "pos": Vector2(0, 3300), "size": Vector2(1100, 210)},
		{"type": "waterfall", "pos": Vector2(-480, 2580), "size": Vector2(135, 500)},
		{"type": "arch", "pos": Vector2(500, 2180), "size": Vector2(180, 230)},
		{"type": "ruin_column", "pos": Vector2(-500, 1780), "size": Vector2(72, 240)},
		{"type": "cloud_bank", "pos": Vector2(0, 1420), "size": Vector2(1200, 240)},
		{"type": "tree", "pos": Vector2(-220, 970), "size": Vector2(145, 185)},
		{"type": "arch", "pos": Vector2(0, 520), "size": Vector2(250, 300)},
	]

static func veils() -> Array[Dictionary]:
	return []
