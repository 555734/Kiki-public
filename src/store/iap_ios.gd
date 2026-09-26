extends Node
## StoreKit, reduced to "get me a receipt".
##
## The plugin is godot-ios-plugins' inappstore, which is StoreKit 1. That
## matters in one place: SK1's idea of restoring past purchases is weaker than
## StoreKit 2's, and has been reported unreliable on recent Godot versions. So
## restoring is not trusted to the plugin -- the server is the record. A device
## that has bought the game gets the same transaction identifier back from
## Apple, and the Worker already knows that identifier, so a restore is a
## lookup rather than a re-derivation. See docs/monetization.md.

var _store = null

static func installed() -> bool:
	return Engine.has_singleton("InAppStore")

func _ready() -> void:
	if not installed():
		return
	_store = Engine.get_singleton("InAppStore")
	_store.set_auto_finish_transaction(false)

func available() -> bool:
	return _store != null

func price_of(product_id: String) -> String:
	if _store == null:
		return ""
	_store.request_product_info({"product_ids": [product_id]})
	var event := await _next_event("product_info")
	var ids: Array = event.get("ids", [])
	var prices: Array = event.get("localized_prices", [])
	var at := ids.find(product_id)
	return String(prices[at]) if at >= 0 and at < prices.size() else ""

func purchase(product_id: String) -> Dictionary:
	if _store == null:
		return {"error": "App Storeに接続できませんでした。"}
	if _store.purchase({"product_id": product_id}) != OK:
		return {"error": "購入を開始できませんでした。"}
	var event := await _next_event("purchase")
	return _receipt_from(event, product_id)

func restore(product_id: String) -> Dictionary:
	if _store == null:
		return {"error": "App Storeに接続できませんでした。"}
	_store.restore_purchases()
	var event := await _next_event("restore")
	return _receipt_from(event, product_id)

func _receipt_from(event: Dictionary, product_id: String) -> Dictionary:
	if String(event.get("result", "")) != "ok":
		return {}
	var transaction_id := String(event.get("transaction_id", ""))
	if transaction_id.is_empty():
		return {}
	# Finishing is safe only once the SERVER has the identifier; until then a
	# crash would lose the only handle on a purchase the player has paid for.
	return {
		"platform": "ios",
		"product_id": product_id,
		"transaction_id": transaction_id,
		"_finish": product_id,
	}

## Tell StoreKit the transaction is done. Called by Iap only after the Worker
## has answered, never before.
func finish(product_id: String) -> void:
	if _store != null:
		_store.finish_transaction(product_id)

## The plugin delivers everything through one pending-event queue rather than
## through signals, so waiting for a particular kind means draining it.
func _next_event(kind: String) -> Dictionary:
	for _i in 600:
		while _store.get_pending_event_count() > 0:
			var event: Dictionary = _store.pop_pending_event()
			if String(event.get("type", "")) == kind:
				return event
		await get_tree().create_timer(0.1).timeout
	return {}
