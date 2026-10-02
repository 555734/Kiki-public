extends Node

class FakeMain extends Node2D:
	var input_hub: InputHub

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var sender := InputHub.new()
	sender.scripted = true
	add_child(sender)
	var receiver := InputHub.new()
	receiver.scripted = true
	add_child(receiver)
	var main := FakeMain.new()
	main.input_hub = receiver
	var host := HostSession.new()
	host.main = main
	host.remote_role = "runner"
	# The press and release both happen before the first 30 Hz send.
	sender.press_jump()
	sender.release_jump()
	check(not sender.jump_held, "short tap is already released at send time")
	var first := Protocol.runner_input(0.0, 0.0, sender.jump_held, false,
		1, sender.jump_press_sequence)
	host._handle({"payload": first})
	check(receiver.take_jump(), "the remote runner receives the short tap")
	check(not receiver.jump_held, "short tap does not become a held jump")
	# One unreliable packet is dropped; the next one repeats the cumulative edge.
	var second := Protocol.runner_input(0.0, 0.0, false, false,
		2, sender.jump_press_sequence)
	host._handle({"payload": second})
	check(not receiver.take_jump(), "repeated count does not jump twice")
	sender.press_jump()
	sender.release_jump()
	var fourth := Protocol.runner_input(0.0, 0.0, false, false,
		4, sender.jump_press_sequence)
	host._handle({"payload": fourth})
	check(receiver.take_jump(), "a tap survives a dropped input packet")
	host._handle({"payload": second})
	check(not receiver.take_jump(), "an out-of-order packet cannot replay a jump")
	# An explicit counter also prevents a timeout's release from replaying a
	# long-held button when traffic resumes.
	sender.press_jump()
	var held := Protocol.runner_input(0.0, 0.0, true, false,
		5, sender.jump_press_sequence)
	host._handle({"payload": held})
	check(receiver.take_jump() and receiver.jump_held,
		"the first held packet starts and holds the jump")
	receiver.drive_runner(0.0, 0.0, false, false)
	var resumed := Protocol.runner_input(0.0, 0.0, true, false,
		6, sender.jump_press_sequence)
	host._handle({"payload": resumed})
	check(not receiver.take_jump() and receiver.jump_held,
		"resuming an existing hold does not create a new jump")

	host.free()
	main.free()
	receiver.free()
	sender.free()
	print("remote jump: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
