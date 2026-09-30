extends Control
## What the players need to read in the 2v2 star match: how many stars each
## team holds against the seven that win, where everybody is, and -- before and
## after play -- who the room is waiting for and who won.
##
## Screen space, in a CanvasLayer, because the camera follows a runner. The
## stars over a runner's head are NOT here -- they belong over a head, which is
## a world-space question, so the arena draws those.
##
## Everything comes through the scene's readouts (`arena.coins()`,
## `arena.score()`, `arena.map_marks()` ...), never from the match or the
## client directly. That is what lets one HUD serve all three ways of running
## the mode: the host has a VersusMatch and a client has only the last
## snapshot, and the HUD should not have to know which.

const COL_INK := Color(0.96, 0.97, 0.99)
const COL_DIM := Color(0.66, 0.70, 0.78)
## Nearly opaque. A map you have to look twice at is not doing its job.
const COL_PANEL := Color(0.05, 0.06, 0.09, 0.90)
const COL_STAR := Color(1.0, 0.82, 0.22)
const COL_STAR_EDGE := Color(0.55, 0.36, 0.05)
const COL_GROUND := Color(0.38, 0.62, 0.30, 0.95)

## Untyped: versus_main.gd is a scene root, not a library, so it has no
## class_name to declare here.
var arena: Node2D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The viewport, not `size`. A Control in a CanvasLayer has no parent container
## to lay it out, so its `size` stays (0,0) until something resizes it.
func _view() -> Vector2:
	return get_viewport_rect().size

func _draw() -> void:
	if arena == null:
		return
	_scoreboard()
	_map()
	if arena.waiting():
		_waiting()
		return
	_edge_arrows()
	var broken: String = arena.link_error()
	if not broken.is_empty():
		_broken(broken)
		return
	if arena.countdown_ticks() > 0:
		_countdown()
	elif arena.phase() == VersusMatch.Phase.OVER:
		_result()

func _font() -> Font:
	return Art.font()

## A five-pointed star, the one shape this mode is about.
func _star(at: Vector2, r: float, fill: Color, edge: Color = COL_STAR_EDGE) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + float(i) * TAU / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, maxf(1.0, r * 0.14))

## Both teams' held stars as a row of seven slots each, along the top. Read
## from the ledger every frame; on a client the total is derived from the
## host's stars for the same reason.
func _scoreboard() -> void:
	var font := _font()
	var w := _view().x
	var panel := Rect2(Vector2(w * 0.5 - 330.0, 8.0), Vector2(660.0, 66.0))
	draw_rect(panel, COL_PANEL)

	for team in range(2):
		var colour: Color = ArenaRules.TEAM_COLOURS[team]
		var held: int = arena.score(team)
		var label_x := panel.position.x + (14.0 if team == 0 else panel.size.x - 74.0)
		draw_string(font, Vector2(label_x, panel.position.y + 42.0),
			"A" if team == 0 else "B", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 30,
			colour * Color(1.2, 1.2, 1.2))
		for k in range(VersusRules.WIN_AT):
			# Team A fills from the middle outwards to the left, team B to the
			# right, so the two rows race towards the edges.
			var slot := float(k)
			var x := panel.position.x + panel.size.x * 0.5 \
				+ (-1.0 if team == 0 else 1.0) * (52.0 + slot * 30.0)
			var at := Vector2(x, panel.position.y + 30.0)
			if k < held:
				_star(at, 12.0, COL_STAR)
			else:
				_star(at, 12.0, Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.35))

	draw_string(font, panel.position + Vector2(0.0, 36.0), "VS",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, COL_DIM)
	var line := TranslationServer.translate("スターを さきに %d こ もったチームの かち") \
		% VersusRules.WIN_AT
	if not String(arena.status).is_empty() and arena.waiting():
		line += "   ·   " + String(arena.status)
	draw_string(font, panel.position + Vector2(0.0, 60.0), line,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, COL_DIM)

