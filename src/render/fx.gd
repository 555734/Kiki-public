class_name Fx
extends Node2D
## One-shot particle bursts, spawned from the global event bus.
##
## Everything here is feedback for a moment the design doc names out loud: the
## puff when the runner lands, the sparks when the guardian's shot connects, the
## flare when a platform materialises under someone mid-jump. Chapter 1 wants
## "that just saved me" to be legible without anyone explaining it, and a hit
## that produces no debris does not read as a hit.
##
## CPUParticles2D rather than GPU particles: a handful of short bursts costs
## nothing on the CPU, and it behaves identically on every mobile driver.

const DUST := Color(0.86, 0.76, 0.58)
const SPARK := Color(1.0, 0.88, 0.55)

var _runner: Runner = null
var _run_dust: CPUParticles2D = null
var _was_airborne: bool = false
var _live_bursts: int = 0

func _ready() -> void:
	z_index = 9
	Events.runner_spawned.connect(_on_runner_spawned)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.shot_fired.connect(_on_shot_fired)
	Events.hologram_spawned.connect(_on_hologram_spawned)
	Events.runner_died.connect(_on_runner_died)
	Events.runner_warped.connect(_on_runner_warped)
	Events.coin_collected.connect(func(at: Vector2) -> void: _burst(at, "spark", 0.7))
	Events.enemy_flicked.connect(_on_enemy_flicked)
	Events.hand_swiped.connect(_on_hand_swiped)
	Events.runner_slung.connect(func(at: Vector2, v: Vector2) -> void:
		_burst(at, "dust", 2.4)
		_ring(at, Balance.C_HOLO, 14.0, 90.0, 0.32, 7.0)
		var foot := at + Vector2(0, Balance.RUNNER_SIZE.y * 0.5)
		_blast(FxBlast.Kind.SLAM, foot, 0.4, 0.9)
		var lines := _blast(FxBlast.Kind.STREAKS, at, 0.3, 0.9)
		lines.dir = -v.normalized()
		kick(6.0))
	Events.rescue_scored.connect(func(tier: int, at: Vector2) -> void:
		_burst(at, "materialize", 0.9 + float(tier) * 0.5)
		_burst(at, "spark", 0.6 + float(tier) * 0.35)
		_ring(at, Balance.C_HOLO, 24.0, 70.0 + 22.0 * float(tier), 0.4))
	Events.spring_bounced.connect(func(at: Vector2) -> void: _burst(at, "dust", 1.4))
	# Bigger than the stage's own spring: this one had a person behind it.
	Events.runner_launched.connect(func(at: Vector2) -> void: _burst(at, "dust", 2.2))
	Events.runner_wall_jumped.connect(func(at: Vector2, _away: int) -> void:
		_burst(at, "dust", 1.1))
	Events.shot_blocked.connect(func(at: Vector2) -> void: _burst(at, "spark", 1.3))
	# Both devices raise crystal_taken, so both show the number. The runner
	# needs to know the detour paid; the guardian needs to know what they can
	# now afford. Same fact, two reasons to want it.
	Events.pinged.connect(_on_pinged)
	Events.hand_hold_changed.connect(_on_hand_hold_changed)
	Events.runner_landed.connect(func(hard: bool) -> void:
		if hard and _runner != null and is_instance_valid(_runner):
			_blast(FxBlast.Kind.SLAM, _runner.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5), 0.35, 0.55)
			kick(3.0))
	# Every shell leaving a barrel, on whichever device: the host's and the
	# guest's copies alike, so it is watched for rather than announced.
	get_tree().node_added.connect(_on_node_added)
	Events.crystal_taken.connect(func(_id: int, at: Vector2, amount: float) -> void:
		_burst(at, "spark", 1.5)
		_float_text(at, "+%d" % int(round(amount)), Color(0.62, 0.95, 1.0)))

