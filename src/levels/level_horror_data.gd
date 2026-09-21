extends RefCounted
## Stage 1-2 "THE HOLLOW OUTSKIRTS".
##
## Rebuilt as a readable 2.5D platforming route rather than one long chase lane.
## Six short beats alternate safe footing, elevation, moving pieces and pursuit.
## Four gaps are intentionally wider than Lira can clear unaided: Orion has to
## place one or two temporary platforms while the Nightwolf keeps closing in.
##
## Enemy vocabulary for this stage is deliberately NOT the round walker family:
## Thornmites own the ground, Wisps own the air, and the Nightwolf is the
## unkillable pressure from behind.

const GROUND_TOP := 400.0
const GROUND_BASE := 900.0
const KILL_Y := 1020.0
const START := Vector2(-1000, 330)
const STAGE_NAME := "THE HOLLOW OUTSKIRTS"
const STAGE_NUMBER := "1-2"
const OBJECTIVE := "Reach the village gate"

const FLOOR := 400.0
const BLOCK := 48.0

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

## Floating masonry gets the same collision as terrain but is painted separately
## by Decor so each block can keep its beveled 2.5D silhouette.
static func solid_decor() -> Array[Rect2]:
	return [
		Rect2(170, 245, BLOCK * 3.0, BLOCK),
		Rect2(1830, 286, BLOCK * 2.0, BLOCK),
		Rect2(2630, 175, BLOCK * 3.0, BLOCK),
		Rect2(4130, 270, BLOCK * 3.0, BLOCK),
		Rect2(5110, 150, BLOCK * 2.0, BLOCK),
		Rect2(7040, 205, BLOCK * 2.0, BLOCK),
		Rect2(8440, 155, BLOCK * 3.0, BLOCK),
		Rect2(10200, 150, BLOCK * 3.0, BLOCK),
	]

static func ground() -> Array[Rect2]:
	var g: Array[Rect2] = []
	# A  : fog road and first enemy read.
	# B  : broken bridge -- 1260..1690 NEEDS one Orion platform.
	# C  : old village -- 3520..3970 NEEDS one Orion platform.
	# D  : flooded ruins -- 6310..6920 NEEDS two Orion platforms.
	# E  : tower road -- moving/crumbling pieces and the shootable gate.
	# F  : village gate -- 9530..10040 NEEDS one or two Orion platforms.
	var slabs := [
		[-1600.0, 420.0, 400.0],
		[520.0, 900.0, 352.0],
		[1010.0, 1260.0, 305.0],
		[1690.0, 2300.0, 400.0],
		[2410.0, 2710.0, 330.0],
		[2820.0, 3150.0, 255.0],
		[3260.0, 3520.0, 350.0],
		[3970.0, 4480.0, 400.0],
		[4590.0, 4920.0, 320.0],
		[5040.0, 5360.0, 250.0],
		[5480.0, 5790.0, 360.0],
		[5910.0, 6310.0, 280.0],
		[6920.0, 7320.0, 340.0],
		[7440.0, 7750.0, 240.0],
		[7870.0, 8200.0, 360.0],
		[8320.0, 8660.0, 290.0],
		[8790.0, 9130.0, 210.0],
		[9250.0, 9530.0, 330.0],
		[10040.0, 10850.0, 260.0],
	]
	for s in slabs:
		g.append(Rect2(s[0], s[2], s[1] - s[0], GROUND_BASE - s[2]))
	return g

## Thorns are now on readable ledges instead of being hidden deep in three
## enormous pits. Every strip has a safe take-off/landing side.
static func hazards() -> Array[Dictionary]:
	return [
		{"pos": Vector2(1125, 282), "size": Vector2(92, 46)},
		{"pos": Vector2(2160, 377), "size": Vector2(110, 46)},
		{"pos": Vector2(4290, 377), "size": Vector2(96, 46)},
		{"pos": Vector2(6140, 257), "size": Vector2(104, 46)},
		{"pos": Vector2(8980, 187), "size": Vector2(86, 46)},
		{"pos": Vector2(10490, 237), "size": Vector2(116, 46)},
	]

