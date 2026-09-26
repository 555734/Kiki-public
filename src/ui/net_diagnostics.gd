class_name NetDiagnostics
extends CanvasLayer
## Answers "why can we not connect?" with evidence instead of a guess.
##
## Every step of the connection is tried in order, on the device that is
## failing, and each one writes a timestamped line saying what it did, what came
## back and how long it took. The result is deliberately long: a short error
## message is what we already have, and it has never been enough to tell a
## blocked port from a wrong URL from a captive-portal Wi-Fi from a bug.
##
## The text sits in a read-only TextEdit and there is a COPY button, because the
## whole point is that it can be pasted into a message.
##
## It reads EOS and the live transport only. It does not create a throwaway
## room or contact the retired Cloudflare relay.

const STEP_TIMEOUT := 12.0

var relay: String = ""

var _log: TextEdit = null
var _lines: PackedStringArray = []
var _started_ms: int = 0
var _http: HTTPRequest = null
var _run_button: Button = null

func _ready() -> void:
	layer = 30
	_started_ms = Time.get_ticks_msec()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.97)
	root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 10
	box.offset_bottom = -10
	root.add_child(box)

	var title := Label.new()
	title.text = "接続診断"
	title.add_theme_font_size_override("font_size", 22)
	var f := Art.font()
	if f != null:
		title.add_theme_font_override("font", f)
	box.add_child(title)

	# Read-only rather than a Label: a TextEdit can be selected and scrolled,
	# which is what makes a long report usable on a phone.
	_log = TextEdit.new()
	_log.editable = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_log.add_theme_font_size_override("font_size", 13)
	box.add_child(_log)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_button("すべてコピー", _copy))
	_run_button = _button("もう一度実行", _rerun)
	row.add_child(_run_button)
	row.add_child(_button("閉じる", func() -> void: queue_free()))

	_http = HTTPRequest.new()
	add_child(_http)
	_run()

func _button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

func _copy() -> void:
	DisplayServer.clipboard_set(report())
	_say("(コピーしました)")

func _rerun() -> void:
	_lines.clear()
	_run()

func report() -> String:
	return "\n".join(_lines)

## One line, stamped with how long the whole run has taken so far. The elapsed
## time is the useful part: a DNS failure and a blocked port look identical
## except that one takes 20ms and the other takes 10 seconds.
func _say(text: String) -> void:
	var t := float(Time.get_ticks_msec() - _started_ms) / 1000.0
	_lines.append("[%6.2fs] %s" % [t, text])
	if _log != null:
		_log.text = report()
		_log.scroll_vertical = _log.get_line_count()

func _run() -> void:
	if _run_button != null:
		_run_button.disabled = true
	_started_ms = Time.get_ticks_msec()
	await _describe_device()
	_check_eos()
	_report_live_session()
	_report_journal()
	_say("")
	_say("=== ここまでをコピーして送ってください ===")
	if _run_button != null:
		_run_button.disabled = false

# ------------------------------------------------------------------- steps

func _describe_device() -> void:
	_say("SIDE / SKY 接続診断")
	_say("時刻 %s" % Time.get_datetime_string_from_system(true))
	_say("ビルド %s / 通信プロトコル v%d" % [Balance.BUILD_ID, Protocol.VERSION])
	_say("端末 %s %s / Godot %s" % [OS.get_name(), OS.get_version(),
		Engine.get_version_info().get("string", "?")])
	_say("モデル %s" % OS.get_model_name())
	_say("描画 %s" % RenderingServer.get_video_adapter_name())
	_say("EOSG組み込み %s" % ("はい" if EosRuntime.available() else "いいえ"))
	var addresses: Array[String] = []
	for a in IP.get_local_addresses():
		var one := String(a)
		# Loopback and link-local say nothing about whether this device is on a
		# network another device could reach it from.
		if one.begins_with("127.") or one.begins_with("::") or one.begins_with("fe80"):
			continue
		addresses.append(one)
	_say("この端末のIP %s" % (", ".join(addresses) if not addresses.is_empty() else "(なし)"))
	_say("")

func _check_eos() -> void:
	_say("[EOS] 状態: %s" % ["未初期化", "初期化中", "準備完了", "失敗"][EosRuntime.state])
	if not EosRuntime.last_error.is_empty():
		_say("  最後のエラー: %s" % EosRuntime.last_error)
	var puid := EosRuntime.product_user_id()
	_say("  Product User ID: %s" % (puid if not puid.is_empty() else "未取得"))

