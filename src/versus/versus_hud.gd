extends Control
## What the players need to read: who is holding how many, and how close either
## side is to ten.
##
## Screen space, in a CanvasLayer, because the camera follows the runner across
## all 16,700px of 1-1 now. The first version drew in world coordinates against
## a fixed camera, which worked only as long as the view never moved.
##
## The coins over a runner's head are NOT here -- they belong over a head, which
## is a world-space question, so the arena draws those.
##
## Everything comes through the scene's readouts (`arena.coins()`,
## `arena.score()`), never from the match or the client directly. That is what
## lets one HUD serve all three ways of running the mode: the host has a
## VersusMatch and a client has only the last snapshot, and the HUD should not
## have to know which.

const COL_INK := Color(0.96, 0.97, 0.99)
const COL_DIM := Color(0.66, 0.70, 0.78)
const COL_PANEL := Color(0.05, 0.06, 0.09, 0.82)
const COL_COIN := Color(1.0, 0.82, 0.29)

## Untyped: versus_main.gd is a scene root, not a library, so it has no
## class_name to declare here.
var arena: Node2D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The viewport, not `size`. A Control in a CanvasLayer has no parent container
## to lay it out, so its `size` stays (0,0) until something resizes it -- and
## the first version centred the scoreboard on that, which put it off the left
## edge of the screen.
func _view() -> Vector2:
	return get_viewport_rect().size

func _draw() -> void:
	if arena == null:
		return
	_scoreboard()
	_map()
	if arena.waiting():
		_waiting()
	elif arena.phase() == VersusMatch.Phase.OVER:
		_result()

func _font() -> Font:
	return Art.font()

## Both totals and the target, along the top of the screen. Read from the coins
## every frame; there is no counter here that could disagree with what is on
## screen -- and on a client the total is derived from the host's coins for the
## same reason.
func _scoreboard() -> void:
	var font := _font()
	var w := _view().x
	var panel := Rect2(Vector2(w * 0.5 - 300.0, 10.0), Vector2(600.0, 74.0))
	draw_rect(panel, COL_PANEL)

	for team in range(2):
		var x := panel.position.x + (30.0 if team == 0 else panel.size.x - 170.0)
		draw_string(font, Vector2(x, panel.position.y + 54.0),
			"%d" % arena.score(team), HORIZONTAL_ALIGNMENT_CENTER, 140.0, 52,
			ArenaRules.TEAM_COLOURS[team] * Color(1.15, 1.15, 1.15))

	draw_string(font, panel.position + Vector2(0.0, 36.0),
		"さきに %d まい" % VersusRules.WIN_AT,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 22, COL_INK)

	var loose := 0
	for c in arena.coins():
		if int(c["state"]) == ArenaCoin.State.WORLD:
			loose += 1
	var line := "おちているコイン %d" % loose
	if not String(arena.status).is_empty():
		line += "   ·   " + String(arena.status)
	draw_string(font, panel.position + Vector2(0.0, 62.0), line,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, COL_DIM)

## The lap, as a bar: where you are, where they are, where the coins are.
##
## 1-1 is 19,000px around and the screen shows about a thirteenth of it, so
## without this the other runner is simply not a thing you have any information
## about. The bar IS the lap -- its left and right edges are the same place, the
## join, which is why both ends are marked.
##
## It draws whatever `arena.map_marks()` returns and decides nothing itself.
func _map() -> void:
	var w := _view().x
	var bar := Rect2(Vector2(w * 0.5 - 300.0, 90.0), Vector2(600.0, 22.0))
	draw_rect(bar, COL_PANEL)
	draw_rect(bar, Color(0.30, 0.34, 0.42, 0.9), false, 1.5)

	# The join, at both ends, because they are the same place.
	for x in [bar.position.x, bar.position.x + bar.size.x]:
		draw_line(Vector2(x, bar.position.y - 4.0),
			Vector2(x, bar.position.y + bar.size.y + 4.0),
			Color(0.62, 0.70, 0.82, 0.9), 2.0)

	for mark in arena.map_marks():
		var x := bar.position.x + bar.size.x * clampf(float(mark["x01"]), 0.0, 1.0)
		var mid := bar.position.y + bar.size.y * 0.5
		match String(mark["kind"]):
			"coin":
				draw_circle(Vector2(x, mid), 3.0, COL_COIN)
			"them":
				var them: Color = ArenaRules.TEAM_COLOURS[int(mark["team"])]
				draw_circle(Vector2(x, mid), 5.0, them)
				draw_arc(Vector2(x, mid), 5.0, 0.0, TAU, 10,
					Color(0, 0, 0, 0.55), 1.5)
			"you":
				# Bigger, and with a pointer above it: at a glance you need to
				# find yourself first and everything else relative to you.
				var you: Color = ArenaRules.TEAM_COLOURS[int(mark["team"])]
				draw_circle(Vector2(x, mid), 7.0, you)
				draw_arc(Vector2(x, mid), 7.0, 0.0, TAU, 12, COL_INK, 2.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 5.0, bar.position.y - 6.0),
					Vector2(x + 5.0, bar.position.y - 6.0),
					Vector2(x, bar.position.y - 1.0)]), COL_INK)

## Before everyone has arrived there is nothing to play, and saying so is
## better than an empty stage that looks broken.
func _waiting() -> void:
	var font := _font()
	var panel := Rect2(Vector2(_view().x * 0.5 - 280.0, _view().y * 0.5 - 90.0),
		Vector2(560.0, 150.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_DIM, false, 2.0)
	draw_string(font, panel.position + Vector2(0.0, 58.0), "まっています",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 34, COL_INK)
	draw_string(font, panel.position + Vector2(0.0, 98.0),
		String(arena.waiting_detail()), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18,
		COL_INK)
	draw_string(font, panel.position + Vector2(0.0, 128.0),
		"ふたりで両役を操作" if arena.room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
		else "チーム戦：各チームに ランナーと ガーディアン",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 15, COL_DIM)

func _result() -> void:
	var font := _font()
	var panel := Rect2(Vector2(_view().x * 0.5 - 250.0, _view().y * 0.5 - 110.0),
		Vector2(500.0, 180.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_DIM, false, 2.0)
	var who: int = arena.winner()
	var tint: Color = ArenaRules.TEAM_COLOURS[who] if who >= 0 else COL_INK
	draw_string(font, panel.position + Vector2(0.0, 70.0),
		"%s チームの かち" % ("A" if who == 0 else "B"),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 40, tint)
	draw_string(font, panel.position + Vector2(0.0, 118.0),
		"%d  -  %d" % [arena.score(0), arena.score(1)],
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 28, COL_INK)
	draw_string(font, panel.position + Vector2(0.0, 156.0),
		"戻るボタンでメニューへ" if arena.room_mode == VersusRoster.RoomMode.DUEL_COMBINED \
		else "R でもういちど  ·  Esc でやめる",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 16, COL_DIM)