static func enemies() -> Array[Dictionary]:
	return [
		# Nightwolf: permanent chase pressure, slightly more forgiving than the
		# previous empty-lane version because the runner now has real obstacles.
		{
			"type": "sky_pursuer",
			"pos": Vector2(-1900, 335),
			"delay": 2.6,
			"speed": 210.0,
			"catchup": 500.0,
			"stun": 1.50,
		},
		# Thornmites: low, horned quadrupeds; explicitly not mushroom/walker skins.
		{"type": "thornmite", "pos": Vector2(250, 345), "patrol": 115.0},
		{"type": "thornmite", "pos": Vector2(1950, 345), "patrol": 150.0},
		{"type": "thornmite", "pos": Vector2(2990, 205), "patrol": 105.0},
		{"type": "thornmite", "pos": Vector2(4210, 345), "patrol": 135.0},
		{"type": "thornmite", "pos": Vector2(5620, 305), "patrol": 105.0},
		{"type": "thornmite", "pos": Vector2(7100, 285), "patrol": 120.0},
		{"type": "thornmite", "pos": Vector2(8500, 235), "patrol": 105.0},
		{"type": "thornmite", "pos": Vector2(10370, 205), "patrol": 140.0},
		# Flyers resolve to the stage-specific Wisp painting through Art.
		{"type": "flyer", "pos": Vector2(760, 205), "patrol": 145.0},
		{"type": "flyer", "pos": Vector2(2580, 135), "patrol": 185.0},
		{"type": "flyer", "pos": Vector2(4770, 150), "patrol": 180.0},
		{"type": "flyer", "pos": Vector2(6100, 125), "patrol": 170.0},
		{"type": "flyer", "pos": Vector2(7580, 88), "patrol": 160.0},
		{"type": "flyer", "pos": Vector2(8940, 70), "patrol": 145.0},
	]

static func gimmicks() -> Array[Dictionary]:
	return [
		# Collapsing bridge planks: safe if read early, P2 rescue if mistimed.
		{"type": "crumble", "pos": Vector2(2355, 350), "span": Vector2(100, 36)},
		{"type": "crumble", "pos": Vector2(5420, 335), "span": Vector2(100, 36)},
		{"type": "crumble", "pos": Vector2(9190, 285), "span": Vector2(100, 36)},

		# Moving pieces create timing changes without replacing the required P2 gaps.
		{"type": "moving_platform", "pos": Vector2(2880, 160),
			"span": Vector2(132, 24), "travel": Vector2(170, -70)},
		{"type": "moving_platform", "pos": Vector2(4750, 205),
			"span": Vector2(132, 24), "travel": Vector2(0, -145)},
		{"type": "moving_platform", "pos": Vector2(7580, 132),
			"span": Vector2(138, 24), "travel": Vector2(170, 0)},
		{"type": "moving_platform", "pos": Vector2(8500, 105),
			"span": Vector2(128, 24), "travel": Vector2(-150, -45)},

		# One guardian-shot gate changes the rhythm before the final chase.
		{"type": "switch", "pos": Vector2(7160, 205), "id": "hollow_gate",
			"hold": 6.0, "sigil": 0},
		{"type": "gate", "pos": Vector2(8070, 265), "span": Vector2(44, 190),
			"id": "hollow_gate", "wants": 0},
	]

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(1790, 350),
		Vector2(4050, 350),
		Vector2(5550, 310),
		Vector2(7000, 290),
		Vector2(10120, 210),
	]

static func goal() -> Vector2:
	return Vector2(10670, 205)

## Crystals sit before/after the P2-heavy sequences so building six temporary
## platforms across the whole stage does not turn into gauge starvation.
static func crystals() -> Array[Vector2]:
	return [
		Vector2(-260, 320),
		Vector2(1080, 225),
		Vector2(1740, 320),
		Vector2(2675, 105),
		Vector2(3340, 270),
		Vector2(4050, 315),
		Vector2(5145, 85),
		Vector2(6100, 185),
		Vector2(6990, 260),
		Vector2(8120, 270),
		Vector2(9360, 250),
		Vector2(10130, 180),
	]

static func springs() -> Array[Vector2]:
	return []

## Coins are breadcrumbs, not filler: arcs point at the intended landing, and
## vertical pairs call out block routes before the runner commits to a jump.
static func coins() -> Array[Vector2]:
	return [
		Vector2(-620, 310), Vector2(-540, 285), Vector2(-455, 300),
		Vector2(610, 270), Vector2(690, 240), Vector2(775, 255),
		Vector2(1100, 205), Vector2(1180, 180),
		Vector2(1360, 245), Vector2(1475, 220), Vector2(1585, 250),
		Vector2(1870, 300), Vector2(1980, 275),
		Vector2(2460, 245), Vector2(2560, 215),
		Vector2(2860, 165), Vector2(2980, 135), Vector2(3090, 165),
		Vector2(3380, 270), Vector2(3650, 235), Vector2(3830, 260),
		Vector2(4080, 300), Vector2(4180, 275),
		Vector2(4680, 225), Vector2(4780, 195),
		Vector2(5120, 120), Vector2(5210, 95),
		Vector2(5600, 270), Vector2(5700, 245),
		Vector2(6020, 180), Vector2(6160, 155),
		Vector2(6470, 205), Vector2(6620, 180), Vector2(6780, 215),
		Vector2(7010, 250), Vector2(7150, 230),
		Vector2(7480, 150), Vector2(7600, 120),
		Vector2(7950, 270), Vector2(8060, 245),
		Vector2(8390, 200), Vector2(8510, 175),
		Vector2(8850, 120), Vector2(8980, 95),
		Vector2(9300, 245), Vector2(9400, 220),
		Vector2(9660, 225), Vector2(9790, 195), Vector2(9910, 220),
		Vector2(10240, 125), Vector2(10350, 100), Vector2(10460, 125),
	]

