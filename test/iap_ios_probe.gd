extends Node
## The StoreKit side of buying and restoring, against a stand-in InAppStore
## that speaks the plugin's event shapes (godot-ios-plugins' in_app_store.mm,
## plus tools/patches/inappstore-original-id.patch). What only a device and an
## App Store account can prove is listed in docs/monetization.md.

const IapIos = preload("res://src/store/iap_ios.gd")

## The four calls iap_ios.gd makes, and a script of events per call.
class FakeStore extends RefCounted:
	var queue: Array[Dictionary] = []
	var on_purchase: Array[Dictionary] = []
	var on_restore: Array[Dictionary] = []
	var on_info: Array[Dictionary] = []
	func set_auto_finish_transaction(_on: bool) -> void: pass
	func finish_transaction(_id: String) -> void: pass
	func get_pending_event_count() -> int: return queue.size()
	func pop_pending_event() -> Dictionary: return queue.pop_front()
	func request_product_info(_q: Dictionary) -> int:
		queue.append_array(on_info)
		return OK
	func purchase(_q: Dictionary) -> int:
		queue.append_array(on_purchase)
		return OK
	func restore_purchases() -> void:
		queue.append_array(on_restore)

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func _ready() -> void:
	call_deferred("run")

func _backend(store: FakeStore) -> Node:
	var b: Node = IapIos.new()
	add_child(b)
	b.use_store(store)
	return b

func run() -> void:
	# Buying: "purchasing" comes first and is not the answer.
	var s := FakeStore.new()
	s.on_purchase = [
		{"type": "purchase", "result": "progress", "product_id": "full_unlock"},
		{"type": "purchase", "result": "ok", "product_id": "full_unlock",
			"transaction_id": "1000000001", "original_transaction_id": "1000000001"}]
	var b := _backend(s)
	var r: Dictionary = await b.purchase("full_unlock")
	check(r.get("transaction_id", "") == "1000000001",
		"a purchase waits past 'purchasing' for the real answer")

	# Restoring after a reinstall: a new id, and the purchase's original.
	s.on_restore = [
		{"type": "restore", "result": "ok", "product_id": "full_unlock",
			"transaction_id": "2000000099", "original_transaction_id": "1000000001"},
		{"type": "restore", "result": "completed"}]
	r = await b.restore("full_unlock")
	check(r.get("original_transaction_id", "") == "1000000001"
		and r.get("transaction_id", "") == "2000000099",
		"a restore sends the purchase's original transaction id to the server")

	# A price lookup still waiting must not swallow the restore's answer.
	var s2 := FakeStore.new()
	var b2 := _backend(s2)
	s2.on_restore = s.on_restore
	var price_done := [false]
	var lookup := func() -> void:
		await b2.price_of("full_unlock")
		price_done[0] = true
	lookup.call()
	await get_tree().create_timer(0.3).timeout
	r = await b2.restore("full_unlock")
	check(r.get("original_transaction_id", "") == "1000000001",
		"a restore is answered even while the price lookup is still waiting")
	s2.queue.append({"type": "product_info", "ids": ["full_unlock"],
		"localized_prices": ["¥480"]})
	await get_tree().create_timer(0.3).timeout
	check(price_done[0], "and the price lookup still gets its own answer")

	# Nothing to restore, and a failed restore, say so.
	var s3 := FakeStore.new()
	var b3 := _backend(s3)
	s3.on_restore = [{"type": "restore", "result": "completed"}]
	r = await b3.restore("full_unlock")
	check(String(r.get("error", "")).contains("App Store"),
		"an account with nothing to restore is told so, in the App Store's name")
	s3.on_restore = [{"type": "restore", "result": "error", "error": "Cannot connect to iTunes Store"}]
	r = await b3.restore("full_unlock")
	check(String(r.get("error", "")).contains("Cannot connect"),
		"a failed restore shows the App Store's own reason")

	if failures.is_empty():
		print("iap ios probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("iap ios probe: " + f)
		get_tree().quit(1)
