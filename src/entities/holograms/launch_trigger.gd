class_name LaunchTrigger
extends Area2D
## The part of a platform the guardian can shoot, to throw the runner off it.
##
## This is the move the whole co-op idea is for: neither player can do it alone
## and neither is waiting on the other. The guardian puts a slab where the gap
## needs one, the runner gets onto it and points the way they want to go, and
## the guardian shoots the trigger. The runner leaves at a fixed angle, far
## further than any jump, in the direction the RUNNER chose.
##
## It is deliberately not a fourth button. Chapter 4 already gives the guardian
## a rifle; asking them to learn a launcher as well would be another control for
## the same hand, and the rifle is already the thing they aim. So the launcher
## is something in the world to aim AT, which also means the runner can see it,
## which is what lets the two of them agree on the plan without saying a word.

## Bright, and above the deck rather than on it. A 26px slab with a runner
## standing on it has no free pixels left, and a trigger that the runner covers
## is a trigger the guardian cannot take.
const RING := Color(1.0, 0.78, 0.25)
const RING_READY := Color(0.55, 1.0, 0.72)
const RING_SPENT := Color(0.45, 0.48, 0.55)

## Set by the guardian when the construct is spawned, on both devices.
var runner: Runner = null

## One launch per slab. A platform that could be fired twice would let a pair
## ladder their way up a single slab, and the placement -- which is what costs
## gauge -- would stop being the decision.
var armed: bool = true

var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("launch_trigger")
	# The layer the rifle already looks at, so nothing about aiming changes.
	collision_layer = 64
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Balance.LAUNCH_TRIGGER_RADIUS
	shape.shape = circle
	add_child(shape)
	# Over the runner, who is at 10. The marker is the one thing on this slab
	# that must stay readable with somebody standing on it.
	z_index = 12

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

## Whether the runner is actually standing on the slab this trigger belongs to.
##
## Both players can see this -- the ring changes colour -- so "get on it" and
## "now" do not have to be said out loud.
func loaded() -> bool:
	if runner == null or not is_instance_valid(runner) or not armed:
		return false
	if not runner.on_ground():
		return false
	var slab := get_parent()
	if slab == null or not (slab is Hologram):
		return false
	var deck: Hologram = slab
	var feet: Vector2 = runner.global_position \
		+ Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
	# Standing on the slab means feet resting on its top surface: half its
	# thickness from the centre line, and above it rather than beside or
	# under it. This holds for a drawn slab at any slope.
	var off := deck.surface_distance(feet) - Balance.PLATFORM_SIZE.y * 0.5
	if absf(off) > Balance.LAUNCH_FOOTING:
		return false
	return deck.is_above_surface(feet)

## Shot. The rifle finds this the same way it finds an enemy, so there is no
## second aiming path to keep in step.
##
## A shot with nobody aboard does NOT spend the trigger. The gauge is gone
## either way -- that is the cost of being early -- but the slab is still there
## to try again, which is the difference between a mistimed shot and a wasted
## platform.
func take_damage(_amount: int, _by: String = "snipe") -> void:
	# The host owns the runner. A client that threw its own puppet would be
	# overwritten by the next snapshot, which reads as the runner twitching.
	if not Clock.is_host or not loaded():
		return
	armed = false
	runner.launch(Runner.launch_velocity(runner.facing))

## The host has thrown the runner from somewhere: work out which slab it was and
## put that marker out.
##
## Nothing on the guardian's device spends a trigger locally -- the host decides,
## and take_damage refuses outright when it is not the host -- so without this
## the ring stays lit on the guardian's screen while it is dead on the runner's.
## Both players can see "loaded", which is what lets them agree on the timing
## without saying a word; a marker that lies about it is worse than no marker,
## because the plan gets made around a slab that will not fire.
##
## The launch position is the runner's own, taken with their feet on the deck,
## so the nearest armed trigger is the one that did it.
static func spend_nearest(tree: SceneTree, at: Vector2) -> void:
	var best: LaunchTrigger = null
	var closest := INF
	for t in tree.get_nodes_in_group("launch_trigger"):
		if not (t is LaunchTrigger) or not (t as LaunchTrigger).armed:
			continue
		var d: float = (t as LaunchTrigger).global_position.distance_to(at)
		if d < closest:
			closest = d
			best = t
	# Generous, but not unbounded. A slab is 150 wide with the marker above it,
	# so a launch off THIS slab is comfortably inside; a launch from somewhere
	# else must not put out a marker the guardian is still aiming at.
	if best != null and closest <= Balance.PLATFORM_SIZE.x:
		best.armed = false

## The rifle's assist must not lock onto a trigger that cannot do anything --
## one already spent, or one with nobody on it while an enemy stands nearby.
func is_shootable_now() -> bool:
	return loaded()

func _draw() -> void:
	var r := Balance.LAUNCH_TRIGGER_RADIUS
	var ready := loaded()
	var colour := RING_SPENT if not armed else (RING_READY if ready else RING)
	# A ring rather than a disc: the guardian has to be able to see the slab and
	# the runner through it.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, colour, 3.0, true)
	if armed:
		var breath := 0.5 + 0.5 * sin(_pulse * (6.0 if ready else 2.4))
		draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 24,
			Color(colour, 0.25 + 0.45 * breath), 2.0, true)
	if not ready:
		return
	# Where they will go, drawn from the trigger and pointing the way the
	# runner is facing. Both devices draw this from the same two facts -- the
	# runner is on the slab, and which way they are facing -- so the arrow the
	# guardian is timing against is the arrow the runner can see.
	var away := Runner.launch_velocity(runner.facing).normalized()
	var from := away * (r + 4.0)
	var to := away * (r + 34.0)
	draw_line(from, to, RING_READY, 4.0, true)
	var wing := away.orthogonal() * 9.0
	draw_line(to, to - away * 12.0 + wing, RING_READY, 4.0, true)
	draw_line(to, to - away * 12.0 - wing, RING_READY, 4.0, true)
