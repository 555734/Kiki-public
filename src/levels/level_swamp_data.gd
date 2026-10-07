extends RefCounted
## Twenty unique production encounters; authored geometry and routes share a builder.
const Sections = preload("res://src/levels/molten_sections.gd")
const WATER_Y := 1450.0
const KILL_Y := 1550.0
const START := Vector2(-1050, 330)
static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE MOLTEN CROSSING"
static func stage_number_value() -> String: return "1-5"
static func objective_value() -> String: return "Reach the lighthouse flag" if stage_number_value() == "1-4" else "Cross the molten gorge"
static func painted_2d_value() -> bool: return true
static func needs_key_value() -> bool: return true
static func ground_one_way(rect: Rect2) -> bool: return rect.size.y <= 48
static func ground() -> Array[Rect2]: return Sections.build().ground.duplicate()
static func solid_decor() -> Array[Rect2]: return []
static func rooms() -> Array[Dictionary]: return Sections.build().sections
static func route() -> Array[Dictionary]: return Sections.build().route
static func gimmicks() -> Array[Dictionary]: return Sections.build().gimmicks
static func checkpoints() -> Array[Vector2]: return Sections.build().checkpoints
static func springs() -> Array[Vector2]: return Sections.build().springs
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(-760, 345), Vector2(-680, 325), Vector2(-600, 345)]
	out.append_array(Sections.build().coins)
	return out
static func crystals() -> Array[Vector2]: return []
static func key_position() -> Vector2:
	var exit: Rect2 = rooms()[-1]["exit"]
	return Vector2(exit.get_center().x - 45, exit.position.y - 4)
static func veils() -> Array[Dictionary]: return []
static func goal() -> Vector2:
	var last := Sections.build().cursor
	return Vector2(last.end.x - 90, last.position.y - 55)
static func hazards() -> Array[Dictionary]:
	var width := goal().x + 1700
	return [{"pos": Vector2(-1500 + width * 0.5, WATER_Y + 34), "size": Vector2(width, 68), "draw_spikes": false}]
static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "sky_pursuer", "pos": START + Vector2(-550, -24), "activation": 120.0, "delay": 4.0,
			"speed": 160.0, "catchup": 360.0, "stun": 2.5, "direction": Vector2.RIGHT},
		{"type": "walker", "pos": Vector2(-350, 379), "patrol": 130.0, "skin": "s15_magma_slime"},
		{"type": "walker", "pos": Vector2(100, 379), "patrol": 90.0, "skin": "s15_magma_slime"},
	]
	out.append_array(Sections.build().enemies)
	return out
static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"type": "swamp_tree", "pos": Vector2(-1240, 400), "height": 280.0}, {"type": "swamp_reeds", "pos": Vector2(-910, 400)}]
	out.append_array(Sections.build().decor)
	return out
