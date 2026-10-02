extends Node
## What App Review rejected 0.9.0 (387632) for, checked on the real scenes.
##
##   Guideline 4    -- no way back to home from a stage; controls crowding the
##                     play area on iPad
##   Guideline 2.1  -- the in-app purchase could not be found
##
## Run:  godot --headless --path . res://test/review_fixes_probe.tscn

var _failures: Array[String] = []
var main: Node2D = null

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	TranslationServer.set_locale("ja")
	ControlLayout.forget()
	_test_tablet_controls()
	await _test_full_game_is_on_the_home_screen()
	await _test_menu_button_pauses_and_goes_home()
	_test_english_hud_strings()
	for failure in _failures:
		push_error("review fixes probe: " + failure)
	print("review fixes probe: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)

# ------------------------------------------------------------------ layout

## Phones keep exactly the layout they had; 4:3 and iPad Air shapes get a
## smaller one, and every control still fits on screen without overlapping
## another or the menu button.
func _test_tablet_controls() -> void:
	var phone := Vector2(1556, 720)
	_check(is_equal_approx(ControlLayout.unit(phone), 720.0), "a phone keeps its control size")
	_check(is_equal_approx(ControlLayout.unit(Vector2(1280, 720)), 720.0),
		"16:9 keeps its control size")
	for view: Vector2 in [Vector2(1280, 960), Vector2(1280, 889), Vector2(1280, 853)]:
		var shrunk: float = ControlLayout.unit(view) / view.y
		_check(shrunk < 0.75, "%s: controls are smaller relative to the screen (%.2f)" % [view, shrunk])
		var menu := ControlLayout.menu_rect(view)
		for mode in ControlLayout.MODES:
			var places := ControlLayout.layout(mode, view, false)
			var ids := places.keys()
			for i in ids.size():
				var a: Dictionary = places[ids[i]]
				var ra := float(a["radius"])
				var ca: Vector2 = a["center"]
				_check(ca.x - ra >= 0.0 and ca.y - ra >= 0.0 and ca.x + ra <= view.x
					and ca.y + ra <= view.y, "%s %s: %s is on screen" % [view, mode, ids[i]])
				_check(not Rect2(ca - Vector2(ra, ra), Vector2(ra, ra) * 2.0).intersects(menu),
					"%s %s: %s clear of the menu button" % [view, mode, ids[i]])
				for j in range(i + 1, ids.size()):
					var b: Dictionary = places[ids[j]]
					var gap: float = ca.distance_to(b["center"]) - ra - float(b["radius"])
					if a["kind"] == "stick" or b["kind"] == "stick":
						continue   # the stick's capture area deliberately overlaps nothing drawn
					_check(gap > 0.0, "%s %s: %s and %s do not overlap" % [view, mode, ids[i], ids[j]])

# ------------------------------------------------------------- purchasing

func _boot() -> NetPanel:
	Stage.use(Stage.Which.GREENFIELD)
	if main != null:
		main.free()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	return main.get_node_or_null("NetPanel") as NetPanel

func _test_full_game_is_on_the_home_screen() -> void:
	var panel := await _boot()
	_check(panel != null, "the home screen is up at launch")
	if panel == null:
		return
	var buy := panel.find_child("FullGame", true, false) as Button
	_check(buy != null and buy.is_visible_in_tree(), "the home screen offers the full game")
	if buy == null:
		return
	var rect := buy.get_global_rect()
	var view := get_viewport().get_visible_rect().size
	_check(rect.position.x >= 0.0 and rect.end.x <= view.x and rect.position.y >= 0.0,
		"the full game button is on screen (%s)" % rect)
	_check(not buy.disabled, "a free player can press it")
	buy.pressed.emit()
	await _frames(2)
	var shop := panel.find_children("*", "PurchasePanel", true, false)
	_check(shop.size() == 1, "pressing it opens the purchase screen")
	if shop.is_empty():
		return
	var labels: Array[String] = []
	for b in (shop[0] as Node).find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	_check(labels.any(func(t: String) -> bool: return t.contains("完全版を購入する")),
		"the purchase screen has a buy button (%s)" % [labels])
	_check(labels.any(func(t: String) -> bool: return t.contains("復元")),
		"and a restore button")
	_check(not labels.any(func(t: String) -> bool: return t.contains("友達")),
		"and no friend door, with no stage chosen")
	(shop[0] as Node).queue_free()
	await _frames(1)

# -------------------------------------------------------------- home menu

func _test_menu_button_pauses_and_goes_home() -> void:
	var panel := await _boot()
	if panel != null:
		panel.queue_free()
	await _frames(3)
	var button := main.find_child("MenuButton", true, false) as Button
	_check(button != null and button.is_visible_in_tree(), "the menu button is on screen during play")
	if button == null:
		return
	var hub: InputHub = main.input_hub
	# A finger on it must not also be a finger in the world.
	var placed_before: Vector2 = hub.aim_point
	var at := button.get_global_rect().get_center()
	hub._touch_down(0, at)
	_check(not hub._touch_owner.has(0), "a touch on the menu button is not routed to the game")
	hub._touch_up(0, at)
	_check(hub.aim_point == placed_before, "and does not move the aim")

	button.pressed.emit()
	await _frames(2)
	var menu := main.get_node_or_null("PauseMenu") as PauseMenu
	_check(menu != null, "the menu button opens the menu")
	if menu == null:
		return
	_check(main.process_mode == Node.PROCESS_MODE_DISABLED and not GameState.running,
		"offline, the world stands still behind the menu")
	_check(not button.is_visible_in_tree(), "the button hides while its menu is open")
	_check(menu.find_child("Home", true, false) != null, "the menu offers a way home")
	menu.close()
	await _frames(2)
	_check(main.process_mode != Node.PROCESS_MODE_DISABLED and GameState.running,
		"resuming lets the world go on")

	# Pressing Home reloads the current scene, which here would be this probe;
	# what is checked is that the button is wired to the way home.
	button.pressed.emit()
	await _frames(2)
	menu = main.get_node_or_null("PauseMenu") as PauseMenu
	_check(menu != null, "the menu opens a second time")
	if menu == null:
		return
	var home := menu.find_child("Home", true, false) as Button
	var wired := false
	for c in home.pressed.get_connections():
		wired = wired or (c["callable"] as Callable).get_method() == "go_home"
	_check(wired, "the home button goes home")
	menu.close()
	await _frames(1)
	main.free()
	main = null

func _test_english_hud_strings() -> void:
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("Reach the village gate") == "Reach the village gate",
		"English devices keep English objectives")
	_check(TranslationServer.translate("⌂  ホームに戻る（ステージ選択）").begins_with("⌂  Back to home"),
		"the home button is translated")
	_check(TranslationServer.translate("★  完全版を購入（全ステージ）").contains("full game"),
		"the full game button is translated")
	TranslationServer.set_locale("ja")
	_check(TranslationServer.translate("Reach the village gate") == "村の門をめざせ",
		"Japanese devices see Japanese objectives")
