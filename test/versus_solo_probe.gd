extends Node
## 「1台で ためす」 on a phone: one player on touch controls -- move, jump,
## co-op platforms and the co-op rifle -- against a practice partner who stands still. The desktop
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
	check(scene.touch_solo and scene.controls != null and scene.guardian != null,
		"a phone's solo test has on-screen buttons and a rifle")
	var shared := ControlLayout.layout("shared", Vector2(1280, 720), false)
	var drawn: Dictionary = scene.controls.places()
	var same := true
	for id in ["stick", "jump", "slot_1", "slot_3"]:
		same = same and drawn.has(id) and shared.has(id) \
			and Vector2(drawn[id]["center"]).is_equal_approx(shared[id]["center"])
	check(same, "the stick, jump, platform and shot buttons sit exactly where one-device 1-1 has them")
	check(not drawn.has("slot_2") and not drawn.has("slot_4") and not drawn.has("attack"),
		"and there is no wall, warp or close-range attack button")
	var abilities: Array = scene.guardian.abilities.keys()
	abilities.sort()
	check(abilities == [1, 3] and scene.guardian.command_router == null,
		"the co-op Guardian's own platform and rifle, run locally as 1-1 runs them")
	var me: Runner = scene.runners[0]
	var partner: Runner = scene.runners[1]
	var partner_at := partner.global_position
	var layout := ControlLayout.layout("shared", Vector2(1280, 720), false)
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

	# A platform: 1-1's platform tool is chosen to begin with; trace a line
	# on the right of the screen and the co-op hologram appears there.
	var g: Guardian = scene.guardian
	check(g.active_slot == 1, "the platform is chosen first, as in 1-1")
	var from := Vector2(900.0, 300.0)   # in the air above the floor
	await _drag(6, from, from + Vector2(160.0, 0.0))
	await _ticks(6)
	var platforms: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(platforms.size() == 1, "tracing on the right draws a platform (%d)" % platforms.size())
	check(scene._holos.size() == 1 and scene._holos.values()[0]["copies"].size() == 2,
		"with a copy a lap either way, so the loop has it too")

	# Shooting: choose the rifle, then tap the partner on the right.
	await _ticks(10)
	var m: VersusMatch = scene.match_rules
	for c in m.ledger.coins:
		if c.state == ArenaCoin.State.WORLD:
			ArenaCoin.to_recycle(c, m.tick)
	m._spawn_in = 100000
	var star: ArenaCoin.Record = m.ledger.get_coin(0)
	ArenaCoin.to_held(star, 1)
	var held_before := m.ledger.held_by(1).size()
	partner.global_position = me.global_position + Vector2(330.0, 0.0)
	partner.velocity = Vector2.ZERO
	await _ticks(20)
	var shot_button: Vector2 = layout["slot_3"]["center"]
	_touch(4, shot_button, true)
	_touch(4, shot_button, false)
	await _ticks(4)
	check(g.active_slot == 3, "the 射撃 button chooses the rifle")
	var shots := [0]
	var count_shot := func(_a: Vector2, _b: Vector2, hit: bool) -> void:
		if hit:
			shots[0] += 1
	Events.shot_fired.connect(count_shot)
	var on_screen: Vector2 = view.get_canvas_transform() * partner.global_position
	check(on_screen.x > 1280.0 * ControlLayout.DIVIDER, "the partner is on the right of the screen")
	_touch(5, on_screen, true)
	_touch(5, on_screen, false)
	await _ticks(4)
	Events.shot_fired.disconnect(count_shot)
	check(shots[0] == 1, "tapping the partner fires the co-op rifle, and it hits")
	check(m.ledger.held_by(1).size() == held_before - 1,
		"and knocks the partner's star loose")

	# Picking a star up plays the coin sound.
	var sounds_before: int = scene.star_sounds_played
	var loose: ArenaCoin.Record = m.ledger.get_coin(3)
	ArenaCoin.to_world(loose, me.global_position, m.tick, Vector2.ZERO, 0)
	await _ticks(6)
	check(loose.state == ArenaCoin.State.HELD and loose.owner == 0,
		"walking onto a star takes it")
	# Counted by the arena: Audio.last_key may already be a landing by now.
	check(scene.star_sounds_played > sounds_before, "and plays the coin sound")

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

## A finger drawn across the screen, the way a platform is traced.
func _drag(finger: int, from: Vector2, to: Vector2) -> void:
	_touch(finger, from, true)
	for k in range(1, 9):
		var e := InputEventScreenDrag.new()
		e.index = finger
		e.position = from.lerp(to, float(k) / 8.0)
		e.relative = (to - from) / 8.0
		view.push_input(e, true)
		await get_tree().physics_frame
	_touch(finger, to, false)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
