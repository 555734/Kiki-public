extends Node
## Measures how every placed thing SITS, from the rendered picture.
##
## "Characters and enemies are barely touching the ground" came back twice, and
## both times the honest answer was that nothing in the suite could see it: the
## checks compared spawn positions against level data, which is the same
## arithmetic the game does, so a wrong constant agreed with itself. What the
## player complains about is pixels, so this measures pixels.
##
## For each subject it renders the frame, hides the subject, renders again, and
## takes the difference -- the lowest changed pixel is where the subject is
## DRAWN down to. It does the same to the terrain to find where the grass is
## drawn up to. The gap between those two numbers is the float, in world pixels,
## and it is the same number the player is looking at.
##
## Glow is switched off first. A bloom pass spreads a change across the whole
## frame, which is what made three earlier attempts at this measurement report
## nonsense.
##
##   xvfb-run godot --path . --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 res://test/seating_probe.tscn

## How far a sprite may sit off its surface before it reads as floating.
##
## Wildly asymmetric, and deliberately so. Most things draw a contact shadow
## BELOW their feet, and the measurement cannot tell a shadow from a boot, so a
## correctly seated sprite always reads a little negative -- the bounce pads,
## which sit right, come out at -2px and the runner at -19px with their shadow.
## A POSITIVE gap has no such excuse: nothing is drawn above a sprite's feet, so
## a gap between the sprite and the grass is a gap the player can see.
const FLOAT_TOLERANCE := 3.0
const SUNK_TOLERANCE := 30.0

