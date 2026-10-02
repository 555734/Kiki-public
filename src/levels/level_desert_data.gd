extends RefCounted
## Stage 1-6: a readable run of escalating platforming beats. Short jumps
## teach the rhythm before the crumbling causeway, guardian gap, lift, blinking
## steps and final sprint. Every free jump stays within the measured ~300px
## sprint arc; the 550px gap is deliberately a guardian task.

const BASE := 900.0
const START := Vector2(-1040, 350)
const KILL_Y := 760.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE SANDGLASS RUINS"
static func stage_number_value() -> String: return "1-6"
static func objective_value() -> String: return "Cross the desert ruins"

const SLABS := [
	[-1400.0, -360.0, 400.0], # A: acceleration and first scarab
	[-175.0, 190.0, 360.0],   # A: 40px step up
	[375.0, 690.0, 300.0],    # A: 60px step up
	[870.0, 1350.0, 300.0],   # B: hop past cactus and thorns
	[1510.0, 1930.0, 250.0],  # B: rope bridge to high bank
	[2100.0, 2350.0, 150.0],  # C: launch into crumbling causeway
	[3070.0, 3650.0, 130.0],  # C: brief landing, then co-op crossing
	[4200.0, 4660.0, 220.0],  # D: guardian landing
	[5100.0, 5550.0, 20.0],   # E: top of the lift
	[6270.0, 6740.0, 80.0],   # F: blinking-step landing
	[6920.0, 7360.0, 170.0],  # G: downhill running jumps
	[7540.0, 7960.0, 250.0],
	[8140.0, 8630.0, 300.0],  # H: final falling causeway
	[9430.0, 10300.0, 320.0], # H: goal bank
]

static func ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for slab in SLABS:
		out.append(Rect2(slab[0], slab[2], slab[1] - slab[0], BASE - slab[2]))
	return out

static func solid_decor() -> Array[Rect2]:
	# The bridge is a real floor; its painted deck lines up with this rectangle.
	return [Rect2(1350, 290, 160, 22)]

static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "desert_arch", "pos": Vector2(-850, 400), "height": 235.0},
		{"type": "desert_flower", "pos": Vector2(-1180, 400)},
		{"type": "desert_crystal", "pos": Vector2(-420, 400)},
		{"type": "desert_cactus", "pos": Vector2(515, 300)},
		{"type": "desert_crystal", "pos": Vector2(1010, 300)},
		{"type": "desert_arch", "pos": Vector2(1720, 250), "height": 190.0},
		{"type": "desert_flower", "pos": Vector2(2240, 150)},
		{"type": "desert_crystal", "pos": Vector2(3190, 130)},
		{"type": "desert_cactus", "pos": Vector2(3500, 130)},
		{"type": "desert_flower", "pos": Vector2(4320, 220)},
		{"type": "desert_arch", "pos": Vector2(5320, 20), "height": 200.0},
		{"type": "desert_crystal", "pos": Vector2(5400, 20)},
		{"type": "desert_cactus", "pos": Vector2(6630, 80)},
		{"type": "desert_flower", "pos": Vector2(7170, 170)},
		{"type": "desert_crystal", "pos": Vector2(7770, 250)},
		{"type": "desert_cactus", "pos": Vector2(8360, 300)},
		{"type": "desert_arch", "pos": Vector2(9930, 320), "height": 210.0},
		{"type": "desert_bridge", "rect": Rect2(1350, 290, 160, 22)},
	]
	return out

static func hazards() -> Array[Dictionary]:
	# Two short strips make a deliberate hop on otherwise safe banks.
	return [
		{"pos": Vector2(1170, 292), "size": Vector2(110, 18)},
		{"pos": Vector2(7830, 242), "size": Vector2(90, 18)},
	]

