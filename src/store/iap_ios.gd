extends Node
## StoreKit, reduced to "get me a receipt".
##
## The plugin is godot-ios-plugins' inappstore, which is StoreKit 1. Two things
## about SK1 shape this file:
##
## * A restore does NOT give back the purchase's transaction identifier. Each
##   restored transaction gets a new one, and the purchase it restores is its
##   originalTransaction. Apple's server API and the Worker know the purchase
##   by that original id, so the receipt carries original_transaction_id --
##   which the stock plugin does not report; tools/patches adds it.
## * Everything arrives on one pending-event queue. One reader (_pump) drains
##   it into an inbox and each caller takes only what is its own, so a price
##   lookup still waiting at launch can never swallow a restore's answer.
##
## The server is the record either way: see docs/monetization.md.

## How long a purchase or a restore may take, Apple ID password included.
const WAIT_SECONDS := 180.0
## Old, unclaimed events kept at most (a replayed purchase nobody waits for).
const INBOX_MAX := 64

var _store = null
var _inbox: Array[Dictionary] = []

static func installed() -> bool:
	return Engine.has_singleton("InAppStore")

func _ready() -> void:
	if _store == null and installed():
		use_store(Engine.get_singleton("InAppStore"))

## The StoreKit singleton, or a stand-in with the same four methods (probes).
func use_store(store) -> void:
	_store = store
	_store.set_auto_finish_transaction(false)

func available() -> bool:
	return _store != null

func price_of(product_id: String) -> String:
	if _store == null:
		return ""
	_store.request_product_info({"product_ids": [product_id]})
	var event := await _take(func(e: Dictionary) -> bool:
		return String(e.get("type", "")) == "product_info")
	var ids: Array = event.get("ids", [])
	var prices: Array = event.get("localized_prices", [])
	var at := ids.find(product_id)
	return String(prices[at]) if at >= 0 and at < prices.size() else ""

func purchase(product_id: String) -> Dictionary:
	if _store == null:
		return {"error": "App Storeに接続できませんでした。"}
	if _store.purchase({"product_id": product_id}) != OK:
		return {"error": "購入を開始できませんでした。少し待ってからもう一度お試しください。"}
	# StoreKit reports "purchasing" (result "progress") first, and "deferred"
	# (Ask to Buy) the same way: neither is the answer.
	var event := await _take(func(e: Dictionary) -> bool:
		return String(e.get("type", "")) == "purchase" \
			and String(e.get("product_id", product_id)) == product_id \
			and String(e.get("result", "")) in ["ok", "error"])
	if event.is_empty():
		return {"error": "App Storeから応答がありませんでした。購入済みなら「復元」をお試しください。"}
	return _receipt_from(event, product_id)

func restore(product_id: String) -> Dictionary:
	if _store == null:
		return {"error": "App Storeに接続できませんでした。"}
	# An earlier restore that timed out may have left its "completed" behind;
	# it would end this one before it started.
	_pump()
	_inbox = _inbox.filter(func(e: Dictionary) -> bool:
		return String(e.get("type", "")) != "restore" or String(e.get("result", "")) == "ok")
	_store.restore_purchases()
	# Each restored purchase arrives before "completed", so the first event
	# that is ours, or the end of the list, is the answer.
	var event := await _take(func(e: Dictionary) -> bool:
		if String(e.get("type", "")) != "restore":
			return false
		var result := String(e.get("result", ""))
		if result == "ok":
			return String(e.get("product_id", product_id)) == product_id
		return result == "completed" or result == "error")
	if event.is_empty():
		return {"error": "App Storeから応答がありませんでした。通信を確認してもう一度お試しください。"}
	if String(event.get("result", "")) == "completed":
		return {}
	return _receipt_from(event, product_id)

func _receipt_from(event: Dictionary, product_id: String) -> Dictionary:
	if String(event.get("result", "")) == "error":
		var why := String(event.get("error", ""))
		return {"error": "App Store: " + why if not why.is_empty() else "App Storeでエラーが起きました。"}
	if String(event.get("result", "")) != "ok":
		return {}
	var transaction_id := String(event.get("transaction_id", ""))
	if transaction_id.is_empty():
		return {}
	# Finishing is safe only once the SERVER has the identifier; until then a
	# crash would lose the only handle on a purchase the player has paid for.
	var receipt := {
		"platform": "ios",
		"product_id": product_id,
		"transaction_id": transaction_id,
		"_finish": product_id,
	}
	var original := String(event.get("original_transaction_id", ""))
	if not original.is_empty():
		receipt["original_transaction_id"] = original
	return receipt

## Tell StoreKit the transaction is done. Called by Iap only after the Worker
## has answered, never before.
func finish(product_id: String) -> void:
	if _store != null:
		_store.finish_transaction(product_id)

## Move everything StoreKit has said into the inbox.
func _pump() -> void:
	while _store.get_pending_event_count() > 0:
		_inbox.append(_store.pop_pending_event())
	while _inbox.size() > INBOX_MAX:
		_inbox.pop_front()

## The first event `wanted` accepts, removed from the inbox; {} after
## WAIT_SECONDS. Events it does not want stay for whoever does.
func _take(wanted: Callable) -> Dictionary:
	var waited := 0.0
	while true:
		_pump()
		for i in _inbox.size():
			if wanted.call(_inbox[i]):
				var event: Dictionary = _inbox[i]
				_inbox.remove_at(i)
				return event
		if waited >= WAIT_SECONDS:
			return {}
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return {}
