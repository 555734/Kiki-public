extends Control
## The on-screen controls, exactly as 1-1 shows them: the same layout
## (ControlLayout "shared" -- the stick alone on the left; jump, shot and
## platform on the right) drawn by the same painter (ControlPainter) the co-op
## HUD uses. A 2v2 guardian gets the guardian layout, as in co-op.
##
## Drawing only. The touches themselves are the InputHub's and the Guardian's,
## the same code that handles them in co-op, so a button here is exactly where
## a press on it lands.

var arena = null
## The hub whose controls are drawn. `input_hub`/`guardian`/gauge()/
## slot_pulse()/scope_up() are what ControlPainter asks its source for.
var hub: InputHub = null
var input_hub: InputHub:
	get: return hub
var guardian: Guardian:
	get: return arena.guardian if arena != null else null

var _pulse: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Events.ability_used.connect(func(slot: int, _at: Vector2) -> void: _pulse[slot] = 1.0)
	# The controls are only built on a touch screen: show them from the start
	# rather than after the first touch, as there is no keyboard to fall back on.
	if hub != null:
		hub.assume_touch()

func gauge() -> float:
	return guardian.gauge if guardian != null else Balance.GAUGE_MAX

func slot_pulse(slot: int) -> float:
	return float(_pulse.get(slot, 0.0))

func scope_up() -> bool:
	return guardian != null and guardian.scope_active

## Redrawn when what it shows changes -- the thumb on the stick, a held or
## chosen tool, a press's pulse, the screen size -- not every frame.
var _shown := ""

func _process(delta: float) -> void:
	for slot in _pulse.keys():
		_pulse[slot] = maxf(0.0, float(_pulse[slot]) - delta * 3.0)
		if _pulse[slot] <= 0.0:
			_pulse.erase(slot)
	var now := "%s|%s|%d|%d|%s" % [_size(), str(hub.stick_visual()) if hub != null else "",
		hub.held_slot() if hub != null else -1,
		guardian.active_slot if guardian != null else -1, str(_pulse)]
	if now != _shown:
		_shown = now
		queue_redraw()

func _size() -> Vector2:
	return get_viewport_rect().size

## The controls on screen, as id -> {center, radius} (for the probes).
func places() -> Dictionary:
	if hub == null:
		return {}
	var all := ControlLayout.layout(hub.layout_mode(), _size(), not hub.runner_on_left)
	var out: Dictionary = {}
	for id in ["stick", "jump", "slot_1", "slot_3"]:
		if all.has(id):
			out[id] = all[id]
	return out

func _draw() -> void:
	if arena == null or hub == null:
		return
	ControlPainter.draw_controls(self, self, _size())
