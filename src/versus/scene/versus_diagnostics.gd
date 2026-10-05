class_name VersusDiagnostics
extends Node
## The versus scene's on-device connection log: a short rolling list for the
## waiting screen, the same lines in user://versus-debug.log, a button to copy
## them, an HTTP probe of the relay route, and periodic notes on the local
## input and the match state. Editor builds only -- none of it ships.

const LOG_PATH := "user://versus-debug.log"

var arena = null
var copy_button: Button = null
## Why the relay looked wrong to the HTTP probe, or "".
var relay_probe_detail: String = ""

var _lines: Array[String] = []
var _file: FileAccess = null
var _probe: HTTPRequest = null
var _last_match_state: String = ""
var _last_input_direction: int = 0
var _input_trace_ticks: int = 0

func start_log() -> void:
	_lines.clear()
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	debug("build=versus diag-v1 role=%s room=%s mode=%d protocol=%d" % [
		arena.role_name(), arena.room_code, arena.room_mode, VersusProtocol.VERSION])
	debug("relay=%s (WebSocket uses /room4/<code>)" % arena.relay().strip_edges().rstrip("/"))
	if _file == null:
		debug("%s could not be opened: %d" % [LOG_PATH, FileAccess.get_open_error()])

func debug(message: String) -> void:
	if not OS.has_feature("editor"):
		return
	var line := "%s %s" % [Time.get_time_string_from_system(), message]
	print("[versus] " + line)
	_lines.append(line)
	if _lines.size() > 9:
		_lines.pop_front()
	if _file != null:
		_file.store_line(line)
		_file.flush()

func lines() -> Array[String]:
	return _lines.duplicate()

## The copy button sits under the waiting screen's text, online and in the
## editor only.
func add_copy_button(layer: CanvasLayer) -> void:
	copy_button = Button.new()
	copy_button.text = "接続ログをコピー"
	copy_button.custom_minimum_size = Vector2(200, 44)
	copy_button.size = Vector2(200, 44)
	copy_button.pressed.connect(copy_log)
	layer.add_child(copy_button)

func place_copy_button(shown: bool, viewport_size: Vector2) -> void:
	if copy_button == null:
		return
	copy_button.visible = shown
	copy_button.position = Vector2(viewport_size.x * 0.5 - 100.0,
		viewport_size.y * 0.5 + 214.0)

func copy_log() -> void:
	var content := FileAccess.get_file_as_string(LOG_PATH)
	if content.is_empty():
		content = "\n".join(_lines)
	DisplayServer.clipboard_set(content)
	debug("log copied to clipboard")

## A GET without Upgrade MUST return 426 on our deployed /room4 handler.
## 404 instead means the worker serving this URL does not have /room4.
## WebSocketPeer itself does not expose HTTP handshake response status.
func probe_relay_route(relay: String, room_code: String) -> void:
	if not OS.has_feature("editor"):
		return
	var base := relay.strip_edges().rstrip("/")
	if base.begins_with("wss://"):
		base = "https://" + base.substr(6)
	elif base.begins_with("ws://"):
		base = "http://" + base.substr(5)
	elif not base.begins_with("https://") and not base.begins_with("http://"):
		base = "https://" + base
	_probe = HTTPRequest.new()
	_probe.name = "VersusRelayProbe"
	_probe.timeout = 10.0
	add_child(_probe)
	_probe.request_completed.connect(_on_probe_complete)
	var url := "%s/room4/%s" % [base, room_code]
	debug("PROBE GET " + url + " (expected HTTP 426; no websocket upgrade)")
	var err := _probe.request(url)
	if err != OK:
		relay_probe_detail = TranslationServer.translate("接続先のHTTP検査を開始できません (%d)") % err
		debug("PROBE request error=%d" % err)

func _on_probe_complete(result: int, http_status: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	debug("PROBE result=%d HTTP=%d body=%s" % [result, http_status,
		body.get_string_from_utf8().substr(0, 120).replace("\n", " ")])
	if result != HTTPRequest.RESULT_SUCCESS:
		relay_probe_detail = TranslationServer.translate("中継HTTP接続失敗 result=%d (DNS/通信を確認)") % result
	elif http_status == 426:
		relay_probe_detail = ""
		debug("PROBE /room4 exists on deployed relay")
	elif http_status == 404:
		relay_probe_detail = "中継に /room4 がありません (サーバーの更新が必要)"
	elif http_status == 429:
		relay_probe_detail = "中継の接続回数制限 HTTP 429"
	else:
		relay_probe_detail = TranslationServer.translate("中継の /room4 が HTTP %d を返しました") % http_status

## The value Runner actually reads, plus touch owner and the local actor.
## Emit on direction changes and at 3-second intervals so a stuck input can
## be diagnosed from the copyable log without recording every physics frame.
func trace_local_input() -> void:
	if not OS.has_feature("editor"):
		return
	var team: int = arena.local_team
	if arena.is_solo() or team < 0 or arena.input.hubs.is_empty():
		return
	var h: InputHub = arena.input.hubs[0]
	var direction := int(signf(h.move_axis))
	_input_trace_ticks += 1
	if direction == _last_input_direction and _input_trace_ticks < 180:
		return
	_last_input_direction = direction
	_input_trace_ticks = 0
	var runner: Runner = arena.runners[team]
	debug("INPUT team=%d axis=%.2f y=%.2f touch=%s fingers=%s left=%s scripted=%s physics=%s x=%.1f vx=%.1f" % [
		team, h.move_axis, h.move_axis_y, str(h._has_touch),
		str(h._touch_owner), str(h.runner_on_left), str(h.scripted),
		str(runner.is_physics_processing()),
		runner.global_position.x, runner.velocity.x])

func record_match_state() -> void:
	var info := ""
	var host: VersusHost = arena.host
	var client: VersusClient = arena.client
	if host != null:
		info = "HOST authenticated=%d can_play=%s playing=%s" % [
			host.roster.peers_filled(), str(host.roster.can_play()), str(host.playing)]
	elif client != null:
		info = "JOIN connected=%s refused=%s seen_world=%s phase=%d seat=%d" % [
			str(client.connected), str(client.refused), str(client.seen_world),
			client.phase, client.seat]
	if not info.is_empty() and info != _last_match_state:
		_last_match_state = info
		debug(info)
