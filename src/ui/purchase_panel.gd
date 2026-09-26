class_name PurchasePanel
extends Control
## What a free player sees when they tap a stage they have not bought.
##
## Three doors, because there are three real situations and pretending there is
## only one is how a store screen makes somebody feel stuck:
##
##   買う        -- they want the game
##   友達と遊ぶ  -- their friend already bought it, and that is enough
##   復元する    -- they already bought it, on this account, on another phone
##
## It is deliberately NOT a wall. The middle door is the one this game is
## actually about: a free player can play every stage tonight if the person
## they are on the phone with owns it. Saying so here, at the moment the lock
## appears, is the difference between a paywall and an invitation.
##
## The look is borrowed from NetPanel rather than invented: same panel style,
## same buttons, same font. A purchase screen that arrives in a different
## visual language reads as something bolted on, which is exactly what it is
## and exactly what it should not look like.

signal closed
signal buy_requested
signal restore_requested
signal join_requested

var stage_number: String = ""
var stage_name: String = ""
var price_text: String = ""

var _status: Label = null
var _buy: Button = null

func _ready() -> void:
	# set_anchors_AND_OFFSETS: anchors alone leave the offsets where they were,
	# which on a freshly made Control is a zero-sized box in the corner -- and
	# everything anchored inside it then lands off the top-left of the screen.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.10, 0.20, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# A centring container rather than centre anchors, because the card's size
	# is not known until its text has been laid out.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", NetPanel.panel_style())
	centre.add_child(card)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(NetPanel.heading("%s  %s" % [stage_number, stage_name], 22,
		Color("073f89")))
	box.add_child(NetPanel.heading("このステージは完全版に入っています", 14,
		Color("37638d")))
	box.add_child(_spacer(6))

	_buy = NetPanel.action_button(_price_label(), func() -> void:
		buy_requested.emit())
	_buy.custom_minimum_size.y = 54
	box.add_child(_buy)

	box.add_child(NetPanel.action_button("👥  購入済みの友達と遊ぶ", func() -> void:
		join_requested.emit()))
	box.add_child(NetPanel.heading(
		"友達が完全版を持っていれば、その人の部屋に入るだけで\n"
		+ "全ステージを一緒に遊べます。購入は要りません。", 12, Color("416b91")))
	box.add_child(_spacer(4))

	box.add_child(NetPanel.action_button("↺  購入を復元する", func() -> void:
		restore_requested.emit()))
	box.add_child(NetPanel.heading("機種変更や再インストールのあとはこちら", 12,
		Color("416b91")))

	_status = NetPanel.heading("", 13, Color("264c70"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 34
	box.add_child(_status)

	box.add_child(NetPanel.action_button("‹  もどる", func() -> void:
		closed.emit()
		queue_free()))

## The price comes from the store, never from the source. A build cannot know
## what a regional price is, and one hard-coded number is how a store listing
## and a game end up disagreeing in public.
func _price_label() -> String:
	return tr("▶  完全版を購入する（%s）") % price_text if not price_text.is_empty() \
		else tr("▶  完全版を購入する（価格を読み込み中…）")

func set_price(text: String) -> void:
	price_text = text
	if _buy != null and is_instance_valid(_buy):
		_buy.text = _price_label()

func say(message: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = tr(message)

## Purchases can be slow and can be cancelled. While one is in flight nothing
## else on this panel may be pressed, or a second tap buys a second time.
func set_busy(busy: bool) -> void:
	for node in find_children("*", "Button", true, false):
		(node as Button).disabled = busy

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
