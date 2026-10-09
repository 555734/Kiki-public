class_name GuardianHand
extends RefCounted
## The guardian's finger, acting on the world directly.
##
## The tools (platform, wall, rifle, warp) are chosen and then placed. The hand
## is the other half: the finger lands ON something and the thing is the tool.
##
##   the runner, standing   pull back and let go: a slingshot
##   a big enemy            flick it: it is thrown off the screen
##   a bullet               pinch it: let go and it goes home to its turret
##   a boulder              press it: it stays still while the finger does
##   a gate                 hold it: it stays up until the finger lets go
##   fliers                 a quick swipe across them sweeps them away
##
## InputHub only reports what the finger did (grab / release / swipe). This
## turns that into an act, and the act is applied where the world is owned:
## here offline, on the host when online (Protocol.hand), exactly like a tool.

enum Act { NONE, SLING, FLICK, CATCH, THROW, HOLD, LET_GO, SWIPE }

var guardian: Guardian

func _init(owner: Guardian) -> void:
	guardian = owner

# ------------------------------------------------------------------ finding

## Where the guardian's finger is on this device: their own aim on their
## device, the aim that arrives over the wire on the other. A bullet held in
## the fingers sits there, and a dark room is lit there.
static func finger_point(tree: SceneTree) -> Vector2:
	if tree == null:
		return Vector2(INF, INF)
	var g := tree.get_first_node_in_group("guardian") as Guardian
	if g == null or g.input_hub == null:
		return Vector2(INF, INF)
	return g.input_hub.aim_world()

## What a finger landing on `world` takes hold of, or {} for nothing -- then
## the finger aims and draws as it always has. Nearest kind first: a bullet is
## smaller than the turret behind it, and what the finger is on is what it means.
static func target_at(g: Guardian, world: Vector2) -> Dictionary:
	var tree := g.get_tree()
	if tree == null:
		return {}
	var best: Node2D = null
	var closest := INF
	for node in tree.get_nodes_in_group("projectile"):
		var p := node as Projectile
		if p == null or p.state != Projectile.State.FLYING or p.is_queued_for_deletion():
			continue
		var d := p.global_position.distance_to(world)
		if d <= Balance.HAND_GRAB_PROJECTILE and d < closest:
			closest = d
			best = p
	if best != null:
		return {"kind": "projectile", "id": (best as Projectile).net_id, "node": best}
	for node in tree.get_nodes_in_group("hand_holdable"):
		if node.has_method("hand_grab_at") and node.hand_grab_at(world):
			return {"kind": "holdable", "id": int(node.hand_id), "node": node}
	for node in tree.get_nodes_in_group("flickable"):
		var e := node as Enemy
		if e == null or e.hp <= 0 or e.is_queued_for_deletion() or not e.visible:
			continue
		var d := e.global_position.distance_to(world)
		if d <= e.hand_radius() and d < closest:
			closest = d
			best = e
	if best != null:
		return {"kind": "enemy", "id": (best as Enemy).net_id, "node": best}
	var r := g.runner
	if r != null and is_instance_valid(r) and r.state != Runner.State.DEAD \
			and r.is_on_floor() and r.global_position.distance_to(world) <= Balance.HAND_GRAB_RUNNER:
		return {"kind": "runner", "id": 0, "node": r}
	return {}

## The fliers a swipe along `points` sweeps away.
static func swipe_hits(tree: SceneTree, points: PackedVector2Array) -> Array:
	var out: Array = []
	if points.size() < 2:
		return out
	for node in tree.get_nodes_in_group("swipeable"):
		var e := node as Enemy
		if e == null or e.hp <= 0 or e.is_queued_for_deletion():
			continue
		for i in range(1, points.size()):
			var near := Geometry2D.get_closest_point_to_segment(e.global_position, points[i - 1], points[i])
			if near.distance_to(e.global_position) <= Balance.SWIPE_REACH:
				out.append(e)
				break
	return out

## The slingshot's throw for a pull from `from` (where the finger took hold)
## to `to` (where it let go): the opposite way, harder the further it went.
static func sling_velocity(from: Vector2, to: Vector2) -> Vector2:
	var pull := from - to
	var length := pull.length()
	if length < Balance.SLING_MIN_PULL:
		return Vector2.ZERO
	var k := clampf(length / Balance.SLING_MAX_PULL, 0.0, 1.0)
	return pull / length * Balance.SLING_SPEED * lerpf(0.45, 1.0, k)