static func decor() -> Array[Dictionary]:
	return [
		# A — sparse road: safe enough to read the new enemy silhouette.
		{"type": "cart", "pos": Vector2(-1300, 400), "flip": true},
		{"type": "lantern", "pos": Vector2(-1010, 400), "scale": 0.82},
		{"type": "fence", "pos": Vector2(-820, 400), "width": 210.0},
		{"type": "puddle", "pos": Vector2(-340, 400), "width": 220.0},
		{"type": "ruin_blocks", "pos": Vector2(170, 245), "count": 3, "cell": BLOCK},
		{"type": "lantern", "pos": Vector2(610, 352), "scale": 0.68},

		# B — broken bridge / village approach.
		{"type": "roots", "pos": Vector2(1180, 305), "flip": false},
		{"type": "banner", "pos": Vector2(1780, 400), "flip": false},
		{"type": "grave", "pos": Vector2(2050, 400), "scale": 0.72},
		{"type": "ruin_blocks", "pos": Vector2(1830, 286), "count": 2, "cell": BLOCK},
		{"type": "fence", "pos": Vector2(2440, 330), "width": 175.0},
		{"type": "ruin_blocks", "pos": Vector2(2630, 175), "count": 3, "cell": BLOCK},
		{"type": "crow", "pos": Vector2(3040, 200), "flip": true},

		# C — old village, alternating height and enclosed silhouettes.
		{"type": "lantern", "pos": Vector2(3340, 350), "scale": 0.72},
		{"type": "grave", "pos": Vector2(3440, 350), "scale": 0.82},
		{"type": "cart", "pos": Vector2(4040, 400), "flip": false},
		{"type": "ruin_blocks", "pos": Vector2(4130, 270), "count": 3, "cell": BLOCK},
		{"type": "puddle", "pos": Vector2(4680, 320), "width": 185.0},
		{"type": "banner", "pos": Vector2(4840, 320), "flip": true},
		{"type": "ruin_blocks", "pos": Vector2(5110, 150), "count": 2, "cell": BLOCK},
		{"type": "roots", "pos": Vector2(5550, 360), "flip": true},

		# D — flooded ruins. Wide empty silhouettes make Orion platforms obvious.
		{"type": "lantern", "pos": Vector2(5980, 280), "scale": 0.78},
		{"type": "fence", "pos": Vector2(6080, 280), "width": 170.0},
		{"type": "crow", "pos": Vector2(6200, 145), "flip": false},
		{"type": "puddle", "pos": Vector2(7040, 340), "width": 220.0},
		{"type": "ruin_blocks", "pos": Vector2(7040, 205), "count": 2, "cell": BLOCK},
		{"type": "lantern", "pos": Vector2(7490, 240), "scale": 0.72},

		# E — tower road: denser props, then a clear shot line to the switch.
		{"type": "grave", "pos": Vector2(7920, 360), "scale": 0.76},
		{"type": "banner", "pos": Vector2(8130, 360), "flip": false},
		{"type": "fence", "pos": Vector2(8350, 290), "width": 180.0},
		{"type": "ruin_blocks", "pos": Vector2(8440, 155), "count": 3, "cell": BLOCK},
		{"type": "crow", "pos": Vector2(8880, 150), "flip": true},
		{"type": "lantern", "pos": Vector2(9060, 210), "scale": 0.82},
		{"type": "roots", "pos": Vector2(9360, 330), "flip": false},

		# F — final gate. Warm lights take over as the village gets close.
		{"type": "lantern", "pos": Vector2(10120, 260), "scale": 0.92},
		{"type": "ruin_blocks", "pos": Vector2(10200, 150), "count": 3, "cell": BLOCK},
		{"type": "banner", "pos": Vector2(10430, 260), "flip": true},
		{"type": "fence", "pos": Vector2(10520, 260), "width": 160.0},
	]

## Both players see the same world here. See Veil, and stage 1-V.
static func veils() -> Array[Dictionary]:
	return []
