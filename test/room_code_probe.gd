extends Node
## Focused regression test for the six-digit numeric relay room code.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _ready() -> void:
	for i in range(200):
		var code := WebSocketTransport.new_code()
		check(code.length() == 6, "generated code has six digits")
		check(WebSocketTransport.valid_code(code), "generated code is numeric")

	check(WebSocketTransport.valid_code("004281"), "leading zeroes stay valid")
	check(not WebSocketTransport.valid_code("4281"), "short code is rejected")
	check(not WebSocketTransport.valid_code("1234567"), "long code is rejected")
	check(not WebSocketTransport.valid_code("12A456"), "letters are rejected")
	check(not WebSocketTransport.valid_code("12-456"), "symbols are rejected")

	var panel := NetPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var code_field: LineEdit = panel.get("_code") as LineEdit
	check(code_field != null, "room code input exists")
	if code_field != null:
		check(code_field.max_length == 6, "room code input is limited to six characters")
		check(code_field.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER,
			"room code input uses the numeric keyboard")
		check(code_field.placeholder_text.contains("6桁"), "room code input explains six digits")

	panel.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("room code probe: all checks passed")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("room code probe: " + failure)
		get_tree().quit(1)
