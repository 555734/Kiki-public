extends Node
## The trailer's foley: recorded, physical sounds for what is on screen --
## every footfall, the shot, the hit, the stab of a death, the cannon, the
## hound -- logged against film time for trailer_mix.py, which lays them from
## tools/trailer_assets/sfx/ (CC0 recordings; see SOURCES.md there).
##
## The game's own sounds are synthesised blips; good for play, thin for a
## trailer. This listens to the same events the game's effects do, and polls
## the runner's stride, so the sound lands on the frame it belongs to.

var cap: Node = null
## Entries for trailer_mix.py: {"t", "key", "db", "pitch"}.
var entries: Array = []
var _rng := RandomNumberGenerator.new()
var _last_step := -1
var _hound_seen := {}
var _last_gallop := -10.0
var _main: Node = null

func _ready() -> void:
	_rng.seed = 2701
	Events.shot_fired.connect(_on_shot)
	Events.enemy_killed.connect(_on_killed)
	Events.runner_died.connect(_on_died)
	Events.enemy_flicked.connect(func(_at: Vector2, _d: Vector2) -> void:
		play("punch_heavy", 0.0)
		play("whoosh", -4.0))
	Events.hand_swiped.connect(func(_p: PackedVector2Array) -> void: play("whoosh", -1.0, 1.15))
	Events.runner_slung.connect(func(_at: Vector2, _v: Vector2) -> void:
		play("spring", -3.0)
		play("whoosh", -2.0, 0.9))
	Events.runner_jumped.connect(func() -> void: play("jump", -9.0, _rng.randf_range(0.95, 1.1)))
	Events.runner_landed.connect(func(hard: bool) -> void: play("land", -2.0 if hard else -7.0))
	Events.hand_hold_changed.connect(_on_hold)
	Events.projectile_changed.connect(_on_projectile)
	get_tree().node_added.connect(_on_node_added)

## Log a clip at the current film time -- only while a shot is filming.
func play(key: String, db := 0.0, pitch := 1.0) -> void:
	if cap == null or not bool(cap.get("recording")):
		return
	entries.append({"t": snappedf(cap.now(), 0.001), "key": key, "db": db, "pitch": snappedf(pitch, 0.001)})

func _on_shot(_from: Vector2, _to: Vector2, hit: bool) -> void:
	play("gun", 0.0, _rng.randf_range(0.96, 1.04))
	if hit:
		play("gun_hit", -2.0)

func _on_killed(enemy: Node2D, by: String) -> void:
	if enemy is Turret:
		play("explosion", 0.0)
	elif by == "swipe":
		play("squeak", -3.0, _rng.randf_range(0.9, 1.2))
		play("flap", -5.0, _rng.randf_range(1.0, 1.25))
	elif by != "flick":
		play("gun_hit", -3.0)

## The one the user asked for by name: the stab of a death, a squish under
## it, and the body hitting the ground.
func _on_died(_cause: String) -> void:
	play("stab", 0.0)
	play("squish", -3.0)
	play("thud", -2.0)

func _on_hold(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var held: bool = node.hold.held_at(Clock.tick) if "hold" in node else false
	if node is LiftGate:
		if held:
			play("latch", -3.0)
			play("creak", -5.0)
		else:
			get_tree().create_timer(Balance.LIFT_GATE_DROP).timeout.connect(func() -> void:
				play("gate_slam", 0.0))
	elif held:
		play("soft_hit", -2.0, 0.7)

func _on_projectile(p: Node2D) -> void:
	if not (p is Projectile):
		return
	match (p as Projectile).state:
		Projectile.State.HELD:
			play("catch", -2.0)
		Projectile.State.THROWN:
			play("whoosh_short", 0.0, 0.9)

func _on_node_added(node: Node) -> void:
	if node is Projectile:
		_cannon.call_deferred(node)

## Whether a world point is in the picture (with a margin): a sound for
## something off screen is a sound for nothing.
func _seen(at: Vector2, margin := 120.0) -> bool:
	# The game is filmed in its own viewport, not this node's.
	if _main == null or not is_instance_valid(_main):
		return true
	var cam: Camera2D = _main.get_viewport().get_camera_2d()
	if cam == null:
		return true
	var half := Vector2(1280, 720) * 0.5 / cam.zoom + Vector2(margin, margin)
	return absf(at.x - cam.get_screen_center_position().x) < half.x \
		and absf(at.y - cam.get_screen_center_position().y) < half.y

func _cannon(p: Projectile) -> void:
	if is_instance_valid(p) and p.state == Projectile.State.FLYING and _seen(p.global_position):
		play("cannon", -1.0, _rng.randf_range(0.95, 1.05))

## Once a tick while filming a co-op shot: footfalls on the runner's stride,
## the hound's gallop and its bark.
func tick(main: Node) -> void:
	if main == null or not is_instance_valid(main) or not ("runner" in main):
		return
	_main = main
	var r: Runner = main.runner
	if r == null or not is_instance_valid(r):
		return
	var v: Node = r.visual
	# A foot comes down at frames 0 and 4 of the eight-frame stride.
	var step := int(float(v.get("_run_t"))) / 4
	if r.state == Runner.State.RUN and r.is_on_floor():
		if step != _last_step:
			play("step_%d" % _rng.randi_range(0, 5), -3.0, _rng.randf_range(0.94, 1.06))
	_last_step = step
	for e in get_tree().get_nodes_in_group("instant_death"):
		if not (e is Node2D) or not main.is_ancestor_of(e) or not e.has_method("stunned"):
			continue
		var vis: Node = e.get("visual")
		if vis == null:
			continue
		var speed := float(vis.get("_speed"))
		var id := e.get_instance_id()
		if not _seen((e as Node2D).global_position) or speed > 3000.0:
			continue
		if speed > 120.0:
			if not _hound_seen.has(id):
				_hound_seen[id] = true
				play("bark_0", -1.0)
			# Its paws on the stones: a recorded run, laid end to end.
			if cap.now() - _last_gallop > 1.25:
				_last_gallop = cap.now()
				play("gallop", -6.0, 0.85)
		elif bool(vis.get("_woke")) and speed < 15.0 and _rng.randf() < 0.03:
			# Held at the bars or knocked back: a growl, or barking at it.
			if _rng.randf() < 0.4:
				play("growl", -5.0, _rng.randf_range(0.9, 1.0))
			else:
				play("bark_%d" % _rng.randi_range(1, 2), -3.0, _rng.randf_range(0.95, 1.05))

## A new shot builds a new game: forget the last one's runner and hound.
func reset() -> void:
	_last_step = -1
	_hound_seen.clear()
