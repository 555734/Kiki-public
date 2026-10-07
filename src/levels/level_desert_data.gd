extends RefCounted
## Twenty distinct desert encounters. The first ten build on the oasis route;
## the next ten sit above them in desert_sections.gd. No room recipe
## repeats. route() records the production geometry for real-Runner checks.
const Sections = preload("res://src/levels/desert_sections.gd")
const PREFIX_NAMES := ["oasis_run", "sand_columns", "low_thorn_corridor", "guarded_rope_bridge",
	"crumbling_hourglass", "mirage_crossing", "ruin_elevator", "blink_fork", "reversing_dunes", "sigil_causeway"]

const BASE := 900.0
const START := Vector2(-1040, 350)
const KILL_Y := 760.0
const SAND_COLUMN := Rect2(240, 210, 120, 48)
const RETURN_BANK := Rect2(10700, 320, 650, 580)
const ASCENT_MOUTH := Vector2(9940, 275)
const ASCENT_EXIT := Vector2(2330, -630)
const RETURN_EXIT := Vector2(10940, 270)

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
	[4440.0, 4660.0, 220.0],  # D: guardian landing
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
	out.append(Rect2(960, 180, 100, 64)) # Low corridor, ending before the launch pad.
	out.append(Rect2(4960, 105, 80, 36)) # Lift's intermediate dismount.
	out.append(Rect2(5620, 170, 150, 40)) # Optional lower blink route.
	out.append(Rect2(5930, 220, 160, 40))
	out.append(Rect2(7200, -200, 180, 180)) # Housing above the sigil gate.
	out.append(SAND_COLUMN)
	out.append_array(Sections.build().ground)
	out.append(RETURN_BANK)
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
		{"type": "desert_flower", "pos": Vector2(4500, 220)},
		{"type": "desert_arch", "pos": Vector2(5320, 20), "height": 200.0},
		{"type": "desert_crystal", "pos": Vector2(5400, 20)},
		{"type": "desert_cactus", "pos": Vector2(6630, 80)},
		{"type": "desert_flower", "pos": Vector2(7170, 170)},
		{"type": "desert_crystal", "pos": Vector2(7770, 250)},
		{"type": "desert_cactus", "pos": Vector2(8360, 300)},
		{"type": "desert_arch", "pos": Vector2(9930, 320), "height": 210.0},
		{"type": "desert_bridge", "rect": Rect2(1350, 290, 160, 22)},
	]
	out.append_array(Sections.build().decor)
	out.append({"type": "desert_hourglass", "pos": Vector2(4700, 220), "height": 760.0})
	for index in [1, 3, 5, 7]:
		var floor_: Rect2 = Sections.build().sections[index]["exit"]
		out.append({"type": "desert_column", "pos": floor_.get_center() + Vector2(0, 300), "height": 300.0 + floor_.size.y * 0.5})
	return out

static func hazards() -> Array[Dictionary]:
	# Two short strips make a deliberate hop on otherwise safe banks.
	return [
		{"pos": Vector2(1170, 292), "size": Vector2(110, 18)},
		{"pos": Vector2(7830, 242), "size": Vector2(90, 18)},
	]

static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "sky_pursuer", "pos": start_position() + Vector2(-550, -24),
			"activation": 120.0, "delay": 4.0, "speed": 160.0, "catchup": 360.0,
			"stun": 2.5, "direction": Vector2.RIGHT},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(-610, 373), "patrol": 155.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(-75, 340), "patrol": 70.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(1250, 267), "patrol": 60.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(1740, 125), "patrol": 135.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(2220, 130), "patrol": 90.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(2710, 0), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(3390, 103), "patrol": 140.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(3890, 45), "patrol": 115.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(4550, 187), "patrol": 60.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(4870, 45), "patrol": 90.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(5360, 0), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(5900, -95), "patrol": 110.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(6530, 53), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "cactus", "pos": Vector2(7700, 217), "patrol": 80.0},
		{"type": "desert_enemy", "kind": "fin", "pos": Vector2(8380, 280), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "jelly", "pos": Vector2(8990, 160), "patrol": 100.0},
		{"type": "desert_enemy", "kind": "scarab", "pos": Vector2(9840, 293), "patrol": 135.0},
	]
	out.append_array(Sections.build().enemies)
	return out

