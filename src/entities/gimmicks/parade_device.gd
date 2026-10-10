class_name ParadeDevice
extends Area2D
## Shootable theatre machinery. Only the host applies forces; clock poses and
## explicit state events are replayable by the guardian and after migration.
const KINDS := ["mask", "curtain", "turntable", "accordion", "spot", "wheel",
	"scenery", "trapdoors", "cannon", "conveyor", "vent", "bell", "mirror",
	"moon", "balcony", "magnet", "fireworks", "breakaway"]
const GOLD := Color("eeb85c")
const TEAL := Color("36cbd0")
var kind := "mask"
var switch_id := ""
var active := false
var placed_tick := 0
var charge := 0.0
var runner: Runner
var span := Vector2(260, 24)
var target := Vector2(0, -110)
var _decks: Array[AnimatableBody2D] = []
var _home := Vector2.ZERO
var _last_cue := -1
var _spent: Dictionary = {}
var _weight := 0.0
var _angle := 0.0
var _cooldowns: Dictionary = {}

static func from_spec(spec: Dictionary, who: Runner) -> Node2D:
	var d := ParadeDevice.new()
	d.kind = String(spec.get("kind", "mask"))
	d.switch_id = String(spec.get("id", ""))
	d.span = spec.get("span", Vector2(260, 24))
	d.target = spec.get("target", Vector2(0, -110))
	d.runner = who
	return d

func _ready() -> void:
	_home = global_position
	add_to_group("switch")
	add_to_group("shootable")
	add_to_group("parade_device")
	collision_layer = 64
	collision_mask = 0
	z_index = 4
	process_physics_priority = 10
	var s := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 22
	s.shape = c
	s.position = target
	add_child(s)
	Events.switch_activated.connect(_receive)
	var count := 6 if kind == "wheel" else (4 if kind in ["trapdoors", "moon", "breakaway"] else 1)
	if kind in ["spot", "vent", "bell", "mirror", "magnet", "fireworks"]: count = 0
	for i in count:
		var b := AnimatableBody2D.new()
		b.collision_layer = 1
		b.collision_mask = 0
		b.sync_to_physics = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(116, 20) if kind == "wheel" else (Vector2(span.x / count, span.y) if count > 1 else span)
		shape.shape = rect
		shape.one_way_collision = kind != "breakaway"
		b.add_child(shape)
		add_child(b)
		_decks.append(b)
	pose_at(Clock.tick)

func shot_position() -> Vector2: return global_position + target

func replay_id() -> String:
	return "%s|%d|%d|%.2f" % [switch_id, int(active), placed_tick, charge]

func set_active(value: bool) -> void:
	if active == value: return
	Events.switch_activated.emit("%s|%d|%d|%.2f" % [switch_id, int(value), Clock.tick, charge])

func _receive(id: String) -> void:
	var fields := id.split("|")
	if fields.size() != 4 or fields[0] != switch_id: return
	active = fields[1] == "1"
	placed_tick = int(fields[2])
	charge = float(fields[3])
	_spent.clear()
	pose_at(Clock.tick)

func take_damage(_amount: int, _by: String = "snipe") -> void:
	if not Clock.is_host: return
	var passengers: Array[Node2D] = []
	if kind == "accordion" and not active:
		charge = maxf(1.0, _weight)
		for a in actors():
			if carries(a.global_position,span.x,95): passengers.append(a)
	if kind == "wheel" and not active: charge = _angle
	# A broken flat is a discovered route, not a resetting door.
	if kind == "breakaway" and active: return
	set_active(not active)
	# Capture riders on the compressed deck BEFORE it unfolds. Querying the
	# moved deck afterwards would leave the very passengers who loaded it behind.
	for a in passengers:
		_kick(a,Vector2(480,-650-minf(charge,6)*65))
		_spent[a.net_id + 1 if a is Enemy else 0] = true

func actors() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if is_instance_valid(runner) and runner.state != Runner.State.DEAD: out.append(runner)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.hp > 0 and not e.is_queued_for_deletion(): out.append(e)
	return out

func carries(at: Vector2, width: float = -1.0, height: float = 70.0) -> bool:
	var p := at - global_position
	if kind == "accordion" and not _decks.is_empty(): p.y -= _decks[0].position.y
	return absf(p.x) < (span.x if width < 0 else width) * 0.5 and p.y > -height and p.y < 35

func _physics_process(delta: float) -> void:
	var near := not is_instance_valid(runner) or absf(runner.global_position.x - global_position.x) < 1600
	_weight = 0
	var crowd := actors()
	for a in crowd:
		if not a is Enemy: continue
		if kind == "wheel":
			for b in _decks:
				if a.global_position.distance_to(b.global_position + Vector2(0,-25)) < 70: _weight += -1 if b.position.x < 0 else 1
		elif carries(a.global_position): _weight += 2 if a is ParadeActor and a.active else 1
	if Clock.is_host and near: apply_effects(crowd, delta)
	pose_at(Clock.tick)
	if near: queue_redraw()

