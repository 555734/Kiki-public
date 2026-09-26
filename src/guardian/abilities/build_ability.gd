class_name BuildAbility
extends GuardianAbility
## Shared behaviour for the two constructs. The only differences between a
## platform and a wall are size, lifetime, and how many may exist at once, so
## they are one class parameterised rather than two near-identical ones.

var kind: Hologram.Kind = Hologram.Kind.PLATFORM
var size: Vector2 = Balance.PLATFORM_SIZE
var max_alive: int = Balance.PLATFORM_MAX_ALIVE

func check(guardian: Node, world_pos: Vector2) -> String:
	# The gauge is the constraint now, on its own. Building used to be refused
	# while the scope was up, because raising the scope was how you selected the
	# sniper; with a button per tool that refusal would only mean an ability
	# button that ignores the first press. See Guardian.set_scope.
	if guardian.gauge < cost:
		return "gauge"
	if guardian.runner != null:
		if world_pos.distance_to(guardian.runner.global_position) > Balance.PLACE_MAX_RANGE:
			return "range"
	if _blocked(guardian, world_pos):
		return "blocked"
	return ""

func execute(guardian: Node, world_pos: Vector2) -> void:
	var live: Array = guardian.holograms_of(kind)
	# Chapter 4: "placing a third removes the oldest". Recycling rather than
	# refusing keeps the guardian moving instead of bookkeeping.
	while live.size() >= max_alive:
		var oldest: Hologram = live.pop_front()
		if is_instance_valid(oldest):
			# Tell the other device, too: platforms no longer expire on a shared
			# timer, so without this the guardian's screen kept every one.
			if Clock.is_host and oldest.net_id > 0:
				Events.hologram_revoked.emit(oldest.net_id)
			oldest.expire()
	var holo := Hologram.create(kind, world_pos, _path(guardian))
	guardian.spawn_hologram(holo)

## The platform's shape for this placement, relative to its centre: the traced
## stroke's, or the standard level slab.
func _path(guardian: Node) -> PackedVector2Array:
	if kind != Hologram.Kind.PLATFORM:
		return PackedVector2Array()
	var traced = guardian.get("place_path")
	if traced is PackedVector2Array and (traced as PackedVector2Array).size() >= 2:
		return traced
	return Hologram.standard_path()

func preview(guardian: Node, world_pos: Vector2) -> Dictionary:
	var drawn := size
	var out := {"kind": "build", "valid": check(guardian, world_pos) == ""}
	if kind == Hologram.Kind.PLATFORM:
		var shape := _path(guardian)
		drawn = Hologram.path_size(shape)
		out["path"] = shape
	out["rect"] = Rect2(world_pos - drawn * 0.5, drawn)
	return out

## A construct may not be spawned inside terrain or inside another construct.
##
## The runner is a blocker for a WALL and deliberately not for a PLATFORM, and
## the difference matters more than it looks. A wall is 190px tall: materialising
## one around the runner traps them, and chapter 4 only calls blocking their
## *path* part of the comedy. A platform is a 26px slab, and putting it under a
## falling runner is the entire point of the game -- so counting the runner as
## an obstacle refused the rescue exactly when it was needed.
##
## That was not theoretical. The first end-to-end network test failed with
## "blocked" precisely because the runner was falling through the spot the
## guardian had aimed at, which is the case the whole design exists to serve. A
## thin slab appearing around a falling body is resolved upward by move_and_slide,
## so the outcome is a landing rather than a trap.
func _blocked(guardian: Node, world_pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = guardian.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1 | 8              # terrain | hologram
	if kind == Hologram.Kind.WALL:
		query.collision_mask |= 2             # ...and the runner, for a wall
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if kind == Hologram.Kind.PLATFORM:
		# A drawn slab is tested piece by piece, with the same shapes it will
		# be built from, each a little smaller so touching is not overlapping.
		var hit := false
		for piece in Hologram.path_shapes(_path(guardian)):
			var shape: Shape2D = piece.shape
			if shape is RectangleShape2D:
				(shape as RectangleShape2D).size -= Vector2(4, 4)
			elif shape is CircleShape2D:
				(shape as CircleShape2D).radius -= 2.0
			if not hit:
				query.shape = shape
				query.transform = Transform2D(piece.rotation, world_pos + piece.position)
				hit = not space.intersect_shape(query, 1).is_empty()
			piece.free()
		return hit
	var rect := RectangleShape2D.new()
	rect.size = size - Vector2(4, 4)
	query.shape = rect
	query.transform = Transform2D(0.0, world_pos)
	return not space.intersect_shape(query, 1).is_empty()

static func platform() -> BuildAbility:
	var a := BuildAbility.new()
	a.slot = 1
	a.cost = Balance.COST_PLATFORM
	a.display_name = "Platform"
	a.kind = Hologram.Kind.PLATFORM
	a.size = Balance.PLATFORM_SIZE
	a.max_alive = Balance.PLATFORM_MAX_ALIVE
	return a

static func wall() -> BuildAbility:
	var a := BuildAbility.new()
	a.slot = 2
	a.cost = Balance.COST_WALL
	a.display_name = "Wall"
	a.kind = Hologram.Kind.WALL
	a.size = Balance.WALL_SIZE
	a.max_alive = Balance.WALL_MAX_ALIVE
	return a