var main: Node = null
var _failures: int = 0
var _rows: Array = []

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print("--- seating: TIMED OUT ---")
		get_tree().quit(1))
	Stage.use(Stage.Which.GREENFIELD)
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	var panel: Node = main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
	var bloom: Node = main.get_node_or_null("Bloom")
	if bloom != null:
		bloom.queue_free()
	# Nothing should move while a subject is being measured across two frames.
	main.input_hub.scripted = true
	# The camera follows the runner and nothing else, so the runner IS the
	# camera: park them on each subject and freeze them there. Without this the
	# view never leaves the start line and every subject measured as "nothing
	# drawn" -- two identical frames, which is what an unmoved camera gives you.
	main.runner.set_physics_process(false)
	main.runner.velocity = Vector2.ZERO
	# And freeze the world. Clouds drift, grass sways, the checkpoint flag
	# animates: with any of that running the two frames being compared differ
	# almost everywhere. The first run of this probe reported every subject as
	# ~450px sunk for exactly that reason.
	_freeze()
	# Pausing the tree stops _process, but an enemy that is MID-STRIDE when the
	# pause lands keeps its walk phase, and anything that redraws from that
	# phase can still differ between two captures. Stop them where they stand.
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node2D:
			(e as Node).set_physics_process(false)
			(e as Node).set_process(false)
			for child in (e as Node).get_children():
				(child as Node).set_process(false)
	await _frames(6)

	await _measure_all()
	_report()
	get_tree().quit(1 if _failures > 0 else 0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## By script, not by index. Indexing the Static container picked up the ground
## COLLIDER as "decor" -- 34 runtime errors, and 33 props that never got a row.
func _by_script(tail: String) -> Node2D:
	for n in main.level.get_node("Static").get_children():
		var sc: Script = n.get_script()
		if sc != null and String(sc.resource_path).ends_with(tail):
			return n as Node2D
	return null

func _terrain_node() -> Node2D:
	return _by_script("terrain.gd")

func _decor_node() -> Node2D:
	return _by_script("decor.gd")

## Everything the level places that is supposed to be standing on something.
func _subjects() -> Array:
	var out: Array = []
	for e in Level01Data.enemies():
		var kind := String(e.get("type", ""))
		if kind == "flyer":
			continue    # flies by design
		out.append({"name": kind, "at": e["pos"] as Vector2, "kind": "enemy"})
	for at in Level01Data.springs():
		out.append({"name": "spring", "at": at, "kind": "spring"})
	for d in Level01Data.decor():
		var kind := String(d.get("type", ""))
		# Clouds and hills are backdrop. Block rows are the platformer's other
		# tradition -- they hang in the air to be jumped at, and measuring them
		# against the ground says nothing: they come out ~90px "floating", which
		# is the point of them. Their heights are audited for reach instead, in
		# _test_level_reachability.
		if kind in ["cloud", "hill", "blocks"]:
			continue
		out.append({"name": kind, "at": d["pos"] as Vector2, "kind": "decor",
			"item": d})
	for i in Level01Data.checkpoints().size():
		out.append({"name": "checkpoint", "at": Level01Data.checkpoints()[i],
			"kind": "checkpoint"})
	out.append({"name": "runner", "at": Vector2.ZERO, "kind": "runner"})
	return out

func _measure_all() -> void:
	var all := _subjects()
	print("  measuring %d subjects" % all.size())
	for s in all:
		await _measure(s)

## One subject: stand the camera on it, diff it out of the picture, diff the
## terrain out of the picture, and report the distance between the two edges.
func _measure(subject: Dictionary) -> void:
	var at: Vector2 = subject["at"]
	var kind := String(subject["kind"])
	var node: Node2D = null
	var decor_backup: Array = []

	# The camera follows the runner and nothing else, so the runner IS the
	# camera: park them on the subject. Do it BEFORE looking for the node --
	# dynamic entities are spawned around the runner, so a walker 9000px away
	# is not in the scene until the runner is standing next to it.
	if kind == "runner":
		# The runner has to be standing on something, so let physics have them
		# back for as long as it takes to land on the start plateau.
		get_tree().paused = false
		Engine.time_scale = 1.0
		main.runner.set_physics_process(true)
		main.runner.global_position = Vector2(-400, 300)
		main.runner.velocity = Vector2.ZERO
		await _frames(2)
		for i in range(90):
			await get_tree().physics_frame
			if main.runner.is_on_floor():
				break
		main.runner.set_physics_process(false)
		_freeze()
		at = main.runner.global_position
		node = main.runner
	else:
		main.runner.global_position = at + Vector2(0, -30)
		main.camera.global_position = main.runner.global_position
		await _frames(6)
		if kind == "decor":
			# Decor is one node drawing a whole list, so isolate this item by
			# giving that node a list of one and putting the rest back after.
			var d: Node2D = _decor_node()
			decor_backup = d.items
			# Typed: decor.items is Array[Dictionary], and handing it a plain
			# Array is a runtime error that silently swallowed all 34 props.
			var one: Array[Dictionary] = [subject["item"]]
			d.items = one
			d.queue_redraw()
			node = d
		else:
			node = _nearest_node(at)

	if node == null:
		_restore(decor_backup)
		_row(subject["name"], at, NAN, "not found in the scene")
		_failures += 1
		return

	main.camera.global_position = main.runner.global_position
	main.runner.visible = kind == "runner"
	await _frames(8)

	var with_it := await _shot()
	node.visible = false
	await _frames(3)
	var without := await _shot()
	node.visible = true
	await _frames(3)
	# Put it back and check the picture came back with it. If these two frames
	# differ, something inside the band is moving on its own and every number
	# below is noise -- so say so instead of reporting it.
	var again := await _shot()
	# The whole screen, not a column. Hiding ONE node only changes that node's
	# pixels, so there is nothing to guard against -- and a column centred on
	# the node missed anything drawn off-centre. That is how five checkpoints
	# were reported as floating 67px: the band fell to the right of the post and
	# measured the bottom of the banner instead.
	var edge := _lowest_difference(with_it, without)
	var sprite_bottom: int = edge.y
	var stable := _lowest_difference(with_it, again).y < 0
	# The grass is read directly under the sprite's lowest pixels, because the
	# ground steps and a column somewhere else is a different height.
	var band := Vector2i(edge.x - 12, edge.x + 12)

	var terrain: Node2D = _terrain_node()
	var before_terrain := await _shot()
	terrain.visible = false
	await _frames(3)
	var no_terrain := await _shot()
	terrain.visible = true
	await _frames(2)
	var grass_top := _highest_difference(before_terrain, no_terrain, band)

	main.runner.visible = true
	_restore(decor_backup)

	if not stable:
		# Not a failure, because it is not a measurement. Something in the frame
		# moved between the two shots and every number below it would be noise,
		# so it is reported and skipped. In practice this is the patrolling
		# enemies; their seating is checked arithmetically instead, by
		# _test_everything_stands_on_the_ground, which is the cheap guard this
		# probe exists to calibrate rather than replace.
		_row("%s [%s]" % [subject["name"], node.name], at, NAN,
			"not measured -- the picture would not hold still")
		_save(with_it, subject["name"] + "_unstable", at,
			Vector2i(0, 0), _lowest_difference(with_it, again).y, -1)
		return
	if grass_top < 0 and sprite_bottom >= 0:
		# Nothing under it at all. True of the one turret that hangs over the
		# crossing, and of nothing else.
		_row("%s [%s]" % [subject["name"], node.name], at, NAN, "no ground below")
		return
	if sprite_bottom < 0 or grass_top < 0:
		_row("%s [%s]" % [subject["name"], node.name], at, NAN,
			"nothing drawn (sprite %d, grass %d)" % [sprite_bottom, grass_top])
		_failures += 1
		return

	# Screen rows -> world pixels. Positive means the sprite stops ABOVE the
	# grass: a gap the player reads as floating.
	var gap := float(grass_top - sprite_bottom) / Balance.CAMERA_ZOOM
	var note := ""
	if gap > FLOAT_TOLERANCE:
		note = "FLOATS"
		_failures += 1
	elif gap < -SUNK_TOLERANCE:
		note = "SUNK"
		_failures += 1
	_row("%s [%s]" % [subject["name"], node.name], at, gap, note)
	# Keep the frame that produced the number, with the two rows it was read
	# off. A measurement nobody can look at is a measurement nobody can check.
	if note != "":
		_save(with_it, subject["name"], at, band, sprite_bottom, grass_top)

func _freeze() -> void:
	Engine.time_scale = 0.0
	get_tree().paused = true

func _restore(decor_backup: Array) -> void:
	if decor_backup.is_empty():
		return
	_decor_node().items = decor_backup
	_decor_node().queue_redraw()

func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()

const DIFF := 0.035

## The lowest row where the two frames differ, and the middle of the run of
## differing pixels on it: (x, y), or y = -1 when the frames are identical.
func _lowest_difference(a: Image, b: Image) -> Vector2i:
	var whole := Vector2i(0, a.get_width())
	for y in range(a.get_height() - 1, -1, -1):
		if _row_differs(a, b, whole, y):
			var lo := a.get_width()
			var hi := -1
			for x in range(a.get_width()):
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > DIFF:
					lo = mini(lo, x)
					hi = maxi(hi, x)
			return Vector2i((lo + hi) / 2, y)
	return Vector2i(0, -1)

func _highest_difference(a: Image, b: Image, band: Vector2i) -> int:
	for y in range(a.get_height()):
		if _row_differs(a, b, band, y):
			return y
	return -1

func _row_differs(a: Image, b: Image, band: Vector2i, y: int) -> bool:
	var hits := 0
	for x in range(maxi(0, band.x), mini(a.get_width(), band.y)):
		var ca := a.get_pixel(x, y)
		var cb := b.get_pixel(x, y)
		if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > DIFF:
			hits += 1
			# Two adjacent columns, so one stray antialiased pixel is not an edge.
			if hits >= 2:
				return true
	return false

func _nearest_node(at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 120.0
	for n in _walk(main):
		if not (n is Node2D) or n == main.runner:
			continue
		var script: Script = n.get_script()
		if script == null:
			continue
		var path := String(script.resource_path)
		if not (path.contains("/enemies/") or path.contains("/gimmicks/")
				or path.contains("spring") or path.contains("checkpoint")):
			continue
		var d: float = (n as Node2D).global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = n
	return best

func _walk(root: Node) -> Array:
	var out: Array = [root]
	for c in root.get_children():
		out.append_array(_walk(c))
	return out

func _row(name: String, at: Vector2, gap: float, note: String) -> void:
	_rows.append({"name": name, "at": at, "gap": gap, "note": note})

func _report() -> void:
	print("\n  %-12s %-16s %8s  %s" % ["subject", "at", "gap", ""])
	for r in _rows:
		var gap: float = r["gap"]
		print("  %-12s %-16s %8s  %s" % [r["name"], str(r["at"]),
			("  n/a" if is_nan(gap) else "%+.1fpx" % gap), r["note"]])
	print("\n--- seating: %d failed ---" % _failures)

## Writes the measured frame with the sprite's bottom row in magenta and the
## grass's top row in green, plus the band edges, so the number can be checked
## against the picture instead of trusted.
func _save(frame: Image, name: String, at: Vector2, band: Vector2i,
		sprite_bottom: int, grass_top: int) -> void:
	var img := frame.duplicate() as Image
	for x in range(img.get_width()):
		if sprite_bottom >= 0:
			img.set_pixel(x, sprite_bottom, Color.MAGENTA)
		if grass_top >= 0:
			img.set_pixel(x, grass_top, Color(0.2, 1.0, 0.2))
	for y in range(img.get_height()):
		for x in [band.x, band.y]:
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, Color(1.0, 0.9, 0.2))
	var dir := "user://seating"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png("%s/%s_%d.png" % [dir, name, int(at.x)])
