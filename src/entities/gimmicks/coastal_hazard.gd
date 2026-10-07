class_name CoastalHazard
extends VolcanicHazard
## Water blowholes and falling anchors reuse the tested shared-clock motion,
## telegraph and collider rules. Ocean artwork stays separate from lava art.
static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var node := CoastalHazard.new()
	node.kind = "geyser" if spec.get("kind", "surge") == "surge" else "meteor"
	node.travel = spec.get("travel", Vector2(0, -230))
	node.width = float(spec.get("width", 64.0))
	node.period = float(spec.get("period", 4.8))
	node.phase_offset = float(spec.get("phase", 0.0))
	return node

func effect_texture() -> String: return "s14_surge" if kind == "geyser" else "s14_anchor"
func fallback_colour() -> Color: return Color("67ddeb") if kind == "geyser" else Color("46678b")
func draw_ellipse_vent() -> void:
	draw_rect(Rect2(-width * 0.65, -8, width * 1.3, 16), Color("435d73"))
	draw_rect(Rect2(-width * 0.5, -5, width, 8), Color("83e4ed"))
