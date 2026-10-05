extends Node
## Renders the two mode cards on the スターたいせん menu from the real arena:
## みんなで (several runners, each their own colour, one star) and 2対2 (team
## A's Lira against team B's blue). Run with:
##
##   xvfb-run -a godot --path . tools/capture_versus_cards.tscn
##
## and commit the PNGs it writes to assets/menu/.

## Twice the card's picture area on the menu.
const SHOT := Vector2i(1040, 600)

const SHOTS := [
	# The join in 1-1's arena: 760px of flat grass, four people and a star.
	{"file": "versus_ffa.png", "stage": Stage.Which.GREENFIELD, "ffa": true,
		"centre_x": 3200.0, "zoom": 2.2, "spread": [-195.0, 95.0, -70.0, 200.0]},
	# 1-4's middle shelf: Lira against team B's blue, the star between them.
	{"file": "versus_team.png", "stage": Stage.Which.SEA, "ffa": false,
		"centre_x": 1600.0, "zoom": 2.35, "spread": [-140.0, 130.0]},
]

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_size(SHOT)
	get_window().size = SHOT
	await get_tree().process_frame
	for shot in SHOTS:
		await _capture(shot)
	VersusLaunch.clear()
	get_tree().quit()

func _ground(x: float) -> Vector2:
	return Vector2(x, VersusStageData.top_at(x) - 26.0)

func _capture(shot: Dictionary) -> void:
	VersusLaunch.clear()
	VersusLaunch.how = VersusLaunch.How.SOLO
	VersusLaunch.stage = int(shot["stage"])
	var arena: Node = load("res://src/versus/versus_main.tscn").instantiate()
	add_child(arena)
	for _i in 20:
		await get_tree().physics_frame
	# The picture is the match, not its interface.
	for name in ["Hud"]:
		var node := arena.get_node_or_null(name)
		if node != null:
			node.queue_free()
	var x: float = shot["centre_x"]
	var people: Array = []
	for r in arena.runners:
		r.set_physics_process(false)
		people.append(r)
	if bool(shot["ffa"]):
		# Two more people, washed towards their own colours as the
		# free-for-all does (VersusMain._build_runners).
		for i in [2, 3]:
			var extra := Runner.new()
			arena.add_child(extra)
			extra.set_physics_process(false)
			extra.visual.modulate = Color.WHITE.lerp(
				VersusRules.colour_of(VersusRoster.RoomMode.FREE_FOR_ALL, i), 0.6) \
				* Color(1.25, 1.25, 1.25)
			people.append(extra)
		people[1].visual.modulate = Color.WHITE.lerp(
			VersusRules.colour_of(VersusRoster.RoomMode.FREE_FOR_ALL, 1), 0.6) \
			* Color(1.25, 1.25, 1.25)
	var spread: Array = shot["spread"]
	for k in people.size():
		var r: Runner = people[k]
		r.global_position = _ground(x + spread[k])
		r.facing = 1 if spread[k] < 0.0 else -1
		r.state = Runner.State.RUN if k % 2 == 0 else Runner.State.IDLE
	# One runner in the air, reaching for the star.
	var jumper: Runner = people[people.size() - 1 if bool(shot["ffa"]) else 1]
	jumper.global_position += Vector2(0, -80)
	jumper.state = Runner.State.JUMP
	jumper.velocity = Vector2(-120, -300)
	jumper.facing = -1
	var m: VersusMatch = arena.match_rules
	for c in m.ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.to_recycle(c, m.tick)
	m._spawn_in = 1 << 30
	ArenaCoin.to_world(m.ledger.coins[0], _ground(x) + Vector2(0, -105), m.tick)
	m.ledger.coins[0].velocity = Vector2.ZERO
	arena.set_physics_process(false)
	arena._camera.zoom = Vector2.ONE * float(shot["zoom"])
	arena._camera.global_position = Vector2(x, VersusStageData.top_at(x) - 80.0)
	arena.set_process(false)
	for _i in 6:
		await get_tree().process_frame
		arena._overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://assets/menu/" + String(shot["file"]))
	print("captured ", shot["file"], " ", image.get_size())
	arena.queue_free()
	await get_tree().process_frame
