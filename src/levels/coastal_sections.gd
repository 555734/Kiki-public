extends RefCounted
const R = preload("res://src/levels/radical_sections.gd")
const NAMES := ["sky_mouth", "under_the_island", "trapdoor_pier", "rifle_tide",
	"cliff_rescue", "wind_ship", "falling_reef", "ship_wheel", "upper_lower_portals",
	"undertow_tunnel", "phase_ferry", "harbour_sigil", "turning_launcher", "backwash_loop",
	"wreck_pendulum", "low_tide_choice", "lighthouse_hand", "rolling_breakwater",
	"sky_bridge_exit", "last_lighthouse_rescue"]
static var _built: SectionBuilder

static func build() -> SectionBuilder:
	if _built != null: return _built
	var b := SectionBuilder.new(Rect2(400, 400, 200, 48))
	b.add_ground(Rect2(-1600, 400, 2200, 500))
	for i in NAMES.size():
		b.begin(NAMES[i], 1)
		_room(NAMES[i], b)
		R.finish(b, b.cursor, i % 2 == 0 or i == 19, "sea", i)
	_built = b
	return b

static func landing(b: SectionBuilder, dx: float, y: float, width: float = 260.0) -> Rect2:
	return b.ledge(dx, b.cursor.position.y - y, width)

