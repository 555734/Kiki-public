extends Control
## The on-screen buttons, drawn exactly where co-op 1-1's one-device layout
## puts them (ControlLayout "shared"): the stick and the jump under the left
## thumb, the platform and shot buttons on the right, and the right of the
## screen is where you draw a platform or tap to shoot, whichever is chosen.
## A 2v2 guardian has the guardian layout (the same two tools). The chosen one
## is ringed in gold, as the choice sticks until the other is pressed.
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

## The controls on screen, as id -> {center, radius}. 1-1's shared layout:
## the wall and warp slots of the co-op layout are not in versus.
func places() -> Dictionary:
	if hub == null:
		return {}
	var all := ControlLayout.layout(hub.layout_mode(), _size(), false)
	var out: Dictionary = {}
	for id in ["stick", "jump", "slot_1", "slot_3"]:
		if all.has(id):
			out[id] = all[id]
	return out

func _draw() -> void:
	if arena == null:
		return
	var font := Art.font()
	var names := {"stick": "移動", "jump": "ジャンプ", "slot_1": "足場", "slot_3": "射撃"}
	var p := places()
	var chosen := -1
	if arena.guardian != null:
		chosen = arena.guardian.active_slot
	for id in p:
		var c: Vector2 = p[id]["center"]
		var r: float = p[id]["radius"]
		var fill := Color(0.08, 0.12, 0.21, 0.40)
		if id == "slot_3":
			fill = Color(0.45, 0.10, 0.10, 0.55)
		elif id == "slot_1":
			fill = Color(0.10, 0.32, 0.45, 0.55)
		draw_circle(c, r, fill)
		var on: bool = id == "slot_%d" % chosen
		draw_arc(c, r, 0.0, TAU, 40,
			Color(1.0, 0.86, 0.35, 0.95) if on else Color(0.93, 0.95, 0.99, 0.75),
			4.0 if on else 2.0)
		draw_string(font, c + Vector2(-r, 6.0), TranslationServer.translate(names[id]),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 17, Color.WHITE)
