class_name SwitchBridge
extends StaticBody2D
## A hidden stepping stone that briefly becomes solid when its linked target is shot.

@export var span := Vector2(150.0, 26.0)
@export var switch_id := ""
@export var delay := 0.0

const RISE_TIME := 0.28
const WARN_TIME := 1.0

var _shape: CollisionShape2D
var _active := false
var _start_tick := -1
var _expires_at_tick := -1

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	z_index = 4
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = span
	_shape.shape = box
	_shape.one_way_collision = Stage.is_cave()
	_shape.disabled = true
	add_child(_shape)
	Events.switch_activated.connect(_on_switch)
	set_physics_process(false)

func _on_switch(id: String) -> void:
	if id == switch_id:
		if not _active:
			_start_tick = Clock.tick
		_active = true
		set_physics_process(true)
		# A second shot extends the timer without making a rider's platform blink.
		for node in get_tree().get_nodes_in_group("switch"):
			if node is ShootableSwitch and node.switch_id == switch_id and node.active:
				_expires_at_tick = Clock.tick + Clock.ticks_for(node.hold_time)
				break
	elif id == switch_id + ":off":
		_active = false
		_expires_at_tick = -1
		_shape.set_deferred("disabled", true)
		set_physics_process(false)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var solid := _active and Clock.seconds_at(Clock.tick - _start_tick) >= delay + RISE_TIME
	if _shape.disabled == solid:
		_shape.set_deferred("disabled", not solid)
	var camera := get_viewport().get_camera_2d()
	if camera == null or absf(global_position.x - camera.global_position.x) < 1100.0:
		queue_redraw()

func _draw() -> void:
	var progress := 0.0
	if _active:
		progress = clampf((Clock.seconds_at(Clock.tick - _start_tick) - delay) / RISE_TIME, 0.0, 1.0)
	var r := Rect2(-span * 0.5, span)
	var rim := Color("b8ada0") if Stage.is_cave() else Color("f0c886")
	var fill := Color("5d6870") if Stage.is_cave() else Color("a46c4e")
	if _active and _expires_at_tick >= 0 \
			and Clock.seconds_at(_expires_at_tick - Clock.tick) < WARN_TIME:
		rim = Color("dfaa7c")
	# The dashed outline remains visible while hidden; the shot has an obvious destination.
	if progress < 1.0:
		for i in maxi(1, int(span.x / 22.0)):
			var x := r.position.x + float(i) * 22.0
			draw_line(Vector2(x, r.position.y), Vector2(minf(x + 12.0, r.end.x), r.position.y),
				Color(rim, 0.45), 2.0)
	if progress <= 0.0:
		return
	var body := Rect2(r.position.x, r.position.y + (1.0 - progress) * 70.0,
		r.size.x, r.size.y)
	draw_rect(body, fill)
	draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 7.0), rim)
	for i in 3:
		var x := body.position.x + (float(i) + 0.5) * body.size.x / 3.0
		draw_line(Vector2(x - 8.0, body.position.y + 15.0),
			Vector2(x + 8.0, body.position.y + 15.0), Color(rim, 0.55), 2.0)
