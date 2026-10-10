class_name StageSpecSchema
extends RefCounted
## Accepted data keys mirror the builder and gimmick from_spec readers.
## Keep defaults optional; position/type are required for placed entities.
const ENEMIES := {
	"parade_actor": ["kind", "bounds", "dir"],
	"parade_gremlin": ["speed", "dir", "wake", "bounds", "large"],
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
	"parade_device": ["kind", "id", "span", "target"],
	"parade_machine": ["kind", "id", "period", "phase", "height"],
	"coastal_hazard": ["kind", "travel", "width", "period", "phase"],
	"volcanic_hazard": ["kind", "travel", "width", "period", "phase"],
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
			elif key in ["pos", "span", "size", "exit", "exit_velocity", "bounds", "target"] or (kind in ["moving_platform", "volcanic_hazard", "coastal_hazard"] and key == "travel"):
				var vector: Variant = spec[key]
				if not vector is Vector2 or not vector.is_finite():
					out.append(label + ": " + String(key) + " must be a finite Vector2")
				elif key in ["span", "size"] and (vector.x <= 0 or vector.y <= 0):
					out.append(label + ": " + String(key) + " must have positive dimensions")
			elif key in ["period", "beat", "phase"] or (kind in ["moving_platform", "parade_gremlin"] and key == "speed") or (kind == "parade_machine" and key == "height") or (kind in ["volcanic_hazard", "coastal_hazard"] and key == "width"):
				var number: Variant = spec[key]
				if not (number is int or number is float) or not is_finite(float(number)):
					out.append(label + ": " + String(key) + " must be finite numeric data")
				elif key != "phase" and float(number) <= 0:
					out.append(label + ": " + String(key) + " must be positive")
		if kind == "parade_machine":
			if spec.get("kind", "mouth") not in ["mouth", "hammer"]:
				out.append(label + ": unknown machine kind")
			if not spec.get("id", "") is String or String(spec.get("id", "")).is_empty():
				out.append(label + ": a named switch id is required")
		if kind == "parade_device":
			if spec.get("kind", "") not in ParadeDevice.KINDS: out.append(label + ": unknown parade device")
			if not spec.get("id", "") is String or String(spec.get("id", "")).is_empty(): out.append(label + ": a named switch id is required")
			if not spec.get("target", Vector2.ZERO) is Vector2: out.append(label + ": target must be Vector2")
		if kind == "parade_actor":
			if spec.get("kind", "") not in ParadeActor.KINDS: out.append(label + ": unknown parade actor")
			if spec.get("dir", 1) not in [-1, 1]: out.append(label + ": dir must be -1 or 1")
			var limits: Variant = spec.get("bounds", Vector2.ZERO)
			if limits is Vector2 and limits.x >= limits.y: out.append(label + ": bounds must be increasing")
		if kind == "parade_gremlin":
			if spec.get("dir", 1) not in [-1, 1]: out.append(label + ": dir must be -1 or 1")
			var bounds: Variant = spec.get("bounds", Vector2(-1200, 1550))
			if bounds is Vector2 and bounds.x >= bounds.y: out.append(label + ": bounds must be increasing")
			var wake: Variant = spec.get("wake", 200.0)
			if not (wake is int or wake is float) or not is_finite(float(wake)): out.append(label + ": wake must be finite")
		if kind in ["volcanic_hazard", "coastal_hazard"]:
			var kinds := ["surge", "anchor"] if kind == "coastal_hazard" else ["geyser", "meteor"]
			var motion: Variant = spec.get("kind", kinds[0])
			if motion not in kinds:
				out.append(label + ": unknown hazard kind")
			var period_value: Variant = spec.get("period", 4.8)
			if (period_value is int or period_value is float) and float(period_value) < 3.0:
				out.append(label + ": period must leave a safe cooldown (>=3s)")
			var travel: Variant = spec.get("travel", Vector2(0, -230))
			if travel is Vector2 and travel.is_finite():
				if (motion == kinds[0] and (travel.y >= 0 or travel.x != 0)) or (motion == kinds[1] and travel.y <= 0):
					out.append(label + ": jets rise vertically and falling hazards descend")
