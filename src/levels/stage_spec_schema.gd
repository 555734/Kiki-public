class_name StageSpecSchema
extends RefCounted
## Accepted data keys mirror the builder and gimmick from_spec readers.
## Keep defaults optional; position/type are required for placed entities.
const ENEMIES := {
	"cave_enemy": ["kind", "patrol", "wander", "dart"],
	"desert_enemy": ["kind", "patrol"],
	"chaser": ["speed", "activation", "spawn_distance"],
	"sky_pursuer": ["activation", "delay", "speed", "catchup", "stun", "direction"],
	"thornmite": ["patrol"],
	"walker": ["patrol", "skin"],
	"flyer": ["patrol"],
	"shieldbearer": [],
	"keeper": ["gate", "home"],
	"mine": ["bob", "period", "phase", "wander", "dart"],
	"seedling": ["reach", "period", "phase"],
	"golem": ["patrol", "period", "phase"],
	"turret": ["aim", "burst"],
}
const GIMMICKS := {
	"moving_platform": ["span", "travel", "speed", "phase", "style", "one_way"],
	"cave_trap": ["kind", "travel", "period", "phase"],
	"switch_bridge": ["span", "id", "delay", "one_way"],
	"trick_pad": ["dir", "flip", "phase", "forward", "rise"],
	"clock_hand": ["length", "period", "phase"],
	"gear_wheel": ["radius", "speed", "dir", "phase"],
	"tower_trap": ["kind", "length", "travel", "period", "phase", "facing"],
	"blink": ["span", "beat", "colour", "phase", "one_way"],
	"conveyor": ["span", "speed", "flip", "dir", "phase", "one_way"],
	"warp": ["exit", "size", "mark", "exit_velocity"],
	"warp_exit": ["exit", "size", "mark"],
	"crumble": ["span", "one_way"],
	"laser": ["dir", "length"],
	"switch": ["id", "hold", "sigil"],
	"gate": ["span", "id", "wants"],
	"barricade": ["act"],
	"updraft": ["span"],
}

static func errors(enemies: Array, gimmicks: Array) -> Array[String]:
	var out: Array[String] = []
	_validate(enemies, ENEMIES, "enemy", out)
	_validate(gimmicks, GIMMICKS, "gimmick", out)
	return out

static func _validate(specs: Array, schema: Dictionary, category: String, out: Array[String]) -> void:
	for i in specs.size():
		var value: Variant = specs[i]
		var label := "%s[%d]" % [category, i]
		if not value is Dictionary:
			out.append(label + ": expected Dictionary")
			continue
		var spec: Dictionary = value
		var kind: Variant = spec.get("type")
		if not kind is String or not schema.has(kind):
			out.append(label + ": unknown type")
			continue
		label += ":" + String(kind)
		if not spec.get("pos") is Vector2:
			out.append(label + ": pos must be Vector2")
		for key in spec:
			if key != "type" and key != "pos" and not schema[kind].has(key):
				out.append(label + ": unknown property " + String(key))
			elif key in ["pos", "span", "size", "exit", "exit_velocity"] or (kind == "moving_platform" and key == "travel"):
				var vector: Variant = spec[key]
				if not vector is Vector2 or not vector.is_finite():
					out.append(label + ": " + String(key) + " must be a finite Vector2")
				elif key in ["span", "size"] and (vector.x <= 0 or vector.y <= 0):
					out.append(label + ": " + String(key) + " must have positive dimensions")
			elif key in ["period", "beat", "phase"] or (kind == "moving_platform" and key == "speed"):
				var number: Variant = spec[key]
				if not (number is int or number is float) or not is_finite(float(number)):
					out.append(label + ": " + String(key) + " must be finite numeric data")
				elif key != "phase" and float(number) <= 0:
					out.append(label + ": " + String(key) + " must be positive")
