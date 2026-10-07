class_name StageSelectView
extends VBoxContainer
## The first screen of the start menu: a page of three stage tiles, the page
## arrows, a horizontal swipe between pages, and the way into versus.
##
## Each tile is a thumbnail of its stage (StageCards.thumbnail). Swiping left,
## or tapping the next arrow, moves on to the next three; swiping right, or the
## previous arrow, goes back to the three before.
##
## A tile only says which stage was picked; NetPanel decides what that means
## (the play screen, a reload, or the purchase screen for a locked stage).

const PER_PAGE := StageCards.PER_PAGE

var panel = null
var page: int = 0
## The row of tiles, which the swipe is measured against.
var row: HBoxContainer = null
## which -> tile button, for the tiles on this page.
var cards: Dictionary = {}
## The page arrows, for the probes.
var previous_button: Button = null
var next_button: Button = null

var _swipe := StageSwipe.new()

func _init(owner_panel, on_page: int) -> void:
	panel = owner_panel
	page = on_page
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)

	add_child(UiKit.heading("—  ステージを選択  —", 30, Color("073f89")))
	# Between stages of a kept room (CoopRoom) this is the room's stage list.
	if CoopRoom.holding():
		add_child(_room_bar())
	else:
		if not CoopRoom.parting_words.is_empty():
			add_child(UiKit.heading(CoopRoom.parting_words, 19, Color("b8420f")))
			CoopRoom.parting_words = ""
		add_child(UiKit.heading("遊ぶステージをタップ。左右にスワイプして切り替え。", 19, Color("37638d")))
	add_child(UiKit.spacer(8))

	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var all := StageCards.all()
	var first := page * PER_PAGE
	for i in range(first, mini(first + PER_PAGE, all.size())):
		var card := _card(all[i])
		row.add_child(card)
		cards[int(all[i]["which"])] = card
	# The last page may hold fewer than three. The blank slots keep the tiles
	# the same width as on every other page.
	for i in range(PER_PAGE - row.get_child_count()):
		var filler := Control.new()
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(filler)
	refresh()

	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 18)
	add_child(navigation)
	var previous := UiKit.action_button("‹  前のステージ", func() -> void: panel._change_stage_page(-1))
	previous.disabled = page == 0
	previous.custom_minimum_size = Vector2(200, 54)
	navigation.add_child(previous)
	previous_button = previous
	var last := mini(first + PER_PAGE, all.size()) - 1
	var page_label := UiKit.heading("%s  〜  %s" % [all[first]["number"], all[last]["number"]],
		20, Color("073f89"))
	page_label.custom_minimum_size.x = 160
	navigation.add_child(page_label)
	var next := UiKit.action_button("次のステージ  ›", func() -> void: panel._change_stage_page(1))
	next.disabled = first + PER_PAGE >= all.size()
	next.custom_minimum_size = Vector2(200, 54)
	navigation.add_child(next)
	next_button = next
	# 2v2 versus. Always shown and never locked: versus is free for every
	# player, whatever they have bought (docs/versus-2v2-stars.md).
	var versus := UiKit.action_button("⚔  スターたいせん", panel._on_versus)
	versus.custom_minimum_size = Vector2(240, 54)
	versus.add_theme_color_override("font_color", Color("b8420f"))
	# Not from inside a co-op room: that would be leaving it by another door.
	versus.visible = not CoopRoom.holding()
	navigation.add_child(versus)

	if not CoopRoom.holding():
		add_child(UiKit.heading("カードを選ぶと、遊び方と難易度の画面へ進みます", 18, Color("416b91")))

## The room this pair are still in, between stages: its code, who chooses,
## and the one way out of it.
func _room_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	var text := tr("ルーム %s に接続中") % RoomBanner.spaced(CoopRoom.room_code)
	text += "  ·  " + (tr("次のステージを選んでください") if CoopRoom.is_host
		else tr("ホストがステージを選んでいます…"))
	bar.add_child(UiKit.heading(text, 19, Color("0b6b3a")))
	var leave := UiKit.action_button("接続を切る", panel._on_leave_room)
	leave.custom_minimum_size = Vector2(180, 48)
	leave.add_theme_color_override("font_color", Color("b8420f"))
	bar.add_child(leave)
	return bar

static func page_count() -> int:
	return ceili(float(StageCards.all().size()) / PER_PAGE)

