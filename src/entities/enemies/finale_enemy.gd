class_name FinaleEnemy
extends Enemy
## 1-10's cast. Each area gets its own behaviour, not one patrol reskinned:
##
##   burrbug      grassland sprout: walks up to meet the runner, hops when
##                jumped over (it tries to catch you in the air).
##   spark        storm wisp: hovers over the bridge, lunges when close.
##   magma_slime  hops platform to platform on a fixed beat.
##   fire_bat     figure-eights over the lava lake.
##   rail_gunner  rides a train roof and fires back down the train.
##   wax_wisp     hive swarm: follows the runner, keeping apart.
##   skull_drone  rotor skull: drifts, winds up, lunges, recovers.
##   brass_drone  title-run pursuer: shadows the runner from behind and above,
##                swooping every few seconds.
##
## Every one dies to a guardian shot. Contact costs the runner a heart.

const KINDS := ["burrbug", "spark", "magma_slime", "fire_bat", "rail_gunner",
	"wax_wisp", "skull_drone", "brass_drone"]
var kind := "burrbug"
var data: Dictionary = {}
var runner: Runner = null
var _home := Vector2.ZERO
var _dir := -1
var _lunge_t := -1.0
var _lunge_from := Vector2.ZERO
var _lunge_to := Vector2.ZERO
var _fire_cd := 1.5
var _hop_cd := 0.0
var _flash := 0.0

static func from_spec(spec: Dictionary, who: Runner) -> FinaleEnemy:
	var e := FinaleEnemy.new()
	e.kind = String(spec.get("kind", "burrbug"))
	e.data = spec.get("data", {})
	e.runner = who
	return e

func _build_body() -> void:
	_home = global_position
	add_to_group("finale_enemy")
	z_index = 6
	match kind:
		"burrbug":
			_add_box(Vector2(40, 42))
		"rail_gunner":
			hp = 2
			_add_box(Vector2(48, 56))
			collision_mask = 0
		"magma_slime":
			_add_box(Vector2(56, 40))
			collision_mask = 0
		_:
			_add_box(Vector2(50, 46))
			collision_mask = 0

func _near() -> bool:
	return is_instance_valid(runner) and (runner.global_position - global_position).length() < 1400.0

func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if not _near() and kind != "rail_gunner":
		return
	match kind:
		"burrbug": _burrbug(delta)
		"spark": _hover_lunge(delta, 260.0, 380.0)
		"magma_slime": _slime()
		"fire_bat": _bat()
		"rail_gunner": _gunner(delta)
		"wax_wisp": _wisp(delta)
		"skull_drone": _hover_lunge(delta, 300.0, 430.0)
		"brass_drone": _pursue(delta)
	queue_redraw()

func _t() -> float:
	return Clock.seconds_at(Clock.tick, float(net_id) * 0.37)

func _burrbug(delta: float) -> void:
	var bounds: Vector2 = data.get("bounds", Vector2(_home.x - 200, _home.x + 200))
	var dx := runner.global_position.x - global_position.x
	var close := absf(dx) < 520.0 and absf(runner.global_position.y - global_position.y) < 220.0
	if close:
		_dir = 1 if dx > 0 else -1
	elif global_position.x <= bounds.x + 4:
		_dir = 1
	elif global_position.x >= bounds.y - 4:
		_dir = -1
	# Jumped over? It skids, spins round and gives chase -- with a startled
	# little hop once the runner is safely past.
	_hop_cd = maxf(0.0, _hop_cd - delta)
	var overhead := absf(dx) < 60.0 and runner.global_position.y < global_position.y - 60.0
	if overhead and _hop_cd <= 0.0:
		_hop_cd = 0.9
	var skid := _hop_cd > 0.55
	velocity.x = 0.0 if skid else float(_dir) * (95.0 if close else 55.0)
	velocity.y = minf(velocity.y + 2200.0 * delta, 900.0)
	if is_on_floor() and _hop_cd > 0.0 and _hop_cd < 0.5 and absf(dx) > 90.0:
		velocity.y = -260.0
		_hop_cd = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, bounds.x, bounds.y)

