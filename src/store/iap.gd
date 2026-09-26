extends Node
## The store, behind one door.
##
## Two things happen on a purchase and only the first is the store's:
##
##   1. the platform sells the item and hands back a receipt
##   2. the entitlement server checks that receipt with Apple or Google and
##      issues the signed token this game actually believes
##
## Step 2 is why nothing here decides anything. A backend's job is to get a
## receipt and hand it over; it never unlocks a stage, and there is no path
## from "the plugin said yes" to a playable stage that does not go through the
## server. That is what makes a patched plugin worth nothing.
##
## Built the way EosRuntime is: if the native half is missing -- in the editor,
## in a headless test, in a desktop build -- available() is false and every
## call says so politely instead of crashing. The game is fully playable in
## that state; it is just a game where nothing can be bought.

## Both stores, one id. Nothing in the existing setup forced them apart, and two
## ids is two places for a typo to become a support thread.
const PRODUCT_ID := "full_unlock"

signal changed

var _backend: Node = null
var _price: String = ""

func _ready() -> void:
	_backend = _make_backend()
	if _backend != null:
		add_child(_backend)
		_refresh_price()
	# Nothing here runs at launch: the entitlement is bound to an EOS
	# ProductUserId, and there is no such thing until EOS has logged in --
	# which only happens when somebody goes online. A device that never plays
	# online never makes a request, and keeps playing on the token it has.
	EosRuntime.state_changed.connect(_on_eos_state)

func _on_eos_state(state: int, _detail: String) -> void:
	if state != EosRuntime.State.READY:
		return
	var puid := EosRuntime.product_user_id()
	Entitlement.bind_to(puid)
	await renew_if_stale()
	# A token that was just dropped for naming a different device is exactly
	# the case "restore" exists for, and it can be done without asking.
	if Entitlement.level() == Entitlement.Level.FREE and available():
		await restore()

func available() -> bool:
	return _backend != null and _backend.available()

## The store's own words for the price, in the player's own currency, or ""
## until the store has answered. Never a number from this repository: a build
## cannot know a regional price, and one hard-coded figure is how a store
## listing and a game end up disagreeing in public.
func price_text() -> String:
	return _price

func product_id() -> String:
	return PRODUCT_ID

## Returns "" on success, or a sentence to show the player.
func purchase() -> String:
	if not available():
		return "このビルドではストアに接続できません。"
	var receipt: Dictionary = await _backend.purchase(PRODUCT_ID)
	return await _redeem(receipt)

func restore() -> String:
	if not available():
		return "このビルドではストアに接続できません。"
	var receipt: Dictionary = await _backend.restore(PRODUCT_ID)
	return await _redeem(receipt)

## Quietly top up a token that is getting old. Called at launch; never blocks
## anything and never takes an unlock away on its own -- a device that cannot
## reach the server keeps playing on the token it already has until that token
## genuinely expires. See docs/monetization.md on store outages.
func renew_if_stale() -> void:
	if not Entitlement.wants_renewal():
		return
	var puid := EosRuntime.product_user_id()
	if puid.is_empty():
		return
	var answer: Dictionary = await EntitlementClient.renew(Entitlement.local_token(), puid)
	if bool(answer.get("revoked", false)):
		# The one case where an unlock is withdrawn: the server says the
		# purchase was refunded or cancelled. It is the server's call, never
		# a guess made here from a failed request.
		Entitlement.clear_token()
		changed.emit()
		return
	var token := String(answer.get("token", ""))
	if not token.is_empty():
		Entitlement.install_token(token, puid)
		changed.emit()

# ------------------------------------------------------------------ internals

## Hand the store's receipt to the entitlement server and keep what it signs.
func _redeem(receipt: Dictionary) -> String:
	if receipt.has("error"):
		return String(receipt["error"])
	if receipt.is_empty():
		return "購入が見つかりませんでした。"
	var puid := EosRuntime.product_user_id()
	if puid.is_empty():
		return "オンラインの準備ができていません。通信を確認してもう一度お試しください。"
	var answer: Dictionary = await EntitlementClient.verify(receipt, puid)
	if answer.has("error"):
		return String(answer["error"])
	var token := String(answer.get("token", ""))
	if token.is_empty() or not Entitlement.install_token(token, puid):
		return "購入は確認できましたが、権限を受け取れませんでした。"
	changed.emit()
	return ""

func _refresh_price() -> void:
	if not available():
		return
	_price = await _backend.price_of(PRODUCT_ID)
	changed.emit()

## One backend per platform, and none anywhere else.
##
## Each backend answers for itself whether its plugin is actually present,
## rather than this asking what OS it is on: a build exported without the
## plugin then behaves exactly like a build on a platform that has no store,
## which is what it is. Both scripts are loaded dynamically and name no type
## from an addon, so a checkout that has never run tools/install-iap-plugins.sh
## -- every checkout the tests run in -- still parses.
func _make_backend() -> Node:
	var android := load("res://src/store/iap_android.gd")
	if android.installed():
		return android.new()
	var ios := load("res://src/store/iap_ios.gd")
	if ios.installed():
		return ios.new()
	return null
