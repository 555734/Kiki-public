extends Node2D
## The guardian, on the screen: a hand of light that goes where they point.
##
## The guardian has no body in this game. On a shared screen that is fine for
## the person holding the device, but for the runner -- and for anyone
## watching -- platforms and shots simply appeared out of nowhere, and half of
## the pair was invisible. This gives them a presence in the world: it hovers
## over the aim, rides the tip of a stroke being drawn, and darts to wherever a
## tool was just used.
##
## Drawn only, and only where the reticle would be (InputHub.shows_guardian_cursor),
## so it follows exactly the same rules as the rest of the guardian's cursor --
## including staying away on a runner's device until the guardian's aim has
## actually arrived. It also stays asleep until the guardian first does
## something, so a stage that is only being looked at is unchanged.

var guardian: Guardian = null

const HOVER := Vector2(0.0, -22.0)
const TRAIL := 12
## The finger is drawn this tall (world px), fingertip on the point.
const HAND_SIZE := 54.0

var _pos := Vector2.ZERO
var _trail: Array[Vector2] = []
var _alpha := 0.0
var _awake := false
var _t := 0.0
var _last_aim := Vector2(INF, INF)
var _dash_left := 0.0
var _dash_to := Vector2.ZERO
## What the hand was last doing, for its pose: "point", "pinch", "press",
## "flick", "swipe", and how long ago a one-off pose started.
var _pose := "point"
var _pose_age := 0.0

func _ready() -> void:
	z_index = 30
	Events.ability_used.connect(_on_ability_used)
	Events.enemy_flicked.connect(func(_at: Vector2, _d: Vector2) -> void: _flash_pose("flick"))
	Events.runner_slung.connect(func(_at: Vector2, _v: Vector2) -> void: _flash_pose("flick"))
	Events.hand_swiped.connect(func(_p: PackedVector2Array) -> void: _flash_pose("swipe"))

func _flash_pose(pose: String) -> void:
	_awake = true
	_pose = pose
	_pose_age = 0.0

func _on_ability_used(_slot: int, at: Vector2) -> void:
	_awake = true
	_dash_to = at
	_dash_left = 0.2