func _check_relay_reachable() -> void:
	_say("[1/3] 中継サーバーに届くか  GET %s/health" % relay)
	var result := await _http_get(relay.rstrip("/") + "/health")
	if int(result["error"]) != OK:
		_say("  失敗: HTTPRequest エラー %d (%s)"
			% [result["error"], _http_error_name(int(result["error"]))])
		_say("  → この端末からインターネットに出られていないか、URLが違います。")
		_say("    機内モード／VPN／会社や学校のWi-Fiのフィルタを疑ってください。")
		return
	_say("  HTTP %d  %.2f秒  本文: %s"
		% [result["code"], result["seconds"], result["body"]])
	if int(result["code"]) == 200:
		_say("  → 中継サーバーは生きています。")
	else:
		_say("  → 200 以外です。URLが違うか、サーバーが更新されています。")

## Carried from step 2 to step 3, so the WebSocket test dials the room that was
## just created rather than a code of its own. Testing a different room still
## proves the network works, but it stops short of proving the whole chain.
var _made_room: String = ""

func _check_room_creation() -> void:
	_say("")
	_say("[2/3] 部屋を作れるか  POST %s/room" % relay)
	var result := await _http_post(relay.rstrip("/") + "/room")
	if int(result["error"]) != OK:
		_say("  失敗: HTTPRequest エラー %d (%s)"
			% [result["error"], _http_error_name(int(result["error"]))])
		return
	_say("  HTTP %d  %.2f秒  本文: %s"
		% [result["code"], result["seconds"], result["body"]])
	var parsed = JSON.parse_string(String(result["body"]))
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("code"):
		_made_room = String(parsed["code"])

## The one that matters. HTTP working and WebSockets not is the signature of a
## network that proxies web traffic and drops the upgrade -- common on office,
## school and hotel Wi-Fi, and the reason this is a separate step.
func _check_websocket() -> void:
	_say("")
	var code := _made_room if not _made_room.is_empty() else WebSocketTransport.new_code()
	var base := relay.strip_edges().rstrip("/")
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	elif not base.begins_with("ws"):
		base = "wss://" + base
	var url := "%s/room/%s" % [base, code]
	_say("[3/3] WebSocketがつながるか  %s" % url)

	var socket := WebSocketPeer.new()
	var err := socket.connect_to_url(url)
	if err != OK:
		_say("  失敗: connect_to_url がエラー %d (%s)" % [err, error_string(err)])
		_say("  → URLの形が不正です。https:// から始まる中継URLを入れてください。")
		return

	var began := Time.get_ticks_msec()
	var last := -1
	var opened := false
	var joined := ""
	while true:
		socket.poll()
		var state := socket.get_ready_state()
		if state != last:
			last = state
			_say("  状態 → %s  (%.2f秒)"
				% [_ws_state_name(state), float(Time.get_ticks_msec() - began) / 1000.0])
		if state == WebSocketPeer.STATE_OPEN:
			opened = true
			while socket.get_available_packet_count() > 0:
				var packet := socket.get_packet()
				if socket.was_string_packet():
					joined = packet.get_string_from_utf8()
					_say("  受信: %s" % joined)
			if not joined.is_empty():
				break
		if state == WebSocketPeer.STATE_CLOSED and opened:
			_say("  閉じられました code=%d reason='%s'"
				% [socket.get_close_code(), socket.get_close_reason()])
			break
		if state == WebSocketPeer.STATE_CLOSED and not opened \
				and Time.get_ticks_msec() - began > 400:
			_say("  つながる前に閉じられました code=%d" % socket.get_close_code())
			break
		if Time.get_ticks_msec() - began > int(STEP_TIMEOUT * 1000.0):
			_say("  %.0f秒待っても開きませんでした" % STEP_TIMEOUT)
			break
		await get_tree().process_frame

	if not joined.is_empty():
		_say("  → WebSocketは通っています。")
		_say("    これは『いま新しい接続を作れるか』の結果であって、")
		_say("    ゲームが使っている接続が生きている証拠ではありません。")
		_say("    そちらは下の『いま動いているゲーム接続』を見てください。")
	elif opened:
		_say("  → 開いたのに relay からの joined が来ませんでした。中継サーバー側の問題です。")
	else:
		_say("  → WebSocketがつながりません。HTTPは通るのにここで止まる場合、")
		_say("    そのWi-FiがWebSocketを遮断しています（社内・学校・ホテルに多い）。")
		_say("    携帯回線（テザリング）で試すと切り分けられます。")
	socket.close()

