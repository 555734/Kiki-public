class_name SniperAbility
extends GuardianAbility
## Chapter 4: the sniper is not a weapon for clearing the level, it is a tool
## for deleting exactly one danger or triggering one mechanism. It is a hitscan
## on whatever sits under the reticle -- no ballistics, no line of sight -- so
## that the interesting decision is *what* to shoot and when, not whether the
## shot will connect.

const HIT_RADIUS := 26.0

## How far off the reticle the rifle will still find a target.
##
## A thumb on a phone is not a mouse. Under the old rule the reticle had to
## land within 26px of an enemy's body, which on a 5" screen at this zoom is
## about a fingertip -- so "aim, then fire" was a precision exercise on a
## moving target, using the same thumb that had just come off a button.
##
## Console and mobile shooters all do this and they do it for the reason that
## applies here: the interesting decision is WHAT to shoot and when, which is
## what chapter 4 says the rifle is for. Whether the thumb landed within a
## fingertip of a mushroom is not a decision, it is a tax. It stays honest
## because the rifle still costs gauge, still has a cooldown, and still cannot
## reach anything that is not already on the reticle's side of the screen.
const ASSIST_RADIUS := 110.0

var cooldown: float = 0.0

func _init() -> void:
	slot = 3
	cost = Balance.COST_SNIPE
	display_name = "Snipe"

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func check(guardian: Node, _world_pos: Vector2) -> String:
	if guardian.gauge < cost:
		return "gauge"
	if cooldown > 0.0:
		return "cooldown"
	return ""

func execute(guardian: Node, world_pos: Vector2) -> void:
	cooldown = Balance.SNIPE_COOLDOWN
	var target := target_at(guardian, world_pos)
	var at := world_pos
	if target != null:
		# The tracer goes to what was actually hit, not to where the thumb was.
		# A shot that visibly lands beside a dying enemy reads as a bug even
		# when the enemy dies, which is worse than missing.
		at = (target as Node2D).global_position
		target.take_damage(Balance.SNIPE_DAMAGE, "snipe")
	Events.shot_fired.emit(guardian.tracer_origin(at), at, target != null)

## What the rifle would hit from here, or null.
##
## Two passes. Anything actually under the reticle wins; only if nothing is does
## the assist radius come into play, and then the nearest one. That ordering
## matters when two enemies are close together -- the one being pointed at is
## the one that gets shot.
func target_at(guardian: Node, world_pos: Vector2) -> Node:
	var exact := _nearest(guardian, world_pos, HIT_RADIUS)
	return exact if exact != null else _nearest(guardian, world_pos, ASSIST_RADIUS)

func _nearest(guardian: Node, world_pos: Vector2, radius: float) -> Node:
	var space: PhysicsDirectSpaceState2D = guardian.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0.0, world_pos)
	query.collision_mask = 4 | 64   # enemy | shootable
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var target: Node = null
	var best := INF
	for hit in space.intersect_shape(query, 16):
		var collider = hit.get("collider")
		if collider == null or not (collider is Node2D):
			continue
		if not collider.has_method("take_damage"):
			continue
		# The assist must not reach past what it is pointed at.
		#
		# A target can be present and not shootable: a launch trigger with
		# nobody aboard, a shield-bearer's weak point while the shield is
		# between it and the shot. Letting the assist snap to one of those
		# would spend the shot on nothing and, worse, would take the aim off
		# the thing the guardian actually meant -- so they are not candidates
		# at all rather than candidates that fail afterwards.
		if collider.has_method("is_shootable_now") and not collider.is_shootable_now():
			continue
		var d: float = (collider as Node2D).global_position.distance_to(world_pos)
		if d < best:
			best = d
			target = collider
	return target

func preview(guardian: Node, world_pos: Vector2) -> Dictionary:
	# The lock is the whole point of showing a preview at all: it is the game
	# saying "this one", before the trigger, so firing is a decision rather
	# than a guess.
	var target := target_at(guardian, world_pos)
	var out := {
		"kind": "snipe",
		"rect": Rect2(world_pos - Vector2(HIT_RADIUS, HIT_RADIUS),
			Vector2(HIT_RADIUS, HIT_RADIUS) * 2.0),
		"valid": check(guardian, world_pos) == "",
	}
	if target != null and is_instance_valid(target):
		out["lock"] = (target as Node2D).global_position
	return out

## Shots the current gauge affords, capped for the HUD. Mockup 3 shows a "3/3"
## magazine; rather than bolt a second resource onto the design, the readout is
## derived from the one gauge the design document specifies.
static func ammo_for(gauge: float) -> int:
	if Balance.COST_SNIPE <= 0.0:
		return Balance.SNIPE_AMMO_DISPLAY_CAP   # unlimited
	return mini(int(floor(gauge / Balance.COST_SNIPE)), Balance.SNIPE_AMMO_DISPLAY_CAP)
