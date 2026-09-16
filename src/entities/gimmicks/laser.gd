class_name Laser
extends Node2D
## A beam that cycles on and off. The single raycast below is what makes the
## wall matter: whatever the ray hits first stops the beam, so a wall dropped in
## the path shields the runner without any special-casing.

@export var direction: Vector2 = Vector2.RIGHT
@export var max_length: float = 520.0
@export var phase_offset: float = 0.0

var _time: float = 0.0
var _on: bool = false
var _end: Vector2 = Vector2.ZERO
var _warn: float = 0.0

## Whether the beam is firing at a given tick. A pure function of the tick, so
## the on/off phase never has to be synchronised -- see docs/netcode.md 4.1.
func is_on_at(at_tick: int) -> bool:
	var cycle := Balance.LASER_ON_TIME + Balance.LASER_OFF_TIME
	return fmod(Clock.seconds_at(at_tick, phase_offset), cycle) < Balance.LASER_ON_TIME

func _ready() -> void:
	z_index = 6
	_time = phase_offset

func _physics_process(_delta: float) -> void:
	var cycle := Balance.LASER_ON_TIME + Balance.LASER_OFF_TIME
	_time = Clock.seconds(phase_offset)
	var t := fmod(_time, cycle)
	_on = t < Balance.LASER_ON_TIME
	# Telegraph the last third of a second before it fires.
	_warn = 0.0 if _on else clampf((t - (cycle - 0.35)) / 0.35, 0.0, 1.0)

	var dir := direction.normalized()
	var space := get_world_2d().direct_space_state
	var from := global_position
	var to := from + dir * max_length
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 | 2 | 8)
	var hit := space.intersect_ray(query)
	_end = hit.get("position", to) if not hit.is_empty() else to

	if _on and not hit.is_empty():
		var collider = hit.get("collider")
		if collider is Runner:
			(collider as Runner).die("laser")
	queue_redraw()

func _draw() -> void:
	var local_end := to_local(_end)
	if Balance.USE_TEXTURES and _draw_painted(local_end):
		return
	# Emitter housing
	DrawUtil.rounded_rect(self, Rect2(-16, -16, 32, 32), 7.0, Color("4a3b5c"))
	DrawUtil.rounded_rect(self, Rect2(-11, -11, 22, 22), 5.0, Color("6c5687"))

	if _warn > 0.0:
		draw_line(Vector2.ZERO, local_end, Color(1.0, 0.35, 0.4, 0.12 + _warn * 0.25), 2.0)
		draw_circle(Vector2.ZERO, 6.0 + _warn * 5.0, Color(1.0, 0.4, 0.4, 0.3 + _warn * 0.4))
	if not _on:
		return

	var w := Balance.LASER_WIDTH
	var flicker := 0.88 + 0.12 * sin(_time * 40.0)
	draw_line(Vector2.ZERO, local_end, Color(1.0, 0.22, 0.32, 0.34), w * 2.4 * flicker)
	draw_line(Vector2.ZERO, local_end, Color(1.0, 0.30, 0.38, 0.85), w * 1.3 * flicker)
	draw_line(Vector2.ZERO, local_end, Color(1.0, 0.62, 0.66, 0.95), w * 0.7)
	draw_line(Vector2.ZERO, local_end, Color(1.0, 0.96, 0.96, 1.0), w * 0.30)
	draw_circle(local_end, w * 0.85, Color(1.0, 0.6, 0.6, 0.55))
	draw_circle(Vector2.ZERO, w * 0.7, Color(1.0, 0.9, 0.9, 0.9))

## The beam is one 8x48 cross-section strip stretched down the ray, so its
## soft-edged profile survives at any length without a shader.
func _draw_painted(local_end: Vector2) -> bool:
	var housing := Art.tex("laser_emitter")
	if housing == null:
		return false
	var dir := direction.normalized()
	var angle := dir.angle()

	if _on or _warn > 0.0:
		var length := local_end.length()
		var thickness := Balance.LASER_WIDTH * (2.6 if _on else 1.2)
		var flicker := 0.9 + 0.1 * sin(_time * 40.0)
		var tint := Color(1, 1, 1, (0.95 * flicker) if _on else (0.10 + _warn * 0.30))
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
		Art.draw_stretched(self, "laser_beam",
			Rect2(0.0, -thickness * 0.5, length, thickness), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _on:
			draw_circle(local_end, thickness * 0.42, Color(1.0, 0.72, 0.72, 0.55))

	var flip := absf(angle) > PI * 0.5
	var rot := 0.0
	if absf(dir.y) > 0.7:
		rot = PI * 0.5 * signf(dir.y)
		flip = false
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	Art.draw_sprite(self, "laser_emitter", Vector2(0.0, 22.0), 46.0, flip)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func is_firing() -> bool:
	return _on
