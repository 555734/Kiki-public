extends Node
## How far off the ground does the runner actually come to rest?
##
## Reported from the device as "after landing from a jump the character
## sometimes floats", with the reasonable guess that it is unavoidable. Before
## accepting that, measure it: jump the runner over and over, on terrain and on
## the guardian's constructs, and after every landing raycast from its feet to
## whatever is underneath. A gap is a gap whatever caused it.
##
##   godot --headless --path . --fixed-fps 60 res://test/landing_probe.tscn

## Places to jump from. All of them are ground the screenshot pass already
## stands the runner on, so a fall here is a bug rather than a pit.
const SPOTS: Array = [
	Vector2(430, 300), Vector2(1100, 330), Vector2(2600, 300),
	Vector2(3050, 266), Vector2(6250, 146), Vector2(7100, 190),
	Vector2(9700, 190), Vector2(10600, 186), Vector2(12700, -34),
]

## Anything under this reads as contact rather than as floating: Godot's own
## collision margin lives down here.
const TOLERABLE: float = 1.5

var main: Node2D = null
var _gaps: Array = []
var _worst: float = 0.0
var _worst_where: String = ""

func _ready() -> void:
	Stage.use(Stage.Which.GREENFIELD)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(6)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true
	main._respawn_timer = -1.0

	print("== plain jumps on the stage's own ground ==")
	for spot in SPOTS:
		await _jump_at(spot, "terrain %.0f" % spot.x)

	print("")
	print("== jumps that land on one of the guardian's platforms ==")
	for spot in [SPOTS[1], SPOTS[4], SPOTS[7]]:
		await _jump_onto_construct(spot)

	print("")
	_report()
	get_tree().quit(0)

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _physics(n: int) -> void:
	for _i in range(n):
		await get_tree().physics_frame

## Drops the runner at `spot`, lets it settle, jumps, waits for the landing,
## then measures once the dust has settled and once more a moment later.
func _jump_at(spot: Vector2, label: String) -> void:
	main._respawn_timer = -1.0
	main.runner.global_position = spot
	main.runner.velocity = Vector2.ZERO
	main.runner._invuln = 10.0
	await _settle()
	if not main.runner.is_on_floor():
		print("  %-18s could not be stood up here; skipped" % label)
		return
	main.input_hub.press_jump()
	main.input_hub.jump_held = true
	await _physics(8)
	main.input_hub.jump_held = false
	# Up, over, and down again.
	var airborne := false
	for _i in range(140):
		await get_tree().physics_frame
		if not main.runner.is_on_floor():
			airborne = true
		elif airborne:
			break
	if not airborne:
		print("  %-18s never left the ground; skipped" % label)
		return
	await _physics(2)
	_measure("%s (just landed)" % label)
	await _physics(20)
	_measure("%s (settled)" % label)

## The same, but the thing underneath is a construct the guardian just made.
func _jump_onto_construct(spot: Vector2) -> void:
	main._respawn_timer = -1.0
	main.runner.global_position = spot
	main.runner.velocity = Vector2.ZERO
	main.runner._invuln = 10.0
	await _settle()
	var g: Guardian = main.guardian
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	# A slab a jump's height above them, a little ahead.
	var slab := spot + Vector2(90.0, -Balance.RUNNER_REACH_STEP)
	main.input_hub.aim_at_world(slab)
	await _physics(2)
	g.select_slot(1)
	g.use_active(slab)
	await _physics(2)
	main.input_hub.press_jump()
	main.input_hub.jump_held = true
	main.input_hub.move_axis = 1.0
	await _physics(10)
	main.input_hub.jump_held = false
	var landed := false
	for _i in range(90):
		await get_tree().physics_frame
		if main.runner.is_on_floor() and main.runner.global_position.y < spot.y - 20.0:
			landed = true
			break
	main.input_hub.move_axis = 0.0
	if not landed:
		print("  platform %-9.0f the jump did not reach it; skipped" % spot.x)
		return
	await _physics(2)
	_measure("platform %.0f (just landed)" % spot.x)
	await _physics(20)
	_measure("platform %.0f (settled)" % spot.x)

func _settle() -> void:
	for _i in range(40):
		await get_tree().physics_frame
		if main.runner.is_on_floor():
			return

## Distance from the soles to whatever is directly beneath them.
func _measure(label: String) -> void:
	var r: Runner = main.runner
	var feet := r.global_position + Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
	var space := r.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		feet - Vector2(0.0, 2.0), feet + Vector2(0.0, 80.0))
	query.collision_mask = 1 | 8      # terrain | hologram
	query.exclude = [r.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		print("  %-32s nothing underneath" % label)
		return
	var gap: float = float(hit["position"].y) - feet.y
	_gaps.append(gap)
	if gap > _worst:
		_worst = gap
		_worst_where = label
	var flag := "" if gap <= TOLERABLE else "   <-- floating"
	print("  %-32s gap %6.2fpx%s" % [label, gap, flag])

func _report() -> void:
	if _gaps.is_empty():
		print("no landings were measured at all")
		return
	var over := 0
	var total := 0.0
	for g in _gaps:
		total += float(g)
		if float(g) > TOLERABLE:
			over += 1
	print("== %d landings measured ==" % _gaps.size())
	print("   average gap %.2fpx, worst %.2fpx (%s)" % [total / float(_gaps.size()),
		_worst, _worst_where])
	print("   %d of %d are further than %.1fpx off the ground" % [over, _gaps.size(), TOLERABLE])
