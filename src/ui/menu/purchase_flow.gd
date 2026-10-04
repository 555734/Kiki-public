class_name PurchaseFlow
extends RefCounted
## What happens when a player taps a stage they have not bought: the purchase
## screen and its three doors -- buy, restore, or carry the stage to a friend's
## room without buying it -- and the store calls behind the first two.

var panel = null
var _screen: PurchasePanel = null

func _init(owner_panel) -> void:
	panel = owner_panel

func showing() -> bool:
	return _screen != null and is_instance_valid(_screen)

func show(which: int) -> void:
	if showing():
		return
	var info := StageCards.for_which(which)
	_screen = PurchasePanel.new()
	_screen.stage_number = String(info.get("number", ""))
	_screen.stage_name = String(info.get("name", ""))
	_screen.price_text = Iap.price_text()
	_screen.closed.connect(func() -> void: _screen = null)
	_screen.buy_requested.connect(_on_buy)
	_screen.restore_requested.connect(_on_restore)
	_screen.join_requested.connect(func() -> void: _on_join_as_guest(which))
	panel._root.add_child(_screen)
	if not Iap.available():
		_screen.set_store_available(false)
		_screen.say(Iap.unavailable_message())

## The middle door. It does not unlock anything -- it lets the player carry a
## stage they cannot host as far as the room-code field, where the unlock will
## arrive from the person who did buy it. If nobody answers, they have taken
## nothing they should not have.
func _on_join_as_guest(which: int) -> void:
	NetPanel._join_only = true
	_close()
	panel._select_stage(which)

func _on_buy() -> void:
	if not showing():
		return
	if not Iap.available():
		_screen.say(Iap.unavailable_message())
		return
	_screen.set_busy(true)
	_screen.say("ストアに接続しています…")
	var result: String = await Iap.purchase()
	_after_store(result)

func _on_restore() -> void:
	if not showing():
		return
	if not Iap.available():
		_screen.say(Iap.unavailable_message())
		return
	_screen.set_busy(true)
	_screen.say("購入履歴を確認しています…")
	var result: String = await Iap.restore()
	_after_store(result)

func _after_store(error: String) -> void:
	if not showing():
		return
	_screen.set_busy(false)
	if error.is_empty() and Entitlement.unlocked():
		_close()
		NetPanel._join_only = false
		panel._refresh_stage_buttons()
		return
	_screen.say(error if not error.is_empty()
		else "購入が見つかりませんでした。別のアカウントで購入した場合は、"
			+ "そのアカウントでストアにログインしてからもう一度お試しください。")

func _close() -> void:
	if showing():
		_screen.queue_free()
	_screen = null
