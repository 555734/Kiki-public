extends Node
## 「1台で ためす」 on a phone: one player on touch controls -- move, jump,
## attack, build -- against a practice partner who stands still. The desktop
## version (two players on one keyboard) is versus_play_probe's.

class TouchSolo extends "res://src/versus/versus_main.gd":
	func _read_command_line() -> void:
		mode = Mode.SOLO
		room_mode = VersusRoster.RoomMode.TEAM_SPLIT
		_seat = 0
		_set_local_team()
	func _wants_touch() -> bool:
		return true
	func _start_debug_log() -> void:
		pass

var failures: Array[String] = []
var view: SubViewport = null
var scene = null

func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func _ready() -> void:
	view = SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.world_2d = World2D.new()
	add_child(view)
	scene = TouchSolo.new()
	view.add_child(scene)
	await _ticks(60)
	check(scene.touch_solo and scene.controls != null and scene.controls.duel,
		"a phone's solo test has on-screen buttons, build palette included")
	check(scene.controls._circles().has("attack") and scene.controls._circles().has("build"),
		"with attack and build")
	var me: Runner = scene.runners[0]
	var partner: Runner = scene.runners[1]
	var partner_at := partner.global_position
	var layout := ControlLayout.layout("runner", Vector2(1280, 720), false)
	var stick: Dictionary = layout["stick"]
	var right: Vector2 = stick["center"] + Vector2(float(stick["radius"]) * 0.7, 0)
	var before := me.global_position.x
	_touch(0, right, true)
	await _ticks(30)
	_touch(0, right, false)
	await _ticks(10)
	check(me.global_position.x > before + 40.0,
		"the stick walks P1 (%.0fpx)" % (me.global_position.x - before))
	me.global_position = Vector2(250.0, 370.0)
	me.velocity = Vector2.ZERO
	await _ticks(20)
	var y := me.global_position.y
	var jump_at: Vector2 = layout["jump"]["center"]
	_touch(1, jump_at, true)
	await _ticks(8)
	check(me.global_position.y < y - 10.0, "the jump button jumps")
	_touch(1, jump_at, false)
	await _ticks(40)
	check(partner.global_position.distance_to(partner_at) < 4.0,
		"and the practice partner stands still")

	# Attack: the partner, holding a star, loses it.
	partner.global_position = me.global_position + Vector2(36.0, 0.0)
	me.facing = 1
	var star: ArenaCoin.Record = scene.match_rules.ledger.get_coin(0)
	ArenaCoin.to_held(star, 1)
	await _ticks(4)
	var attack_at: Vector2 = scene.controls._circles()["attack"]
	_touch(2, attack_at, true)
	_touch(2, attack_at, false)
	await _ticks(VersusRules.STRIKE_STARTUP_TICKS + 6)
	check(star.state != ArenaCoin.State.HELD or star.owner != 1,
		"the attack button knocks a star out of the partner")
	await _ticks(90)

	# Build: open the palette, tap the world, a platform appears and is solid.
	var build_at: Vector2 = scene.controls._circles()["build"]
	_touch(3, build_at, true)
	_touch(3, build_at, false)
	await _ticks(2)
	_touch(4, Vector2(640, 250), true)
	_touch(4, Vector2(640, 250), false)
	await _ticks(4)
	check(scene._built.size() == 1, "tapping the world builds a platform")
	var r: Rect2 = scene._built[0]
	check(scene.match_rules.world.floor_below(r.get_center() + Vector2(0, -40), 80.0) < INF,
		"and it is solid for the match")
	scene.request_construct_undo()
	check(scene._built.is_empty(), "and undo takes it back")

	view.queue_free()
	await get_tree().process_frame
	print("versus solo probe: %d checks failed" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _touch(finger: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	view.push_input(event, true)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
