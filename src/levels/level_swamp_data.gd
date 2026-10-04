extends RefCounted
## Stage 1-5 climbs out of the poison marsh: the bright green pool stays at the
## bottom, lethal as ever, and the route goes up a hollow, moss-grown cliff.
##
## It is a cliff with few ledges. Where the moss gives out, the guardian has to
## build the next step (`gap`, `chasm`); where it forks, the pair choose between
## a long way past crawlers and a short cut over the guardian's platform; and
## between them, drifting log lifts, columns of marsh gas, rot that gives way and
## a lure the guardian shoots to raise a ledge. The rooms are laid out by
## ClimbBuilder, which also records how each is meant to be climbed (`route`).

const ClimbBuilder = preload("res://src/levels/climb_builder.gd")

const BASE_Y := 8200.0
## The poison sits a little under the starting bank, as it did on the flat.
const WATER_Y := BASE_Y + 60.0
const KILL_Y := BASE_Y + 200.0
const STAGE_NAME := "THE POISON MARSH"
const STAGE_NUMBER := "1-5"
const OBJECTIVE := "Climb out of the poison marsh"

static var _built: ClimbBuilder = null

static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return Vector2(-300, BASE_Y - 50.0)
static func stage_name_value() -> String: return STAGE_NAME
static func stage_number_value() -> String: return STAGE_NUMBER
static func objective_value() -> String: return OBJECTIVE

## Stage traits: what Stage answers for this stage instead of its default.
static func painted_2d_value() -> bool: return true
static func progress_direction_value() -> Vector2: return Vector2.UP
static func needs_key_value() -> bool: return true
static func pit_centre_x_value() -> float: return 4200.0
## A climb: ledges above the floor can be jumped through from below. Its
## gimmicks stay solid (no platforms_one_way, unlike 1-8).
static func ground_one_way(rect: Rect2) -> bool:
	return rect.position.y < start_position().y

static func _theme() -> Dictionary:
	var phase := [0.0]
	return {
		"ground": func(at: Vector2, patrol: float) -> Dictionary:
			return {"type": "walker", "skin": "walker_spiky",
				"pos": at + Vector2(0, -21), "patrol": patrol},
		"air": func(at: Vector2, patrol: float) -> Dictionary:
			return {"type": "flyer", "pos": at, "patrol": patrol},
		"lift": func(at: Vector2, span: Vector2, travel: Vector2) -> Dictionary:
			phase[0] += 0.37
			return {"type": "moving_platform", "pos": at, "span": span,
				"travel": travel, "speed": 70.0, "phase": phase[0]},
		"air_column": func(at: Vector2, span: Vector2) -> Dictionary:
			return {"type": "updraft", "pos": at, "span": span},
		# Rotten stones: they hold one landing, then go.
		"blink": func(at: Vector2, _k: int) -> Dictionary:
			return {"type": "crumble", "pos": at + Vector2(0, 5), "span": Vector2(150, 36)},
	}

static func _b() -> ClimbBuilder:
	if _built != null:
		return _built
	var b := ClimbBuilder.new(Rect2(-520, BASE_Y, 1040, 320), _theme())
	b.stairs(1, false)
	b.gap()
	b.nook()
	b.lift()
	b.fork()
	b.chimney()
	b.gap(true)
	b.mirage("marsh_rise_1")
	b.blinks()
	b.chasm()
	b.lift()
	b.spring()
	b.chimney()
	b.gap(true)
	b.nook()
	b.mirage("marsh_rise_2")
	b.blinks()
	b.lift()
	b.spring()
	b.chasm()
	b.chimney()
	b.lift()
	b.gap(true)
	b.chimney()
	b.gap()
	b.finish()
	_built = b
	return b

static func route() -> Array[Dictionary]: return _b().route
static func ground() -> Array[Rect2]: return _b().ground
static func solid_decor() -> Array[Rect2]: return []
static func veils() -> Array[Dictionary]: return []

static func hazards() -> Array[Dictionary]:
	# The pool's surface: one sensor, no spikes drawn -- the green is the warning.
	var out: Array[Dictionary] = [{"pos": Vector2(0, WATER_Y + 34),
		"size": Vector2(3200, 68), "draw_spikes": false}]
	out.append_array(_b().hazards)
	return out

static func enemies() -> Array[Dictionary]:
	# The climbing chaser from 1-3 first: it rises from the pool, so the climb
	# cannot be taken at leisure; the guardian's shot knocks it back down.
	var out: Array[Dictionary] = [{"type": "sky_pursuer",
		"pos": start_position() + Vector2(0, 420), "delay": 2.0, "speed": 195.0,
		"catchup": 460.0, "stun": 1.5, "direction": Vector2.UP}]
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
		{"type": "swamp_tree", "pos": Vector2(-470, BASE_Y), "height": 300.0},
		{"type": "swamp_reeds", "pos": Vector2(-60, BASE_Y)},
		{"type": "swamp_mushroom", "pos": Vector2(300, BASE_Y)},
		{"type": "swamp_tree", "pos": Vector2(250, top), "height": 260.0, "flip": true},
		{"type": "swamp_reeds", "pos": Vector2(-300, top)},
	]
	var i := 0
	for spot in _b().decor_spots:
		out.append({"type": "swamp_mushroom" if i % 2 == 0 else "swamp_reeds",
			"pos": spot + Vector2(60.0 if i % 2 == 0 else -60.0, 0)})
		i += 1
	return out