## The whole arena in miniature, top right: the floors, every runner and every
## loose star. The field is small enough to fit in one glance, and this is the
## glance -- you always know where the other team is.
func _map() -> void:
	var w := _view().x
	var box := Rect2(Vector2(w - 262.0, 8.0), Vector2(250.0, 66.0))
	draw_rect(box.grow(4.0), COL_PANEL)
	var map := VersusStageData.MAP_RECT
	var scale := Vector2(box.size.x / map.size.x, box.size.y / map.size.y)
	# The ground, from the same data the world is built from.
	var solids: Array[Rect2] = VersusStageData.floors()
	solids.append_array(VersusStageData.solid_decor())
	for r in solids:
		var top := maxf(r.position.y, map.position.y)
		var bottom := minf(r.end.y, map.end.y)
		if bottom <= top:
			continue
		var p := box.position + (Vector2(r.position.x, top) - map.position) * scale
		var q := box.position + (Vector2(r.end.x, bottom) - map.position) * scale
		draw_rect(Rect2(p, q - p), COL_GROUND)
	draw_rect(box, Color(0.30, 0.34, 0.42, 0.9), false, 1.5)

	for mark in arena.map_marks():
		var at := box.position + Vector2(box.size.x * float(mark["x01"]),
			box.size.y * float(mark["y01"]))
		match String(mark["kind"]):
			"star":
				_star(at, 5.0, COL_STAR)
			"them":
				var them: Color = ArenaRules.TEAM_COLOURS[int(mark["team"])]
				draw_circle(at, 5.0, them)
				draw_arc(at, 5.0, 0.0, TAU, 10, Color(0, 0, 0, 0.7), 1.5)
			"you":
				var you: Color = ArenaRules.TEAM_COLOURS[int(mark["team"])]
				draw_circle(at, 6.5, you)
				draw_arc(at, 6.5, 0.0, TAU, 12, COL_INK, 2.0)

## An arrow on the screen's edge for everything the map shows that the camera
## does not: a runner off to one side, a star up out of view. A red-edged
## arrow is the other team, gold is a star.
func _edge_arrows() -> void:
	var view := _view()
	var inset := Rect2(Vector2(40.0, 96.0), view - Vector2(80.0, 136.0))
	var centre := inset.get_center()
	var font := _font()
	for mark in arena.offscreen_marks():
		var dir: Vector2 = mark["dir"]
		if dir == Vector2.ZERO:
			continue
		# Where the ray from the centre leaves the inset rectangle.
		var tx := INF if is_zero_approx(dir.x) else (inset.size.x * 0.5) / absf(dir.x)
		var ty := INF if is_zero_approx(dir.y) else (inset.size.y * 0.5) / absf(dir.y)
		var at := centre + dir * minf(tx, ty)
		var kind := String(mark["kind"])
		var fill: Color = COL_STAR if kind == "star" \
			else ArenaRules.TEAM_COLOURS[int(mark["team"])]
		var size := 13.0 if kind == "star" else 18.0
		var side := dir.orthogonal()
		var tip := at + dir * size
		draw_colored_polygon(PackedVector2Array([tip,
			at - dir * size * 0.4 + side * size * 0.8,
			at - dir * size * 0.4 - side * size * 0.8]), fill)
		draw_polyline(PackedVector2Array([tip,
			at - dir * size * 0.4 + side * size * 0.8,
			at - dir * size * 0.4 - side * size * 0.8, tip]),
			Color(0.9, 0.15, 0.15) if kind == "them" else Color(0, 0, 0, 0.6), 2.5)
		if kind == "star":
			continue
		# How far, in body lengths of the arena's own scale: enough to tell
		# "just off screen" from "the other end".
		var metres := int(round(float(mark["distance"]) / 100.0))
		draw_string(font, at - dir * 26.0 + Vector2(-30.0, 6.0), "%dm" % metres,
			HORIZONTAL_ALIGNMENT_CENTER, 60.0, 15, COL_INK)