static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		# C: keep moving. Each ledge falls 0.45s after contact.
		{"type": "crumble", "pos": Vector2(2460, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2670, 165), "span": Vector2(110, 30)},
		{"type": "crumble", "pos": Vector2(2880, 155), "span": Vector2(110, 30)},
		# A hidden causeway answers the guardian's shot in two beats. The ghost
		# outlines make the surprise legible before anyone commits to the jump.
		{"type": "switch", "id": "desert_mirage", "pos": Vector2(3500, -5),
			"hold": 8.0},
		{"type": "switch_bridge", "id": "desert_mirage", "pos": Vector2(3830, 205),
			"span": Vector2(155, 26)},
		{"type": "switch_bridge", "id": "desert_mirage", "pos": Vector2(4025, 205),
			"span": Vector2(155, 26), "delay": 0.30},
		# The arrow pad fires sideways over hazards and patrols, unlike a spring.
		{"type": "trick_pad", "pos": Vector2(1120, 300), "forward": 640.0, "rise": 1200.0},
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
		{"type": "trick_pad", "pos": Vector2(8330, 300), "forward": 360.0},
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
		{"type": "switch", "id": "desert_last_mirage", "pos": Vector2(8500, 185),
			"hold": 9.0},
		{"type": "switch_bridge", "id": "desert_last_mirage", "pos": Vector2(9000, 315),
			"span": Vector2(120, 30)},
		{"type": "crumble", "pos": Vector2(9210, 315), "span": Vector2(110, 30)},
	]
	out.append_array(Sections.build().gimmicks)
	# The two marked pairs make the fold a real, host-authoritative route.
	out.append({"type": "warp", "pos": ASCENT_MOUTH, "exit": ASCENT_EXIT, "mark": 3})
	out.append({"type": "warp_exit", "pos": ASCENT_EXIT, "mark": 3})
	out.append({"type": "warp", "pos": _return_mouth(), "exit": RETURN_EXIT, "mark": 4})
	out.append({"type": "warp_exit", "pos": RETURN_EXIT, "mark": 4})
	return out
static func veils() -> Array[Dictionary]: return []
static func checkpoints() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(900, 250), Vector2(1800, 200), Vector2(3180, 80),
		Vector2(4500, 170), Vector2(5180, -30), Vector2(6360, 30),
		Vector2(6980, 120), Vector2(8220, 250), Vector2(9540, 270)]
	out.append(Vector2(Sections.ENTRY.get_center().x, Sections.ENTRY.position.y - 50))
	out.append_array(Sections.build().checkpoints)
	out.append(RETURN_EXIT)
	return out
static func goal() -> Vector2: return Vector2(RETURN_BANK.end.x - 110, RETURN_BANK.position.y - 55)

static func _return_mouth() -> Vector2:
	var floor_: Rect2 = Sections.build().cursor
	return Vector2(floor_.end.x - 100, floor_.position.y - 45)

static func key_position() -> Vector2:
	# The key makes the upper journey mandatory; the lower goal cannot be rushed.
	var floor_: Rect2 = Sections.build().cursor
	return Vector2(floor_.get_center().x - 55, floor_.position.y - 4)

static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = [
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
	out.append_array(Sections.build().coins)
	return out

static func crystals() -> Array[Vector2]: return []
static func springs() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(100, 360)]
	out.append_array(Sections.build().springs)
	return out

static func ground_one_way(rect: Rect2) -> bool: return rect.size.y <= 48

static func rooms() -> Array[Dictionary]:
	var g := ground()
	var indices := [[0, 1], [1, 2], [2, 3], [3, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 10], [10, 13]]
	var out: Array[Dictionary] = []
	for i in PREFIX_NAMES.size():
		var entry: Rect2 = g[indices[i][0]]
		var exit: Rect2 = g[indices[i][1]]
		out.append({"name": PREFIX_NAMES[i], "entry": entry, "exit": exit,
			"x_start": entry.position.x, "x_end": exit.end.x})
	out.append_array(Sections.build().sections)
	return out

