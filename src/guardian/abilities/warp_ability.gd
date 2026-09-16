class_name WarpAbility
extends GuardianAbility
## Slot 4. A pair of gates: the runner entering either comes out of the other.
##
## This is the guardian's only tool that MOVES the runner instead of giving them
## somewhere to stand, so it is the one most capable of turning the runner into
## a passenger -- exactly what chapter 4 forbids. Three things keep it honest:
##
## 1. It takes two presses and two charges. 44 of a 100 gauge for one working
##    pair, more than a platform and a wall together.
## 2. Each gate expires on its own clock from the moment it is placed, so the
##    guardian cannot leave a mouth parked somewhere useful and come back to it.
## 3. Both mouths are inside PLACE_MAX_RANGE of the runner, so a gate cannot
##    reach ahead into a part of the stage nobody has arrived at yet.
##
## What it is *for* is the case the other three tools answer badly: the runner is
## committed to a fall, or shut behind a closing gate, or pinned on a ledge under
## fire. A platform gives them a floor; the warp gives them somewhere else to be.

func check(guardian: Node, world_pos: Vector2) -> String:
	if guardian.gauge < cost:
		return "gauge"
	if guardian.runner != null:
		if world_pos.distance_to(guardian.runner.global_position) > Balance.PLACE_MAX_RANGE:
			return "range"
	if _in_terrain(guardian, world_pos):
		return "blocked"
	return ""

func execute(guardian: Node, world_pos: Vector2) -> void:
	# The pair rule -- at most two, and a third press starts a fresh pair -- is
	# enforced in Guardian.spawn_hologram rather than here, so that a gate
	# arriving over the network on the guardian's own device obeys it too
	# without a packet having to say so.
	guardian.spawn_hologram(Hologram.create(Hologram.Kind.WARP, world_pos))

func preview(guardian: Node, world_pos: Vector2) -> Dictionary:
	return {
		"kind": "build",
		"rect": Rect2(world_pos - Balance.WARP_SIZE * 0.5, Balance.WARP_SIZE),
		"valid": check(guardian, world_pos) == "",
	}

## A gate inside the ground is a gate nobody can walk into. Only terrain counts:
## unlike a platform or a wall, a gate is not solid, so it may legitimately
## overlap the runner, an enemy or another construct.
##
## The probe is the ARCHWAY, not the frame, and it sits in the upper half of the
## gate. That is not a fudge -- it is where the opening is. A gate standing on a
## ledge has its stone feet in that ledge by definition, so testing the whole
## rect refused every gate placed the obvious way, on the ground the guardian
## was pointing at. Testing the opening refuses the case that actually matters,
## a gate buried in rock, and allows the one the player will try first.
func _in_terrain(guardian: Node, world_pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = guardian.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Balance.WARP_SIZE * Vector2(0.45, 0.40)
	query.shape = rect
	query.transform = Transform2D(0.0,
		world_pos - Vector2(0.0, Balance.WARP_SIZE.y * 0.20))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_shape(query, 1).is_empty()

static func make() -> WarpAbility:
	var a := WarpAbility.new()
	a.slot = 4
	a.cost = Balance.COST_WARP
	a.display_name = "Warp"
	return a