func _on_runner_spawned(runner: Node2D) -> void:
	_runner = runner as Runner
	if _run_dust == null:
		_run_dust = _make(24, 0.5)
		_run_dust.emitting = false
		_run_dust.explosiveness = 0.0
		_run_dust.direction = Vector2(0, -1)
		_run_dust.spread = 55.0
		_run_dust.initial_velocity_min = 20.0
		_run_dust.initial_velocity_max = 70.0
		_run_dust.scale_amount_min = 2.0
		_run_dust.scale_amount_max = 5.0
		_run_dust.color = Color(DUST.r, DUST.g, DUST.b, 0.5)
		add_child(_run_dust)

func _process(_delta: float) -> void:
	if _runner == null or not is_instance_valid(_runner) or _run_dust == null:
		return
	var grounded := _runner.is_on_floor()
	var moving := absf(_runner.velocity.x) > 90.0
	_run_dust.global_position = _runner.global_position + Vector2(
		-signf(_runner.velocity.x) * 10.0, Balance.RUNNER_SIZE.y * 0.5)
	_run_dust.emitting = grounded and moving

	if _was_airborne and grounded:
		_burst(_runner.global_position + Vector2(0, Balance.RUNNER_SIZE.y * 0.5),
			"dust", clampf(absf(_runner.velocity.y) / 700.0 + 0.4, 0.4, 1.4))
	_was_airborne = not grounded

func _on_enemy_killed(enemy: Node2D, by: String) -> void:
	if not is_instance_valid(enemy):
		return
	var at := enemy.global_position
	if enemy is Turret:
		# A gun emplacement does not fall over; it goes up.
		_explosion(at, 1.6)
		return
	_burst(at, "poof", 1.4 if by == "snipe" else 1.1)
	_burst(at, "spark", 1.2)
	_ring(at, Color(1.0, 0.92, 0.7), 16.0, 92.0, 0.32, 7.0)
	_blast(FxBlast.Kind.IMPACT, at, 0.16, 1.0)
	_blast(FxBlast.Kind.STAR, at, 0.55, 1.0)
	kick(5.0)

## Both ends, so the trip reads as a trip. Flashing only the arrival looks like
## the runner blinked out of existence and reappeared for no reason.
func _on_runner_warped(from: Vector2, to: Vector2) -> void:
	_burst(from, "materialize", 1.0)
	_burst(to, "materialize", 1.4)

func _on_shot_fired(from: Vector2, to: Vector2, hit: bool) -> void:
	# BANG: the flash at the barrel, the round's path burned across the
	# screen for a blink, and at the far end a flash, a ring of force, speed
	# lines and smoke. A hit gets all of it and the lettering; a miss only
	# the shot and a puff -- the guardian has to tell which it was at a glance.
	var dir := (to - from).normalized() if to.distance_squared_to(from) > 1.0 else Vector2.RIGHT
	var flash := _blast(FxBlast.Kind.MUZZLE, from, 0.09, 1.0)
	flash.dir = dir
	var beam := _blast(FxBlast.Kind.BEAM, from, 0.11, 1.0)
	beam.to = to
	beam.colour = Color(1.0, 0.8, 0.35)
	_burst(to, "spark" if hit else "puff", 1.4 if hit else 1.0)
	if not hit:
		_blast(FxBlast.Kind.SMOKE, to, 0.4, 0.45)
		kick(2.5)
		return
	_blast(FxBlast.Kind.IMPACT, to, 0.18, 1.3)
	_blast(FxBlast.Kind.SHOCK, to, 0.32, 1.0)
	var lines := _blast(FxBlast.Kind.STREAKS, to, 0.22, 1.0)
	lines.dir = dir
	_blast(FxBlast.Kind.SMOKE, to, 0.6, 0.7)
	var word := _blast(FxBlast.Kind.BANG, to + Vector2(0, -70), 0.55, 0.8)
	word.text = "BANG!"
	_ring(to, Color.WHITE, 4.0, 40.0, 0.14, 9.0)
	kick(9.0)

func _on_hologram_spawned(_kind: int, at: Vector2) -> void:
	_burst(at, "materialize", 1.0)