func _hover_lunge(delta: float, trigger: float, speed: float) -> void:
	var amp: Vector2 = data.get("amp", Vector2(60, 40))
	var t := _t()
	var drift := _home + Vector2(sin(t * 1.3) * amp.x, sin(t * 2.1) * amp.y)
	if _lunge_t < 0.0:
		global_position = global_position.lerp(drift, minf(1.0, delta * 4.0))
		if Clock.is_host and runner.global_position.distance_to(global_position) < trigger:
			_lunge_t = 0.0
			_lunge_from = global_position
			_lunge_to = global_position + (runner.global_position - global_position).normalized() * speed * 0.55
	else:
		_lunge_t += delta
		if _lunge_t < 0.45:
			global_position = _lunge_from + Vector2(sin(_lunge_t * 60.0), 0) * 3.0
		elif _lunge_t < 1.0:
			var k := (_lunge_t - 0.45) / 0.55
			global_position = _lunge_from.lerp(_lunge_to, 1.0 - (1.0 - k) * (1.0 - k))
		elif _lunge_t < 2.4:
			global_position = global_position.lerp(drift, minf(1.0, delta * 2.0))
		else:
			_lunge_t = -1.0

func _slime() -> void:
	var hop: Vector2 = data.get("hop", Vector2(200, 0))
	var period := 2.2
	var b := fposmod(_t(), period * 2.0)
	var leg := 0 if b < period else 1
	var k := clampf((fposmod(b, period) - 1.4) / 0.8, 0.0, 1.0)
	var from := _home if leg == 0 else _home + hop
	var to := _home + hop if leg == 0 else _home
	global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 170.0)

func _bat() -> void:
	var amp: Vector2 = data.get("amp", Vector2(220, 60))
	var t := _t()
	global_position = _home + Vector2(sin(t * 0.8) * amp.x, sin(t * 1.6) * amp.y)

func _gunner(delta: float) -> void:
	var line: Node = null
	for node in get_tree().get_nodes_in_group("finale_rail"):
		line = node
	if line == null:
		return
	var p: Vector2 = line.roof_point(int(data.get("train", 0)), int(data.get("car", 0)))
	if p.x == INF:
		visible = false
		collision_layer = 0
		global_position = _home
		return
	visible = true
	collision_layer = LAYER_ENEMY
	global_position = p + Vector2(0, -28)
	_fire_cd -= delta
	if not Clock.is_host or not is_instance_valid(runner):
		return
	var dx := runner.global_position.x - global_position.x
	if _fire_cd <= 0.0 and dx < -60.0 and dx > -900.0 and absf(runner.global_position.y - global_position.y) < 200.0:
		_fire_cd = 2.6
		_flash = 0.25
		var shot := preload("res://src/entities/enemies/projectile.gd").new()
		shot.direction = Vector2.LEFT
		shot.global_position = global_position + Vector2(-34, -6)
		get_parent().add_child(shot)
		Audio.play("shot", -5.0, 0.4, 0.8)

func _wisp(delta: float) -> void:
	var target := _home + Vector2(sin(_t() * 1.1) * 40.0, cos(_t() * 1.7) * 30.0)
	if runner.global_position.distance_to(global_position) < 560.0:
		target = runner.global_position + Vector2(sin(_t() * 2.0 + net_id) * 90.0, -60.0 + cos(_t() * 1.6) * 50.0)
	var step := (target - global_position).limit_length(135.0 * delta)
	# Keep the swarm apart so it reads as several insects, not one blob.
	for other in get_tree().get_nodes_in_group("finale_enemy"):
		if other != self and other is FinaleEnemy and other.kind == kind:
			var away: Vector2 = global_position - other.global_position
			if away.length() < 70.0 and away.length() > 0.1:
				step += away.normalized() * 60.0 * delta
	global_position += step

