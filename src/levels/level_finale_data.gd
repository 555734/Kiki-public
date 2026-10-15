extends RefCounted
## 1-10 THE LAST RUN: nine linked biomes, each with its own machine.
##
## World is laid out left to right but climbs and falls a long way: the
## grassland chasm drops 1,060px, the sand ruins collapse 1,500px into the
## volcano, geyser lifts carry the runner back up 1,200px to the railway, and
## the hive shaft launches another 1,100px. Every vertical value stays inside
## Snapshot's y range (>= -1024) so online play quantises nothing away.
##
## Gimmick/enemy kinds are implemented in FinaleMachine / FinaleSlope /
## FinaleEnemy. docs/stage-1-10.md has the area map, and shots() below ties
## every storyboard cut to a place in this file.

static func kill_y_value() -> float: return 3400.0
static func start_position() -> Vector2: return Vector2(-300, 876)
static func stage_name_value() -> String: return "THE LAST RUN"
static func stage_number_value() -> String: return "1-10"
static func objective_value() -> String: return "Nine lands, one run. Build what the runner needs."
static func painted_2d_value() -> bool: return true
static func pit_centre_x_value() -> float: return 14000.0
## Thin ledges (<= 40px) can be jumped through from below.
static func ground_one_way(rect: Rect2) -> bool: return rect.size.y <= 40.0
static func solid_decor() -> Array[Rect2]: return []
static func decor() -> Array[Dictionary]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func springs() -> Array[Vector2]: return []
static func goal() -> Vector2: return Vector2(28600, 365)

## Areas, in course order. `skin` picks terrain art, `sky` the backdrop.
static func zones() -> Array[Dictionary]:
	return [
		{"name": "GRASSLAND CLIFFS", "from": -1000, "to": 3150, "skin": "grass", "sky": "meadow", "seconds": "0-10"},
		{"name": "THUNDER BRIDGE", "from": 3150, "to": 5800, "skin": "storm", "sky": "storm", "seconds": "10-13"},
		{"name": "SHIFTING SAND RUINS", "from": 5800, "to": 7500, "skin": "sand", "sky": "sand", "seconds": "13-16"},
		{"name": "VOLCANO CORE", "from": 7500, "to": 11300, "skin": "lava", "sky": "lava", "seconds": "16-20"},
		{"name": "IRON RAIL", "from": 11300, "to": 15600, "skin": "rail", "sky": "rail", "seconds": "20-24"},
		{"name": "HONEYCOMB HIVE", "from": 15600, "to": 17300, "skin": "hive", "sky": "hive", "seconds": "24-30"},
		{"name": "STONE GIANT", "from": 17300, "to": 19660, "skin": "cliff", "sky": "cliff", "seconds": "30-33"},
		{"name": "DRAGON BONE CANYON", "from": 19660, "to": 24600, "skin": "bone", "sky": "canyon", "seconds": "33-39"},
		{"name": "TITLE RUN", "from": 24600, "to": 29500, "skin": "grass", "sky": "meadow", "seconds": "39-49"},
	]

## Terrain art for a slab: its area, except where the course folds back
## under itself (the volcano runs beneath the ruins, the station sits on
## the volcano's rim).
static func skin_for(rect: Rect2) -> String:
	var x := rect.position.x + minf(rect.size.x, 200.0) * 0.5
	var top := rect.position.y
	if top >= 2300.0 and x > 6800.0 and x < 11500.0:
		return "lava"
	# The geyser-lift chimney climbs under the station: still volcano rock.
	if top >= 1700.0 and x >= 10500.0 and x < 11700.0:
		return "lava"
	if top < 2300.0 and x >= 7500.0 and x < 8000.0:
		return "sand"
	if top <= 1560.0 and x >= 10850.0 and x < 15700.0:
		return "rail"
	return String(zone_at(x)["skin"])

static func zone_at(x: float) -> Dictionary:
	var all := zones()
	for z in all:
		if x < float(z["to"]):
			return z
	return all[-1]