func pose_at(tick: int) -> void:
	var t := Clock.seconds_at(tick)
	var since := maxf(0, float(tick - placed_tick) / 60.0)
	_angle = t * 0.25 + clampf(_weight, -4, 4) * 0.055 * sin(t * 0.5) if not active else charge
	for i in _decks.size():
		var b := _decks[i]
		var at := Vector2.ZERO
		var enabled := true
		b.rotation = 0
		match kind:
			"mask": enabled = active
			"curtain": at.y = -220 * (0.5 - 0.5 * cos(t * 1.1 + (PI if active else 0)))
			"turntable": at.y = -155 if active else 0
			"accordion": at.y = minf(40, _weight * 7) if not active else -minf(130, charge * 20) * exp(-since * 3)
			"scenery": at = Vector2((150 if active else -80) + sin(t * 0.55) * 35, -130)
			"trapdoors":
				at.x = (i - 1.5) * span.x / 4
				# An enemy starts a travelling opening, not four identical blink floors.
				enabled = not active or posmod(int(since * 3), 6) != i
			"cannon": at = Vector2(-10, -15)
			"conveyor": b.constant_linear_velocity = Vector2(-185 if active else 185, 0)
			"balcony":
				b.rotation = -0.28 if active else 0.28
			"wheel": at = Vector2(cos(_angle + i * TAU / 6), sin(_angle + i * TAU / 6)) * 225
			"moon":
				at = Vector2((i - 1.5) * span.x / 4, (-40 + absf(i - 1.5) * 22) - (0 if active else 185))
			"breakaway":
				at = Vector2(i * 65, -i * 48) if active else Vector2(0, -60 - i * 60)
		b.position = at
		b.collision_layer = 1 if enabled else 0

func _kick(a: Node2D, v: Vector2) -> void:
	if a is Runner: a.launch(v)
	elif a.has_method("parade_impulse"): a.parade_impulse(v)
	elif a is Enemy: a.velocity = v

func apply_effects(crowd: Array[Node2D], delta: float) -> void:
	var t := Clock.seconds_at(Clock.tick)
	var cycle := int(t / 4.8)
	for a in crowd:
		var p := a.global_position - global_position
		# Stable across machines and rebuilt worlds; instance IDs are not.
		var id: int = a.net_id + 1 if a is Enemy else 0
		match kind:
			"mask":
				if not active and carries(a.global_position, span.x * 0.7) and fposmod(t, 4.0) > 1.4 and fposmod(t, 4.0) < 1.85:
					if a is Runner: a.die("parade")
					else: a.take_damage(99, "parade")
			"turntable":
				if a is Enemy and carries(a.global_position) and not _spent.has(id):
					_kick(a, Vector2(240, -680) if active else Vector2(-230, -90))
					_spent[id] = true
			"trapdoors":
				if a is Enemy and carries(a.global_position) and not active: set_active(true)
			"accordion":
				if active and Clock.tick - placed_tick < 30 and carries(a.global_position, span.x, 95) and not _spent.has(id):
					_kick(a, Vector2(480, -650 - minf(charge, 6) * 65))
					_spent[id] = true
			"cannon":
				if carries(a.global_position, 120) and Clock.tick > int(_cooldowns.get(id, -1)):
					_kick(a, Vector2(460, -880) if active else Vector2(590, -380))
					_cooldowns[id] = Clock.tick + 70
			"vent":
				if p.x > -70 and p.x < 70 and p.y < 10 and p.y > -350:
					var side := active
					for wall in get_tree().get_nodes_in_group("hologram"):
						if wall is Hologram and wall.kind == Hologram.Kind.WALL and wall.global_position.distance_to(global_position + Vector2(0, -140)) < 150: side = true
					if a is Runner:
						a.end_player_jump_control()
						a.velocity.y = move_toward(a.velocity.y, -510, Balance.UPDRAFT_ACCEL * delta)
						a.velocity.x = move_toward(a.velocity.x, 300 if side else 80, 700 * delta)
					elif a.has_method("parade_impulse"): a.parade_impulse(Vector2(300 if side else 80,-510),2)
			"bell":
				var angle := sin(t * 1.6 + (PI if active else 0)) * 0.95
				var bell := Vector2(sin(angle), cos(angle)) * 270
				if p.distance_to(bell) < 72 and Clock.tick > int(_cooldowns.get(id, -1)):
					_kick(a, Vector2(signf(angle) * 480, -390))
					_cooldowns[id] = Clock.tick + 55
			"spot":
				if a is ParadeActor and a.kind == "shadow" and absf(p.x) < 280: a.set_active(not active)
			"mirror":
				if active and a is Enemy and absf(p.x) < 550 and "direction" in a: a.direction = 1 if p.x < 240 else -1
			"magnet":
				if a is Enemy and absf(p.x) < 95 and p.y > 0 and p.y < 410 and not active:
					if a.has_method("parade_impulse"): a.parade_impulse(Vector2(0,-190),2)
				elif a is Enemy and active and absf(p.x) < 170 and p.y > -30 and p.y < 180:
					_kick(a,Vector2(260,260))
			"balcony":
				if not active and a is Enemy and p.x > 30 and carries(a.global_position): set_active(true)
			"breakaway":
				if not active and a is ParadeActor and a.kind == "hound" and absf(p.x) < 100 and absf(a.velocity.x) > 350: set_active(true)
			"fireworks":
				var beat := fposmod(t + (2.4 if active else 0), 4.8)
				if beat > 2.4 and beat < 3.6 and absf(p.x - (int((beat - 2.4) * 2.5) - 1) * 95) < 55 and p.y > -240 and p.y < 30 and int(_cooldowns.get(id, -1)) != cycle:
					_kick(a, Vector2(330, -630))
					_cooldowns[id] = cycle
	if kind == "accordion" and active and Clock.tick - placed_tick > 65: set_active(false)

