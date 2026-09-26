class_name Goal
extends Area2D
## "Find the Ancient Gate" -- the objective shown in the mockup HUD. Chapter 3
## keeps the win condition as simple as possible: both players get there.

var _pulse: float = 0.0
var _cleared: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 190)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)

var _told_locked: bool = false

func _on_body_entered(body: Node2D) -> void:
	if _cleared or not (body is Runner):
		return
	if Stage.needs_key() and not GameState.has_key:
		if not _told_locked:
			_told_locked = true
			Events.notice.emit("鍵がかかっている！ 地上のどこかにある鍵を探そう")
		return
	_cleared = true
	GameState.running = false
	Events.stage_cleared.emit(GameState.stats())

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()
	# The key can arrive while the runner is already standing in the gate.
	if not _cleared and Stage.needs_key() and GameState.has_key:
		for body in get_overlapping_bodies():
			if body is Runner:
				_on_body_entered(body)
				break
	if not (Stage.needs_key() and not GameState.has_key):
		_told_locked = false

## Half-round arch closed into a solid: arc from +x over the top to -x, then
## straight down the left side and back along the base.
func _arch_points(half_width: float, rise: float, base_y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(25):
		var a := PI * (float(i) / 24.0)
		pts.append(Vector2(cos(a) * half_width, -30.0 - sin(a) * rise))
	pts.append(Vector2(-half_width, base_y))
	pts.append(Vector2(half_width, base_y))
	return pts

func _draw() -> void:
	_draw_gate()
	if Stage.needs_key() and not GameState.has_key:
		_draw_lock()

## A padlock hung across the gate while the key is still out on the course.
func _draw_lock() -> void:
	var c := Vector2(0, -10)
	var shake := sin(_pulse * 3.0) * 1.5
	c.x += shake
	draw_circle(c + Vector2(0, 6), 40.0, Color(0, 0, 0, 0.18))
	draw_arc(c + Vector2(0, -14), 15.0, PI, TAU, 16, Color("5a4a2a"), 9.0, true)
	draw_arc(c + Vector2(0, -14), 15.0, PI, TAU, 16, Color("c9a23a"), 5.0, true)
	draw_rect(Rect2(c + Vector2(-22, -14), Vector2(44, 36)), Color("5a4a2a"))
	draw_rect(Rect2(c + Vector2(-19, -11), Vector2(38, 30)), Color("f3c334"))
	draw_circle(c + Vector2(0, 0), 5.0, Color("3a2a10"))
	draw_rect(Rect2(c + Vector2(-2, 2), Vector2(4, 10)), Color("3a2a10"))

func _draw_gate() -> void:
	var glow := 0.5 + 0.5 * sin(_pulse * 2.0)
	if Stage.is_sea() and Balance.USE_TEXTURES and Art.tex("goal") != null:
		# 1-4's goal is the pack's red flag, planted on the ground (the goal
		# sits 55px above the ledge), with a soft beacon glow over it.
		draw_circle(Vector2(0, -60.0), 34.0 + glow * 12.0,
			Color(1.0, 0.86, 0.45, 0.14 + glow * 0.10))
		Art.draw_sprite(self, "goal", Vector2(8.0, 57.0), 210.0)
		return
	if Balance.USE_TEXTURES and Art.tex("goal") != null:
		Art.draw_sprite(self, "goal", Vector2(0.0, 96.0), 246.0)
		draw_circle(Vector2(0, -40.0), 26.0 + glow * 10.0,
			Color(0.42, 0.86, 1.0, 0.16 + glow * 0.10))
		for i in range(5):
			var y := 80.0 - float(i) * 30.0 - fmod(_pulse * 26.0, 30.0)
			if y < -70.0:
				continue
			draw_line(Vector2(-30.0, y), Vector2(30.0, y), Color(0.75, 0.96, 1.0, 0.18), 2.5)
		return
	# A standing stone arch with a shimmering portal inside it. The two closing
	# points have to continue the arc's winding -- the sweep ends on the left,
	# so the base goes left-then-right or the polygon crosses itself and
	# triangulation fails.
	draw_colored_polygon(_arch_points(46.0, 62.0, 95.0), Color("7b6a58"))
	draw_colored_polygon(_arch_points(32.0, 48.0, 95.0),
		Color(0.13, 0.62, 0.85, 0.55 + glow * 0.25))

	for i in range(5):
		var y := 80.0 - float(i) * 30.0 - fmod(_pulse * 26.0, 30.0)
		if y < -70.0:
			continue
		draw_line(Vector2(-30.0, y), Vector2(30.0, y), Color(0.7, 0.95, 1.0, 0.22), 2.5)
	draw_circle(Vector2(0, -95.0), 8.0 + glow * 4.0, Color(1.0, 0.92, 0.6, 0.55))