static func _tail(r: Rect2) -> Rect2:
	return Rect2(r.end.x - minf(200, r.size.x), r.position.y, minf(200, r.size.x), r.size.y)

static func route() -> Array[Dictionary]:
	var g := ground()
	var out: Array[Dictionary] = [
		{"section": PREFIX_NAMES[0], "via": "jump", "from": _tail(g[0]), "to": g[1]},
		{"section": PREFIX_NAMES[1], "via": "ride", "how": "spring", "from": g[1], "to": SAND_COLUMN, "at": Vector2(100, 360)},
		{"section": PREFIX_NAMES[1], "via": "jump", "from": SAND_COLUMN, "to": g[2]},
		{"section": PREFIX_NAMES[2], "via": "jump", "from": _tail(g[2]), "to": Rect2(870, 300, 80, 48)},
		{"section": PREFIX_NAMES[2], "via": "walk", "from": Rect2(870, 300, 80, 48), "to": Rect2(990, 300, 30, 48)},
		{"section": PREFIX_NAMES[3], "via": "ride", "how": "pad", "from": g[3], "to": g[4], "at": Vector2(1120, 300), "dir": 1},
		{"section": PREFIX_NAMES[3], "via": "jump", "from": _tail(g[4]), "to": g[5]},
		{"section": PREFIX_NAMES[4], "via": "ride", "how": "timed", "from": _tail(g[5]), "to": g[6],
			"pieces": [Vector2(2460, 165), Vector2(2670, 165), Vector2(2880, 155)], "tries": 12},
		{"section": PREFIX_NAMES[5], "via": "assist", "from": _tail(g[6]), "to": g[7],
			"platforms": [Rect2(3760, 90, 150, 26), Rect2(4100, 110, 150, 26)]},
		{"section": PREFIX_NAMES[6], "via": "ride", "how": "timed", "from": g[7], "to": g[8],
			"pieces": [Vector2(4860, 205)], "tries": 16, "spacing": 29},
		{"section": PREFIX_NAMES[7], "via": "ride", "how": "timed", "from": _tail(g[8]), "to": g[9],
			"pieces": [Vector2(5690, 20), Vector2(5890, 35), Vector2(6090, 60)], "tries": 20, "spacing": 23},
		{"section": PREFIX_NAMES[8], "via": "jump", "from": _tail(g[9]), "to": g[10], "tries": 12},
		{"section": PREFIX_NAMES[9], "via": "ride", "how": "gate", "id": "desert_oracle", "sigil": 2,
			"from": Rect2(6980, 170, 190, 48), "to": Rect2(7325, 170, 35, 48)},
		{"section": PREFIX_NAMES[9], "via": "jump", "from": _tail(g[10]), "to": g[11]},
		{"section": PREFIX_NAMES[9], "via": "jump", "from": _tail(g[11]), "to": g[12]},
		{"section": PREFIX_NAMES[9], "via": "ride", "how": "timed", "from": _tail(g[12]), "to": g[13],
			"pieces": [Vector2(8790, 315), Vector2(9000, 315), Vector2(9210, 315)],
			"activate": "desert_last_mirage", "tries": 12},
	]
	out.append({"section": PREFIX_NAMES[-1], "via": "ride", "how": "warp", "from": _tail(g[13]),
		"to": Sections.ENTRY, "at": ASCENT_MOUTH})
	out.append_array(Sections.build().route)
	out.append({"section": Sections.NAMES[-1], "via": "ride", "how": "warp", "from": Sections.build().cursor,
		"to": RETURN_BANK, "at": _return_mouth()})
	for step in out:
		if PREFIX_NAMES.has(step["section"]): step["sprint"] = true
	return out

static func painted_2d_value() -> bool: return true
static func needs_key_value() -> bool: return true
static func pit_centre_x_value() -> float: return 2700.0
