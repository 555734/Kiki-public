class_name ParadeActor
extends Enemy
## The extra cast are mechanical actors, not reskins of one walker. Their
## useful transformations are state events, so a missed shot can be replayed.
const KINDS := ["drummer", "stilt", "balloon", "shadow", "mimic", "spider",
	"imp", "acrobat", "hound", "twins", "manager"]
var kind := "drummer"
var runner: Runner
var bounds := Vector2.ZERO
var direction := 1
var active := false
var placed_tick := 0
var switch_id := ""
var _last_cue := -1
var _home := Vector2.ZERO
var _platform: AnimatableBody2D
var _target: Area2D
var _body: CollisionShape2D
var _awake := false
var _impulse_until := 0
var _impulse_x := 0.0

func parade_impulse(v: Vector2, ticks: int = 45) -> void:
	velocity = v
	_impulse_x = v.x
	_impulse_until = Clock.tick + ticks

static func from_spec(spec: Dictionary, who: Runner) -> ParadeActor:
	var a := ParadeActor.new()
	a.kind = String(spec.get("kind", "drummer"))
	a.bounds = spec.get("bounds", Vector2(0, 100))
	a.direction = int(spec.get("dir", 1))
	a.runner = who
	return a

func _build_body() -> void:
	_home = global_position
	switch_id = "parade_cast_%d" % net_id
	add_to_group("switch")
	add_to_group("parade_actor")
	z_index = 6
	var size := Vector2(46, 64)
	if kind == "stilt": size = Vector2(35, 170)
	if kind == "manager": size = Vector2(100, 130)
	if kind == "hound": size = Vector2(80, 40)
	_add_box(size)
	_body = get_child(get_child_count() - 1) as CollisionShape2D
	_platform = AnimatableBody2D.new()
	_platform.collision_mask = 0
	_platform.collision_layer = 0
	_platform.sync_to_physics = false
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(150, 18) if kind == "stilt" else Vector2(70, 24)
	s.shape = r
	s.one_way_collision = true
	_platform.add_child(s)
	add_child(_platform)
	_target = Area2D.new()
	_target.set_script(preload("res://src/entities/enemies/parade_target.gd"))
	_target.owner_actor = self
	_target.collision_layer = 64
	_target.collision_mask = 0
	var hit := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	hit.shape = circle
	_target.add_child(hit)
	add_child(_target)
	_target.position = target_offset()
	if kind == "manager": hp = 3
	Events.switch_activated.connect(_receive)
	refresh_pose()

func target_offset() -> Vector2:
	return Vector2(0, -35) if kind in ["balloon", "acrobat"] else Vector2.ZERO

func shot_position() -> Vector2: return global_position + target_offset()
func replay_id() -> String: return "%s|%d|%d|0" % [switch_id, int(active), placed_tick]

func set_active(value: bool) -> void:
	if value == active: return
	Events.switch_activated.emit("%s|%d|%d|0" % [switch_id, int(value), Clock.tick])

func _receive(id: String) -> void:
	var row := id.split("|")
	if row.size() != 4 or row[0] != switch_id: return
	active = row[1] == "1"
	placed_tick = int(row[2])
	refresh_pose()

func take_damage(amount: int, by: String = "snipe") -> void:
	if by == "snipe" and kind in ["stilt", "balloon", "acrobat", "twins"] and not active:
		set_active(true)
		return
	if kind == "shadow" and active and by == "snipe": return
	super.take_damage(amount, by)

func refresh_pose() -> void:
	var solid := active and kind in ["stilt", "shadow"]
	collision_layer = 0 if solid else (1 if kind == "mimic" and not active else 4)
	_platform.collision_layer = 1 if solid else 0
	_platform.position = Vector2(0, 5)
	_platform.rotation = -0.18 if kind == "stilt" else 0
	_body.disabled = solid

