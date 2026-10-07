extends RefCounted
const R = preload("res://src/levels/radical_sections.gd")
const NAMES := ["eruption_entry", "air_drop", "false_floor", "rock_rain", "furnace_rescue",
	"crossing_lifts", "double_furnace_gate", "piston_escape", "rolling_lava", "double_deck",
	"caldera_descent", "gear_foundry", "crossed_portals", "pendulum_belt", "cooling_windows",
	"chimney_fall", "roof_spring", "core_relay", "emergency_exit", "cold_rock_rescue"]
static var _built: SectionBuilder
static var _deck_y := 0.0

static func build() -> SectionBuilder:
	if _built != null: return _built
	var b := SectionBuilder.new(Rect2(300, 400, 200, 48))
	b.add_ground(Rect2(-1400, 400, 1900, 500))
	for i in NAMES.size():
		_deck_y = 900.0 if i >= 11 else 0.0
		b.begin(NAMES[i], 1)
		_room(NAMES[i], b)
		R.finish(b, b.cursor, i % 2 == 0 or i == 19, "lava", i)
	_built = b
	return b

static func landing(b: SectionBuilder, dx: float, y: float, width: float = 280.0) -> Rect2:
	return b.ledge(dx, b.cursor.position.y - (y + _deck_y), width)

static func geyser(b: SectionBuilder, dx: float, dy: float, reach: float = 230.0, phase: float = 0.0) -> void:
	b.gimmick({"type": "volcanic_hazard", "kind": "geyser", "pos": b.at(dx, dy),
		"travel": Vector2(0, -reach), "width": 62.0, "period": 4.8, "phase": phase})

static func meteor(b: SectionBuilder, dx: float, dy: float, travel: Vector2, phase: float = 0.0) -> void:
	b.gimmick({"type": "volcanic_hazard", "kind": "meteor", "pos": b.at(dx, dy),
		"travel": travel, "width": 56.0, "period": 5.4, "phase": phase})