## What the GAME's connection is doing, as opposed to the three steps above.
##
## The distinction is the point. Steps 1-3 open a BRAND NEW connection from this
## device and prove the network and the relay can carry one. They say nothing
## about the connection the game is actually using, which may have been made
## minutes ago, to a different room, and be dead. A report that ran the three
## steps, saw them pass and concluded "the connection is fine" was answering a
## question nobody asked.
func _report_live_session() -> void:
	var root: Node = get_parent()
	while root != null and root.get("link") == null:
		root = root.get_parent()
	_say("")
	_say("── いま動いているゲーム接続 ──")
	if root == null:
		_say("  この画面からゲーム本体が見つかりません（未確定）")
		return

	var link: NetLink = root.get("link")
	for line in link.lines():
		_say("  " + line)

	var client: Node = root.get("client_session")
	var host: Node = root.get("host_session")
	var session: Node = client if client != null else host
	if session == null or not is_instance_valid(session):
		_say("  役: まだどちらでもありません（部屋に入っていません）")
		_conclude_no_session(link)
		return
	_say("  役: %s" % ("ガーディアン側" if client != null else "ランナー側"))

	var t: Object = session.get("transport")
	if t == null:
		_say("  transport がありません（未確定）")
		return
	if t.has_method("room_code"):
		_say("  ★ この端末がいる部屋: %s" % String(t.call("room_code")))
		_say("     （相手の画面の合言葉と、一文字ずつ見比べてください）")
	var link_open: bool = t.has_method("is_link_open") and bool(t.call("is_link_open"))
	var peer_here: bool = t.has_method("is_connected_to_peer") \
		and bool(t.call("is_connected_to_peer"))
	_say("  EOS P2Pリンク: %s" % ("開いています" if link_open else "閉じています"))
	_say("  相手がいるか: %s" % ("はい" if peer_here else "いいえ"))
	_say("  受信 %d 個 / 送信 %d 個"
		% [int(t.get("packets_in")), int(t.get("packets_out"))])
	if t.get("last_close_code") != null and int(t.get("last_close_code")) >= 0:
		_say("  最後の切断: コード %d / 理由 %s"
			% [int(t.get("last_close_code")),
				String(t.get("last_close_reason")) if not String(t.get("last_close_reason")).is_empty() else "（なし）"])

	if client != null:
		var buf: Array = session.get("_buffer")
		var newest: int = int(buf[buf.size() - 1].tick) if buf.size() > 0 else 0
		# Zero and "never measured" are different facts. Printing 0ms for both
		# is the report lying about one of them.
		var rtt: float = float(session.call("round_trip"))
		_say("  往復: %s" % ("まだ測れていません" if rtt < 0.0 else "%.0fms" % (rtt * 1000.0)))
		_say("  時計 %d / 最新スナップショット %s / 表示位置 %d"
			% [Clock.tick, str(newest) if newest > 0 else "まだ来ていません",
				int(session.call("view_tick"))])
		if newest > 0:
			_say("  表示の遅れ %dms"
				% int(float(newest - int(session.call("view_tick"))) * Clock.DT * 1000.0))
		_say("  最後に受信してからの時間 %.1f秒" % float(session.get("_silence")))

	_say("")
	_say("── この記録から言えること ──")
	_conclude(link, link_open, peer_here, int(t.get("packets_in")))