func _physics_process(delta: float) -> void:
	if not Clock.is_host: return
	if not is_instance_valid(runner): return
	if absf(runner.global_position.x - _home.x) > 1100: return
	_awake = true
	if Clock.tick < _impulse_until:
		velocity.x = _impulse_x
		velocity.y += Balance.RUNNER_GRAVITY * delta
		move_and_slide()
		return
	var t := Clock.seconds_at(Clock.tick, net_id * 0.08)
	var beat := fposmod(t, 4.0)
	var cue := int(t / 4.0)
	var move := 65.0 * direction
	if active and kind in ["stilt", "shadow"]:
		velocity = Vector2.ZERO
		if kind == "stilt" and Clock.tick - placed_tick > 300: set_active(false)
		return
	match kind:
		"drummer":
			move = 45 * direction
			if beat > 0.7 and _last_cue != cue:
				_last_cue = cue
				for e in get_tree().get_nodes_in_group("enemy"):
					if e is ParadeGremlin and e.global_position.distance_to(global_position) < 320: e.velocity.y = -670
		"mimic":
			if not active:
				move = 0
				if runner.global_position.distance_to(global_position) < 165: set_active(true)
			else: move = direction * 175
		"imp":
			move = 0
			if beat > 1.0 and _last_cue != cue:
				_last_cue = cue
				var p := ParadeBall.new()
				p.direction = direction
				p.birth_tick = int((cue * 4.0 + 1.0 - net_id * 0.08) * 60) + 1
				p.runner = runner
				p.position = global_position + Vector2(direction * 50, -5)
				get_parent().add_child(p)
		"spider":
			global_position = _home + Vector2(sin(t) * 90, sin(t * 0.6) * 45)
			if beat > 0.75 and _last_cue != cue:
				_last_cue = cue
				for d in get_tree().get_nodes_in_group("parade_device"):
					if d.kind in ["curtain", "trapdoors"] and d.global_position.distance_to(global_position) < 800: d.set_active(not d.active)
			return
		"balloon":
			if not active:
				global_position = _home + Vector2(sin(t * 0.7) * 70, sin(t) * 20)
				return
			move = 0
		"acrobat":
			global_position = _home + Vector2(sin(t * 1.1) * (150 if active else -150), cos(t * 1.1) * 75)
			return
		"hound":
			move = direction * 65 if beat < 0.9 else direction * 470
			if beat < 0.9: direction = 1 if runner.global_position.x > global_position.x else -1
		"twins":
			move = 155 * direction if active else cos(t * 1.5) * 135
		"manager":
			move = 0
			if beat > 1.2 and _last_cue != cue:
				_last_cue = cue
				for d in get_tree().get_nodes_in_group("parade_device"):
					if d.kind in ["wheel", "moon", "fireworks"] and absf(d.global_position.x - global_position.x) < 900: d.set_active(not d.active)
	velocity.x = move
	velocity.y = minf(1100, velocity.y + Balance.RUNNER_GRAVITY * delta)
	move_and_slide()
	if global_position.x < bounds.x: direction = 1
	if global_position.x > bounds.y: direction = -1
	if global_position.y > 1100: take_damage(99, "pit")

func _process(_delta: float) -> void:
	# Guest reconstructs the same clock-cued ball. Forces stay host-only.
	if not Clock.is_host and kind == "imp" and is_instance_valid(runner) and absf(runner.global_position.x - _home.x) < 1100:
		var t := Clock.seconds_at(Clock.tick, net_id * 0.08)
		if fposmod(t,4.0) > 1.0 and _last_cue != int(t / 4.0):
			_last_cue = int(t / 4.0)
			var ball := ParadeBall.new()
			ball.direction = direction
			ball.birth_tick = int((_last_cue * 4.0 + 1.0 - net_id * 0.08) * 60) + 1
			ball.runner = runner
			ball.position = global_position + Vector2(direction * 50,-5)
			get_parent().add_child(ball)
	if is_instance_valid(runner) and absf(runner.global_position.x - global_position.x) < 1600: queue_redraw()

func _draw() -> void:
	if kind == "mimic" and not active:
		ParadeArt.crate_on(self,Rect2(-35,-32,70,62))
		return
	if kind == "shadow" and active:
		ParadeArt.crate_on(self,Rect2(-35,-6,70,55),Color("8796ae"))
		ParadeArt.floor_on(self,Rect2(-35,-7,70,18))
		return
	var tall := 100.0
	match kind:
		"stilt": tall = 210
		"balloon": tall = 150
		"shadow": tall = 145
		"spider": tall = 135
		"acrobat": tall = 170
		"hound": tall = 95
		"twins": tall = 155
		"manager": tall = 210
	var beat := fposmod(Clock.seconds_at(Clock.tick, net_id * 0.08), 4)
	var angle := -PI * 0.38 if active and kind == "stilt" else sin(Clock.seconds_at(Clock.tick) * 8 + net_id) * 0.025
	if kind == "manager" and beat < 1.2: angle = -0.08
	draw_set_transform(Vector2.ZERO, angle, Vector2(direction, 1))
	ParadeArt.actor_on(self, KINDS.find(kind) + 1, tall, Color("8098b5") if active and kind == "shadow" else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if _platform.collision_layer == 1:
		ParadeArt.floor_on(self, Rect2(-75 if kind == "stilt" else -35, -6, 150 if kind == "stilt" else 70, 18))
	if kind in ["drummer", "imp", "hound", "manager"] and beat < 1.0:
		draw_arc(Vector2(0, -tall), 13, 0, TAU * beat, 18, Color("ffc56c"), 4, true)
	if kind in ["stilt", "balloon", "acrobat", "twins"]:
		draw_arc(target_offset(), 17, 0, TAU, 20, Color("39d4df") if active else Color("ffc56c"), 3)
