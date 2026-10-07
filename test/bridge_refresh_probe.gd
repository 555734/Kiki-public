extends Node
var failures := 0
func _ready() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("%s %s" % ["ok" if ok else "FAIL", message])
	if not ok: failures += 1
func frames(count: int) -> void:
	for _i in count: await get_tree().physics_frame
func run() -> void:
	var id := "bridge_refresh_probe"
	var first := ShootableSwitch.new(); first.switch_id = id; first.hold_time = 0.6
	var second := ShootableSwitch.new(); second.switch_id = id; second.hold_time = 1.2
	var bridge := SwitchBridge.new(); bridge.switch_id = id
	add_child(first); add_child(second); add_child(bridge)
	var off := [0]
	var listen := func(key: String) -> void:
		if key == id + ":off": off[0] += 1
	Events.switch_activated.connect(listen)
	first.take_damage(1)
	await frames(20)
	check(not bridge._shape.disabled, "first shot raises the actual bridge collider")
	second.take_damage(1)
	await frames(25)
	check(not first.active and second.active, "original target expires while the island target remains active")
	check(not bridge._shape.disabled and off[0] == 0, "old target does not remove the renewed bridge")
	second.take_damage(1)
	await frames(35)
	check(not bridge._shape.disabled and second.active, "another shot extends bridge life continuously")
	await frames(60)
	check(bridge._shape.disabled and off[0] == 1, "bridge withdraws once the last active target expires")
	Events.switch_activated.disconnect(listen)
	first.free(); second.free(); bridge.free()
	print("bridge refresh probe: ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