func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(guardian) or guardian.input_hub == null:
		return
	var hub: InputHub = guardian.input_hub
	var aim := hub.aim_world()
	# Awake once the guardian has done anything: used a tool, put a finger on
	# the world, or moved the aim. The aim parked on the runner at the start
	# does not count.
	if hub.aiming() or not hub.trace_points.is_empty():
		_awake = true
	if _last_aim.x != INF and aim.distance_to(_last_aim) > 1.0 and _t > 0.5:
		_awake = true
	_last_aim = aim
	var shown := _awake and hub.shows_guardian_cursor()
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * 5.0)

	# The fingertip is ON the point: it is touching, not hovering.
	var target := aim + Vector2(0.0, sin(_t * 3.2) * 2.0)
	if not hub.trace_points.is_empty():
		# Riding the tip of the stroke: this is the hand drawing it.
		target = hub.trace_points[hub.trace_points.size() - 1]
	_pose_age += delta
	var held: Dictionary = hub.hand_state.get("target", {})
	match String(held.get("kind", "")):
		"projectile":
			_pose = "pinch"
		"holdable":
			_pose = "press"
		"runner", "enemy":
			_pose = "press"
		_:
			if _pose_age > 0.35:
				_pose = "point"
	if not held.is_empty():
		_awake = true
		target = aim
	var rate := 10.0 if hub.hand_state.is_empty() else 40.0
	if _dash_left > 0.0:
		_dash_left -= delta
		target = _dash_to + HOVER * 0.5
		rate = 24.0
	if _alpha <= 0.0:
		_pos = target
	else:
		_pos = _pos.lerp(target, clampf(delta * rate, 0.0, 1.0))
	_trail.push_front(_pos)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.01:
		return
	var c := Balance.C_HOLO
	for i in range(_trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / float(TRAIL)
		draw_circle(to_local(_trail[i]), 6.0 * k, Color(c, 0.18 * k * _alpha))
	var tip := to_local(_pos)
	_draw_band(tip)
	# A soft pool where the fingertip touches.
	draw_circle(tip, 14.0, Color(c, 0.18 * _alpha))
	draw_circle(tip, 5.0, Color(1, 1, 1, 0.85 * _alpha))
	if Art.draw_sprite_fit(self, "finger_" + _pose, tip + Vector2(HAND_SIZE * 0.32, HAND_SIZE * 0.42),
			HAND_SIZE, Color(1, 1, 1, _alpha)):
		return
	_draw_hand(tip, _pose, HAND_SIZE / 54.0, _alpha)

## The slingshot's band, from the runner to the finger pulling it back.
func _draw_band(tip: Vector2) -> void:
	if not is_instance_valid(guardian) or guardian.input_hub == null:
		return
	var held: Dictionary = guardian.input_hub.hand_state.get("target", {})
	if String(held.get("kind", "")) != "runner":
		return
	var r: Node2D = held.get("node")
	if r == null or not is_instance_valid(r):
		return
	var at := to_local(r.global_position)
	var stretch := clampf(at.distance_to(tip) / Balance.SLING_MAX_PULL, 0.0, 1.0)
	var band := Color(1.0, lerpf(0.9, 0.45, stretch), lerpf(0.5, 0.2, stretch), 0.9 * _alpha)
	for side in [-1.0, 1.0]:
		draw_line(at + Vector2(side * 16.0, -10.0), tip, band, lerpf(5.0, 2.5, stretch), true)
	# Where the throw will go: the opposite way, a short dotted hint.
	var dir := (at - tip).normalized()
	for k in 4:
		draw_circle(at + dir * (34.0 + k * 22.0) * (0.4 + stretch), 3.5 - k * 0.6,
			Color(1, 1, 1, (0.7 - k * 0.15) * _alpha * stretch))

## A hand made of the guardian's light, fingertip at `tip`, reaching up and
## to the left. Drawn twice: a bright rim, then the glassy fill inside it.
static func _hand_parts(pose: String) -> Array:
	# [kind, a, b, radius] in a frame where the fingertip is the origin and the
	# hand hangs down and to the right of it.
	var parts: Array = []
	match pose:
		"pinch":
			parts.append(["cap", Vector2(0, 0), Vector2(6, 24), 5.5])      # index
			parts.append(["cap", Vector2(0, 2), Vector2(-14, 22), 5.5])    # thumb
		"press":
			parts.append(["cap", Vector2(-4, 0), Vector2(0, 26), 5.5])     # index
			parts.append(["cap", Vector2(7, 3), Vector2(9, 27), 5.5])      # middle
			parts.append(["cap", Vector2(-12, 36), Vector2(-19, 26), 5.0]) # thumb
		"swipe":
			for k in 4:
				parts.append(["cap", Vector2(-6 + k * 7, 2 + k * 2), Vector2(-2 + k * 7, 26), 5.0])
			parts.append(["cap", Vector2(-14, 40), Vector2(-22, 30), 5.0])
		_:
			parts.append(["cap", Vector2(0, 0), Vector2(0, 26), 5.5])      # index
			parts.append(["cap", Vector2(-12, 36), Vector2(-19, 26), 5.0]) # thumb
			for k in 3:                                                    # curled
				parts.append(["dot", Vector2(8 + k * 5, 27 + k * 3), Vector2.ZERO, 6.0])
	parts.append(["palm", Vector2(-14, 24), Vector2(30, 30), 9.0])
	return parts

func _draw_hand(tip: Vector2, pose: String, scale_k: float, alpha: float) -> void:
	var xf := Transform2D(-0.42, Vector2(scale_k, scale_k), 0.0, tip)
	draw_set_transform_matrix(xf)
	var parts := _hand_parts(pose)
	var c := Balance.C_HOLO
	for pass_i in 2:
		var grow := 2.6 if pass_i == 0 else 0.0
		var col := Color(0.85, 0.98, 1.0, 0.95 * alpha) if pass_i == 0 \
			else Color(c.lightened(0.15), 0.62 * alpha)
		for p in parts:
			match String(p[0]):
				"cap":
					draw_line(p[1], p[2], col, (float(p[3]) + grow) * 2.0, true)
					draw_circle(p[1], float(p[3]) + grow, col)
					draw_circle(p[2], float(p[3]) + grow, col)
				"dot":
					draw_circle(p[1], float(p[3]) + grow, col)
				"palm":
					var r := Rect2(p[1], p[2]).grow(grow)
					var rad := float(p[3]) + grow
					draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2.0, 0)), col)
					draw_rect(Rect2(r.position + Vector2(0, rad), r.size - Vector2(0, rad * 2.0)), col)
					for corner in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
							r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]:
						draw_circle(corner, rad, col)
	# A bright core along the pointing finger, the way the hologram slabs glow.
	draw_line(Vector2(0, 2), Vector2(0, 20), Color(1, 1, 1, 0.55 * alpha), 3.0, true)
	if pose == "flick" and _pose_age < 0.35:
		for k in 3:
			var off := Vector2(10 + k * 6, -4 + k * 7)
			draw_line(off, off + Vector2(14, 6), Color(1, 1, 1, 0.8 * alpha * (1.0 - _pose_age / 0.35)), 2.5, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
