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
	Events.rescue_scored.connect(func(tier: int, at: Vector2) -> void:
		_burst(at, "materialize", 0.9 + float(tier) * 0.5)
		_burst(at, "spark", 0.6 + float(tier) * 0.35))
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
	if is_instance_valid(enemy):
		_burst(enemy.global_position, "poof", 1.2 if by == "snipe" else 1.0)

## Both ends, so the trip reads as a trip. Flashing only the arrival looks like
## the runner blinked out of existence and reappeared for no reason.
func _on_runner_warped(from: Vector2, to: Vector2) -> void:
	_burst(from, "materialize", 1.0)
	_burst(to, "materialize", 1.4)

func _on_shot_fired(_from: Vector2, to: Vector2, hit: bool) -> void:
	_burst(to, "spark" if hit else "puff", 1.0)

func _on_hologram_spawned(_kind: int, at: Vector2) -> void:
	_burst(at, "materialize", 1.0)

func _on_runner_died(_cause: String) -> void:
	if _runner != null and is_instance_valid(_runner):
		_burst(_runner.global_position, "poof", 1.6)

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

func _on_burst_finished() -> void:
	_live_bursts = maxi(0, _live_bursts - 1)
