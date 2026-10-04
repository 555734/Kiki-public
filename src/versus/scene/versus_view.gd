class_name VersusView
extends RefCounted
## What this machine is looking at: the following camera, the sky behind it
## and, on the stages co-op draws in 3D, the 3D view.

var arena = null
var camera: Camera2D = null
var sky: Node = null
var world_view: Node = null

func _init(owner_arena) -> void:
	arena = owner_arena

func build_camera(at: Vector2) -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = false   # smoothed by hand, in follow()
	camera.zoom = Vector2.ONE * VersusRules.CAMERA_ZOOM
	camera.global_position = at
	arena.add_child(camera)
	camera.make_current()
	replace_sky()

## A fresh sky for the current stage, scrolled to where the old one was.
func replace_sky() -> void:
	var offset: float = sky.scroll_offset if sky != null else 0.0
	if sky != null:
		sky.queue_free()
	sky = preload("res://src/render/sky.gd").new()
	sky.name = "Sky"
	sky.camera = camera
	sky.scroll_offset = offset
	arena.add_child(sky)

## The 3D view, for the stages co-op draws in 3D (1-3) and only those: 1-1,
## 1-2, 1-4 and 1-5 are painted 2D stages, here exactly as in co-op.
func add_world_view() -> void:
	if Balance.USE_3D and Stage.world_3d() and world_view == null:
		world_view = load("res://src/render/three/world_view.gd").new()
		arena.add_child(world_view)

func drop_world_view() -> void:
	if world_view != null:
		world_view.queue_free()
		world_view = null

## Follows a runner with the same lead and the same smoothing the cooperative
## camera uses -- a guardian is reading the road ahead of their own runner here
## exactly as they do there.
func follow(who: Runner, delta: float) -> void:
	if camera == null or who == null or not is_instance_valid(who):
		return
	var lead := clampf(who.velocity.x / Balance.RUNNER_RUN_SPEED, -1.0, 1.0) \
		* Balance.CAMERA_LOOKAHEAD
	var target := who.global_position + Vector2(lead, -40.0)
	var t := clampf(delta * Balance.CAMERA_SMOOTH, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target, t)

## The followed runner was moved by exactly one lap: move the camera with it
## so nothing on screen jumps, and keep the backdrop scrolling as if nothing
## moved -- without that it jumped a lap's worth of parallax at the join.
func shift(dx: float) -> void:
	if camera == null:
		return
	camera.global_position.x += dx
	if sky != null:
		sky.scroll_offset -= dx

## Where to draw something canonical (in lap 0): the copy nearest the camera.
func near(at: Vector2) -> Vector2:
	return VersusStageData.nearest_image(at, camera.global_position) \
		if camera != null else at

## The world rectangle currently on screen, for the HUD's edge arrows.
func rect() -> Rect2:
	if camera == null:
		return Rect2()
	var size: Vector2 = arena.get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
