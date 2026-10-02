extends RefCounted
## 1-8: a long underground run that escalates from readable machinery to two
## further guardian crossings and a dense final gauntlet.

const BASE := 900.0
const START := Vector2(-1090, 350)
const KILL_Y := 760.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE UNDERGROVE"
static func stage_number_value() -> String: return "1-8"
static func objective_value() -> String: return "Cross the underground cavern"

# x start, x end, top. Most gaps are 190-230px. Three 550-560px fissures
# require a guardian platform; the later two also lead into sigil gates.
const SLABS := [
	[-1400.0, -420.0, 400.0],
	[-230.0, 360.0, 360.0],
	[570.0, 1140.0, 320.0],
	[1370.0, 1800.0, 300.0],
	[2020.0, 2540.0, 360.0],
	[2770.0, 3310.0, 280.0],
	[3540.0, 4050.0, 240.0],
	[4270.0, 4750.0, 300.0],
	[4950.0, 5400.0, 220.0],
	[5950.0, 6450.0, 220.0],
	[6670.0, 7150.0, 170.0],
	[7380.0, 7960.0, 230.0],
	[8190.0, 8690.0, 180.0],
	[8920.0, 9510.0, 250.0],
	[9740.0, 10300.0, 300.0],
	[10530.0, 11200.0, 320.0],
	[11430.0, 12000.0, 280.0],
	[12230.0, 12730.0, 220.0],
	[12960.0, 13410.0, 270.0],
	[13970.0, 14470.0, 240.0],
	[14700.0, 15240.0, 300.0],
	[15470.0, 16030.0, 230.0],
	[16260.0, 16820.0, 190.0],
	[17050.0, 17610.0, 250.0],
	[17840.0, 18400.0, 210.0],
	[18960.0, 19500.0, 210.0],
	[19730.0, 20270.0, 260.0],
	[20500.0, 21040.0, 180.0],
	[21270.0, 21820.0, 240.0],
	[22050.0, 22650.0, 200.0],
	[22880.0, 23550.0, 260.0],
]

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for slab in SLABS:
		out.append(Rect2(slab[0], slab[2], slab[1] - slab[0], BASE - slab[2]))
	return out

static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slab in SLABS:
		out.append({"type": "cave_lamp", "pos": Vector2(
			(slab[0] + slab[1]) * 0.5, slab[2] - 155.0)})
	for where in [Vector2(80, 360), Vector2(2980, 280),
			Vector2(4620, 300), Vector2(6890, 170), Vector2(9330, 250),
			Vector2(12450, 220), Vector2(15100, 300),
			Vector2(17300, 250), Vector2(20680, 180),
			Vector2(22380, 200)]:
		out.append({"type": "cave_crystal", "pos": where})
	out.append({"type": "cave_rail", "pos": Vector2(1245, 324), "width": 290.0})
	out.append({"type": "cave_rail", "pos": Vector2(4145, 305), "width": 310.0})
	out.append({"type": "cave_rail", "pos": Vector2(12845, 255), "width": 310.0})
	out.append({"type": "cave_rail", "pos": Vector2(20385, 240), "width": 310.0})
	return out

static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(1750, 292), "size": Vector2(92, 18)},
		{"pos": Vector2(7800, 222), "size": Vector2(100, 18)},
		{"pos": Vector2(9340, 242), "size": Vector2(95, 18)},
		{"pos": Vector2(11910, 272), "size": Vector2(90, 18)},
		{"pos": Vector2(12665, 212), "size": Vector2(90, 18)},
		{"pos": Vector2(14405, 232), "size": Vector2(90, 18)},
		{"pos": Vector2(15950, 222), "size": Vector2(90, 18)},
		{"pos": Vector2(18290, 202), "size": Vector2(90, 18)},
		{"pos": Vector2(20965, 172), "size": Vector2(100, 18)},
		{"pos": Vector2(21745, 232), "size": Vector2(100, 18)},
		{"pos": Vector2(22580, 192), "size": Vector2(95, 18)},
	]