## Selection badge, lock and rim, from the current stage and entitlements.
## Run again after a purchase without rebuilding the page.
func refresh() -> void:
	for which in cards:
		var button: Button = cards[which]
		var selected: bool = which == Stage.current()
		var accent: Color = button.get_meta("accent")
		var badge: Label = button.get_meta("badge")
		badge.visible = selected
		# A locked card is still a button: tapping it is how the player finds
		# out what it would take to play, which is the whole point of putting
		# the three doors behind it rather than greying it out and saying no.
		var locked: bool = not Entitlement.can_play(which)
		for node in (button.get_meta("lock") as Array):
			(node as CanvasItem).visible = locked
		button.add_theme_stylebox_override("normal",
			UiKit.stage_style(accent if selected else Color.WHITE, 0.30 if selected else 0.94,
				18, 5 if selected else 2))
		# In a kept room only the host chooses; the guest's cards show what is coming.
		button.disabled = CoopRoom.holding() and not CoopRoom.is_host

func _card(info: Dictionary) -> Button:
	var number: String = info["number"]
	var accent: Color = info["accent"]
	var which: int = int(info["which"])
	var button := Button.new()
	button.text = number
	button.custom_minimum_size = Vector2(300, 260)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_stylebox_override("normal", UiKit.stage_style(Color.WHITE, 0.94, 18, 2))
	button.add_theme_stylebox_override("hover", UiKit.stage_style(accent, 0.28, 18, 4))
	button.add_theme_stylebox_override("pressed", UiKit.stage_style(accent, 0.42, 18, 4))
	button.pressed.connect(func() -> void:
		if not _swipe.consumed:
			panel._select_stage(which))
	panel.guard(button)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The thumbnail is cropped around the stage's runner, enemy and terrain.
	# The caption occupies the bottom of the tile, so a centered cover crop hid
	# the action and left mostly sky visible above the text.
	art.texture = StageCards.thumbnail(info)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Leave the button's coloured selection rim visible around the artwork.
	art.offset_left = 5
	art.offset_top = 5
	art.offset_right = -5
	art.offset_bottom = -5
	button.add_child(art)

	# A ramp rather than a bar. The flat panel that used to sit here cut the
	# picture in half along a hard horizontal line, which read as two images
	# stacked rather than as one card with writing on it.
	button.add_child(UiKit.scrim(152, false))
	button.add_child(UiKit.scrim(72, true))

	var caption := VBoxContainer.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 12
	caption.offset_right = -12
	caption.offset_top = -132
	caption.offset_bottom = -12
	caption.alignment = BoxContainer.ALIGNMENT_END
	caption.add_theme_constant_override("separation", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := UiKit.heading(number, 26, accent)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_color_override("font_outline_color", Color(0, 0.06, 0.12, 0.9))
	heading.add_theme_constant_override("outline_size", 6)
	caption.add_child(heading)
	var stage_title := UiKit.heading(tr(String(info["name"])), 17, Color.WHITE)
	stage_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(stage_title)
	var blurb := UiKit.heading(tr(String(info["blurb"])), 15, Color("c8dced"))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_child(blurb)
	button.add_child(caption)

	var badge := UiKit.heading("✓", 32, accent)
	badge.position = Vector2(18, 10)
	badge.size = Vector2(100, 50)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.add_theme_color_override("font_outline_color", Color.WHITE)
	badge.add_theme_constant_override("outline_size", 7)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(badge)
	# The lock is built for every card and shown only where it belongs, so
	# refresh() can turn it on and off after a purchase without rebuilding the
	# screen.
	var lock_shade := ColorRect.new()
	lock_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_shade.offset_left = 5
	lock_shade.offset_top = 5
	lock_shade.offset_right = -5
	lock_shade.offset_bottom = -5
	lock_shade.color = Color(0.04, 0.12, 0.22, 0.52)
	lock_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lock_shade)
	var lock := UiKit.heading("🔒", 30, Color(1, 1, 1, 0.94))
	lock.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lock.offset_top = 70
	lock.offset_bottom = 126
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lock)

	button.set_meta("which", which)
	button.set_meta("accent", accent)
	button.set_meta("badge", badge)
	button.set_meta("lock", [lock_shade, lock])
	return button

# -------------------------------------------------------------------- swipe

## A horizontal drag across the cards turns the page. Read from the panel's
## _input, because the cards are buttons and would swallow the drag.
func handle_swipe(event: InputEvent) -> void:
	if _swipe.handle(event, row.get_global_rect(), panel._change_stage_page):
		get_viewport().set_input_as_handled()
