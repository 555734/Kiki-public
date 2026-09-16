class_name Gate
extends StaticBody2D
## A barrier that a switch opens. Deliberately on a timer rather than a latch:
## chapter 4's "snipe then platform" combo is about doing two things inside one
## window, and a permanent unlock would remove the window.

@export var span: Vector2 = Vector2(40, 190)
@export var switch_id: String = "gate_a"
## Which mark opens it, or 0 for a gate any of its switches opens.
##
## Only the GUARDIAN is shown it -- the runner is standing right in front of
## this gate and cannot read what it wants, while the guardian, a screen away,
## can read nothing else about it. See Sigil.
@export var wants: int = 0

var _open_amount: float = 0.0
var _target: float = 0.0
var _shape: CollisionShape2D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = span
	_shape.shape = rect
	add_child(_shape)
	add_to_group("gate")
	Sigil.demand(switch_id, wants)
	Events.switch_activated.connect(_on_switch)

func _exit_tree() -> void:
	# A checkpoint throws every gate away and builds new ones. The answer has to
	# go with them, or a rebuilt stage keeps answering to the old one.
	Sigil.forget(switch_id)

func _on_switch(id: String) -> void:
	if id == switch_id:
		_target = 1.0
	elif id == switch_id + ":off":
		_target = 0.0

func _process(delta: float) -> void:
	_open_amount = move_toward(_open_amount, _target, delta * 2.2)
	_shape.set_deferred("disabled", _open_amount > 0.85)
	queue_redraw()

func reset_state() -> void:
	_open_amount = 0.0
	_target = 0.0
	if _shape != null:
		_shape.set_deferred("disabled", false)

func _draw() -> void:
	_draw_body()
	# What it is asking for, for the player who cannot reach it.
	if wants > 0 and Sigil.shown_to(Veil.GUARDIAN):
		var plate := Vector2(0.0, -span.y * 0.5 - 30.0)
		draw_circle(plate, 17.0, Color(0.09, 0.11, 0.15, 0.85))
		draw_arc(plate, 17.0, 0.0, TAU, 24, Color("8fd8ff"), 2.0, true)
		Sigil.draw_mark(self, wants, plate, 10.0, Color("8fd8ff"))

func _draw_body() -> void:
	var lift := _open_amount * span.y * 0.92
	var r := Rect2(-span.x * 0.5, -span.y * 0.5 - lift, span.x, span.y)
	if Balance.USE_TEXTURES and Art.tex("gate") != null:
		draw_rect(Rect2(-span.x * 0.5 - 5, -span.y * 0.5 - 8, span.x + 10, 8), Color("3a3f4a"))
		Art.draw_stretched(self, "gate", r)
		draw_rect(r, Color(0.16, 0.12, 0.08, 0.55), false, 2.5)
		return
	# Frame stays put so the gap is legible even when the gate is up.
	draw_rect(Rect2(-span.x * 0.5 - 4, -span.y * 0.5 - 6, span.x + 8, 6), Color("3a3f4a"))
	DrawUtil.rounded_rect(self, r, 5.0, Color("7a6a52"))
	for i in range(4):
		var y := r.position.y + 10.0 + float(i) * (r.size.y - 20.0) / 3.0
		draw_rect(Rect2(r.position.x + 4, y, r.size.x - 8, 5), Color("5d5040"))
	draw_rect(r, Color("453b2d"), false, 2.5)