static func _room(name: String, b: SectionBuilder) -> void:
	var a := b.cursor
	match name:
		"eruption_entry":
			R.pad(b, b.top_of(a))
			geyser(b, 235, -25, 245)
			var out := b.ledge(420, 150, 280)
			b.ride("pad", a, out, {"at": b.top_of(a), "dir": 1})
			b.coin_line(160, 190, 330, 230, 4); b.finish(out)
		"air_drop":
			var out := landing(b, 650, 210, 230)
			var mouth := b.top_of(a, 90) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(out, -50) + Vector2(0, -320), 1, Vector2(120, 50))
			meteor(b, 755, 490, Vector2(-120, 430), 2.5)
			b.ride("warp", a, out, {"at": mouth}); b.finish(out)
		"false_floor":
			var trap := R.crumble(b, b.surface(260, 20), 230)
			var catch_ := b.ledge(260, -110, 310)
			geyser(b, 260, -240, 210, 1.1)
			var out := landing(b, 590, 300, 250)
			b.jump(a, trap); b.step("drop", trap, catch_)
			b.jump(catch_, out); b.finish(out)
		"rock_rain":
			var p := b.ledge(230, 60, 170)
			var q := b.ledge(480, 10, 210)
			meteor(b, 150, 440, Vector2(80, 352), 0.3)
			meteor(b, 550, 390, Vector2(-70, 352), 2.4)
			var out := landing(b, 750, 250)
			b.jump(a, p); b.jump(p, q); b.jump(q, out); b.finish(out)
		"furnace_rescue":
			var out := b.ledge(380, 440, 300)
			b.assist(a, out, [b.platform(160, 146), b.platform(290, 292)])
			b.finish(out)
		"crossing_lifts":
			var horizontal := b.surface(210, 20)
			var vertical := b.surface(570, 10)
			b.gimmick({"type": "moving_platform", "pos": horizontal, "span": Vector2(185, 26), "travel": Vector2(120, 0), "speed": 70.0})
			b.gimmick({"type": "moving_platform", "pos": vertical, "span": Vector2(175, 26), "travel": Vector2(0, -110), "speed": 65.0})
			var out := b.ledge(850, 90, 280)
			geyser(b, 390, -180, 320, 2.0)
			R.timed(b, a, out, [horizontal, vertical], {"tries": 32}); b.finish(out)
		"double_furnace_gate":
			var floor_ := b.span(100, 900, 0, 80)
			for j in 2:
				var dx := 340.0 + j * 310.0
				var id := "molten_gate_%d" % j
				R.switch_at(b, id, b.at(dx - 150, 130), 6)
				b.gimmick({"type": "gate", "pos": b.at(dx, 120), "span": Vector2(44, 240), "id": id})
				b.span(dx - 55, dx + 55, 500, 260)
			var mid := b.part(460, 520, floor_)
			var out := b.part(800, 900, floor_)
			b.ride("gate", a, mid, {"id": "molten_gate_0"})
			b.ride("gate", mid, out, {"id": "molten_gate_1"}); b.finish(out)
		"piston_escape":
			var floor_ := b.span(70, 650, -100, 80)
			b.span(150, 460, 55, 64)
			b.gimmick({"type": "tower_trap", "kind": "piston", "pos": b.at(300, 20), "travel": 115.0, "period": 4.8})
			var spring := b.spring_on(floor_, 210)
			var out := landing(b, 880, 180)
			meteor(b, 700, 390, Vector2(-40, 430), 1.4)
			b.step("walk", a, b.part(200, 310, floor_))
			b.ride("spring", floor_, out, {"at": spring, "sprint": true}); b.finish(out)
		"rolling_lava":
			var p := b.ledge(245, 110, 185)
			var q := b.ledge(510, 45, 200)
			b.gimmick({"type": "cave_trap", "kind": "boulder", "pos": b.at(405, -35), "travel": 175.0, "period": 3.9})
			var out := landing(b, 790, 240)
			b.jump(a, p); b.jump(p, q); b.jump(q, out); b.finish(out)
		"double_deck":
			var blink := b.surface(230, 35)
			R.blink(b, blink, 200, 1.1)
			var rescue := R.crumble(b, b.surface(270, -90), 270)
			var middle := b.ledge(510, 0, 250)
			geyser(b, 375, -190, 230, 0.7)
			var out := landing(b, 790, 210)
			R.timed(b, a, middle, [blink]); b.jump(middle, out)
			b.coins_over(rescue, 2); b.finish(out)
		"caldera_descent":
			# A real open depression, not an image of a pit. Broken terraces
			# descend 850px, with safe dry checkpoints before the lower fold.
			var first := b.ledge(220, -180, 220)
			var second := b.ledge(440, -390, 250)
			var third := b.ledge(660, -600, 250)
			var basin := b.ledge(880, -850, 340)
			meteor(b, 535, -40, Vector2(-95, 402), 1.2)
			geyser(b, 760, -900, 240, 2.0)
			b.jump(a, first); b.jump(first, second); b.jump(second, third); b.jump(third, basin)
			b.checkpoint_on(basin, -90)
			var out := b.add_ground(Rect2(3000, 1110, 280, 48))
			var mouth := b.top_of(basin, 110) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(out) + Vector2(0, -65), 2)
			b.ride("warp", basin, out, {"at": mouth}); b.finish(out)
		"gear_foundry":
			var gear := b.at(250, -40)
			var lift := b.surface(490, 30)
			b.gimmick({"type": "gear_wheel", "pos": gear, "radius": 105.0, "speed": 0.65, "dir": 1})
			b.gimmick({"type": "moving_platform", "pos": lift, "span": Vector2(175, 26), "travel": Vector2(100, -70), "speed": 65.0})
			var out := landing(b, 820, 120)
			geyser(b, 375, -190, 260, 1.0)
			R.timed(b, a, out, [gear, lift], {"tries": 32}); b.finish(out)
		"crossed_portals":
			var high := b.ledge(360, 190, 270)
			var out := landing(b, 760, 270, 290)
			var first := b.top_of(a, 90) + Vector2(0, -45)
			var second := b.top_of(high, 90) + Vector2(0, -45)
			R.portal(b, first, b.top_of(high) + Vector2(0, -80), 3)
			R.portal(b, second, b.top_of(out) + Vector2(0, -210), 4, Vector2(0, 50))
			b.gimmick({"type": "volcanic_hazard", "kind": "meteor", "pos": b.top_of(out) + Vector2(140, -430),
				"travel": Vector2(-140, 402), "width": 56.0, "period": 5.4, "phase": 2.2})
			b.ride("warp", a, high, {"at": first})
			b.ride("warp", high, out, {"at": second}); b.finish(out)
		"pendulum_belt":
			var floor_ := b.span(120, 620, 0, 72)
			b.gimmick({"type": "conveyor", "pos": b.at(320, -13), "span": Vector2(380, 26), "speed": 100.0, "flip": 3.6, "dir": -1})
			b.gimmick({"type": "tower_trap", "kind": "pendulum", "pos": b.at(370, 235), "length": 230.0, "period": 4.4})
			geyser(b, 610, -100, 160, 1.6)
			var out := landing(b, 850, 190)
			b.step("walk", a, b.part(500, 620, floor_))
			b.jump(b.part(500, 620, floor_), out); b.finish(out)
		"cooling_windows":
			var id := "molten_cooling"
			R.switch_at(b, id, b.at(0, 135), 4.5)
			var p := R.bridge(b, id, b.surface(250, 10), 180)
			var island := b.ledge(500, -30, 260)
			geyser(b, 680, -150, 210, 2.4)
			R.switch_at(b, id, b.at(500, 115), 4.5)
			var q := R.bridge(b, id, b.surface(780, 20), 185)
			var out := landing(b, 1040, 240)
			b.ride("echo", a, p, {"id": id}); b.jump(p, island)
			b.ride("echo", island, q, {"id": id}); b.jump(q, out); b.finish(out)
		"chimney_fall":
			var wind := b.at(180, 0)
			b.gimmick({"type": "updraft", "pos": wind, "span": Vector2(180, 400)})
			var high := b.ledge(330, 300, 200)
			var shelf := b.ledge(580, 90, 240)
			meteor(b, 450, 480, Vector2(110, 362), 1.7)
			var out := landing(b, 870, 260)
			b.ride("updraft", a, high, {"at": wind})
			b.jump(high, shelf); b.jump(shelf, out); b.finish(out)
		"roof_spring":
			var roof := b.span(170, 290, 115, 64)
			var out := b.ledge(355, 175, 300)
			var spring := b.spring_on(a, 45)
			meteor(b, 520, 500, Vector2(-40, 297), 1.0)
			b.ride("spring", a, out, {"at": spring, "sprint": true})
			b.coins_over(roof, 3); b.finish(out)
		"core_relay":
			var id := "molten_core"
			R.switch_at(b, id, b.at(0, 150), 6)
			var p := R.bridge(b, id, b.surface(230, 20), 180)
			var blink := b.surface(465, 40)
			var lift := b.surface(690, 45)
			R.blink(b, blink, 190, 0.5)
			b.gimmick({"type": "moving_platform", "pos": lift, "span": Vector2(175, 26), "travel": Vector2(100, 50), "speed": 60.0})
			var out := landing(b, 990, 150)
			geyser(b, 575, -200, 300, 0.8)
			meteor(b, 850, 490, Vector2(-90, 430), 3.2)
			b.ride("echo", a, p, {"id": id})
			R.timed(b, p, out, [blink, lift], {"activate": id, "tries": 32}); b.finish(out)
		"emergency_exit":
			var first := b.surface(245, -20)
			var second := b.surface(475, -35)
			var p := R.crumble(b, first, 170)
			var q := R.crumble(b, second, 180)
			var refuge := b.ledge(715, -70, 230)
			geyser(b, 365, -160, 240, 1.3)
			var out := landing(b, 1120, 260, 300)
			var mouth := b.top_of(refuge, 80) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(out) + Vector2(0, -120), 5, Vector2(0, -200))
			R.timed(b, a, refuge, [first, second])
			b.ride("warp", refuge, out, {"at": mouth}); b.finish(out)
		"cold_rock_rescue":
			# The final dry bank and key cannot be reached via the upstairs
			# descent: both Guardian rescues stay on the lower route's far end.
			var top := b.ledge(360, 440, 300)
			b.assist(a, top, [b.platform(160, 146), b.platform(285, 292)])
			var gap := b.ledge(1520, 440, 320)
			b.assist(top, gap, [b.platform(770, 450), b.platform(1090, 445)])
			b.route[-1]["sprint"] = true
			var out := b.span(1780, 2180, 230, 200)
			b.jump(gap, out)
			b.finish(out)
