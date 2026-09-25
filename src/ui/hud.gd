class_name Hud
extends CanvasLayer
## Screen furniture: stage information, ability controls, and run messages.
## The upper-left player and life panels are intentionally hidden.

const SKEW := 16.0

var guardian: Guardian = null
var input_hub: InputHub = null

var _root: Control = null
var _overlay: Control = null
var _hp: int = Balance.RUNNER_MAX_HP
var _gauge: float = Balance.GAUGE_MAX
var _refusal_flash: float = 0.0
var _refusal_text: String = ""
var _notice: String = ""
var _notice_timer: float = 0.0
var _countdown: float = 0.0
var _cleared: Dictionary = {}
## Seconds since the stage was cleared, for the celebration's timing.
var clear_age: float = 0.0
## Counts down while the GAME OVER plate is up. Driven by the same events on
## both devices -- the host raises runner_died locally and sends RUNNER_DIE, and
## the client turns that back into the same signal -- so the guardian sees the
## run end at the same moment the runner does.
var _game_over: float = 0.0
var _scope_up: bool = false
## Non-empty while the link is down. Sits above everything else because a player
## staring at a frozen partner deserves to know why before they start pressing
## things harder.
var _link: String = ""
## The graded catch, for the moment it is worth shouting about.
var _rescue_tier: int = 0
var _rescue_flash: float = 0.0
var _time: float = 0.0
var _slot_pulse: Dictionary = {1: 0.0, 2: 0.0, 3: 0.0}

func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_script(preload("res://src/ui/hud_canvas.gd"))
	add_child(_root)
	_root.hud = self

	# Interactive/readability layer: segmented numeric gauge and the real
	# touchable button on the stage-clear screen.
	_overlay = Control.new()
	_overlay.set_script(preload("res://src/ui/hud_overlay.gd"))
	_overlay.hud = self
	add_child(_overlay)

	# A guardian playing on their own device should not have to reach across the
	# phone. These are defaults only: any layout the player already saved wins.
	_ensure_guardian_left_defaults()

	Events.runner_damaged.connect(func(hp: int, _m: int) -> void: _hp = hp)
	Events.gauge_changed.connect(func(v: float, _m: float) -> void: _gauge = v)
	Events.ability_refused.connect(_on_refused)
	Events.ability_used.connect(func(slot: int, _p: Vector2) -> void: _slot_pulse[slot] = 1.0)
	Events.notice.connect(_on_notice)
	Events.countdown_started.connect(func() -> void: _countdown = 3.99)
	Events.stage_cleared.connect(func(stats: Dictionary) -> void: _cleared = stats)
	Events.runner_died.connect(func(_cause: String) -> void:
		_game_over = Balance.RESPAWN_DELAY)
	Events.runner_respawned.connect(func(_index: int) -> void: _game_over = 0.0)
	Events.scope_state_changed.connect(func(active: bool, _z: float) -> void:
		_scope_up = active)
	Events.link_state.connect(func(text: String) -> void: _link = text)
	Events.rescue_scored.connect(func(tier: int, _at: Vector2) -> void:
		_rescue_tier = tier
		_rescue_flash = 1.3)

func _process(delta: float) -> void:
	if not _cleared.is_empty():
		clear_age += delta
	_time += delta
	_refusal_flash = maxf(0.0, _refusal_flash - delta)
	_notice_timer = maxf(0.0, _notice_timer - delta)
	if _countdown > 0.0:
		_countdown = maxf(0.0, _countdown - delta)
	_game_over = maxf(0.0, _game_over - delta)
	_rescue_flash = maxf(0.0, _rescue_flash - delta)
	for slot in _slot_pulse.keys():
		_slot_pulse[slot] = maxf(0.0, _slot_pulse[slot] - delta * 2.2)
	# If the layout editor's Reset clears the in-memory defaults, reinstate the
	# new guardian-left defaults on the next frame. Saved custom layouts are left
	# untouched because has_custom("guardian") stays true.
	_ensure_guardian_left_defaults()
	_root.queue_redraw()

## The guardian's two buttons take their places from ControlLayout
## (platform left, shot right); nothing is forced here any more.
func _ensure_guardian_left_defaults() -> void:
	pass

func _on_refused(_slot: int, reason: String) -> void:
	_refusal_flash = 0.9
	_refusal_text = {
		"gauge": "NOT ENOUGH GAUGE",
		"scoped": "LOWER THE SCOPE TO BUILD",
		"blocked": "NO ROOM THERE",
		"range": "TOO FAR FROM THE RUNNER",
		"cooldown": "RELOADING",
	}.get(reason, reason.to_upper())

func _on_notice(text: String) -> void:
	_notice = {"blocked": "SHOT BLOCKED"}.get(text, text.to_upper())
	_notice_timer = 1.1

# --- state accessors for the canvas -----------------------------------------
func hp() -> int: return _hp
func gauge() -> float: return _gauge
func refusal_flash() -> float: return _refusal_flash
func refusal_text() -> String: return _refusal_text
func notice_text() -> String: return _notice if _notice_timer > 0.0 else ""
func countdown() -> float: return _countdown
func cleared() -> Dictionary: return _cleared
func game_over() -> float: return _game_over
func scope_up() -> bool: return _scope_up
func link_text() -> String: return _link
func rescue_flash() -> float: return _rescue_flash
func rescue_tier() -> int: return _rescue_tier
func time() -> float: return _time
func slot_pulse(slot: int) -> float: return _slot_pulse.get(slot, 0.0)