static func ground() -> Array[Rect2]:
	return [
		# ---- GRASSLAND CLIFFS (0-10s). Start hill; the downhill is a slope.
		Rect2(-900, 900, 1100, 900),
		Rect2(900, 1160, 640, 2300),          # run-up before the gorge; its wall drops out of sight
		# The gorge: 760px across and bottomless (kill_y). A full sprint jump
		# with the air jump covers ~470px, so the leap falls short in the open,
		# far from both walls -- without the guardian it is a fall to death.
		Rect2(2300, 1080, 620, 300),          # far bank, 80 above the lip: an overhang
		Rect2(2860, 1380, 340, 2000),         # the bank's wall recedes under it: nothing to slide down
		Rect2(2920, 1080, 280, 1060),         # rise to the bridge (slope above it)
		# ---- THUNDER BRIDGE (10-13s). The deck itself is the storm machine.
		Rect2(4110, 920, 130, 40),            # broken spans above the strike
		Rect2(4330, 800, 110, 40),
		Rect2(4520, 860, 110, 40),
		Rect2(4700, 760, 110, 40),
		Rect2(5280, 1040, 620, 1100),         # far abutment
		# ---- SHIFTING SAND RUINS (13-16s)
		Rect2(5900, 1040, 500, 1300),         # entrance terrace
		Rect2(6400, 1160, 700, 1700),         # pendulum hall floor + shaft wall
		Rect2(6460, 930, 190, 36),            # upper route over the pendulum
		Rect2(6760, 830, 200, 36),
		Rect2(6990, 940, 110, 36),
		Rect2(7500, 700, 400, 1860),          # wall: the only way on is down
		Rect2(7100, 1500, 80, 20), Rect2(7420, 1800, 80, 20),  # sand ledges
		Rect2(7100, 2100, 80, 20), Rect2(7420, 2400, 80, 20),
		# ---- VOLCANO CORE (16-20s)
		Rect2(6900, 2700, 1180, 500),         # landing chamber below the shaft
		Rect2(8080, 2660, 130, 440), Rect2(8300, 2560, 120, 540),
		Rect2(8500, 2620, 130, 480), Rect2(8700, 2520, 170, 580),
		Rect2(9400, 2420, 200, 36),           # escape ledge, clear above the ball
		Rect2(10740, 2420, 170, 680),         # landing after the swings
		Rect2(11080, 2100, 140, 40), Rect2(11140, 1800, 120, 40),  # geyser ledges
		Rect2(10900, 1620, 120, 36),
		Rect2(10900, 2440, 480, 660),         # vent floor under the lifts
		Rect2(11360, 2100, 140, 340),         # rock pillar right of the middle lift
		# ---- IRON RAIL (20-24s)
		Rect2(11050, 1500, 450, 60),          # station deck over the west portal
		Rect2(15000, 1420, 380, 36),          # footbridge over the line
		Rect2(15380, 1290, 320, 170),         # cutting above the far tunnel
		# ---- HONEYCOMB HIVE (24-30s)
		Rect2(15700, 1300, 600, 600),         # hive hall floor
		Rect2(16300, 1000, 250, 900),         # comb cliff (paddle wheel climb)
		Rect2(16550, 1300, 750, 600),         # bubble chamber floor
		Rect2(16700, 200, 130, 950),          # shaft walls
		Rect2(16970, 200, 330, 950),
		Rect2(17300, 200, 200, 1700),
		Rect2(15960, 1120, 140, 36), Rect2(16130, 990, 130, 36),  # inverted tiers
		# ---- STONE GIANT (30-33s)
		Rect2(17930, 300, 150, 1500),         # last rock before the giant's stone bridge (the bridge is its machine)
		Rect2(18900, 300, 760, 1500),         # far plateau, 820px across the gorge; the giant stands behind it
		# ---- DRAGON BONE CANYON (33-39s)
		Rect2(20300, 320, 120, 1700),         # bone pillar between ribs
		Rect2(21100, 280, 300, 1700),         # bone mesa
		Rect2(24000, 300, 600, 1500),         # past the jaw gate
		# ---- TITLE RUN (39-49s)
		Rect2(25200, 520, 500, 1200),
		Rect2(25800, 460, 340, 1200),
		Rect2(26180, 560, 260, 1200),
		Rect2(26540, 480, 60, 1200), Rect2(26630, 430, 60, 1200),
		Rect2(26700, 420, 600, 1200),
		Rect2(27650, 480, 500, 1200),
		Rect2(28150, 420, 750, 1200),
	]

