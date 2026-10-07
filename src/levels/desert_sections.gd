extends RefCounted
## Ten individually authored chambers above the lower desert route.
const ENTRY := Rect2(2200, -580, 260, 48)
const NAMES := ["wind_well", "pendulum_tomb", "sun_wheel", "piston_underpass",
	"phase_transfer", "warp_labyrinth", "sniper_windows", "rescue_wall", "falling_escape", "last_sandglass"]
static var _built: SectionBuilder

static func build() -> SectionBuilder:
	# Pure authored data: do not allocate all twenty route/geometry arrays again
	# when the camera, renderer and builder ask Stage for their separate lists.
	if _built != null: return _built
	var b := SectionBuilder.new(ENTRY)
	b.add_ground(ENTRY)
	for name in NAMES:
		var entry := b.cursor
		b.begin(name, 1)
		_room(name, b)
		b.sections[-1]["entry"] = entry
		b.sections[-1]["x_start"] = entry.get_center().x
		b.sections[-1]["x_end"] = b.cursor.get_center().x
		b.coins_over(b.cursor, 3)
		if name in ["pendulum_tomb", "piston_underpass", "warp_labyrinth", "sniper_windows", "falling_escape"]:
			b.checkpoint_on(b.cursor)
		b.ornament({"type": "desert_crystal", "pos": b.top_of(b.cursor, -45)})
	_built = b
	return b

