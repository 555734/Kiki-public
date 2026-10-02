extends Control
## The larger purchase copy must still fit the phone's landscape viewport.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	var failures: Array[String] = []
	for locale in ["ja", "en"]:
		TranslationServer.set_locale(locale)
		var purchase := PurchasePanel.new()
		purchase.stage_number = "1-5"
		purchase.stage_name = "THE POISON MARSH"
		purchase.price_text = "$9.99"
		add_child(purchase)
		var buy: Button = purchase.get("_buy")
		var restore: Button = purchase.get("_restore")
		if not purchase.find_children("*", "LineEdit", true, false).is_empty():
			failures.append("%s: reviewer code entry is still visible" % locale)
		var buttons := purchase.find_children("*", "Button", true, false)
		if buttons.size() != 4:
			failures.append("%s: purchase choices are not buy, join, restore and back" % locale)
		if not buy.text.contains("$9.99"):
			failures.append("%s: purchase price is missing from the primary action" % locale)
		if not restore.flat or restore.custom_minimum_size.y >= buy.custom_minimum_size.y:
			failures.append("%s: restore is competing with the purchase action" % locale)
		purchase.set_store_available(false)
		purchase.say("このAPKは操作確認用です。完全版はGoogle Play版で購入してください。")
		if not buy.disabled or not restore.disabled:
			failures.append("%s: unavailable store still offers purchase or restore" % locale)
		if buy.text != TranslationServer.translate("▶  このビルドでは購入できません"):
			failures.append("%s: unavailable purchase button still shows a loading price" % locale)
		purchase.set_busy(true)
		purchase.set_busy(false)
		if not buy.disabled or not restore.disabled:
			failures.append("%s: store buttons re-enabled after another action" % locale)
		await get_tree().process_frame
		var cards := purchase.find_children("*", "PanelContainer", true, false)
		if cards.is_empty():
			failures.append("%s: purchase card is missing" % locale)
		else:
			var rect: Rect2 = (cards[0] as PanelContainer).get_global_rect()
			var viewport_size := get_viewport_rect().size
			if rect.position.x < 0.0 or rect.position.y < 0.0 \
					or rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
				failures.append("%s: purchase card exceeds the viewport (%s)" % [locale, rect])
		purchase.queue_free()
		await get_tree().process_frame
	for failure in failures:
		push_error("purchase layout probe: " + failure)
	print("purchase layout probe: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
