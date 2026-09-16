class_name Crystal
extends Node2D
## The runner's half of the gauge.
##
## Everything else in this game flows one way: the guardian spends, the runner
## benefits. That makes the runner a passenger in the one system the whole
## partnership runs on. A crystal is the return leg -- the runner goes and gets
## it, and the guardian can afford the next thing.
##
## The loop the stage is built around is: the guardian puts a platform somewhere
## the runner could not reach, the runner uses it to fetch a crystal, and the
## gauge that comes back pays for the platform after this one. Neither of them
## can run that loop alone, and it is the reason a crystal is worth a detour
## rather than being free money on the path.
##
## Regeneration still exists and still covers the basics. A crystal is not what
## keeps a pair solvent -- it is what lets them be extravagant, which is the
## difference between surviving a section and choosing how to beat it.

## Big enough to be worth crossing for, small enough that one does not pay for a
## whole section. Regeneration covers the basics; this buys a decision.
const RADIUS := 30.0

## Its name on both devices, from the order it appears in the level data. The
## same reasoning as the enemies: an index into a live list changes the moment
## anything is taken, and then the two devices are talking about different
## things. See Enemy.net_id.
var net_id: int = -1
var amount: float = 0.0
var runner: Runner = null

var _taken: bool = false
var _spin: float = 0.0

func _ready() -> void:
	z_index = 4
	add_to_group("crystal")
	_spin = float(int(global_position.x)) * 0.013

func _process(delta: float) -> void:
	_spin += delta * 2.2
	queue_redraw()
	if _taken or runner == null or not is_instance_valid(runner):
		return
	# The HOST decides. On the guardian's device the runner is a puppet whose
	# position arrives in snapshots, so a local check there would be reading the
	# host's own answer a few ticks late and could disagree at the edge of the
	# radius -- and then one device has spent a crystal the other still has.
	if not Clock.is_host:
		return
	if runner.global_position.distance_to(global_position) > RADIUS:
		return
	Events.crystal_reached.emit(self)

## Taking it is separate from touching it, because only the host may decide and
## the guardian's device has to be told rather than work it out.
func collect() -> void:
	if _taken:
		return
	_taken = true
	visible = false
	set_process(false)

func taken() -> bool:
	return _taken

func _draw() -> void:
	if _taken:
		return
	var lift := sin(_spin) * 4.0
	var centre := Vector2(0.0, lift)
	var tall := RADIUS * 0.62
	var wide := RADIUS * 0.36
	var points := PackedVector2Array([
		centre + Vector2(0.0, -tall),
		centre + Vector2(wide, 0.0),
		centre + Vector2(0.0, tall),
		centre + Vector2(-wide, 0.0),
	])
	draw_circle(centre, RADIUS * 0.75, Color(Balance.C_HOLO, 0.16))
	draw_colored_polygon(points, Color(0.62, 0.95, 1.0))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
		Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
	# A second, brighter core so it reads at a distance on the guardian's zoomed
	# out view, where the whole thing is a few pixels across.
	draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0.0, -tall * 0.45),
		centre + Vector2(wide * 0.45, 0.0),
		centre + Vector2(0.0, tall * 0.45),
		centre + Vector2(-wide * 0.45, 0.0),
	]), Color(1.0, 1.0, 1.0, 0.9))
