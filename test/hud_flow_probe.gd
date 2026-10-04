extends Node
## Focused probe for the HUD changes that matter on a phone:
## guardian-only controls default left, and stage clear exposes a real button.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	ControlLayout.forget()
	var hud := Hud.new()
	hud.name = "ProbeHud"
	add_child(hud)
	await get_tree().process_frame

	var view := Vector2(1280.0, 720.0)
	var layout := ControlLayout.layout("guardian", view, false)
	# The guardian's screen carries two tools; the wall, warp, scope, ping and
	# undo buttons are retired (ControlLayout.GUARDIAN_LEFT).
	for id in ["slot_1", "slot_3"]:
		check(layout.has(id), "guardian layout contains %s" % id)
		if layout.has(id):
			check(float(layout[id]["center"].x) < view.x * 0.5,
				"%s defaults to the left half" % id)
	for id in ["slot_2", "slot_4", "scope", "ping", "undo"]:
		check(not layout.has(id), "the retired %s button stays off the guardian's screen" % id)

	Events.stage_cleared.emit({"time": 12.0, "rescues": 1})
	await get_tree().process_frame
	var button := hud.find_child("ReturnToStart", true, false) as Button
	check(button != null, "stage clear has a real return button")
	if button != null:
		check(button.visible, "return button becomes visible after stage clear")
		# Compared in the machine's locale: the label goes through translation.
		check(button.text == TranslationServer.translate("スタート画面へ戻る"),
			"button says it returns to the start screen")

	if failures.is_empty():
		print("hud flow probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("hud flow probe: " + failure)
		get_tree().quit(1)