func _on_runner_died(_cause: String) -> void:
	if _runner != null and is_instance_valid(_runner):
		var at := _runner.global_position
		_burst(at, "poof", 1.8)
		_burst(at, "spark", 1.4)
		var hit := _blast(FxBlast.Kind.IMPACT, at, 0.2, 1.2)
		hit.colour = Color(1.0, 0.5, 0.35)
		_blast(FxBlast.Kind.SHOCK, at, 0.35, 0.9)
		_blast(FxBlast.Kind.STAR, at, 0.6, 0.9)
		kick(11.0)

## A big one: a fireball, two rings of force, smoke rolling off, debris, and
## the lettering. The cannon sent its own ball home.
func _explosion(at: Vector2, size: float) -> void:
	_blast(FxBlast.Kind.FIREBALL, at, 0.55, size)
	_blast(FxBlast.Kind.SHOCK, at, 0.4, size * 1.3)
	_blast(FxBlast.Kind.SHOCK, at, 0.6, size * 2.0)
	_blast(FxBlast.Kind.SMOKE, at + Vector2(0, -20), 1.1, size)
	var lines := _blast(FxBlast.Kind.STREAKS, at, 0.3, size)
	lines.dir = Vector2.UP
	_burst(at, "poof", 2.4)
	_burst(at, "spark", 2.0)
	var word := _blast(FxBlast.Kind.BANG, at + Vector2(0, -40), 0.7, size * 0.8)
	word.text = "BOOM!"
	kick(16.0)

## A shell leaving a barrel: a flash and a blast of smoke at the muzzle, and
## the gun's whole frame jolts.
func _on_node_added(node: Node) -> void:
	if node is Projectile:
		_muzzle_blast.call_deferred(node)

func _muzzle_blast(shot: Projectile) -> void:
	if not is_instance_valid(shot) or shot.state != Projectile.State.FLYING:
		return
	var at := shot.global_position
	var d := shot.direction.normalized() if shot.direction.length_squared() > 0.01 else Vector2.LEFT
	var flash := _blast(FxBlast.Kind.MUZZLE, at, 0.12, 1.7)
	flash.dir = d
	var smoke := _blast(FxBlast.Kind.SMOKE, at + d * 10.0, 0.8, 0.9)
	smoke.dir = d
	_blast(FxBlast.Kind.SHOCK, at, 0.25, 0.6)
	_burst(at, "spark", 0.9)
	kick(4.0)

## The guardian's hand: a press lands with a pulse; a portcullis let go
## comes down with a crash a moment later.
func _on_hand_hold_changed(node: Node2D) -> void:
	if not is_instance_valid(node) or not node.has_method("hand_point"):
		return
	var held: bool = node.hold.held_at(Clock.tick) if "hold" in node else false
	if held:
		var pulse := _blast(FxBlast.Kind.SHOCK, node.hand_point(), 0.3, 0.7)
		pulse.colour = Balance.C_HOLO
		kick(3.0)
		return
	if node is LiftGate:
		var foot := node.global_position
		get_tree().create_timer(Balance.LIFT_GATE_DROP).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_blast(FxBlast.Kind.SLAM, foot, 0.5, 1.2)
				_burst(foot, "dust", 2.6)
				var word := _blast(FxBlast.Kind.BANG, foot + Vector2(60, -120), 0.6, 0.75)
				word.text = "CLANG!"
				kick(12.0))

## Spawn a drawn effect here and return it, to be told which way it goes.
func _blast(k: int, at: Vector2, life: float, size: float) -> FxBlast:
	var b := FxBlast.make(k, at, life, size)
	add_child(b)
	return b

## Shake the view: every device shakes for what it sees.
func kick(strength: float) -> void:
	Events.screen_kick.emit(strength)

