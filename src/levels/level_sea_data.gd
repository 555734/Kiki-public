extends RefCounted
## Twenty unique production encounters; authored geometry and routes share a builder.
const Sections = preload("res://src/levels/coastal_sections.gd")
const WATER_Y := 1450.0
const KILL_Y := 1550.0
const START := Vector2(-1000, 330)
static func kill_y_value() -> float: return KILL_Y
static func water_y_value() -> float: return WATER_Y
static func start_position() -> Vector2: return START
static func stage_name_value() -> String: return "THE SUNLIT COAST"
static func stage_number_value() -> String: return "1-4"
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
	return []
static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"type": "sky_pursuer", "pos": START + Vector2(-550, -24), "activation": 120.0, "delay": 4.0,
			"speed": 160.0, "catchup": 360.0, "stun": 2.5, "direction": Vector2.RIGHT},
		{"type": "walker", "pos": Vector2(-350, 379), "patrol": 130.0, "skin": "sea_crab"},
		{"type": "walker", "pos": Vector2(100, 379), "patrol": 90.0, "skin": "sea_crab"},
	]
	out.append_array(Sections.build().enemies)
	return out
static func decor() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"type": "sea_palm", "pos": Vector2(-1420, 400), "height": 300.0}, {"type": "sea_boulder", "pos": Vector2(-820, 400), "width": 150.0}]
	out.append_array(Sections.build().decor)
	return out