## Before the match: who is here, who is missing, and what happens next.
func _waiting() -> void:
	var font := _font()
	var panel := Rect2(Vector2(_view().x * 0.5 - 300.0, _view().y * 0.5 - 170.0),
		Vector2(600.0, 250.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_DIM, false, 2.0)
	var title := TranslationServer.translate("2対2 スターたいせん")
	draw_string(font, panel.position + Vector2(0.0, 44.0), title,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 30, COL_INK)
	var code := String(arena.room_code)
	if not code.is_empty():
		draw_string(font, panel.position + Vector2(0.0, 80.0),
			TranslationServer.translate("ルーム番号  %s") % code,
			HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 24, COL_STAR)
	var names := {
		0: "Aチーム ランナー", 1: "Aチーム ガーディアン",
		2: "Bチーム ランナー", 3: "Bチーム ガーディアン",
	}
	var lines: Array[Dictionary] = arena.seat_lines()
	for line in lines:
		var seat := int(line["seat"])
		var col := seat / 2
		var row := seat % 2
		var at := panel.position + Vector2(40.0 + float(col) * 280.0,
			120.0 + float(row) * 30.0)
		var colour: Color = ArenaRules.TEAM_COLOURS[int(line["team"])]
		draw_circle(at + Vector2(8.0, -6.0), 7.0,
			colour if bool(line["taken"]) else Color(1, 1, 1, 0.15))
		var text := TranslationServer.translate(names[seat])
		if bool(line["you"]):
			text += TranslationServer.translate("（あなた）")
		draw_string(font, at + Vector2(24.0, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, 250.0, 17,
			COL_INK if bool(line["taken"]) else COL_DIM)
	draw_string(font, panel.position + Vector2(0.0, 206.0),
		String(arena.waiting_detail()), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 17,
		COL_INK)
	draw_string(font, panel.position + Vector2(0.0, 234.0),
		TranslationServer.translate("ランナーは スターを あつめて、ガーディアンは 足場と壁で たすける"),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, COL_DIM)
	_debug_trace()

## Deliberately legible in a screenshot: users can report what the link said,
## not just a generic 'waiting' state. Editor builds only.
func _debug_trace() -> void:
	if not OS.has_feature("editor"):
		return
	var lines: Array[String] = arena.debug_lines()
	if lines.is_empty():
		return
	var font := _font()
	var size := _view()
	var width := minf(size.x - 36.0, 880.0)
	var count := mini(lines.size(), 4)
	var panel := Rect2(Vector2((size.x - width) * 0.5, size.y - float(count) * 19.0 - 24.0),
		Vector2(width, float(count) * 19.0 + 16.0))
	draw_rect(panel, Color(0.03, 0.05, 0.08, 0.89))
	var offset := maxi(0, lines.size() - count)
	for i in range(count):
		draw_string(font, panel.position + Vector2(8.0, 21.0 + float(i) * 19.0),
			lines[offset + i], HORIZONTAL_ALIGNMENT_LEFT, width - 16.0, 14,
			Color(0.96, 0.97, 0.99))

## The room is gone (the host left, or the link dropped). Said plainly, with
## the leave button under it, rather than a match that silently stops moving.
func _broken(reason: String) -> void:
	var font := _font()
	var panel := Rect2(Vector2(_view().x * 0.5 - 280.0, _view().y * 0.5 - 80.0),
		Vector2(560.0, 140.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, Color(0.95, 0.35, 0.30), false, 2.0)
	draw_string(font, panel.position + Vector2(0.0, 56.0),
		TranslationServer.translate("たいせんが 中断されました"),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 28, COL_INK)
	draw_string(font, panel.position + Vector2(0.0, 100.0),
		TranslationServer.translate(reason),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, COL_DIM)

func _countdown() -> void:
	var font := _font()
	var left: int = arena.countdown_ticks()
	var n := int(ceil(float(left) / 60.0))
	var centre := _view() * 0.5
	draw_circle(centre, 70.0, COL_PANEL)
	draw_string(font, centre + Vector2(-70.0, 28.0), str(n),
		HORIZONTAL_ALIGNMENT_CENTER, 140.0, 80, COL_STAR)

func _result() -> void:
	var font := _font()
	var panel := Rect2(Vector2(_view().x * 0.5 - 250.0, _view().y * 0.5 - 110.0),
		Vector2(500.0, 180.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_DIM, false, 2.0)
	var who: int = arena.winner()
	var tint: Color = ArenaRules.TEAM_COLOURS[who] if who >= 0 else COL_INK
	draw_string(font, panel.position + Vector2(0.0, 70.0),
		TranslationServer.translate("%s チームの かち") % ("A" if who == 0 else "B"),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 40, tint)
	draw_string(font, panel.position + Vector2(0.0, 118.0),
		"%d  -  %d" % [arena.score(0), arena.score(1)],
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 28, COL_INK)
	var note := "ホストが「もういちど」を押すと 再戦します" if not arena.is_host() \
		else "「もういちど」で 同じメンバーで再戦"
	draw_string(font, panel.position + Vector2(0.0, 156.0),
		TranslationServer.translate(note),
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 16, COL_DIM)