static func enemies() -> Array[Dictionary]:
	return [
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(-720, 372), "patrol": 160.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(-25, 337), "patrol": 90.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(380, 110), "patrol": 100.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(850, 130), "patrol": 120.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(1640, 272), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(2210, 332), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(2450, 337), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(2890, 75), "patrol": 135.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(3200, 70), "patrol": 85.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(3670, 212), "patrol": 100.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(4470, 272), "patrol": 90.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(5210, 197), "patrol": 100.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(5570, 30), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(6360, 192), "patrol": 45.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(6900, 10), "patrol": 90.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(7670, 202), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(8420, 157), "patrol": 85.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(9100, 30), "patrol": 115.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(10040, 272), "patrol": 120.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(10720, 120), "patrol": 100.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(11800, 257), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(12380, 20), "patrol": 100.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(12510, 192), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(13100, 242), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(13250, 50), "patrol": 85.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(14090, 15), "patrol": 90.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(14345, 212), "patrol": 55.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(14870, 277), "patrol": 65.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(15130, 90), "patrol": 80.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(15830, 202), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(16630, 162), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(16740, -5), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(17180, 227), "patrol": 60.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(17500, 45), "patrol": 80.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(18260, 182), "patrol": 65.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(18330, 0), "patrol": 80.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(19320, 0), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(19440, 187), "patrol": 55.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(19910, 232), "patrol": 80.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(20120, 60), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(20850, 152), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(20960, -20), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "slime", "pos": Vector2(21390, 217), "patrol": 70.0},
		{"type": "cave_enemy", "kind": "bat", "pos": Vector2(21690, 45), "patrol": 80.0},
		{"type": "cave_enemy", "kind": "burrower", "pos": Vector2(22430, 172), "patrol": 75.0},
		{"type": "cave_enemy", "kind": "mushroom", "pos": Vector2(22550, 172), "patrol": 45.0},
		{"type": "cave_enemy", "kind": "beetle", "pos": Vector2(23000, 50), "patrol": 80.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# Cracked blocks reward timing; later bridges feed into crowded landings.
		{"type": "crumble", "pos": Vector2(455, 355), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(1905, 328), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(2655, 318), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(7270, 215), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(8075, 225), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(9625, 283), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(11315, 308), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(12115, 248), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(14585, 263), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(15355, 268), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(16935, 208), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(17725, 228), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(21155, 205), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(21935, 218), "span": Vector2(100, 32)},
		{"type": "crumble", "pos": Vector2(22765, 218), "span": Vector2(100, 32)},
		{"type": "moving_platform", "style": "minecart",
			"pos": Vector2(1190, 303), "span": Vector2(150, 26),
			"travel": Vector2(100, 0), "speed": 78.0},
		{"type": "moving_platform", "style": "minecart",
			"pos": Vector2(4135, 284), "span": Vector2(150, 26),
			"travel": Vector2(95, 0), "speed": 95.0, "phase": 1.0},
		{"type": "moving_platform", "style": "minecart",
			"pos": Vector2(12845, 247), "span": Vector2(150, 26),
			"travel": Vector2(95, 0), "speed": 110.0, "phase": 0.6},
		{"type": "moving_platform", "style": "minecart",
			"pos": Vector2(20385, 245), "span": Vector2(150, 26),
			"travel": Vector2(95, 0), "speed": 120.0, "phase": 1.3},
		{"type": "moving_platform", "pos": Vector2(4850, 292),
			"span": Vector2(135, 24), "travel": Vector2(0, -90), "speed": 75.0},
		{"type": "updraft", "pos": Vector2(3040, 275),
			"span": Vector2(120, 255)},
		{"type": "updraft", "pos": Vector2(9030, 245),
			"span": Vector2(115, 240)},
		{"type": "updraft", "pos": Vector2(12480, 215),
			"span": Vector2(110, 230)},
		{"type": "updraft", "pos": Vector2(17200, 245),
			"span": Vector2(115, 245)},
		{"type": "updraft", "pos": Vector2(21480, 235),
			"span": Vector2(110, 235)},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(2310, -20),
			"travel": 310.0, "period": 3.2, "phase": 0.4},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(3800, 199),
			"travel": 145.0, "period": 3.5, "phase": 0.2},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(7720, -80),
			"travel": 245.0, "period": 2.8, "phase": 0.8},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(9140, 210),
			"travel": 160.0, "period": 3.0, "phase": 0.7},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(10210, -20),
			"travel": 260.0, "period": 2.7, "phase": 1.1},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(11800, -25),
			"travel": 300.0, "period": 2.65, "phase": 0.2},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(12520, -75),
			"travel": 295.0, "period": 2.5, "phase": 1.0},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(13200, 230),
			"travel": 140.0, "period": 2.8, "phase": 0.4},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(14990, -20),
			"travel": 305.0, "period": 2.5, "phase": 0.6},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(15100, 260),
			"travel": 95.0, "period": 2.9, "phase": 1.2},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(16520, -70),
			"travel": 255.0, "period": 2.5, "phase": 0.7},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(17530, 210),
			"travel": 60.0, "period": 2.7, "phase": 0.8},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(18060, -80),
			"travel": 285.0, "period": 2.45, "phase": 0.1},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(19920, 220),
			"travel": 120.0, "period": 2.75, "phase": 0.3},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(20830, -90),
			"travel": 270.0, "period": 2.4, "phase": 0.9},
		{"type": "cave_trap", "kind": "boulder", "pos": Vector2(22380, 160),
			"travel": 100.0, "period": 2.6, "phase": 1.4},
		{"type": "cave_trap", "kind": "stalactite", "pos": Vector2(23020, -30),
			"travel": 275.0, "period": 2.45, "phase": 1.1},
		# The runner identifies the marked target; the guardian sees the gate's
		# requested mark and shoots the matching switch while placing a bridge.
		{"type": "switch", "id": "cave_bridge", "pos": Vector2(5100, 110),
			"sigil": 1, "hold": 11.0},
		{"type": "switch", "id": "cave_bridge", "pos": Vector2(5310, 80),
			"sigil": 2, "hold": 11.0},
		{"type": "gate", "id": "cave_bridge", "pos": Vector2(6140, 100),
			"span": Vector2(64, 240), "wants": 2},
		{"type": "switch", "id": "cave_deep_gate", "pos": Vector2(13080, 95),
			"sigil": 1, "hold": 14.0},
		{"type": "switch", "id": "cave_deep_gate", "pos": Vector2(13300, 90),
			"sigil": 2, "hold": 14.0},
		{"type": "gate", "id": "cave_deep_gate", "pos": Vector2(14150, 120),
			"span": Vector2(64, 240), "wants": 1},
		{"type": "switch", "id": "cave_last_gate", "pos": Vector2(18040, 75),
			"sigil": 1, "hold": 15.0},
		{"type": "switch", "id": "cave_last_gate", "pos": Vector2(18320, 65),
			"sigil": 2, "hold": 15.0},
		{"type": "gate", "id": "cave_last_gate", "pos": Vector2(19130, 90),
			"span": Vector2(64, 240), "wants": 2},
	]

