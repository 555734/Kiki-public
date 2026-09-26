extends Node
## Owns EOS startup for release builds while keeping the game scripts loadable
## without native EOS binaries. EOSG is restored by CI before import/export.

signal state_changed(state: int, detail: String)

enum State { UNINITIALIZED, STARTING, READY, FAILED }

const CREDENTIALS_PATH := "res://eos_credentials.json"
const EOSG_ROOT := "res://addons/epic-online-services-godot"

var state: int = State.UNINITIALIZED
var last_error: String = ""

func available() -> bool:
	return ClassDB.can_instantiate("EOSGMultiplayerPeer") \
		and ResourceLoader.exists(EOSG_ROOT + "/heos/hcredentials.gd")

func product_user_id() -> String:
	var auth := get_node_or_null("/root/HAuth")
	return String(auth.get("product_user_id")) if auth != null else ""

func ensure_ready() -> bool:
	if state == State.READY:
		return true
	if state == State.STARTING:
		while state == State.STARTING:
			await state_changed
		return state == State.READY
	if not available():
		_fail("EOSライブラリがこのビルドに含まれていません")
		return false
	if not FileAccess.file_exists(CREDENTIALS_PATH):
		_fail("EOS接続設定がこのビルドに含まれていません")
		return false

	_set_state(State.STARTING, "EOSを初期化しています")
	var raw := FileAccess.get_file_as_string(CREDENTIALS_PATH)
	var values = JSON.parse_string(raw)
	if typeof(values) != TYPE_DICTIONARY:
		_fail("EOS接続設定を読み取れません")
		return false
	for key in ["product_name", "product_version", "product_id", "sandbox_id",
			"deployment_id", "client_id", "client_secret"]:
		if String(values.get(key, "")).is_empty():
			_fail(TranslationServer.translate("EOS接続設定に %s がありません") % key)
			return false

	var credentials_script = load(EOSG_ROOT + "/heos/hcredentials.gd")
	var credentials = credentials_script.new()
	# Assign only the audited HCredentials fields. Object membership is not a
	# supported GDScript operation and would fail before EOS was initialized.
	for key in ["product_name", "product_version", "product_id", "sandbox_id",
			"deployment_id", "client_id", "client_secret"]:
		credentials.set(key, values[key])

	var platform := get_node_or_null("/root/HPlatform")
	var auth := get_node_or_null("/root/HAuth")
	var p2p := get_node_or_null("/root/HP2P")
	if platform == null or auth == null or p2p == null:
		_fail("EOSGのAutoloadを開始できません")
		return false
	if not bool(await platform.call("setup_eos_async", credentials)):
		_fail("EOSプラットフォームの初期化に失敗しました")
		return false

	# The pinned EOSG helper is patched at install time so this reuses the
	# installation's Device ID instead of deleting it on every launch.
	var display_name := "SideSky-%s" % NetLink.client_id().substr(0, 8)
	if not bool(await auth.call("login_anonymous_async", display_name)):
		_fail("EOSの匿名ログインに失敗しました")
		return false
	# EOS relay is allowed only as EOS's free NAT fallback. No server of our own
	# receives gameplay packets.
	p2p.call("set_relay_control", 1)
	_set_state(State.READY, "")
	return true

func _fail(message: String) -> void:
	last_error = message
	_set_state(State.FAILED, message)

func _set_state(next: int, detail: String) -> void:
	state = next
	state_changed.emit(next, detail)