## Sloped and curved ground, drawn and collided as polygons (FinaleSlope).
## `points` is the walkable top, left to right, relative to `pos`.
static func _slopes() -> Array[Dictionary]:
	return [
		{"type": "finale_slope", "pos": Vector2(200, 900), "skin": "grass", "depth": 900.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(220, 40), Vector2(450, 140), Vector2(700, 260)])},
		{"type": "finale_slope", "pos": Vector2(2920, 1080), "skin": "grass", "depth": 100.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(140, -20), Vector2(280, -40)])},
		{"type": "finale_slope", "pos": Vector2(5800, 1040), "skin": "sand", "depth": 80.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])},
		# Cracked downhill the magma ball chases the runner along.
		{"type": "finale_slope", "pos": Vector2(8870, 2520), "skin": "lava", "depth": 440.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(200, 25), Vector2(450, 90), Vector2(700, 160), Vector2(830, 180)])},
		# The off-centre landing: an isolated, tilted ledge in the wind.
		{"type": "finale_slope", "pos": Vector2(17620, 330), "skin": "cliff", "depth": 160.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(130, -30), Vector2(260, -50)])},
		# Fossil rib bridges, arched and only 44px thick.
		{"type": "finale_slope", "pos": Vector2(19660, 300), "skin": "bone", "depth": 44.0, "thick": 44.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(150, -70), Vector2(300, -100), Vector2(470, -70), Vector2(640, 20)])},
		{"type": "finale_slope", "pos": Vector2(20420, 320), "skin": "bone", "depth": 44.0, "thick": 44.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(160, -110), Vector2(330, -170), Vector2(500, -120), Vector2(680, -40)])},
		# Out of the canyon: a long downhill into the title meadow.
		{"type": "finale_slope", "pos": Vector2(24600, 300), "skin": "grass", "depth": 1200.0,
			"points": PackedVector2Array([Vector2(0, 0), Vector2(200, 40), Vector2(420, 140), Vector2(600, 220)])},
	]

static func hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Invisible floors of the voids. The lava, river and canyon art is drawn
	# by their machines; these make falling into them final.
	for row in [[2200, 2700, 1400], [4240, 2350, 2400], [13600, 2350, 4200], [21300, 2050, 4700], [26900, 1700, 3200],
			[-1500, 3300, 3000], [28600, 3300, 3000]]:
		out.append({"pos": Vector2(row[0], row[1]), "size": Vector2(row[2], 120), "draw_spikes": false})
	# Title-run spikes: the "down again" pit and the impossible-block bed.
	out.append({"pos": Vector2(25750, 690), "size": Vector2(100, 40)})
	out.append({"pos": Vector2(26575, 1100), "size": Vector2(250, 40)})
	return out

static func checkpoints() -> Array[Vector2]:
	return [
		Vector2(2700, 1030),    # 1 far bank, after the rescue
		Vector2(5450, 990),     # 2 end of the thunder bridge
		Vector2(7700, 2650),    # 3 bottom of the collapse shaft
		Vector2(8780, 2470),    # 4 before the magma ball
		Vector2(10820, 2370),   # 5 after the swings, before the geysers
		Vector2(11250, 1450),   # 6 station
		Vector2(15400, 1240),   # 7 off the train
		Vector2(17150, 150),    # 8 top of the hive shaft
		Vector2(18030, 250),    # 9 the last rock before the giant's bridge
		Vector2(21250, 230),    # 10 bone mesa, before the beast
		Vector2(24200, 250),    # 11 past the jaw gate
		Vector2(26300, 510),    # 12 title run restart point (beside a saw)
		Vector2(27850, 430),    # 13 last stretch
	]

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in [Vector2(450, 880), Vector2(700, 990), Vector2(1100, 1100), Vector2(1250, 1100),
			Vector2(1800, 1040),
			Vector2(3600, 980), Vector2(4180, 860), Vector2(4380, 740), Vector2(4750, 700),
			Vector2(6550, 870), Vector2(6860, 770), Vector2(7300, 1700), Vector2(7300, 2200),
			Vector2(8360, 2500), Vector2(9500, 2380), Vector2(9900, 2650), Vector2(10000, 2650),
			Vector2(12400, 1400), Vector2(13200, 1380), Vector2(14100, 1380),
			Vector2(16000, 1060), Vector2(16900, 800), Vector2(16900, 500),
			Vector2(18200, 240), Vector2(19200, 240), Vector2(19960, 150), Vector2(20750, 100),
			Vector2(22235, 0), Vector2(23200, -30), Vector2(25000, 380),
			Vector2(26900, 360), Vector2(27000, 360), Vector2(27100, 360), Vector2(27760, 420),
			Vector2(27840, 420), Vector2(27920, 420), Vector2(28000, 420), Vector2(28300, 360)]:
		out.append(p)
	return out

