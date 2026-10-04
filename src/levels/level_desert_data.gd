extends RefCounted
## Stage 1-6 climbs the sandglass ruins: a broken sandstone tower standing out
## of the dunes, climbed to the open sky at its top.
##
## Few ledges survive. The guardian builds the missing steps and bridges, the
## route forks around scarabs and cacti, and in between come sand belts,
## blinking cyan stones, lifts, the desert wind, springs, the mirage bridges the
## guardian's shot makes solid, and arrow pads that throw the runner up and
## across. Laid out by ClimbBuilder, which records the intended route.

const ClimbBuilder = preload("res://src/levels/climb_builder.gd")

const BASE_Y := 9400.0
const KILL_Y := BASE_Y + 380.0

static var _built: ClimbBuilder = null

static func kill_y_value() -> float: return KILL_Y
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return "THE SANDGLASS RUINS"
static func stage_number_value() -> String: return "1-6"
static func objective_value() -> String: return "Climb the sandglass ruins"

static func _theme() -> Dictionary:
	var n := [0, 0, 0.0]
	return {
		"ground": func(at: Vector2, patrol: float) -> Dictionary:
			n[0] += 1
			if n[0] % 2 == 0:
				return {"type": "desert_enemy", "kind": "cactus",
					"pos": at + Vector2(0, -33), "patrol": minf(patrol, 40.0)}
			return {"type": "desert_enemy", "kind": "scarab",
				"pos": at + Vector2(0, -27), "patrol": patrol},
		"air": func(at: Vector2, patrol: float) -> Dictionary:
			n[1] += 1
			return {"type": "desert_enemy", "kind": "jelly" if n[1] % 2 == 0 else "fin",
				"pos": at, "patrol": patrol},
		"lift": func(at: Vector2, span: Vector2, travel: Vector2) -> Dictionary:
			n[2] += 0.43
			return {"type": "moving_platform", "pos": at, "span": span,
				"travel": travel, "speed": 75.0, "phase": n[2]},
		"air_column": func(at: Vector2, span: Vector2) -> Dictionary:
			return {"type": "updraft", "pos": at, "span": span},
		"blink": func(at: Vector2, k: int) -> Dictionary:
			return {"type": "blink", "pos": at, "span": Vector2(170, 26), "beat": 1.6,
				"colour": k % 2, "phase": float(k) * 0.5},
	}

## The room's last ledge turns into a sand belt.
static func _belt(b: ClimbBuilder, dir: int) -> void:
	var r := b.cursor
	b.ground.erase(r)
	b.gimmicks.append({"type": "conveyor", "pos": Vector2(r.get_center().x, r.position.y + 13.0),
		"span": Vector2(r.size.x, 26), "speed": 90.0, "flip": 3.2, "dir": dir})

static func _b() -> ClimbBuilder:
	if _built != null:
		return _built
	var b := ClimbBuilder.new(Rect2(-520, BASE_Y, 1040, 360), _theme())
	b.stairs(1, false)
	_belt(b, 1)
	b.gap()
	b.blinks()
	b.fork()
	b.nook()
	b.lift()
	b.mirage("desert_mirage_1")
	_belt(b, -1)
	b.pad()
	b.chimney()
	b.gap(true)
	b.chasm()
	_belt(b, 1)
	b.spring()
	b.blinks()
	b.nook()
	b.lift()
	b.mirage("desert_mirage_2")
	b.pad()
	b.gap(true)
	b.chimney()
	b.fork()
	b.spring()
	b.gap()
	b.lift()
	b.chasm()
	b.chimney()
	b.finish()
	_built = b
	return b

static func route() -> Array[Dictionary]: return _b().route
static func ground() -> Array[Rect2]: return _b().ground
static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []
static func hazards() -> Array[Dictionary]: return _b().hazards

static func enemies() -> Array[Dictionary]:
	# The climbing chaser from 1-3 first: it rises out of the dunes behind the pair.
	var out: Array[Dictionary] = [{"type": "sky_pursuer",
		"pos": start_position() + Vector2(0, 420), "delay": 2.0, "speed": 200.0,
		"catchup": 470.0, "stun": 1.45, "direction": Vector2.UP}]
	out.append_array(_b().enemies)
	return out

static func gimmicks() -> Array[Dictionary]: return _b().gimmicks
static func springs() -> Array[Vector2]: return _b().springs
static func checkpoints() -> Array[Vector2]: return _b().checkpoints

static func goal() -> Vector2:
	var s := _b().shelf
	return Vector2(s.position.x + 120.0, s.position.y - 55.0)

static func key_position() -> Vector2:
	var s := _b().shelf
	return Vector2(s.end.x - 110.0, s.position.y - 4.0)

static func coins() -> Array[Vector2]: return _b().coins
static func crystals() -> Array[Vector2]: return _b().crystals

static func decor() -> Array[Dictionary]:
	var top := _b().shelf.position.y
	var out: Array[Dictionary] = [
		{"type": "desert_arch", "pos": Vector2(-380, BASE_Y), "height": 235.0},
		{"type": "desert_flower", "pos": Vector2(60, BASE_Y)},
		{"type": "desert_cactus", "pos": Vector2(360, BASE_Y)},
		{"type": "desert_arch", "pos": Vector2(150, top), "height": 210.0},
		{"type": "desert_crystal", "pos": Vector2(-300, top)},
	]
	var kinds := ["desert_crystal", "desert_flower", "desert_cactus"]
	var i := 0
	for spot in _b().decor_spots:
		out.append({"type": kinds[i % 3], "pos": spot + Vector2(55.0 if i % 2 == 0 else -55.0, 0)})
		i += 1
	return out
