extends Control
## The on-screen buttons, drawn exactly where co-op 1-1's one-device layout
## puts them (ControlLayout "shared"): the stick and the jump under the left
## thumb, the shot button on the right, and the right of the screen is where
## you tap to shoot. A 2v2 guardian has the guardian layout (the shot only).
##
## Drawing only. The touches themselves are the InputHub's and the Guardian's,
## the same code that handles them in co-op, so a button here is exactly where
## a press on it lands.

var arena = null
## The hub whose layout is drawn.
var hub: InputHub = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _size() -> Vector2:
	return get_viewport_rect().size

## The controls on screen, as id -> {center, radius}. Only these three: the
## build buttons of the co-op layout are not in versus.
func places() -> Dictionary:
	if hub == null:
		return {}
	var all := ControlLayout.layout(hub.layout_mode(), _size(), false)
	var out: Dictionary = {}
	for id in ["stick", "jump", "slot_3"]:
		if all.has(id):
			out[id] = all[id]
	return out

func _draw() -> void:
	if arena == null:
		return
	var font := Art.font()
	var names := {"stick": "移動", "jump": "ジャンプ", "slot_3": "射撃"}
	var p := places()
	for id in p:
		var c: Vector2 = p[id]["center"]
		var r: float = p[id]["radius"]
		var fill := Color(0.45, 0.10, 0.10, 0.55) if id == "slot_3" \
			else Color(0.08, 0.12, 0.21, 0.40)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 40, Color(0.93, 0.95, 0.99, 0.75), 2.0)
		draw_string(font, c + Vector2(-r, 6.0), TranslationServer.translate(names[id]),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 17, Color.WHITE)
