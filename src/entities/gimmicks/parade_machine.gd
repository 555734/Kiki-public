class_name ParadeMachine
extends Area2D
## Shoot the amber pivot to permanently turn a dangerous machine into an
## ally. Active switches use the existing reliable SWITCH and resync path.
## All jaw/hammer poses are pure Clock functions, including after migration.
var kind := "mouth"
var switch_id := "parade_mouth"
var active := false
var period := 4.0
var phase_offset := 0.0
var height := 360.0
var runner: Runner
var _weapon: Area2D
var _shape: CollisionShape2D
var _last_impact_cycle := -1

static func from_spec(spec: Dictionary, runner_: Runner) -> Node2D:
	var m := ParadeMachine.new()
	m.runner = runner_
	m.kind = String(spec.get("kind", "mouth"))
	m.switch_id = String(spec.get("id", "parade_mouth"))
	m.period = float(spec.get("period", 4.0))
	m.phase_offset = float(spec.get("phase", 0.0))
	m.height = float(spec.get("height", 360.0))
	return m

func _ready() -> void:
	add_to_group("shootable")
	add_to_group("switch")
	add_to_group("parade_machine")
	collision_layer = 64
	collision_mask = 0
	z_index = 7
	process_physics_priority = -50
	var target := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 29
	target.shape = circle
	target.position = target_offset()
	add_child(target)
	_weapon = Area2D.new()
	_weapon.add_to_group("instant_death")
	_weapon.collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_weapon.add_child(_shape)
	add_child(_weapon)
	Events.switch_activated.connect(_activate)
	sync_at(Clock.tick)

func target_offset() -> Vector2:
	return Vector2(0, -height * 0.71) if kind == "mouth" else Vector2.ZERO

func shot_position() -> Vector2:
	return global_position + target_offset()

func take_damage(_amount: int, _by: String = "snipe") -> void:
	if not active: Events.switch_activated.emit(switch_id)

func _activate(id: String) -> void:
	if id == switch_id: active = true
	elif id == switch_id + ":off": active = false

func state_at(at_tick: int) -> Dictionary:
	var beat := fposmod(Clock.seconds_at(at_tick, phase_offset), period)
	if kind == "mouth":
		var pose := 0 if beat < 0.65 or beat >= 2.1 else (1 if beat < 1.4 else 2)
		return {"pose": 1 if active else pose, "danger": not active and beat >= 1.4 and beat < 1.9,
			"angle": 0.0, "beat": beat}
	# Raise, telegraph, slam, then recoil. A stationary inactive hammer is
	# visibly parked above the road; it only swings after the guardian fires.
	var angle := -1.32
	if active:
		if beat >= 0.5 and beat < 0.85: angle = lerpf(-1.32, 0, pow((beat - 0.5) / 0.35, 3))
		elif beat >= 0.85 and beat < 1.2: angle = 0
		elif beat >= 1.2 and beat < 1.65: angle = lerpf(0, -1.32, (beat - 1.2) / 0.45)
	return {"pose": 0, "danger": active and beat >= 0.85 and beat < 1.2,
		"angle": angle, "beat": beat}

func impact_rect() -> Rect2:
	if kind == "mouth": return Rect2(-height * 0.21, -height * 0.3, height * 0.42, height * 0.3)
	return Rect2(-height * 0.30, height * 0.65, height * 0.60, height * 0.28)

func sync_at(at_tick: int) -> void:
	var state := state_at(at_tick)
	var rect := impact_rect()
	_shape.position = rect.get_center()
	(_shape.shape as RectangleShape2D).size = rect.size
	_weapon.collision_layer = Hazard.LAYER_HAZARD if state.danger else 0

func _physics_process(_delta: float) -> void:
	sync_at(Clock.tick)
	var state := state_at(Clock.tick)
	if Clock.is_host and state.danger:
		var rect := impact_rect()
		# An actor already inside the sleeping Area does not always get a new
		# area_entered signal when its layer changes. Test continuous contact
		# during the visible impact too, so waiting inside the jaws is lethal.
		if is_instance_valid(runner) and not runner.cleared:
			var body := Rect2(runner.global_position - global_position - Balance.RUNNER_SIZE * 0.5, Balance.RUNNER_SIZE)
			if rect.intersects(body): runner.die("parade")
		# Same visible contact rectangle as the runner's lethal sensor. A whole
		# row can be crushed by one swing, rather than disappearing cosmetically.
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is ParadeGremlin and rect.grow(16).has_point(e.global_position - global_position):
				e.take_damage(99, "parade")
		var cycle := floori(Clock.seconds(phase_offset) / period)
		if cycle != _last_impact_cycle:
			_last_impact_cycle = cycle
			Events.shot_blocked.emit(global_position + rect.get_center())
	var camera := get_viewport().get_camera_2d()
	if camera == null or absf(global_position.x - camera.global_position.x) < 1800: queue_redraw()

func _draw() -> void:
	var state := state_at(Clock.tick)
	if kind == "mouth":
		ParadeArt.mouth_on(self, int(state.pose), height)
	else:
		draw_set_transform(Vector2.ZERO, float(state.angle), Vector2.ONE)
		var ratio := height / 1433.0
		draw_texture_rect(ParadeArt.painting("hammer"), Rect2(-512 * ratio, -103 * ratio,
			1024 * ratio, 1536 * ratio), false)
		draw_set_transform(Vector2.ZERO)
		if active and state.beat >= 0.2 and state.beat < 0.85:
			draw_line(Vector2(-height * 0.31, height), Vector2(height * 0.31, height), Color("ffdc68"), 5)
	var target := target_offset()
	draw_arc(target, 31, 0, TAU, 32, Color("69ffff") if active else Color("ffcc54"), 3, true)
	for i in 4:
		var d := Vector2.from_angle(i * PI * 0.5)
		draw_line(target + d * 35, target + d * 44, Color("fff0ba"), 3, true)
