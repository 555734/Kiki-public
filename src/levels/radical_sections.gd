extends RefCounted
## Construction helpers, not room templates. Both stages author their own
## twenty room recipes; all nodes are made by the production LevelBuilder.
static func portal(b: SectionBuilder, mouth: Vector2, exit: Vector2, mark: int,
		velocity: Vector2 = Vector2.ZERO) -> void:
	var spec := {"type": "warp", "pos": mouth, "exit": exit, "mark": mark, "size": Vector2(80, 110)}
	if velocity != Vector2.ZERO: spec["exit_velocity"] = velocity
	b.gimmick(spec)
	b.gimmick({"type": "warp_exit", "pos": exit, "mark": mark, "size": Vector2(80, 110)})

static func pad(b: SectionBuilder, at: Vector2, flip: float = 0.0) -> void:
	b.gimmick({"type": "trick_pad", "pos": at, "forward": 500.0, "rise": 1050.0, "dir": 1, "flip": flip})

static func crumble(b: SectionBuilder, at: Vector2, width: float = 160.0) -> Rect2:
	b.gimmick({"type": "crumble", "pos": at, "span": Vector2(width, 26)})
	return Rect2(at - Vector2(width * 0.5, 13), Vector2(width, 26))

static func blink(b: SectionBuilder, at: Vector2, width: float, phase: float) -> void:
	b.gimmick({"type": "blink", "pos": at, "span": Vector2(width, 26), "beat": 2.8, "phase": phase, "colour": 0})

static func falling(b: SectionBuilder, dx: float, dy: float, phase: float = 0.0) -> void:
	b.gimmick({"type": "cave_trap", "kind": "stalactite", "pos": b.at(dx, dy),
		"travel": 220.0, "period": 4.5, "phase": phase})

static func bridge(b: SectionBuilder, id: String, at: Vector2, width: float) -> Rect2:
	b.gimmick({"type": "switch_bridge", "id": id, "pos": at, "span": Vector2(width, 26)})
	return Rect2(at - Vector2(width * 0.5, 13), Vector2(width, 26))

static func switch_at(b: SectionBuilder, id: String, at: Vector2, hold: float = 5.0, sigil: int = 0) -> void:
	b.gimmick({"type": "switch", "pos": at, "id": id, "hold": hold, "sigil": sigil})

static func timed(b: SectionBuilder, from: Rect2, to: Rect2, pieces: Array, extra: Dictionary = {}) -> void:
	var data := {"pieces": pieces, "tries": 24, "spacing": 29}
	data.merge(extra, true)
	b.ride("timed", from, to, data)

static func finish(b: SectionBuilder, out: Rect2, checkpoint: bool, theme: String, index: int) -> void:
	b.finish(out)
	b.sections[-1]["entry"] = b.route.filter(func(s: Dictionary) -> bool: return s["section"] == b.sections[-1]["name"])[0]["from"]
	b.coins_over(out, 3)
	if checkpoint: b.checkpoint_on(out, -out.size.x * 0.25)
	if theme == "sea":
		b.ornament({"type": "sea_grass", "pos": b.top_of(out, 65)})
		if index % 4 == 0: b.ornament({"type": "sea_palm_small", "pos": b.top_of(out, 90), "height": 170.0})
	else:
		b.ornament({"type": "swamp_reeds", "pos": b.top_of(out, 65)})
	# Leave checkpoint respawn space clear; residents guard the far end.
	if index % 3 == 0:
		b.enemy({"type": "walker", "pos": b.top_of(out, 55) + Vector2(0, -21),
			"patrol": 35.0, "skin": "sea_crab" if theme == "sea" else "s15_magma_slime"})
	if index % 4 == 1: b.enemy({"type": "flyer", "pos": b.top_of(out, 10) + Vector2(0, -180), "patrol": 90.0})
	if theme == "sea" and index in [3, 7, 13]:
		b.enemy({"type": "turret", "pos": b.top_of(out, 90) + Vector2(0, -26), "aim": Vector2.LEFT, "burst": 2})