func _pursue(delta: float) -> void:
	var amp: Vector2 = data.get("amp", Vector2(60, 40))
	var t := _t()
	var dx := runner.global_position.x - global_position.x
	if absf(dx) > 700.0 and _lunge_t < 0.0:
		global_position = global_position.lerp(_home + Vector2(sin(t) * amp.x, sin(t * 1.7) * amp.y), minf(1.0, delta * 2.0))
		return
	# Shadow from behind and above; every 3.2s, a fast dive through the runner.
	var swoop := fposmod(t, 3.2)
	var target := runner.global_position + Vector2(-170.0, -150.0 + sin(t * 2.0) * 20.0)
	var speed := 340.0
	if swoop > 2.3 and swoop < 2.95:
		target = runner.global_position + Vector2(10.0, -8.0)
		speed = 640.0
	global_position += (target - global_position).limit_length(speed * delta)

func _draw() -> void:
	var t := Clock.seconds_at(Clock.tick)
	var face := -1.0 if is_instance_valid(runner) and runner.global_position.x < global_position.x else 1.0
	match kind:
		"burrbug":
			var frame := "seed_%d" % (int(t * 8.0) % 3)
			if not is_on_floor():
				frame = "seed_hurt"
			FinaleArt.sprite(self, frame, Vector2(0, 22), 62.0, _dir > 0)
		"spark":
			var key := "spark_attack" if _lunge_t >= 0.0 and _lunge_t < 1.0 else "spark_idle"
			FinaleArt.centred(self, key, Vector2.ZERO, 92.0 if key == "spark_attack" else 66.0, 0.0, Color.WHITE, face < 0)
			for k in 3:
				var a := t * 9.0 + k * 2.1
				draw_line(Vector2(cos(a), sin(a)) * 24.0, Vector2(cos(a + 0.5), sin(a + 0.5)) * 40.0, Color(0.7, 0.95, 1.0, 0.8), 2.0)
		"magma_slime":
			var squash := 1.0 + 0.12 * sin(t * 7.0)
			draw_set_transform(Vector2(0, 20), 0.0, Vector2(squash, 2.0 - squash))
			FinaleArt.sprite(self, "magma_slime", Vector2.ZERO, 50.0)
			draw_set_transform(Vector2.ZERO)
		"fire_bat":
			var flap := 1.0 + 0.25 * sin(t * 14.0)
			FinaleArt.centred(self, "fire_bat", Vector2.ZERO, 96.0 * flap, 0.0, Color.WHITE, face < 0)
		"rail_gunner":
			FinaleArt.sprite(self, "turret_fire" if _flash > 0.0 else "turret_idle", Vector2(0, 30), 70.0, true)
		"wax_wisp":
			var key := "wax_wisp_attack" if is_instance_valid(runner) and runner.global_position.distance_to(global_position) < 200.0 else "wax_wisp_idle"
			FinaleArt.centred(self, key, Vector2.ZERO, 80.0 if key == "wax_wisp_attack" else 56.0, 0.0, Color.WHITE, face < 0)
			# Wings.
			var flap := absf(sin(t * 30.0 + net_id))
			draw_circle(Vector2(-6, -22 - flap * 6), 11.0, Color(1, 1, 1, 0.45))
			draw_circle(Vector2(8, -22 - flap * 6), 11.0, Color(1, 1, 1, 0.45))
		"skull_drone", "brass_drone":
			var winding := _lunge_t >= 0.0 and _lunge_t < 0.45
			var tint := Color(1.0, 0.6, 0.6) if winding and int(t * 20.0) % 2 == 0 else Color.WHITE
			FinaleArt.centred(self, kind, Vector2(0, 4), 68.0, sin(t * 3.0) * 0.08, tint)
			var spin := t * 40.0
			for k in 2:
				var a := spin + k * PI
				var tip := Vector2(cos(a) * 46.0, -36.0 + sin(a) * 4.0)
				draw_line(Vector2(0, -36), tip, Color("4a4f5c"), 5.0)
			draw_line(Vector2(-48, -36), Vector2(48, -36), Color(0.8, 0.85, 0.95, 0.3), 3.0)