func _draw() -> void:
	var t := Clock.seconds_at(Clock.tick)
	if kind == "mask": ParadeArt.mouth_on(self, 1 if active else (2 if fposmod(t, 4) > 1.4 and fposmod(t, 4) < 1.85 else 0), 310)
	elif kind not in ["wheel", "bell"] and not (kind == "breakaway" and active): ParadeArt.device_on(self, KINDS.find(kind), Rect2(-140, -230, 280, 230))
	for b in _decks:
		if b.collision_layer == 0: continue
		var size: Vector2 = (b.get_child(0).shape as RectangleShape2D).size
		draw_set_transform(b.position, b.rotation)
		ParadeArt.floor_on(self, Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y))
		draw_set_transform(Vector2.ZERO)
	match kind:
		"wheel":
			draw_arc(Vector2.ZERO, 225, 0, TAU, 80, GOLD, 9, true)
			draw_arc(Vector2.ZERO, 208, 0, TAU, 80, Color("6a5640"), 6, true)
			draw_line(Vector2(0,-8), Vector2(-120,255), GOLD, 16)
			draw_line(Vector2(0,-8), Vector2(120,255), GOLD, 16)
			draw_circle(Vector2.ZERO, 35, Color("9b6437"))
			draw_arc(Vector2.ZERO, 30, 0, TAU, 30, GOLD, 5)
			for b in _decks:
				draw_line(Vector2.ZERO, b.position, GOLD, 6, true)
				ParadeArt.cabin_on(self,b.position)
		"curtain":
			var y := _decks[0].position.y
			draw_line(Vector2(-110, -290), Vector2(-110, y), GOLD, 4)
			draw_line(Vector2(110, -290), Vector2(110, -220 - y), GOLD, 4)
			draw_rect(Rect2(90, -220 - y, 45, 65), Color("bd8f4f"))
		"bell":
			var a := sin(t * 1.6 + (PI if active else 0)) * 0.95
			var end := Vector2(sin(a), cos(a)) * 270
			draw_line(Vector2.ZERO, end, GOLD, 9)
			ParadeArt.bell_on(self,end)
		"vent":
			for i in 12:
				var y := -fposmod(t * 155 + i * 29, 350)
				draw_line(Vector2(-32, y), Vector2(0, y - 18), TEAL, 3)
				draw_line(Vector2(0, y - 18), Vector2(32, y), TEAL, 3)
		"spot":
			var light := PackedVector2Array([Vector2.ZERO, Vector2(90 if active else -180, 260), Vector2(350 if active else 80, 260)])
			draw_colored_polygon(light, Color(1, 0.88, 0.54, 0.22))
		"mirror":
			if active and is_instance_valid(runner):
				draw_set_transform(Vector2(240, 0), 0, Vector2(0.9, 0.9))
				# Actual Lira sprite projected flat, never an invented protagonist.
				Art.draw_sprite(self, "runner_idle", Vector2.ZERO, 64, false, Color(0.12, 0.2, 0.35, 0.6))
				draw_set_transform(Vector2.ZERO)
		"magnet": draw_line(Vector2.ZERO, Vector2(0, 120 + sin(t) * 35), GOLD, 5)
		"fireworks":
			var beat := fposmod(t + (2.4 if active else 0), 4.8)
			for i in 3:
				var at := Vector2((i - 1) * 95, -20)
				draw_circle(at, 8, TEAL if beat < 2.4 else GOLD)
				if beat > 2.4 + i * 0.4 and beat < 2.8 + i * 0.4:
					for j in 8: draw_line(at, at + Vector2(cos(j * TAU / 8), sin(j * TAU / 8)) * 95, GOLD, 3)
	if kind in ["accordion", "balcony"]:
		for i in mini(6, int(_weight)): draw_circle(Vector2(-40 + i * 16, 38), 5, GOLD)
	draw_circle(target, 22, Color("342941"))
	draw_arc(target, 18, 0, TAU, 24, TEAL if active else GOLD, 4, true)
	draw_line(target + Vector2(-8, 0), target + Vector2(8, 0), Color.WHITE, 2)
	draw_line(target + Vector2(0, -8), target + Vector2(0, 8), Color.WHITE, 2)
