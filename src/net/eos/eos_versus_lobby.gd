class_name EosVersusLobby
extends RefCounted
## The EOS lobby a star match is played in: four people for 2v2, up to eight
## for the free-for-all.
##
## A sibling of EosCoopLobby rather than a wider one. The co-op lobby is two
## members by contract -- `remote_puid()` returns THE other player, and host
## migration hands the run to the guardian -- and stretching it to four would
## change what both of those mean for a mode that works today.
##
## What is different here, on purpose:
##   - up to four members, in a bucket of its own, so a versus code can never
##     find a co-op room or the other way round;
##   - no host migration: the host owns the match ledger, and a match that
##     silently moved to a guest would restart the score. The host leaving
##     ends the room for everyone, and the game says so;
##   - no Entitlement check anywhere. Versus is free for everyone, host and
##     guests alike (docs/versus-2v2-stars.md).

signal members_changed
signal failed(reason: String)
## The six digits this host will advertise, known before any EOS round trip.
signal room_code_chosen(code: String)

const CODE_LENGTH := EosCoopLobby.CODE_LENGTH
const MAX_MEMBERS := 4
const FFA_MAX_MEMBERS := 8
const BUCKET := "melos-versus"
const EOS_PATH := EosCoopLobby.EOS_PATH
const MODE_ATTRIBUTE := "mode"
const MODE_VALUE := "versus2v2"
const FFA_MODE_VALUE := "versusffa8"

## Which versus mode this lobby is for. A code only ever finds a room of the
## mode it was typed into, so a 2v2 client can never sit down in an
## eight-person room it has no chairs for.
var room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT

func _init(mode: int = VersusRoster.RoomMode.TEAM_SPLIT) -> void:
	room_mode = mode

func mode_value() -> String:
	return FFA_MODE_VALUE if room_mode == VersusRoster.RoomMode.FREE_FOR_ALL \
		else MODE_VALUE

func max_members() -> int:
	return FFA_MAX_MEMBERS if room_mode == VersusRoster.RoomMode.FREE_FOR_ALL \
		else MAX_MEMBERS

var lobby = null
var room_code: String = ""
var last_error: String = ""
var closed_by_host: bool = false

static func valid_code(code: String) -> bool:
	return EosCoopLobby.valid_code(code)

static func new_code() -> String:
	return EosCoopLobby.new_code()

func create_room() -> bool:
	var lobbies = _lobbies()
	if lobbies == null:
		return _fail("EOS Lobbyを利用できません")
	lobbies.set("presence_enabled", false)
	for attempt in 5:
		if attempt > 0 or not valid_code(room_code):
			room_code = new_code()
		room_code_chosen.emit(room_code)
		if not await _open_lobby(lobbies):
			return false
		var found = await lobbies.call("search_by_attribute_async", _search_attrs(room_code))
		if found == null or (found as Array).size() <= 1:
			_bind_lobby()
			return true
		await lobby.call("leave_async")
		lobby = null
	return _fail("空いているルーム番号を作れませんでした")

func _open_lobby(lobbies) -> bool:
	var eos = load(EOS_PATH)
	var opts = eos.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = BUCKET
	opts.disable_host_migration = true
	opts.max_lobby_members = max_members()
	opts.enable_rtc_room = false
	opts.allow_invites = false
	opts.enable_join_by_id = false
	opts.permission_level = eos.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = false
	lobby = await lobbies.call("create_lobby_async", opts)
	if lobby == null:
		return _fail("EOSルームを作れませんでした")
	lobby.call("add_attribute", "room_code", room_code)
	lobby.call("add_attribute", "protocol", VersusProtocol.VERSION)
	lobby.call("add_attribute", MODE_ATTRIBUTE, mode_value())
	lobby.call("add_attribute", "build", Balance.BUILD_ID)
	lobby.call("add_attribute", "started", 0)
	lobby.call("add_attribute", EosCoopLobby.ROOM_KIND_ATTRIBUTE,
		EosCoopLobby.ROOM_KIND_FRIEND)
	if not bool(await lobby.call("update_async")):
		return _fail("EOSルーム情報を保存できませんでした")
	return true

func join_room(code: String) -> bool:
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
		# Is it a room of the other versus mode? Worth saying so, because
		# "not found" for a code your friend is looking at is baffling.
		var any = await lobbies.call("search_by_attribute_async", [
			{"key": "room_code", "value": code},
			{"key": "protocol", "value": VersusProtocol.VERSION}])
		if any != null and (any as Array).size() > 0:
			return _fail("この番号は別のモードの部屋です")
		return _fail("そのルーム番号は見つかりません（アプリのバージョンも確認してください）")
	var candidate = matches[0]
	if EosCoopLobby._attribute_int(candidate, "started", 0) != 0:
		return _fail("このルームはすでに対戦中です")
	lobby = await lobbies.call("join_async", candidate)
	if lobby == null:
		return _fail("EOSルームに参加できませんでした（満員の可能性があります）")
	_bind_lobby()
	members_changed.emit()
	return true

## Written once the match starts, so a code read out late cannot drop a fifth
## person into a match already under way.
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

func member_count() -> int:
	return (lobby.get("members") as Array).size() if lobby != null else 0

func contains_puid(puid: String) -> bool:
	if lobby == null:
		return false
	for member in lobby.get("members"):
		if String(member.get("product_user_id")) == puid:
			return true
	return false

## A P2P socket name derived from the lobby, so only people who found this
## lobby can guess it. Prefixed differently from co-op's.
func socket_id() -> String:
	if lobby == null:
		return ""
	return "vs" + String(lobby.get("lobby_id")).sha256_text().substr(0, 28)

func leave() -> void:
	if lobby == null:
		return
	lobby.call_deferred("leave_async")
	lobby = null

func refresh() -> void:
	if lobby != null and lobby.has_method("_copy_lobby_data"):
		lobby.call("_copy_lobby_data")

func _bind_lobby() -> void:
	if not lobby.is_connected("lobby_updated", _on_updated):
		lobby.connect("lobby_updated", _on_updated)
	if not lobby.is_connected("lobby_owner_changed", _on_owner_changed):
		lobby.connect("lobby_owner_changed", _on_owner_changed)
	if not lobby.is_connected("kicked_from_lobby", _on_kicked):
		lobby.connect("kicked_from_lobby", _on_kicked)

func _on_updated() -> void:
	members_changed.emit()

## Migration is disabled, so a new owner can only mean the old one is gone.
func _on_owner_changed() -> void:
	closed_by_host = true
	_fail("ホストが部屋を閉じました")

func _on_kicked() -> void:
	closed_by_host = true
	_fail("EOSルームから切断されました")

func _search_attrs(code: String) -> Array[Dictionary]:
	return [
		{"key": "room_code", "value": code},
		{"key": "protocol", "value": VersusProtocol.VERSION},
		{"key": MODE_ATTRIBUTE, "value": mode_value()},
	]

func _lobbies():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("HLobbies") if tree != null else null

func _fail(reason: String) -> bool:
	last_error = reason
	failed.emit(reason)
	return false
