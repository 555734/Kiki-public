extends Node
## Simulates a landscape iPhone safe rectangle on desktop/headless so the
## control-layout geometry can be checked without an iPhone attached.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	var places := {
		"stick": {"center": Vector2(40, 680), "radius": 80.0, "kind": "stick"},
		"jump": {"center": Vector2(1250, 690), "radius": 60.0, "kind": "button"},
		"scope": {"center": Vector2(1260, 80), "radius": 50.0, "kind": "button"},
	}
	# Simulated landscape iPhone: Dynamic Island/notch reserves both sides and
	# the home indicator reserves the bottom.
	var safe := Rect2(Vector2(70, 20), Vector2(1140, 650))
	ControlLayout._clamp_layout_to_safe_area(places, safe)

	for id in places:
		var place: Dictionary = places[id]
		var extent: float = float(place["radius"]) * (ControlLayout.STICK_CAPTURE if place["kind"] == "stick" else 1.0) + ControlLayout.SAFE_PAD
		var c: Vector2 = place["center"]
		check(c.x - extent >= safe.position.x - 0.01, "%s clears the left unsafe edge" % id)
		check(c.x + extent <= safe.end.x + 0.01, "%s clears the right unsafe edge" % id)
		check(c.y - extent >= safe.position.y - 0.01, "%s clears the top unsafe edge" % id)
		check(c.y + extent <= safe.end.y + 0.01, "%s clears the bottom unsafe edge" % id)

	if failures.is_empty():
		print("safe area probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("safe area probe: " + failure)
		get_tree().quit(1)