func _make(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.local_coords = false
	p.gravity = Vector2(0, 420)
	p.damping_min = 40.0
	p.damping_max = 90.0
	return p

func _burst(at: Vector2, kind: String, strength: float) -> void:
	# Drop the burst rather than queue it. Feedback that arrives late is worse
	# than feedback that is missing, and the frames where this cap bites are the
	# ones already under load.
	if _live_bursts >= Balance.MAX_PARTICLE_BURSTS:
		return
	var p := _make(16, 0.5)
	match kind:
		"dust":
			p.amount = int(12 * strength)
			p.direction = Vector2(0, -1)
			p.spread = 78.0
			p.initial_velocity_min = 40.0 * strength
			p.initial_velocity_max = 150.0 * strength
			p.scale_amount_min = 3.0
			p.scale_amount_max = 7.0
			p.color = Color(DUST.r, DUST.g, DUST.b, 0.62)
		"spark":
			p.amount = 22
			p.lifetime = 0.42
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 340.0
			p.scale_amount_min = 1.5
			p.scale_amount_max = 4.0
			p.color = SPARK
		"puff":
			p.amount = 8
			p.lifetime = 0.35
			p.spread = 180.0
			p.gravity = Vector2.ZERO
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 110.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
			p.color = Color(0.72, 0.86, 1.0, 0.5)
		"poof":
			p.amount = int(20 * strength)
			p.lifetime = 0.55
			p.spread = 180.0
			p.gravity = Vector2(0, 180)
			p.initial_velocity_min = 60.0 * strength
			p.initial_velocity_max = 220.0* strength
			p.scale_amount_min = 3.0
			p.scale_amount_max = 8.0
			p.color = Color(0.62, 0.46, 0.28, 0.85)
		"materialize":
			p.amount = 26
			p.lifetime = 0.5
			p.spread = 180.0
			p.gravity = Vector2(0, -60)
			p.initial_velocity_min = 90.0
			p.initial_velocity_max = 260.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 5.0
			p.color = Balance.C_HOLO
	p.global_position = at
	add_child(p)
	_live_bursts += 1
	# Let the emitter retire itself. A scene-tree timer holding a lambda that
	# captures the node dangles if the scene is torn down first, which is
	# exactly what a test harness does between cases.
	p.finished.connect(p.queue_free)
	p.tree_exited.connect(_on_burst_finished)
	p.emitting = true

## Somebody pointing. Drawn in the WORLD rather than on the HUD, because the
## whole content of the message is where it is.
##
## Both players see every mark, including their own -- a mark you cannot see is
## not communication, and seeing your own land is how you know it arrived.
func _on_pinged(at: Vector2, kind: int, from_runner: bool) -> void:
	# A marker names an exact spot on the ground, which inside a veil is the one
	# job the pair are supposed to be doing with their voices. So it does not
	# arrive there. Everywhere else it lands as it always has.
	if VeilField.current != null and is_instance_valid(VeilField.current) \
			and VeilField.current.hides(Veil.MARKS, at):
		return
	var marker := preload("res://src/render/ping_marker.gd").new()
	marker.kind = kind
	marker.from_runner = from_runner
	marker.global_position = at
	add_child(marker)
	_float_text(at + Vector2(0.0, -34.0),
		"待って" if kind == 2 else "ここ",
		Color(1.0, 0.80, 0.35) if kind == 2 else Color(0.62, 0.95, 1.0))

## A number that drifts up and fades. Cheap, and the only thing in this game
## that puts a figure on the world rather than in the HUD -- which is right for
## a pickup: the point is WHERE it came from.
func _float_text(at: Vector2, text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 5)
	var font := Art.font()
	if font != null:
		label.add_theme_font_override("font", font)
	label.global_position = at + Vector2(-18.0, -26.0)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position",
		label.global_position + Vector2(0.0, -46.0), 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

## A ring of light that swells from `r0` to `r1` and thins out: the shape of
## an impact. Drawn, not particles, so it is crisp at any zoom.
class Ring extends Node2D:
	var colour := Color.WHITE
	var r0 := 10.0
	var r1 := 60.0
	var life := 0.3
	var width := 6.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var e := 1.0 - pow(1.0 - k, 3.0)
		var c := colour
		c.a *= 1.0 - k
		draw_arc(Vector2.ZERO, lerpf(r0, r1, e), 0.0, TAU, 40, c, lerpf(width, 1.0, k), true)

func _ring(at: Vector2, colour: Color, r0: float, r1: float, life: float,
		width := 6.0) -> void:
	if _live_bursts >= Balance.MAX_PARTICLE_BURSTS:
		return
	var ring := Ring.new()
	ring.colour = colour
	ring.r0 = r0
	ring.r1 = r1
	ring.life = life
	ring.width = width
	ring.global_position = at
	add_child(ring)
	_live_bursts += 1
	ring.tree_exited.connect(_on_burst_finished)

func _on_burst_finished() -> void:
	_live_bursts = maxi(0, _live_bursts - 1)

# ------------------------------------------------------------------ the hand

## The streak behind something the guardian's finger flicked off the screen,
## ending as a twinkle in the distance.
class Flight extends Node2D:
	var velocity := Vector2.ZERO
	var spin := 0.0
	var life := 0.9
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		velocity.y += 900.0 * delta * 0.35
		position += velocity * delta
		rotation += spin * delta
		var k := clampf(_t / life, 0.0, 1.0)
		scale = Vector2.ONE * lerpf(1.0, 0.35, k)
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		# Speed lines trailing behind, in the frame of the flight.
		var back := -velocity.normalized().rotated(-rotation) * 60.0
		for k in 3:
			var off := back.orthogonal().normalized() * float(k - 1) * 16.0
			draw_line(off, off + back, Color(1, 1, 1, 0.45 * (1.0 - _t / life)), 4.0, true)

class Twinkle extends Node2D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t >= 0.5:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := _t / 0.5
		var r := 26.0 * sin(k * PI)
		var c := Color(1, 1, 0.85, 1.0 - k * 0.5)
		draw_line(Vector2(-r, 0), Vector2(r, 0), c, 4.0, true)
		draw_line(Vector2(0, -r), Vector2(0, r), c, 4.0, true)
		draw_line(Vector2(-r, -r) * 0.45, Vector2(r, r) * 0.45, c, 3.0, true)
		draw_line(Vector2(-r, r) * 0.45, Vector2(r, -r) * 0.45, c, 3.0, true)

func _on_enemy_flicked(at: Vector2, direction: Vector2) -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector2.UP
	_ring(at, Color(1, 1, 1, 0.9), 20.0, 110.0, 0.25, 8.0)
	_burst(at, "spark", 2.0)
	_blast(FxBlast.Kind.IMPACT, at, 0.18, 1.5)
	_blast(FxBlast.Kind.SHOCK, at, 0.35, 1.4)
	var lines := _blast(FxBlast.Kind.STREAKS, at, 0.25, 1.3)
	lines.dir = dir
	var word := _blast(FxBlast.Kind.BANG, at + Vector2(-60, -110), 0.6, 1.0)
	word.text = "POW!"
	kick(13.0)
	# The thing itself flies off on its own (Enemy.flick); this is the streak
	# that goes with it.
	var flight := Flight.new()
	flight.global_position = at
	flight.velocity = dir * 1500.0
	flight.spin = 0.0
	add_child(flight)
	var end := at + dir * 1500.0 * 0.6
	var star := Twinkle.new()
	star.global_position = end
	get_tree().create_timer(0.75).timeout.connect(func() -> void:
		if is_instance_valid(self):
			add_child(star)
		else:
			star.free())

## A swipe: a sheet of wind along the stroke.
class Sweep extends Node2D:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t >= 0.4:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := _t / 0.4
		var dir := (b - a)
		var side := dir.orthogonal().normalized()
		for i in 5:
			var off := side * float(i - 2) * 14.0
			var from := a.lerp(b, clampf(k * 1.4 - 0.4 + float(i) * 0.05, 0.0, 1.0))
			var to := a.lerp(b, clampf(k * 1.4 + float(i) * 0.05, 0.0, 1.0))
			draw_line(from + off, to + off, Color(0.85, 0.97, 1.0, 0.75 * (1.0 - k)), 6.0 - i * 0.6, true)

func _on_hand_swiped(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	var sweep := Sweep.new()
	sweep.a = points[0]
	sweep.b = points[points.size() - 1]
	add_child(sweep)
	var word := _blast(FxBlast.Kind.BANG, points[points.size() / 2] + Vector2(0, -50), 0.5, 0.8)
	word.text = "WHOOSH!"
	kick(6.0)