## Only what the evidence supports. Where it does not reach, the report says so
## rather than picking the likeliest story -- the previous version guessed
## "your code letters do not match" from a packet count of zero and sent the
## player to compare six characters that were already identical.
func _conclude(link: NetLink, link_open: bool, peer_here: bool, packets_in: int) -> void:
	if not link_open:
		_say("  この端末は部屋に入れていません（接続が開いていません）。")
		_say("  上の[1/3][2/3][3/3]は『新しい接続を今から作れるか』の試験なので、")
		_say("  それが通っていてもこの接続が生きていることにはなりません。")
		_say("  ・そのまま待てば数秒おきに自動でつなぎ直します")
		_say("  ・『やめる』を押してから、もう一度部屋を作るか入り直しても直ります")
		return
	if not peer_here:
		if link.desired_role == "guest" and link.relay_role == "host":
			_say("  この合言葉の部屋には、まだ誰もいません。")
			_say("  （ガーディアンとして入ったのに、中継からホスト役を渡されています。")
			_say("   それは部屋が空だったということです）")
			_say("  ・相手が『部屋を作る』を押しているか")
			_say("  ・合言葉が一文字も違っていないか")
			return
		_say("  部屋には入れていますが、相手がまだ来ていません。")
		_say("  通信障害ではありません。待っている状態です。")
		return
	if packets_in == 0:
		_say("  相手は同じ部屋にいますが、この端末にはまだ1個も届いていません。")
		_say("  ホスト側がまだ送り始めていないか、握手が済んでいない可能性があります。")
		_say("  （どちらかはこの記録からは未確定です）")
		return
	_say("  この接続は生きていて、データも届いています。")
	if link.reconnects > 0:
		_say("  ただし %d 回つなぎ直しています。回線が不安定です。" % link.reconnects)

func _conclude_no_session(link: NetLink) -> void:
	_say("")
	_say("── この記録から言えること ──")
	if link.phase == NetLink.Phase.IDLE:
		_say("  まだ部屋を作っても入ってもいません。接続の良し悪しは未確定です。")
	else:
		_say("  接続を始めたところで止まっています（%s）。"
			% NetLink.LABELS.get(link.phase, "?"))
		if not link.last_error.is_empty():
			_say("  最後のエラー: " + link.last_error)

## Every state change this attempt went through, with the time it happened.
## The shape of a failure is usually in the order of these lines.
func _report_journal() -> void:
	var root: Node = get_parent()
	while root != null and root.get("link") == null:
		root = root.get_parent()
	if root == null:
		return
	var link: NetLink = root.get("link")
	var lines := link.journal_lines()
	if lines.is_empty():
		return
	_say("")
	_say("── 接続の経過 ──")
	for line in lines:
		_say(line)


# ------------------------------------------------------------------ helpers

## Named _http_get rather than _get: Object already has a virtual _get(name)
## and shadowing it is a parse error, not a warning.
func _http_get(url: String) -> Dictionary:
	return await _request(url, HTTPClient.METHOD_GET, "")

func _http_post(url: String) -> Dictionary:
	return await _request(url, HTTPClient.METHOD_POST, "")

func _request(url: String, method: int, body: String) -> Dictionary:
	var began := Time.get_ticks_msec()
	var err := _http.request(url, PackedStringArray(), method, body)
	if err != OK:
		return {"error": err, "code": 0, "body": "", "seconds": 0.0}
	# A hung request would otherwise hold the whole report, so it is raced
	# against a timer rather than awaited on its own.
	var timeout := get_tree().create_timer(STEP_TIMEOUT)
	var done := [false]
	var result := {"error": OK, "code": 0, "body": "", "seconds": 0.0}
	var on_done := func(res: int, code: int, _h: PackedStringArray,
			data: PackedByteArray) -> void:
		result["error"] = OK if res == HTTPRequest.RESULT_SUCCESS else res
		result["code"] = code
		result["body"] = data.get_string_from_utf8().substr(0, 400)
		done[0] = true
	_http.request_completed.connect(on_done, CONNECT_ONE_SHOT)
	while not done[0]:
		if timeout.time_left <= 0.0:
			_http.cancel_request()
			result["error"] = ERR_TIMEOUT
			break
		await get_tree().process_frame
	result["seconds"] = float(Time.get_ticks_msec() - began) / 1000.0
	return result

func _ws_state_name(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING: return "CONNECTING"
		WebSocketPeer.STATE_OPEN: return "OPEN"
		WebSocketPeer.STATE_CLOSING: return "CLOSING"
		WebSocketPeer.STATE_CLOSED: return "CLOSED"
	return "?%d" % state

## HTTPRequest's own result codes, which are NOT Godot error codes and whose
## numbers mean nothing to anyone reading a report.
func _http_error_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT: return "つなげない（サーバーに到達しない）"
		HTTPRequest.RESULT_CANT_RESOLVE: return "名前が引けない（DNS）"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "接続エラー"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLSハンドシェイク失敗（証明書）"
		HTTPRequest.RESULT_NO_RESPONSE: return "応答なし"
		HTTPRequest.RESULT_TIMEOUT: return "時間切れ"
	if result == ERR_TIMEOUT:
		return "時間切れ（%.0f秒）" % STEP_TIMEOUT
	return "その他 (%d)" % result
