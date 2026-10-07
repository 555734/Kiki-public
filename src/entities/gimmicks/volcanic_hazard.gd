class_name VolcanicHazard
extends Area2D
## Telegraph -> eruption/fall -> cooldown. Every pose and collider is a pure
## function of Clock.tick, including on guests and after checkpoint rebuilds.
@export_enum("geyser", "meteor") var kind := "geyser"
@export var travel := Vector2(0, -230)
@export var width := 64.0
@export var period := 4.8
@export var phase_offset := 0.0
var _shape: CollisionShape2D

static func from_spec(spec: Dictionary, _runner: Runner) -> Node2D:
	var node := VolcanicHazard.new()
	node.kind = String(spec.get("kind", "geyser"))
	node.travel = spec.get("travel", Vector2(0, -230))
	node.width = float(spec.get("width", 64.0))
	node.period = float(spec.get("period", 4.8))
	node.phase_offset = float(spec.get("phase", 0.0))
	return node

func _ready() -> void:
	add_to_group("instant_death")
	collision_mask = 0
	process_physics_priority = -50
	z_index = 5
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	sync_at(Clock.tick)

func state_at(at_tick: int) -> Dictionary:
	var beat := fposmod(Clock.seconds_at(at_tick, phase_offset), period)
	var warning := beat >= 0.2 and beat < 1.4
	var active := beat >= 1.4 and beat < 2.6
	var rect := Rect2(-width * 0.5, -8, width, 8)
	var head := Vector2.ZERO
	if kind == "geyser":
		var extent := 0.0
		if active:
			extent = minf(1.0, (beat - 1.4) / 0.25) * minf(1.0, (2.6 - beat) / 0.3)
		# Sprite droplets/glow spread farther than the continuous molten core.
		var core_width := width * 0.6
		rect = Rect2(-core_width * 0.5, -maxf(1, -travel.y * extent), core_width, maxf(1, -travel.y * extent))
	else:
		# Fall once, never rewind through the player. The tail is cosmetic;
		# only the clearly visible basalt head is lethal.
		var t := clampf((beat - 1.4) / 0.7, 0.0, 1.0)
		head = travel * t * t
		rect = Rect2(head - Vector2.ONE * width * 0.5, Vector2.ONE * width)
		active = beat >= 1.4 and beat < 2.25
	return {"warning": warning, "active": active, "rect": rect, "head": head}

func sync_at(at_tick: int) -> void:
	var state := state_at(at_tick)
	var rect: Rect2 = state["rect"]
	_shape.position = rect.get_center()
	(_shape.shape as RectangleShape2D).size = rect.size
	collision_layer = Hazard.LAYER_HAZARD if state["active"] else 0

func _physics_process(_delta: float) -> void:
	sync_at(Clock.tick)
	var camera := get_viewport().get_camera_2d()
	var visible_box := Rect2(global_position - Vector2(160, 350), Vector2(320, 400)).merge(
		Rect2(global_position + travel - Vector2(160, 180), Vector2(320, 360)))
	if camera == null or visible_box.grow(850).has_point(camera.global_position): queue_redraw()

func _draw() -> void:
	var state := state_at(Clock.tick)
	var target := travel + Vector2(0, width * 0.5) if kind == "meteor" else Vector2.ZERO
	if state["warning"]:
		# A persistent landing mark and pulsing chevrons precede danger by 1.2s.
		var pulse := 0.65 + 0.35 * sin(Clock.seconds() * 12)
		draw_line(target - Vector2(width * 0.65, 0), target + Vector2(width * 0.65, 0), Color(1, 0.75, 0.25, pulse), 5)
		for i in 3:
			var at := target - Vector2(0, 15 + i * 15)
			draw_polyline(PackedVector2Array([at + Vector2(-9, -6), at, at + Vector2(9, -6)]), Color("ffd15a"), 3, true)
	if kind == "geyser":
		draw_ellipse_vent()
		if state["active"]:
			var r: Rect2 = state["rect"]
			var painting := Rect2(-width * 1.2, r.position.y, width * 2.4, r.size.y)
			if not Art.draw_stretched(self, "s15_eruption", painting): draw_rect(r, Color("fa792a"))
	elif state["active"]:
		var head: Vector2 = state["head"]
		if not Art.draw_stretched(self, "s15_meteor", Rect2(head - Vector2(width * 0.5, width * 1.4), Vector2(width, width * 1.9))):
			draw_circle(head, width * 0.5, Color("dd6634"))

func draw_ellipse_vent() -> void:
	draw_rect(Rect2(-width * 0.65, -8, width * 1.3, 16), Color("522733"))
	draw_rect(Rect2(-width * 0.5, -5, width, 8), Color("f5802b"))
