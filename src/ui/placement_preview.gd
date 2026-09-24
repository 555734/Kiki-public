extends Node2D
## The guardian's cursor, drawn in world space: mockup 2's dashed ghost for a
## pending platform or wall, the drop guide beneath it, and the reticle when the
## sniper is up.
##
## Chapter 6 asks that the runner get a brief warning of an incoming platform
## rather than having one appear under them unannounced. On a shared screen the
## ghost is that warning, so it is drawn in the world layer where the runner is
## already looking -- not in the HUD.

const DASH := 9.0
const GAP := 6.0

var guardian: Guardian = null

var _tracers: Array[Dictionary] = []
var _time: float = 0.0

func _ready() -> void:
	z_index = 8
	Events.shot_fired.connect(_on_shot)

func _on_shot(from: Vector2, to: Vector2, hit: bool) -> void:
	_tracers.append({"from": from, "to": to, "hit": hit, "life": 0.34})

func _process(delta: float) -> void:
	_time += delta
	for t in _tracers:
		t["life"] = float(t["life"]) - delta
	_tracers = _tracers.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	queue_redraw()

func _draw() -> void:
	for t in _tracers:
		_draw_tracer(t)
	# is_instance_valid rather than == null: a freed node is not null, it is a
	# dangling reference, and a queued redraw can still land after the world it
	# belonged to was torn down (which is what the test suite does between
	# cases).
	if not is_instance_valid(guardian):
		return
	# On the runner's device the reticle is the guardian's, arriving over the
	# wire. Before the first aim packet there is nothing to draw, and drawing
	# anyway pinned a dashed outline to wherever the cursor was initialised.
	var hub: InputHub = guardian.input_hub
	if hub != null and not hub.shows_guardian_cursor():
		return
	var preview := guardian.current_preview()
	if preview.is_empty():
		return
	match String(preview.get("kind", "")):
		"build": _draw_build(preview)
		"snipe":
			# The scope draws its own crosshair. A second reticle in world space
			# would be magnified along with everything else and sit right on top
			# of whatever the guardian is trying to look at.
			if not guardian.scope_active:
				_draw_snipe(preview)

func _draw_build(preview: Dictionary) -> void:
	var rect: Rect2 = preview["rect"]
	var valid: bool = preview["valid"]
	var col := Balance.C_HOLO if valid else Color("ff7a55")

	var shape: PackedVector2Array = preview.get("path", PackedVector2Array())
	if shape.size() >= 2:
		# A drawn slab: its own outline, following the stroke.
		var centre_at := rect.get_center()
		var line := PackedVector2Array()
		for p in shape:
			line.append(centre_at + p)
		var thick := Balance.PLATFORM_SIZE.y
		draw_polyline(line, Color(col.r, col.g, col.b, 0.16 if valid else 0.10), thick, true)
		for i in range(line.size() - 1):
			var along := (line[i + 1] - line[i]).normalized()
			var side := Vector2(-along.y, along.x) * thick * 0.5
			_dashed_line(line[i] + side, line[i + 1] + side, Color(col.r, col.g, col.b, 0.9), 2.0)
			_dashed_line(line[i] - side, line[i + 1] - side, Color(col.r, col.g, col.b, 0.9), 2.0)
	else:
		# Faint fill so the shape is readable against busy terrain.
		draw_rect(rect, Color(col.r, col.g, col.b, 0.14 if valid else 0.10))
		_dashed_rect(rect.grow(6.0), Color(1, 1, 1, 0.75 if valid else 0.35), 1.8)
		_dashed_rect(rect, Color(col.r, col.g, col.b, 0.9), 2.0)

	if not valid:
		return
	# Drop guide: a dashed line down to whatever is below, so the guardian can
	# judge the landing without eyeballing it.
	var centre := rect.get_center()
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(centre, centre + Vector2(0, 900.0), 1)
	var hit := space.intersect_ray(query)
	var floor_y: float = hit.get("position", centre + Vector2(0, 900.0)).y if not hit.is_empty() \
		else centre.y + 900.0
	_dashed_line(Vector2(centre.x, rect.position.y + rect.size.y),
		Vector2(centre.x, floor_y), Color(1, 1, 1, 0.30), 1.4)
	# And a horizontal tie back toward the runner, matching the mockup's guides.
	if guardian.runner != null and is_instance_valid(guardian.runner):
		var rp: Vector2 = guardian.runner.global_position
		_dashed_line(Vector2(rp.x, centre.y), Vector2(rect.position.x - 8.0, centre.y),
			Color(1, 1, 1, 0.18), 1.2)