# ------------------------------------------------------------------ deciding

## Turn what the finger did into acts. Returns true when a swipe swept
## something away -- the stroke was a swipe, so the platform the same stroke
## may have drawn is not placed.
func handle(events: Array) -> bool:
	var swept := false
	for e in events:
		match String(e["type"]):
			"grab":
				var t: Dictionary = e["target"]
				match String(t.get("kind", "")):
					"projectile":
						_act(Act.CATCH, int(t["id"]), e["at"], Vector2.ZERO)
					"holdable":
						_act(Act.HOLD, int(t["id"]), e["at"], Vector2.ZERO)
			"release":
				var t: Dictionary = e["target"]
				var cancelled := bool(e.get("cancelled", false))
				var v: Vector2 = e["velocity"]
				match String(t.get("kind", "")):
					"projectile":
						_act(Act.THROW, int(t["id"]), e["at"], v)
					"holdable":
						_act(Act.LET_GO, int(t["id"]), e["at"], Vector2.ZERO)
					"runner":
						if not cancelled and sling_velocity(e["from"], e["at"]) != Vector2.ZERO:
							_act(Act.SLING, 0, e["from"], e["at"])
					"enemy":
						if not cancelled and v.length() >= Balance.FLICK_MIN_SPEED:
							_act(Act.FLICK, int(t["id"]), e["at"], v)
			"swipe":
				var points: PackedVector2Array = e["points"]
				if not swipe_hits(guardian.get_tree(), points).is_empty():
					_act(Act.SWIPE, 0, points[0], points[points.size() - 1], points)
					swept = true
	return swept

func _act(act: int, id: int, a: Vector2, b: Vector2,
		points: PackedVector2Array = PackedVector2Array()) -> void:
	if guardian.command_router != null:
		guardian.command_router.request_hand(act, id, a, b, points)
	else:
		apply(guardian, act, id, a, b, points)

# ------------------------------------------------------------------ acting

## Do it. Offline, or on the host for the guardian's device; the other device
## hears the outcome (a kill, a hold, a bullet's new course, the runner's flight).
static func apply(g: Guardian, act: int, id: int, a: Vector2, b: Vector2,
		points: PackedVector2Array = PackedVector2Array()) -> void:
	var tree := g.get_tree()
	match act:
		Act.SLING:
			var r := g.runner
			if r == null or r.state == Runner.State.DEAD or not r.is_on_floor():
				return
			var v := sling_velocity(a, b)
			if v == Vector2.ZERO:
				return
			r.sling(v)
			Events.runner_slung.emit(r.global_position, v)
		Act.FLICK:
			var e := enemy_named(tree, id)
			if e != null and e.is_flickable():
				e.flick(b.normalized() if b.length_squared() > 0.01 else Vector2.UP)
		Act.CATCH:
			var p := projectile_named(tree, id)
			if p != null:
				p.catch()
		Act.THROW:
			var p := projectile_named(tree, id)
			if p != null:
				p.throw_back(b)
		Act.HOLD:
			var h := holdable_named(tree, id)
			if h != null:
				h.hold_begin(Clock.tick)
				Events.hand_hold_changed.emit(h)
		Act.LET_GO:
			var h := holdable_named(tree, id)
			if h != null:
				h.hold_end(Clock.tick)
				Events.hand_hold_changed.emit(h)
		Act.SWIPE:
			var hits := swipe_hits(tree, points)
			for e in hits:
				(e as Enemy).sweep()
			if not hits.is_empty():
				Events.hand_swiped.emit(points)

static func enemy_named(tree: SceneTree, id: int) -> Enemy:
	for node in tree.get_nodes_in_group("enemy"):
		if node is Enemy and (node as Enemy).net_id == id and not node.is_queued_for_deletion():
			return node
	return null

static func projectile_named(tree: SceneTree, id: int) -> Projectile:
	for node in tree.get_nodes_in_group("projectile"):
		if node is Projectile and (node as Projectile).net_id == id and not node.is_queued_for_deletion():
			return node
	return null

static func holdable_named(tree: SceneTree, id: int) -> Node2D:
	for node in tree.get_nodes_in_group("hand_holdable"):
		if int(node.hand_id) == id:
			return node
	return null