static func _room(name: String, b: SectionBuilder) -> void:
	match name:
		"wind_well":
			var wind := b.at(190, 0)
			b.gimmick({"type": "updraft", "pos": wind, "span": Vector2(170, 360)})
			var high := b.ledge(340, 300, 200)
			var out := b.ledge(650, 150, 260)
			b.ride("updraft", b.cursor, high, {"at": wind})
			b.jump(high, out)
			b.coin_line(190, 80, 190, 270, 4)
			b.enemy({"type": "desert_enemy", "kind": "jelly", "pos": b.at(190, 200), "patrol": 65.0})
			b.finish(out)
		"pendulum_tomb":
			var pocket := b.ledge(230, -60, 160)
			var low := b.ledge(540, -130, 180)
			var out := b.ledge(780, -130, 260)
			b.gimmick({"type": "tower_trap", "kind": "pendulum", "pos": b.at(385, 170),
				"length": 245.0, "period": 4.2, "phase": 0.0})
			b.span(555, 725, 110, 64)
			b.jump(b.cursor, pocket)
			b.jump(pocket, low)
			b.jump(low, out)
			b.coins_over(pocket, 2)
			_resident(b, "cactus", low, 0)
			b.finish(out)
		"sun_wheel":
			var wheel := b.at(270, -50)
			b.gimmick({"type": "gear_wheel", "pos": wheel, "radius": 105.0,
				"speed": 0.6, "dir": 1, "phase": 0.0})
			var out := b.ledge(520, 70, 240)
			b.ride("timed", b.cursor, out, {"pieces": [wheel], "tries": 18, "spacing": 29})
			b.coin_line(200, 90, 340, 100, 4)
			_resident(b, "jelly", out, 85)
			b.finish(out)
		"piston_underpass":
			var floor_ := b.span(150, 690, -100, 64)
			b.span(150, 520, 50, 64)
			b.gimmick({"type": "tower_trap", "kind": "piston", "pos": b.at(325, 30),
				"travel": 105.0, "period": 4.6, "phase": 0.0})
			var spring := b.spring_on(floor_, 200)
			var out := b.ledge(900, 90, 230)
			b.step("walk", b.cursor, b.part(150, 285, floor_))
			b.ride("spring", floor_, out, {"at": spring, "sprint": true})
			b.coin_line(190, -30, 480, -30, 4)
			_resident(b, "fin", floor_, 60)
			b.finish(out)
		"phase_transfer":
			var lift := b.surface(200, 40)
			var blink := b.surface(450, 90)
			b.gimmick({"type": "moving_platform", "pos": lift, "span": Vector2(160, 26),
				"travel": Vector2(150, -60), "speed": 75.0})
			b.gimmick({"type": "blink", "pos": blink, "span": Vector2(170, 26),
				"beat": 2.6, "phase": 0.7, "colour": 0})
			var out := b.ledge(710, -30, 250)
			b.ride("timed", b.cursor, out, {"pieces": [lift, blink], "tries": 20, "spacing": 31})
			b.coins_over(Rect2(blink - Vector2(85, 13), Vector2(170, 26)), 3)
			_resident(b, "scarab", out, 55)
			b.finish(out)
		"warp_labyrinth":
			var hall := b.ledge(220, -60, 260)
			var balcony := b.ledge(620, 80, 220)
			var out := b.ledge(940, -60, 260)
			var mouth := b.top_of(hall) + Vector2(0, -45)
			var destination := b.top_of(balcony) + Vector2(0, -50)
			b.gimmick({"type": "warp", "pos": mouth, "exit": destination,
				"size": Vector2(78, 106), "mark": 1})
			b.gimmick({"type": "warp_exit", "pos": destination,
				"size": Vector2(78, 106), "mark": 1})
			var treasure := b.ledge(430, 160, 110)
			b.coins_over(treasure, 4, 20)
			b.step("walk", b.cursor, Rect2(hall.position + Vector2(70, 0), Vector2(12, hall.size.y)))
			b.ride("warp", hall, balcony, {"at": mouth})
			b.jump(balcony, out)
			_resident(b, "cactus", balcony, 0)
			b.finish(out)
		"sniper_windows":
			var id := "desert_windows"
			var first := b.surface(230, -30)
			var second := b.surface(780, -30)
			var island := b.ledge(520, -60, 220)
			var out := b.ledge(1050, 0, 260)
			b.gimmick({"type": "switch", "id": id, "pos": b.at(50, 110), "hold": 4.0})
			b.gimmick({"type": "switch", "id": id, "pos": b.at(540, 100), "hold": 4.0})
			b.gimmick({"type": "switch_bridge", "id": id, "pos": first, "span": Vector2(170, 26)})
			b.gimmick({"type": "switch_bridge", "id": id, "pos": second, "span": Vector2(160, 26)})
			var p1 := Rect2(first - Vector2(85, 13), Vector2(170, 26))
			var p2 := Rect2(second - Vector2(80, 13), Vector2(160, 26))
			b.ride("echo", b.cursor, p1, {"id": id})
			b.jump(p1, island)
			b.ride("echo", island, p2, {"id": id})
			b.jump(p2, out)
			b.coins_over(island, 2)
			_resident(b, "fin", island, 40)
			b.finish(out)
		"rescue_wall":
			var out := b.ledge(330, 430, 240)
			b.assist(b.cursor, out, [b.platform(150, 143), b.platform(260, 286)])
			b.coin_line(150, 210, 260, 350, 3)
			_resident(b, "jelly", out, 95)
			b.finish(out)
		"falling_escape":
			var first := b.ledge(300, -80, 220)
			var crumble := b.surface(550, -100)
			b.gimmick({"type": "crumble", "pos": crumble, "span": Vector2(140, 26)})
			var launch := b.ledge(840, -200, 250)
			var pad := b.top_of(launch, 50)
			b.gimmick({"type": "trick_pad", "pos": pad, "dir": 1, "forward": 520.0, "rise": 1100.0})
			var out := b.ledge(1170, -270, 260)
			b.jump(b.cursor, first)
			b.ride("timed", first, launch, {"pieces": [crumble], "tries": 10, "spacing": 25})
			b.ride("pad", launch, out, {"at": pad, "dir": 1})
			_resident(b, "jelly", first, 55)
			b.finish(out)

		"last_sandglass":
			var hand := b.at(130, 30)
			b.gimmick({"type": "clock_hand", "pos": hand, "length": 220.0, "period": 4.4, "phase": 0.0})
			var perch := b.ledge(430, 100, 210)
			b.gimmick({"type": "conveyor", "pos": b.top_of(perch) + Vector2(0, 13),
				"span": Vector2(210, 26), "speed": 90.0, "flip": 4.0, "dir": 1})
			var out := b.span(620, 1100, -40, 240)
			b.ride("timed", b.cursor, perch, {"pieces": [hand], "tries": 18, "spacing": 23})
			b.jump(perch, out)
			b.ornament({"type": "desert_arch", "pos": b.top_of(out, 80), "height": 240.0})
			b.finish(out)

static func _resident(b: SectionBuilder, kind: String, floor_: Rect2, patrol: float) -> void:
	var lift := 100.0 if kind == "jelly" else (33.0 if kind == "cactus" else 27.0)
	b.enemy({"type": "desert_enemy", "kind": kind,
		"pos": Vector2(floor_.get_center().x, floor_.position.y - lift), "patrol": patrol})