static func springs() -> Array[Vector2]:
	return [Vector2(4670, 300), Vector2(6870, 170), Vector2(10230, 300),
		Vector2(11500, 280), Vector2(15970, 230), Vector2(20700, 180)]

static func checkpoints() -> Array[Vector2]:
	return [Vector2(270, 308), Vector2(1480, 248), Vector2(2065, 308),
		Vector2(2910, 228), Vector2(4020, 188), Vector2(4300, 248),
		Vector2(5000, 168), Vector2(6210, 168), Vector2(6780, 118),
		Vector2(7480, 178), Vector2(8240, 128), Vector2(9440, 198),
		Vector2(9800, 248), Vector2(11620, 228), Vector2(14040, 188),
		Vector2(15600, 178), Vector2(17330, 198), Vector2(19270, 158),
		Vector2(20150, 208), Vector2(21640, 188)]

static func goal() -> Vector2: return Vector2(23350, 205)

# Late in the gauntlet, clear of the final gate and patrols.
static func key_position() -> Vector2: return Vector2(22180, 196)

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for slab in SLABS:
		var left: float = slab[0]
		var right: float = slab[1]
		var top: float = slab[2]
		for x in range(int(left + 125.0), int(right - 90.0), 175):
			out.append(Vector2(float(x), top - 105.0))
	for x in [435, 1190, 1275, 1905, 2660, 4135, 5580, 5750, 7270, 8080, 9630,
			11320, 12120, 12850, 13580, 13770, 14590, 15360, 16940,
			17730, 18600, 18780, 20390, 21160, 21940, 22770]:
		out.append(Vector2(float(x), 130.0))
	return out
