class_name EosCoopLobby
extends RefCounted
## Two-person EOS lobby. Lobby ownership is also the sole authority election
## mechanism; gameplay never promotes itself after silence alone.

signal peer_joined
signal peer_left
signal owner_changed(owner_puid: String, local_is_owner: bool)
signal failed(reason: String)

const CODE_LENGTH := 6
const BUCKET := "side-sky-coop"
const EOS_PATH := "res://addons/epic-online-services-godot/eos.gd"
const STAGE_KEY_ATTRIBUTE := "stage_key"

var lobby = null
var room_code: String = ""
var desired_role: String = ""
var last_error: String = ""

static func valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for i in code.length():
		var c := code.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true

static func new_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%06d" % rng.randi_range(0, 999999)

func create_room(stage_id: int, stage_key: String = "") -> bool:
	desired_role = "host"
	var lobbies = _lobbies()
	if lobbies == null:
		return _fail("EOS Lobbyを利用できません")
	lobbies.set("presence_enabled", false)
	for _attempt in 10:
		var candidate := new_code()
		var found = await lobbies.call("search_by_attribute_async", _search_attrs(candidate))
		if found == null:
			return _fail("ルーム番号の確認に失敗しました")
		if (found as Array).is_empty():
			room_code = candidate
			break
	if room_code.is_empty():
		return _fail("空いているルーム番号を作れませんでした")

	var eos = load(EOS_PATH)
	var opts = eos.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = BUCKET
	opts.disable_host_migration = false
	opts.max_lobby_members = 2
	opts.enable_rtc_room = false
	opts.allow_invites = false
	opts.enable_join_by_id = false
	opts.permission_level = eos.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = false
	lobby = await lobbies.call("create_lobby_async", opts)
	if lobby == null:
		return _fail("EOSルームを作れませんでした")
	lobby.call("add_attribute", "room_code", room_code)
	lobby.call("add_attribute", "protocol", Protocol.VERSION)
	# Keep the old integer for older clients, but do not use an enum ordinal as
	# the primary identity.  A visible stage such as 1-3 must keep the same
	# network identity even when enum members are appended or reordered.
	lobby.call("add_attribute", "stage", stage_id)
	lobby.call("add_attribute", STAGE_KEY_ATTRIBUTE, _local_stage_key(stage_key, stage_id))
	lobby.call("add_attribute", "build", Balance.BUILD_ID)
	lobby.call("add_attribute", "started", 0)
	if not bool(await lobby.call("update_async")):
		return _fail("EOSルーム情報を保存できませんでした")
	_bind_lobby()
	return true

func join_room(code: String, stage_id: int, stage_key: String = "") -> bool:
	desired_role = "guest"
	room_code = code
	if not valid_code(code):
		return _fail("ルーム番号は6桁の数字で入力してください")
	var lobbies = _lobbies()
	if lobbies == null:
		return _fail("EOS Lobbyを利用できません")
	lobbies.set("presence_enabled", false)
	var found = await lobbies.call("search_by_attribute_async", _search_attrs(code))
	if found == null:
		return _fail("ルームを検索できませんでした")
	var matches: Array = found
	if matches.size() != 1:
		return _fail("そのルーム番号は見つかりません")
	var candidate = matches[0]
	var local_stage_key := _local_stage_key(stage_key, stage_id)
	var remote_stage_key := _attribute_string(candidate, STAGE_KEY_ATTRIBUTE, "")
	var remote_stage_id := _attribute_int(candidate, "stage", -1)
	if not stage_identity_matches(remote_stage_key, remote_stage_id,
			local_stage_key, stage_id):
		var remote_label := remote_stage_key if not remote_stage_key.is_empty() \
			else str(remote_stage_id)
		return _fail("相手と選択中のステージが違います（相手 %s / こちら %s）" \
			% [remote_label, local_stage_key])
	if _attribute_int(candidate, "started", 0) != 0:
		return _fail("このルームはすでにプレイ中です")
	lobby = await lobbies.call("join_async", candidate)
	if lobby == null:
		return _fail("EOSルームに参加できませんでした")
	_bind_lobby()
	_refresh_members()
	return true

func mark_started() -> void:
	if lobby == null or not local_is_owner():
		return
	lobby.call("add_attribute", "started", 1)
	await lobby.call("update_async")

func local_puid() -> String:
	return EosRuntime.product_user_id()

func owner_puid() -> String:
	return String(lobby.get("owner_product_user_id")) if lobby != null else ""

func local_is_owner() -> bool:
	return not local_puid().is_empty() and local_puid() == owner_puid()

func remote_puid() -> String:
	if lobby == null:
		return ""
	for member in lobby.get("members"):
		var puid := String(member.get("product_user_id"))
		if puid != local_puid():
			return puid
	return ""

func socket_id() -> String:
	if lobby == null:
		return ""
	return "ss" + String(lobby.get("lobby_id")).sha256_text().substr(0, 28)

func contains_puid(puid: String) -> bool:
	if lobby == null:
		return false
	for member in lobby.get("members"):
		if String(member.get("product_user_id")) == puid:
			return true
	return false

func leave() -> void:
	if lobby == null:
		return
	# Do not destroy an owned lobby here. Leaving lets EOS promote the remaining
	# member, which is the backend arbitration host migration relies on.
	lobby.call_deferred("leave_async")
	lobby = null

func _bind_lobby() -> void:
	if not lobby.is_connected("lobby_updated", _refresh_members):
		lobby.connect("lobby_updated", _refresh_members)
	if not lobby.is_connected("lobby_owner_changed", _on_owner_changed):
		lobby.connect("lobby_owner_changed", _on_owner_changed)
	if not lobby.is_connected("kicked_from_lobby", _on_kicked):
		lobby.connect("kicked_from_lobby", _on_kicked)

func _refresh_members() -> void:
	if remote_puid().is_empty():
		peer_left.emit()
	else:
		peer_joined.emit()

func _on_owner_changed() -> void:
	owner_changed.emit(owner_puid(), local_is_owner())
	_refresh_members()

func _on_kicked() -> void:
	_fail("EOSルームから切断されました")

func _search_attrs(code: String) -> Array[Dictionary]:
	return [
		{"key": "room_code", "value": code},
		{"key": "protocol", "value": Protocol.VERSION},
	]

func _attribute_int(from_lobby, key: String, fallback: int) -> int:
	var value = from_lobby.call("get_attribute", key)
	return int(value.get("value", fallback)) if typeof(value) == TYPE_DICTIONARY else fallback

func _attribute_string(from_lobby, key: String, fallback: String) -> String:
	var value = from_lobby.call("get_attribute", key)
	return String(value.get("value", fallback)).strip_edges() \
		if typeof(value) == TYPE_DICTIONARY else fallback

static func _local_stage_key(stage_key: String, stage_id: int) -> String:
	var clean := stage_key.strip_edges()
	return clean if not clean.is_empty() else str(stage_id)

## New rooms use the human-stable stage number.  The integer fallback keeps
## rooms made by the immediately preceding release joinable during rollout.
static func stage_identity_matches(remote_key: String, remote_id: int,
		local_key: String, local_id: int) -> bool:
	if not remote_key.is_empty() and not local_key.is_empty():
		return remote_key == local_key
	return remote_id == local_id

func _lobbies():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("HLobbies") if tree != null else null

func _fail(reason: String) -> bool:
	last_error = reason
	failed.emit(reason)
	return false