func _draw_snipe(preview: Dictionary) -> void:
	var rect: Rect2 = preview["rect"]
	var c := rect.get_center()
	var valid: bool = preview["valid"]
	var col := Balance.C_ACCENT if valid else Color("ff7a55")
	var pulse := 0.85 + 0.15 * sin(_time * 6.0)
	draw_arc(c, 20.0 * pulse, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.9), 2.0, true)
	for i in range(4):
		var a := float(i) * PI * 0.5
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 9.0, c + d * 17.0, Color(col.r, col.g, col.b, 0.9), 2.0)
	draw_circle(c, 2.4, Color(col.r, col.g, col.b, 0.95))

	# Locked on. The rifle finds a target from further away than the reticle is
	# wide, so without this the guardian has no way of knowing whether the shot
	# has something to hit -- which turns pulling the trigger back into a guess.
	if not preview.has("lock"):
		return
	var lock: Vector2 = preview["lock"]
	var ring := 26.0 + 4.0 * sin(_time * 7.0)
	var lit := Color(1.0, 0.42, 0.36, 0.95)
	for i in range(4):
		var a := float(i) * PI * 0.5 + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		# Four corner brackets, the way a camera or a targeting computer does
		# it: it reads as "this one" without covering the thing it points at.
		draw_line(lock + d * ring, lock + d * ring - Vector2(d.x, 0.0) * 11.0, lit, 2.4)
		draw_line(lock + d * ring, lock + d * ring - Vector2(0.0, d.y) * 11.0, lit, 2.4)
	if lock.distance_to(c) > 2.0:
		draw_line(c, lock, Color(lit.r, lit.g, lit.b, 0.35), 1.4)

func _draw_tracer(t: Dictionary) -> void:
	var life: float = t["life"]
	var a: float = clampf(life / 0.34, 0.0, 1.0)
	var from: Vector2 = t["from"]
	var to: Vector2 = t["to"]
	draw_line(from, to, Color(0.62, 0.94, 1.0, 0.5 * a), 2.0 + 2.0 * a)
	draw_line(from, to, Color(1, 1, 1, 0.8 * a), 1.0)
	var burst := 1.0 - a
	if bool(t["hit"]):
		# The painted impact, scaled up as it fades so the hit reads as a flash
		# rather than as a sticker that shrinks.
		var star := Art.tex("hit_burst")
		if Balance.USE_TEXTURES and star != null:
			var d := 58.0 + burst * 96.0
			var w := d * (float(star.get_width()) / maxf(float(star.get_height()), 1.0))
			draw_texture_rect(star, Rect2(to - Vector2(w, d) * 0.5, Vector2(w, d)),
				false, Color(1, 1, 1, a))
			return
		draw_circle(to, 6.0 + burst * 26.0, Color(1.0, 0.9, 0.6, 0.45 * a))
		draw_arc(to, 10.0 + burst * 30.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7 * a), 2.5, true)
	else:
		draw_circle(to, 4.0 + burst * 12.0, Color(0.7, 0.85, 1.0, 0.3 * a))

# --- dashed primitives -------------------------------------------------------

func _dashed_line(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var total := from.distance_to(to)
	if total < 0.5:
		return
	var dir := (to - from) / total
	var travelled := 0.0
	while travelled < total:
		var end := minf(travelled + DASH, total)
		draw_line(from + dir * travelled, from + dir * end, col, width)
		travelled = end + GAP

func _dashed_rect(rect: Rect2, col: Color, width: float) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0)
	var c := rect.position + rect.size
	var d := rect.position + Vector2(0, rect.size.y)
	_dashed_line(a, b, col, width)
	_dashed_line(b, c, col, width)
	_dashed_line(c, d, col, width)
	_dashed_line(d, a, col, width)