static func enemies() -> Array[Dictionary]:
	return [
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(-610, 373), "patrol": 155.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(-75, 340), "patrol": 70.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(1250, 267), "patrol": 60.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(1740, 125), "patrol": 135.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(2220, 130), "patrol": 90.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(2710, 0), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(3390, 103), "patrol": 140.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(3890, 45), "patrol": 115.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(4470, 187), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(4870, 45), "patrol": 90.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(5360, 0), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(5900, -95), "patrol": 110.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(6530, 53), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(7700, 217), "patrol": 80.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(8380, 280), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(8990, 160), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(9840, 293), "patrol": 135.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# C: keep moving. Each ledge falls 0.45s after contact.
		{"type": "crumble", "pos": Vector2(2460, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2670, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2880, 155), "span": Vector2(110, 30)},
		# E: wait for the lift, then make a 170px jump to the high bank.
		{"type": "moving_platform", "pos": Vector2(4860, 205),
			"span": Vector2(140, 26), "travel": Vector2(0, -190), "speed": 85.0},
		# F: the cyan platforms from the board become a three-beat rhythm.
		{"type": "blink", "pos": Vector2(5690, 20), "span": Vector2(120, 26),
			"beat": 1.35, "colour": 0, "phase": 0.0},
		{"type": "blink", "pos": Vector2(5890, 35), "span": Vector2(120, 26),
			"beat": 1.35, "colour": 1, "phase": 0.45},
		{"type": "blink", "pos": Vector2(6090, 60), "span": Vector2(120, 26),
			"beat": 1.35, "colour": 0, "phase": 0.90},
		# G: the belt changes direction before the downhill section.
		{"type": "conveyor", "pos": Vector2(6520, 67),
			"span": Vector2(260, 26), "speed": 120.0, "flip": 3.2},
		# G: the runner reads the switches, the guardian reads the gate's mark
		# and shoots the matching target. The high door blocks every normal jump.
		{"type": "switch", "id": "desert_oracle", "pos": Vector2(7030, 95),
			"sigil": 1, "hold": 8.0},
		{"type": "switch", "id": "desert_oracle", "pos": Vector2(7150, 0),
			"sigil": 2, "hold": 8.0},
		{"type": "gate", "id": "desert_oracle", "pos": Vector2(7290, 55),
			"span": Vector2(54, 230), "wants": 2},
		# H: one last run across falling stones to the goal bank.
		{"type": "crumble", "pos": Vector2(8790, 315), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(9000, 315), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(9210, 315), "span": Vector2(110, 30)},
	]
static func veils() -> Array[Dictionary]: return []
static func checkpoints() -> Array[Vector2]:
	return [Vector2(940, 250), Vector2(1800, 200), Vector2(3180, 80),
		Vector2(4290, 170), Vector2(5180, -30), Vector2(6360, 30),
		Vector2(6980, 120), Vector2(8220, 250), Vector2(9540, 270)]
static func goal() -> Vector2: return Vector2(10150, 265)

static func coins() -> Array[Vector2]:
	return [
		Vector2(-760, 340), Vector2(-590, 325),
		Vector2(-280, 265), Vector2(-115, 235), Vector2(65, 245),
		Vector2(285, 220), Vector2(450, 185), Vector2(610, 205),
		Vector2(1130, 185), Vector2(1425, 205), Vector2(1580, 170),
		Vector2(1780, 145), Vector2(2090, 80), Vector2(2300, 55),
		Vector2(2460, 85), Vector2(2670, 85), Vector2(2880, 75),
		Vector2(3220, 30), Vector2(3500, 45),
		Vector2(3780, 20), Vector2(3910, -10), Vector2(4050, 20),
		Vector2(4420, 120), Vector2(4790, 95), Vector2(4860, -5),
		Vector2(5220, -80), Vector2(5440, -70),
		Vector2(5690, -50), Vector2(5890, -35), Vector2(6090, -10),
		Vector2(6410, 10), Vector2(6800, 20),
		Vector2(7080, 70), Vector2(7260, 100),
		Vector2(7550, 150), Vector2(7750, 170),
		Vector2(8100, 210), Vector2(8480, 230),
		Vector2(8790, 235), Vector2(9000, 235), Vector2(9210, 235),
		Vector2(9680, 250), Vector2(9940, 235),
	]

static func crystals() -> Array[Vector2]: return []
static func springs() -> Array[Vector2]: return [Vector2(100, 360)]