static func enemies() -> Array[Dictionary]:
	return [
		# Grassland: the one enemy of the opening, walking up to meet the runner.
		{"type": "finale_enemy", "kind": "burrbug", "pos": Vector2(1180, 1135), "data": {"bounds": Vector2(920, 1480)}},
		{"type": "finale_enemy", "kind": "burrbug", "pos": Vector2(2800, 1055), "data": {"bounds": Vector2(2680, 2900)}},
		# Thunder bridge: sparks that ride the storm.
		{"type": "finale_enemy", "kind": "spark", "pos": Vector2(3760, 960), "data": {"amp": Vector2(0, 110)}},
		{"type": "finale_enemy", "kind": "spark", "pos": Vector2(4480, 920), "data": {"amp": Vector2(70, 120)}},
		# Sand ruins: the existing desert cast, in this course's corridors.
		# On the upper tiers: the hall floor belongs to the swinging block.
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(6860, 802), "patrol": 70.0},
		{"type": "desert_enemy", "kind": "mummy", "pos": Vector2(6555, 900), "patrol": 50.0},
		# Volcano: slimes hop platform to platform, a bat crosses the lake.
		{"type": "finale_enemy", "kind": "magma_slime", "pos": Vector2(8360, 2535), "data": {"hop": Vector2(200, 0)}},
		{"type": "finale_enemy", "kind": "fire_bat", "pos": Vector2(10200, 2250), "data": {"amp": Vector2(260, 60)}},
		# Iron rail: gunners ride the roofs (positions follow the train).
		{"type": "finale_enemy", "kind": "rail_gunner", "pos": Vector2(12000, 1450), "data": {"train": 1, "car": 0}},
		{"type": "finale_enemy", "kind": "rail_gunner", "pos": Vector2(12000, 1450), "data": {"train": 0, "car": 2}},
		# Hive: a swarm that follows the runner among the paddles.
		{"type": "finale_enemy", "kind": "wax_wisp", "pos": Vector2(16000, 900), "data": {}},
		{"type": "finale_enemy", "kind": "wax_wisp", "pos": Vector2(16250, 760), "data": {}},
		{"type": "finale_enemy", "kind": "wax_wisp", "pos": Vector2(16450, 880), "data": {}},
		{"type": "finale_enemy", "kind": "wax_wisp", "pos": Vector2(15950, 1180), "data": {}},
		# Bone canyon: rotor skulls between the ribs.
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(20560, 120), "data": {"amp": Vector2(90, 50)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(20760, 20), "data": {"amp": Vector2(60, 80)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(20950, 140), "data": {"amp": Vector2(100, 40)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(19960, 70), "data": {"amp": Vector2(70, 40)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(21230, 60), "data": {"amp": Vector2(50, 70)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(20650, -20), "data": {"amp": Vector2(80, 30)}},
		{"type": "finale_enemy", "kind": "skull_drone", "pos": Vector2(20880, 40), "data": {"amp": Vector2(40, 60)}},
		# Title run: brass drones in pursuit, a cannon, one walker.
		{"type": "finale_enemy", "kind": "brass_drone", "pos": Vector2(25300, 300), "data": {"amp": Vector2(60, 40), "chase": true}},
		{"type": "finale_enemy", "kind": "brass_drone", "pos": Vector2(25950, 300), "data": {"amp": Vector2(50, 50), "chase": true}},
		{"type": "finale_enemy", "kind": "brass_drone", "pos": Vector2(27200, 260), "data": {"amp": Vector2(80, 40), "chase": true}},
		{"type": "turret", "pos": Vector2(26080, 430), "aim": Vector2.LEFT, "burst": 2},
		{"type": "finale_enemy", "kind": "burrbug", "pos": Vector2(27000, 395), "data": {"bounds": Vector2(26740, 27280)}},
	]

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(_slopes())
	out.append_array(_scenery())
	# ---- GRASSLAND: the overhanging lip that breaks away under the take-off.
	out.append({"type": "finale_machine", "kind": "crumble_lip", "id": "cliff_lip", "pos": Vector2(1530, 1190),
		"data": {"rect": Rect2(1500, 1162, 96, 64), "trigger_x": 1450.0}})
	# ---- THUNDER BRIDGE: thirteen deck spans, three strikes and two
	# electrified stones. The rod on the ruined tower absorbs the storm.
	out.append({"type": "finale_machine", "kind": "storm_bridge", "id": "storm", "pos": Vector2(3200, 1040),
		"data": {"segments": 13, "seg_w": 160.0,
			"strikes": [{"at": 3310.0, "segs": [3]}, {"at": 3950.0, "segs": [7, 8]}, {"at": 4880.0, "segs": [12]}],
			"arcs": [Rect2(4330, 800, 110, 40), Rect2(4700, 760, 110, 40)],
			"rod": Vector2(4480, 610)}})
	# ---- SAND RUINS
	out.append({"type": "finale_machine", "kind": "pendulum_block", "id": "ruin_pendulum", "pos": Vector2(6780, 600),
		"data": {"length": 459.0, "amp": 1.0, "period": 3.4, "size": Vector2(160, 130)}})
	out.append({"type": "finale_machine", "kind": "sandfall", "id": "sandfall_a", "pos": Vector2(6680, 560),
		"data": {"height": 600.0, "width": 70.0}})
	out.append({"type": "finale_machine", "kind": "sand_collapse", "id": "ruin_floor", "pos": Vector2(7100, 1160),
		"data": {"tiles": 5, "tile_w": 80.0, "thick": 40.0}})
	for row in [[7170, 0.0], [7300, 1.1], [7430, 0.5]]:
		out.append({"type": "finale_machine", "kind": "rockfall", "id": "rock_%d" % row[0], "pos": Vector2(row[0], 1250),
			"data": {"fall": 1330.0, "period": 2.4, "phase": row[1]}})
	# ---- VOLCANO CORE
	out.append({"type": "finale_machine", "kind": "lava", "id": "lava_lake", "pos": Vector2(8000, 2960),
		"data": {"width": 2700.0}})
	out.append({"type": "finale_machine", "kind": "magma_ball", "id": "magma", "pos": Vector2(8880, 2420),
		"data": {"trigger": 9020.0, "radius": 100.0, "crust": Rect2(9700, 2700, 400, 30),
			"path": PackedVector2Array([Vector2(8880, 2420), Vector2(9070, 2444), Vector2(9320, 2508),
				Vector2(9570, 2578), Vector2(9700, 2600), Vector2(10100, 2600), Vector2(10180, 2900)])}})
	out.append({"type": "finale_machine", "kind": "chain_swing", "id": "swing_a", "pos": Vector2(9900, 2150),
		"data": {"length": 300.0, "amp": 0.75, "period": 3.0, "phase": 0.0, "width": 140.0}})
	out.append({"type": "finale_machine", "kind": "chain_swing", "id": "swing_b", "pos": Vector2(10450, 2150),
		"data": {"length": 300.0, "amp": 0.75, "period": 3.0, "phase": 1.5, "width": 140.0}})
	for row in [[10990, 2440, 340, 0.0], [11300, 2100, 300, 1.3], [11010, 1800, 300, 2.6]]:
		out.append({"type": "finale_machine", "kind": "geyser_lift", "id": "lift_%d" % row[1], "pos": Vector2(row[0], row[1]),
			"data": {"rise": float(row[2]), "period": 4.0, "phase": float(row[3]), "width": 120.0}})
	for row in [[11160, 2440, 300, 0.7], [11430, 2100, 380, 2.0]]:
		out.append({"type": "volcanic_hazard", "kind": "geyser", "pos": Vector2(row[0], row[1]),
			"travel": Vector2(0, -float(row[2])), "width": 70.0, "period": 4.0, "phase": float(row[3])})
	# ---- IRON RAIL: two trains on one schedule, two cranes, a low bridge.
	out.append({"type": "finale_machine", "kind": "rail_line", "id": "rail", "pos": Vector2(11520, 1720),
		"data": {"portal_in": 11500.0, "portal_out": 15600.0, "cranes": [[12900.0, 0, 0], [14600.0, 1, 1]], "period": 25.0,
			"low_bridge": 15340.0}})
	# ---- HONEYCOMB HIVE
	for row in [[15760, 140], [16080, 160], [16600, 180]]:
		out.append({"type": "finale_machine", "kind": "honey", "id": "honey_%d" % row[0], "pos": Vector2(row[0], 1300),
			"data": {"width": float(row[1])}})
	out.append({"type": "finale_machine", "kind": "paddle_wheel", "id": "paddles_a", "pos": Vector2(15760, 1080),
		"data": {"radius": 140.0, "arms": 4, "speed": 0.55, "plat_w": 110.0}})
	out.append({"type": "finale_machine", "kind": "honey_shaft", "id": "hive_shaft", "pos": Vector2(16900, 1300),
		"data": {"top": 230.0, "left": 16830.0, "right": 16970.0}})
	# ---- STONE GIANT
	# Stands in the gorge behind a long stone bridge. Its slam breaks the
	# bridge; the slammed arm, planted, is the ramp up and over; the other
	# fist swats the top of that arm.
	out.append({"type": "finale_machine", "kind": "stone_giant", "id": "giant", "pos": Vector2(19400, 760),
		"data": {"trigger": 18085.0, "bridge": Rect2(18080, 300, 820, 70), "blocks": [90, 120, 80, 130, 100, 140, 90, 70],
			"slam_at": Vector2(18252, 262), "swat_at": Vector2(18690, -60)}})
	# ---- DRAGON BONE CANYON
	# The way over the fossil: a great rib arcing up over the canyon (spans
	# A B C), a tilted thigh bone below it (upper, lower part), a curved
	# rib (P2), then the long jump to the slope by the jaw gate. The maw
	# bites span B from under the runner (C falls with them onto the thigh
	# bone), then the bone's lower end and P2 as they leave each.
	out.append({"type": "finale_machine", "kind": "bone_maw", "id": "maw", "pos": Vector2(22200, 300),
		"data": {"trigger": 21560.0, "trigger2": 22180.0,
			"spans": {"A": [Vector2(21400, 280), Vector2(21600, 230), 64.0], "B": [Vector2(21600, 230), Vector2(21800, 147), 64.0],
				"C": [Vector2(21800, 147), Vector2(22010, 40), 58.0],
				"L1a": [Vector2(21880, 300), Vector2(22380, 521), 92.0], "L1b": [Vector2(22380, 521), Vector2(22560, 600), 92.0],
				"P2": [Vector2(22720, 572), Vector2(23040, 556), 72.0],
				# The last jump's landing: a great jawbone sloping up to the gate.
				"G": [Vector2(23380, 530), Vector2(24040, 282), 110.0]},
			"knobs": {"L1a": [0], "L1b": [1], "P2": [0, 1], "G": [0]}}})
	out.append({"type": "finale_machine", "kind": "canyon_floor", "id": "canyon_floor", "pos": Vector2(19660, 1750),
		"data": {"width": 4900.0}})
	# ---- TITLE RUN
	out.append({"type": "finale_machine", "kind": "saw", "id": "saw_a", "pos": Vector2(25300, 500),
		"data": {"radius": 46.0, "travel": Vector2(300, 0), "period": 3.2}})
	out.append({"type": "finale_machine", "kind": "saw", "id": "saw_b", "pos": Vector2(26480, 540),
		"data": {"radius": 52.0, "travel": Vector2(0, 0), "period": 1.0}})
	out.append({"type": "finale_machine", "kind": "saw", "id": "saw_c", "pos": Vector2(27150, 300),
		"data": {"radius": 40.0, "travel": Vector2(0, 100), "period": 2.6}})
	out.append({"type": "moving_platform", "pos": Vector2(27460, 520), "span": Vector2(140, 26),
		"travel": Vector2(0, -150), "speed": 90.0})
	return out

## Painted, non-colliding dressing. [sprite, x, y(bottom), height, flip, front]
static func _scenery() -> Array[Dictionary]:
	return [
		{"type": "finale_machine", "kind": "scenery", "id": "dress_grass", "pos": Vector2.ZERO, "data": {"items": [
			["tree", -650, 900, 300, false, false], ["flowers", -380, 900, 70, false, false],
			["signpost", 40, 900, 120, false, false], ["fence", 1000, 1160, 70, false, false],
			# Open gorge: no falls or walls behind the leap, only depth.
			["abyss", 1540, 1150, 2250, false, false, 1330, 140],
			["tree", 2860, 1080, 320, true, false], ["signpost", 2380, 1080, 120, false, false],
			["flowers", 2420, 1080, 70, false, false], ["flowers", 2700, 1080, 70, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_storm", "pos": Vector2.ZERO, "data": {"items": [
			["ruin_tower", 4480, 1100, 520, false, false], ["column", 3120, 1040, 250, false, false],
			["broken_column", 5380, 1040, 160, false, false], ["column", 5800, 1040, 260, true, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_sand", "pos": Vector2.ZERO, "data": {"items": [
			["arch", 6100, 1040, 260, false, false], ["broken_arch", 6560, 1160, 240, false, false],
			["column", 7020, 1160, 230, false, false], ["rubble", 7700, 700, 120, false, false],
			["palm", 5960, 1040, 200, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_lava", "pos": Vector2.ZERO, "data": {"items": [
			["lavafall", 7900, 2960, 420, false, false], ["chain", 8150, 2300, 380, false, false],
			["chain", 8370, 2200, 320, false, false], ["chain", 8560, 2260, 360, false, false],
			["lava_spikes", 9900, 2960, 120, false, false], ["lavafall", 10450, 2960, 520, false, false],
			["gate_glow", 11160, 1500, 0, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_rail", "pos": Vector2.ZERO, "data": {"items": [
			# Each viaduct is ~1,980px wide: kept clear of the volcano lifts.
			["viaduct", 12700, 2300, 580, false, false], ["viaduct", 13900, 2300, 580, false, false],
			["viaduct", 15100, 2300, 580, false, false],
			["lamp", 11200, 1500, 160, false, false], ["signal", 14650, 1720, 160, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_hive", "pos": Vector2.ZERO, "data": {"items": [
			["drip", 15900, 1000, 160, false, false], ["drip", 16250, 760, 200, false, false],
			["drip", 16620, 1150, 120, false, false], ["drip", 17050, 1150, 140, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_cliff", "pos": Vector2.ZERO, "data": {"items": [
			["tree", 18050, 300, 260, false, false], ["rubble", 19100, 300, 110, false, false],
			["grass", 18300, 300, 60, false, false], ["grass", 19300, 300, 60, false, false]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_bone", "pos": Vector2.ZERO, "data": {"items": [
			["canyon_haze", 19560, 420, 1330, false, false, 4500],
			["rib", 20200, 1700, 1500, false, false], ["rib", 21000, 1700, 1400, true, false],
			["rib", 22900, 1700, 1500, false, false], ["skull_rock", 21250, 280, 200, false, false],
			["jaw_gate", 23940, 300, 380, false, true]]}},
		{"type": "finale_machine", "kind": "scenery", "id": "dress_title", "pos": Vector2.ZERO, "data": {"items": [
			["waterfall", 26560, 1700, 1200, false, false], ["tree", 25350, 520, 280, false, false],
			["flowers", 25900, 460, 70, false, false], ["signpost", 26250, 560, 110, false, false],
			["rope_bridge", 27450, 480, 70, false, false], ["tree", 28750, 420, 300, true, false],
			["flowers", 28300, 420, 70, false, false]]}},
	]

## Storyboard cut -> where it is played. See shots below; the capture tool and
## the probe read the same table.
static func shots() -> Array[Dictionary]:
	return preload("res://src/levels/finale_shots.gd").all()