static func _room(name: String, b: SectionBuilder) -> void:
	var a := b.cursor
	match name:
		"sky_mouth":
			R.pad(b, b.top_of(a))
			var perch := b.ledge(330, 170, 220)
			var out := landing(b, 730, 220)
			b.ride("pad", a, perch, {"at": b.top_of(a), "dir": 1})
			var mouth := b.top_of(perch, 80) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(out, -70) + Vector2(0, -180), 1, Vector2(200, -300))
			b.ride("warp", perch, out, {"at": mouth})
			b.finish(out)
		"under_the_island":
			var low := b.span(150, 660, -150, 72)
			b.span(160, 490, 30, 72)
			var out := landing(b, 890, 250, 300)
			b.step("walk", a, b.part(180, 300, low))
			b.jump(b.part(520, 660, low), out)
			b.finish(out)
		"trapdoor_pier":
			var trap := R.crumble(b, b.surface(250, 20), 220)
			var catch_ := b.ledge(260, -100, 320)
			var out := landing(b, 620, 280)
			b.jump(a, trap)
			b.step("drop", trap, catch_)
			b.jump(catch_, out)
			b.finish(out)
		"rifle_tide":
			var id := "coast_tide"
			R.switch_at(b, id, b.at(45, 120))
			var p := R.bridge(b, id, b.surface(260, 0), 190)
			var island := b.ledge(520, -30, 240)
			var q := R.bridge(b, id, b.surface(780, 10), 180)
			R.switch_at(b, id, b.at(520, 110))
			var out := landing(b, 1040, 260)
			b.ride("echo", a, p, {"id": id}); b.jump(p, island)
			b.ride("echo", island, q, {"id": id}); b.jump(q, out)
			b.finish(out)
		"cliff_rescue":
			var out := b.ledge(330, 430, 280)
			b.assist(a, out, [b.platform(150, 143), b.platform(260, 286)])
			b.finish(out)
		"wind_ship":
			var wind := b.at(170, 0)
			b.gimmick({"type": "updraft", "pos": wind, "span": Vector2(170, 380)})
			var high := b.ledge(320, 260, 200)
			var raft := b.surface(570, 240)
			b.gimmick({"type": "moving_platform", "pos": raft, "span": Vector2(170, 26), "travel": Vector2(120, 60), "speed": 70.0})
			var out := b.ledge(870, 200, 280)
			b.ride("updraft", a, high, {"at": wind})
			R.timed(b, high, out, [raft]); b.finish(out)
		"falling_reef":
			var p := b.ledge(240, -100, 200)
			var q := b.ledge(490, -200, 180)
			R.falling(b, 240, 140)
			R.falling(b, 490, 45, 1.6)
			var out := landing(b, 750, 180)
			b.jump(a, p); b.jump(p, q); b.jump(q, out); b.finish(out)
		"ship_wheel":
			var wheel := b.at(250, -45)
			b.gimmick({"type": "gear_wheel", "pos": wheel, "radius": 110.0, "speed": 0.55, "dir": -1})
			var out := landing(b, 530, 110)
			R.timed(b, a, out, [wheel]); b.finish(out)
		"upper_lower_portals":
			var high := b.ledge(350, 180, 240)
			var out := landing(b, 730, 280, 300)
			var mouth := b.top_of(a, 90) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(high) + Vector2(0, -90), 2)
			b.ride("warp", a, high, {"at": mouth})
			var second := b.top_of(high, 60) + Vector2(0, -45)
			R.portal(b, second, b.top_of(out) + Vector2(0, -160), 3, Vector2(0, 80))
			b.ride("warp", high, out, {"at": second}); b.finish(out)
		"undertow_tunnel":
			var floor_ := b.span(120, 660, 0, 80)
			b.span(120, 470, 135, 64)
			b.gimmick({"type": "conveyor", "pos": b.at(290, -13), "span": Vector2(320, 26), "speed": 95.0, "dir": -1})
			var out := landing(b, 870, 190)
			b.step("walk", a, b.part(500, 650, floor_))
			b.jump(b.part(500, 660, floor_), out); b.finish(out)
		"phase_ferry":
			var blink := b.surface(230, 45)
			var lift := b.surface(460, 65)
			R.blink(b, blink, 175, 0.8)
			b.gimmick({"type": "moving_platform", "pos": lift, "span": Vector2(160, 26), "travel": Vector2(130, -50), "speed": 65.0})
			var out := landing(b, 800, 160)
			R.timed(b, a, out, [blink, lift]); b.finish(out)
		"harbour_sigil":
			var floor_ := b.span(80, 700, 0, 80)
			b.span(300, 430, 500, 260)
			R.switch_at(b, "coast_sigil", b.at(170, 125), 6, 2)
			R.switch_at(b, "coast_sigil", b.at(240, 125), 6, 1)
			b.gimmick({"type": "gate", "id": "coast_sigil", "pos": b.at(360, 120), "span": Vector2(44, 240), "wants": 2})
			var out := b.part(550, 700, floor_)
			b.ride("gate", a, out, {"id": "coast_sigil", "sigil": 2}); b.finish(out)
		"turning_launcher":
			R.pad(b, b.top_of(a, 60), 4.5)
			var reward := b.ledge(-250, 100, 160)
			b.coins_over(reward, 5)
			var out := b.ledge(400, 140, 260)
			b.ride("pad", a, out, {"at": b.top_of(a, 60), "dir": 1}); b.finish(out)
		"backwash_loop":
			var return_ := b.ledge(-230, 180, 190)
			var mouth := b.top_of(a, 90) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(return_) + Vector2(0, -60), 4)
			b.ride("warp", a, return_, {"at": mouth})
			var above := b.ledge(20, 270, 200)
			var out := landing(b, 420, 150)
			b.jump(return_, above); b.jump(above, out); b.finish(out)
		"wreck_pendulum":
			var first := b.surface(230, -20)
			var second := b.surface(460, -40)
			R.crumble(b, first, 165); R.crumble(b, second, 155)
			b.gimmick({"type": "tower_trap", "kind": "pendulum", "pos": b.at(370, 190), "length": 235.0, "period": 4.1})
			var out := landing(b, 720, 230)
			R.timed(b, a, out, [first, second]); b.finish(out)
		"low_tide_choice":
			var out := b.ledge(360, 430, 280)
			var low := b.span(140, 510, -80, 64)
			b.coins_over(out, 5)
			b.assist(a, out, [b.platform(170, 145), b.platform(290, 290)])
			var mouth := b.top_of(low, 90) + Vector2(0, -45)
			# Low route reconnects at the entrance, not beyond the rescue wall.
			R.portal(b, mouth, b.top_of(a) + Vector2(0, -70), 5)
			b.finish(out)
		"lighthouse_hand":
			var hand := b.at(140, 0)
			b.gimmick({"type": "clock_hand", "pos": hand, "length": 220.0, "period": 4.6})
			var perch := b.ledge(430, 80, 240)
			var out := b.ledge(740, 250, 280)
			R.timed(b, a, perch, [hand])
			var spring := b.spring_on(perch, 70)
			b.ride("spring", perch, out, {"at": spring, "sprint": true}); b.finish(out)
		"rolling_breakwater":
			var high := b.ledge(240, 100, 200)
			var lower := b.ledge(510, -100, 240)
			b.gimmick({"type": "cave_trap", "kind": "boulder", "pos": b.at(390, -65), "travel": 190.0, "period": 4.3})
			var out := landing(b, 830, 130)
			b.jump(a, high); b.jump(high, lower); b.jump(lower, out); b.finish(out)
		"sky_bridge_exit":
			var id := "coast_sky"
			R.switch_at(b, id, b.at(0, 120))
			var bridge := R.bridge(b, id, b.surface(260, 20), 230)
			var out := landing(b, 760, 100, 320)
			var mouth := b.top_of(bridge, 85) + Vector2(0, -45)
			R.portal(b, mouth, b.top_of(out, -50) + Vector2(0, -240), 1, Vector2(100, -150))
			b.ride("echo", a, bridge, {"id": id})
			b.ride("warp", bridge, out, {"at": mouth}); b.finish(out)
		"last_lighthouse_rescue":
			var top := b.ledge(310, 440, 280)
			b.assist(a, top, [b.platform(145, 145), b.platform(250, 290)])
			var out := b.span(550, 1090, 220, 180)
			b.jump(top, out)
			b.ornament({"type": "sea_palm", "pos": b.top_of(out, 170), "height": 260.0})
			b.finish(out)
