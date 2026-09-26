extends Node
## Google Play Billing, reduced to "get me a receipt".
##
## Written against the first-party GodotGooglePlayBilling plugin, version 3.3.0
## (BillingClient, not the retired 1.x singleton API). The addon is fetched by
## tools/install-iap-plugins.sh the way EOSG is and is not committed, so every
## reference to it here is dynamic: naming the BillingClient TYPE would make
## this file fail to parse in a checkout that has not run that script, which is
## every checkout used for the automated tests.
##
## Acknowledgement is the server's job, not this file's. Google refunds a
## purchase nobody acknowledges within three days, and acknowledging from the
## phone means a player who closes the app on the receipt screen loses a game
## they paid for. The Worker acknowledges as part of verifying, which is the
## first moment the purchase is known to be real.

const BILLING_CLIENT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

var _client = null
var _connected := false
## Play refuses purchase() for a product whose details have not been queried,
## so the query is not only how the price is read -- it is a precondition.
var _details_seen := false

static func installed() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling") \
		and ResourceLoader.exists(BILLING_CLIENT)

func _ready() -> void:
	if not installed():
		return
	_client = load(BILLING_CLIENT).new()
	add_child(_client)
	_client.connected.connect(func() -> void: _connected = true)
	_client.disconnected.connect(func() -> void: _connected = false)
	_client.start_connection()

func available() -> bool:
	return _client != null

func price_of(product_id: String) -> String:
	var details := await _details(product_id)
	if details.is_empty():
		return ""
	# The plugin passes the Play Billing ProductDetails through with its keys
	# renamed, and the exact spelling has moved between billing library
	# versions. Several are tried rather than one being assumed, because the
	# cost of guessing wrong is a price that silently never appears.
	for offer_key in ["one_time_purchase_offer_details", "oneTimePurchaseOfferDetails"]:
		var offer = details.get(offer_key, null)
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		for price_key in ["formatted_price", "formattedPrice"]:
			var price := String((offer as Dictionary).get(price_key, ""))
			if not price.is_empty():
				return price
	return ""

## Returns what the Worker needs to check this purchase with Google, or an
## {"error": ...} to put in front of the player.
func purchase(product_id: String) -> Dictionary:
	if not await _wait_connected():
		return {"error": "Google Playに接続できませんでした。"}
	# Already owned is not an error, it is a restore that arrived through the
	# buy button -- which is what happens after a reinstall, and what Play
	# itself does if the buy flow is started for something the account has.
	var owned := await restore(product_id)
	if not owned.is_empty() and not owned.has("error"):
		return owned
	if (await _details(product_id)).is_empty():
		return {"error": "商品情報を読み取れませんでした。"}
	var launched = _client.purchase(product_id)
	if typeof(launched) == TYPE_DICTIONARY and int(launched.get("response_code", 0)) != 0:
		return {"error": _explain(int(launched.get("response_code", 0)))}
	var result: Dictionary = await _client.on_purchase_updated
	if int(result.get("response_code", 0)) != 0:
		return {"error": _explain(int(result.get("response_code", 0)))}
	return _receipt_from(result.get("purchases", []), product_id)

func restore(product_id: String) -> Dictionary:
	if not await _wait_connected():
		return {"error": "Google Playに接続できませんでした。"}
	_client.query_purchases(0)   # ProductType.INAPP
	var result: Dictionary = await _client.query_purchases_response
	if int(result.get("response_code", 0)) != 0:
		return {"error": _explain(int(result.get("response_code", 0)))}
	return _receipt_from(result.get("purchases", []), product_id)

func _details(product_id: String) -> Dictionary:
	if not await _wait_connected():
		return {}
	_client.query_product_details(PackedStringArray([product_id]), 0)
	var result: Dictionary = await _client.query_product_details_response
	if int(result.get("response_code", 0)) != 0:
		return {}
	_details_seen = true
	for product in result.get("product_details", []):
		if String((product as Dictionary).get("product_id", "")) == product_id:
			return product
	return {}

func _receipt_from(purchases, product_id: String) -> Dictionary:
	for item in purchases:
		var row: Dictionary = item
		var ids: Array = Array(row.get("product_ids", PackedStringArray()))
		if not ids.has(product_id):
			continue
		# PENDING is not a purchase yet -- Play says so explicitly, and paying
		# out on it is how a bank transfer that never completes becomes a free
		# copy of the game.
		if int(row.get("purchase_state", 0)) != 1:
			return {"error": "支払いの確認待ちです。完了したらもう一度お試しください。"}
		return {
			"platform": "android",
			"product_id": product_id,
			"purchase_token": String(row.get("purchase_token", "")),
			"order_id": String(row.get("order_id", "")),
		}
	return {}

func _explain(code: int) -> String:
	match code:
		1: return ""   # the player cancelled; not an error to shout about
		2, 12: return "通信できませんでした。電波を確認してもう一度お試しください。"
		3: return "この端末では購入できません。"
		4: return "この商品はいま購入できません。"
		7: return "すでに購入済みです。「購入を復元する」をお試しください。"
	return "購入できませんでした（%d）。" % code

func _wait_connected() -> bool:
	if _client == null:
		return false
	for _i in 60:
		if _connected or _client.is_ready():
			return true
		await get_tree().create_timer(0.1).timeout
	return false
