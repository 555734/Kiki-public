class_name Hologram
extends StaticBody2D
## Base for the guardian's two constructs. Both are solid, both expire, and both
## are capped in number -- chapter 4 is explicit that the guardian must not be
## able to simply rebuild the level, so scarcity and decay are the whole design.

## WARP is a construct like the other two -- placed, capped, expiring -- but it
## is the only one that is not solid: the runner goes THROUGH it, not onto it.
enum Kind { PLATFORM, WALL, WARP }

const LAYER_HOLOGRAM := 8

static var _white: ImageTexture = null

var kind: Kind = Kind.PLATFORM
var size: Vector2 = Balance.PLATFORM_SIZE
var lifetime: float = Balance.PLATFORM_LIFETIME

## Lifetime is measured in ticks, not accumulated delta. Two devices have to
## expire the same construct on the same frame, and -- more subtly -- a platform
## the host backdated to rescue a falling runner must have *less* life left than
## one placed now. Both fall out of storing the birth and death ticks and letting
## the shared clock decide. See docs/netcode.md 5.4.
var birth_tick: int = -1
var death_tick: int = -1
## Assigned by the host so both sides can talk about the same construct.
var net_id: int = 0
## When the host actually heard about this placement, as opposed to birth_tick,
## which may have been moved into the past to compensate for the guardian's
## latency. Rescues are graded against this one: a guardian on a bad connection
## should not be marked down for the lag the host already forgave them.
var placed_tick: int = -1

## True once this gate has a partner, so the pair actually goes somewhere. Set
## by the guardian, which is what owns the pairing.
var linked: bool = false

## Platforms only: see LaunchTrigger.
var trigger: LaunchTrigger = null

var _age: float = 0.0
var _fade_in: float = 0.0
var _material: ShaderMaterial = null

## A 1x1 white texture, so draw_texture_rect gives the shader a real 0..1 UV.
## draw_rect alone does not, and the hex lattice needs one.
static func white_texture() -> ImageTexture:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white

func _ready() -> void:
	add_to_group("hologram")
	collision_mask = 0
	z_index = 5

	if kind == Kind.WARP:
		# No collider at all. A warp gate the runner could stand on would block
		# the doorway it is supposed to be, and giving it the hologram layer
		# would also make the guardian's own placement check refuse to build
		# anywhere near it.
		collision_layer = 0
	else:
		collision_layer = LAYER_HOLOGRAM
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		add_child(shape)

	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/render/shaders/hologram.gdshader")
	# The painted slab needs no shader; keeping it attached would tint the sprite.
	if Balance.USE_TEXTURES and Art.tex(_texture_key()) != null:
		_material = null
	if _material != null:
		_material.set_shader_parameter("rect_size", size)
		_material.set_shader_parameter("cell_px", 15.0 if kind == Kind.PLATFORM else 17.0)
	if _material != null:
		_material.set_shader_parameter("tint", Balance.C_HOLO)
		material = _material

	if kind == Kind.PLATFORM:
		# The thing the guardian shoots to throw the runner off this slab. Part
		# of the construct rather than a separate placeable: a platform without
		# one would be a second kind of platform to think about, and the whole
		# design here is fewer tools used more ways.
		trigger = LaunchTrigger.new()
		trigger.name = "LaunchTrigger"
		trigger.position = Vector2(0.0, -size.y * 0.5 - Balance.LAUNCH_TRIGGER_LIFT)
		add_child(trigger)

	Events.hologram_spawned.emit(int(kind), global_position)

func _texture_key() -> String:
	match kind:
		Kind.PLATFORM: return "platform"
		Kind.WALL: return "wall"
		_: return "warp_gate"

func _process(delta: float) -> void:
	if birth_tick < 0:
		birth_tick = Clock.tick
	if death_tick < 0:
		death_tick = birth_tick + Clock.ticks_for(lifetime)
	_age = float(Clock.tick - birth_tick) * Clock.DT
	_fade_in = minf(1.0, _fade_in + delta / maxf(Balance.PLACE_FADE_IN, 0.001))
	var remaining := float(death_tick - Clock.tick) * Clock.DT
	if remaining <= 0.0:
		expire()
		return
	if _material != null:
		_material.set_shader_parameter("fade", _fade_in)
		# The last second is the warning window.
		_material.set_shader_parameter("expiring", clampf(1.0 - remaining, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	if Balance.USE_TEXTURES:
		# The painted slab already carries the hex lattice, so the shader is not
		# needed -- but the expiry warning is, since the runner has to be able to
		# see a platform is about to go without reading a timer.
		var warn := clampf(1.0 - remaining_time(), 0.0, 1.0)
		var flash := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 34.0, warn))
		var tint := Color(1, 1, 1, _fade_in).lerp(
			Color(1.0, 0.86, 0.35, _fade_in * 0.85), warn * flash * 0.7)
		if kind == Kind.WARP:
			# An unpaired gate is drawn amber: it is placed but it goes nowhere
			# yet, and the guardian has to be able to see that at a glance rather
			# than by counting their own gates.
			if not linked:
				tint = tint.lerp(Color(1.0, 0.72, 0.30, tint.a), 0.75)
			if Art.draw_stretched(self, "warp_gate",
					Rect2(-size * 0.5 - Vector2(10, 10), size + Vector2(20, 20)), tint):
				return
		elif Art.draw_stretched(self, _texture_key(),
				Rect2(-size * 0.5 - Vector2(6, 6), size + Vector2(12, 12)), tint):
			return
	draw_texture_rect(white_texture(), Rect2(-size * 0.5, size), false)

func remaining_time() -> float:
	if death_tick < 0:
		return lifetime
	return maxf(0.0, float(death_tick - Clock.tick) * Clock.DT)

func expire() -> void:
	Events.hologram_expired.emit(int(kind))
	queue_free()

## Ability slot -> construct. The host, the client's optimistic ghost and the
## HUD all need this mapping, and three copies of it is three chances for the
## client to draw a wall where the host built a gate.
static func kind_for_slot(slot: int) -> Kind:
	match slot:
		1: return Kind.PLATFORM
		2: return Kind.WALL
		_: return Kind.WARP

static func create(p_kind: Kind, at: Vector2, width: float = 0.0) -> Hologram:
	var holo := Hologram.new()
	holo.kind = p_kind
	match p_kind:
		Kind.PLATFORM:
			holo.size = Balance.PLATFORM_SIZE
			if width > 0.0:
				holo.size.x = clampf(width, Balance.TRACE_MIN_WIDTH, Balance.TRACE_MAX_WIDTH)
			holo.lifetime = Balance.PLATFORM_LIFETIME
		Kind.WALL:
			holo.size = Balance.WALL_SIZE
			holo.lifetime = Balance.WALL_LIFETIME
			holo.add_to_group("blocks_projectiles")
		_:
			holo.size = Balance.WARP_SIZE
			holo.lifetime = Balance.WARP_LIFETIME
	holo.global_position = at
	holo.birth_tick = Clock.tick
	holo.death_tick = holo.birth_tick + Clock.ticks_for(holo.lifetime)
	holo.placed_tick = Clock.tick
	return holo
