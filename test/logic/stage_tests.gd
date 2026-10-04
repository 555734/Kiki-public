extends "res://test/logic/logic_suite.gd"
## Stage data and the world built from it: rules, reachability, terrain, art and sound.

## Enemies have to still be there when the runner arrives. A patrol that walks
## itself off its own ledge takes the encounter with it, and the stage would go
## on passing every other check while section A quietly lost the walker the
## player is supposed to learn stomping on. Found by a screenshot run where the
## first walker was simply absent.
func _test_enemies_hold_their_ground() -> void:
	_current = "enemy persistence"
	await _boot()
	# Park the runner far off to the left so nothing here is the player's doing.
	main.runner.global_position = Vector2(-1400, 300)
	await _frames(4)
	var start := _stompable_positions()
	check(start.size() == _walkers_in_data(),
		"every walker in the level data is alive at boot (%d of %d)"
			% [start.size(), _walkers_in_data()])
	# Long enough for a patrol to reach both ends of its beat several times.
	await _wait(12.0)
	var now := _stompable_positions()
	check(now.size() == start.size(),
		"no enemy removes itself while unattended (%d -> %d)" % [start.size(), now.size()])
	for x in now.keys():
		check(float(now[x]) < Level01Data.KILL_Y,
			"enemy near x=%d is still above the kill plane (y=%.0f)" % [x, now[x]])

## Pass-through is a property LevelBuilder sets from the stage data. A gimmick
## used to read Stage.is_cave() itself, so the cave's rule leaked into every
## stage that places the same piece.
func _test_stage_rules_reach_gimmicks() -> void:
	_current = "stage rules reach gimmicks"
	var previous: int = Stage.current()
	Stage.use(Stage.Which.GREENFIELD)
	check(not Stage.platforms_one_way(), "1-1 platforms are solid from below")
	check(not Stage.ground_is_one_way(Stage.ground()[0]), "and so is its ground")
	var plain := MovingPlatform.new()
	LevelBuilder.configure_gimmick(plain, {})
	check(not plain.one_way, "a 1-1 platform is built solid")
	var asked := Conveyor.new()
	LevelBuilder.configure_gimmick(asked, {"one_way": true})
	check(asked.one_way, "unless its own spec asks for one-way")

	Stage.use(Stage.Which.CAVE)
	check(Stage.platforms_one_way(), "1-8 platforms default to one-way")
	var cave := BlinkBlock.new()
	LevelBuilder.configure_gimmick(cave, {})
	check(cave.one_way, "so a 1-8 blink block is built one-way")
	var solid := CrumblingFloor.new()
	LevelBuilder.configure_gimmick(solid, {"one_way": false})
	check(not solid.one_way, "and a 1-8 spec can still opt a piece out")
	var floor_rect := Rect2(Stage.start() + Vector2(-100, 10), Vector2(400, 60))
	check(not Stage.ground_is_one_way(floor_rect), "the cavern floor stays solid")
	check(Stage.ground_is_one_way(Rect2(Stage.start() + Vector2(0, -400), Vector2(200, 48))),
		"while a ledge above it can be jumped through")
	add_child(cave)
	check(cave._shape.one_way_collision, "and the collision shape carries it")
	for n in [plain, asked, cave, solid]:
		n.free()
	Stage.use(previous)

## A new stage is a data file and a line in Stage._DATA_FILES. This is what
## makes leaving something out fail here, rather than as a wrong answer from a
## fallback deep inside a playthrough.
func _test_every_stage_keeps_the_contract() -> void:
	_current = "every stage keeps the contract"
	var previous: int = Stage.current()
	var types := {}
	for which in Stage.Which.values():
		check(Stage._DATA_FILES.has(which), "stage %d has a data script" % which)
		if not Stage._DATA_FILES.has(which):
			continue
		Stage.use(which)
		var missing: Array[String] = []
		for method in Stage.REQUIRED:
			if not Stage.data().has_method(method):
				missing.append(method)
		check(missing.is_empty(), "%s answers every required function (missing %s)"
			% [Stage._DATA_FILES[which], missing])
		for spec in Stage.gimmicks():
			types[String(spec.get("type", ""))] = spec
		var unknown := LevelBuilder.unknown_types(Stage.enemies(), Stage.gimmicks())
		check(unknown.is_empty(), "%s names only types the builder knows (unknown %s)"
			% [Stage._DATA_FILES[which], unknown])
	Stage.use(previous)
	# And the check itself catches a one-letter slip, which used to build
	# nothing and say nothing.
	check(LevelBuilder.unknown_types([{"type": "walkre"}], [{"type": "moving_platfrom"}])
		== ["enemy:walkre", "gimmick:moving_platfrom"], "a misspelt type is reported")
	for type in types:
		check(LevelBuilder.GIMMICKS.has(type), "gimmick type '%s' is registered" % type)
		if not LevelBuilder.GIMMICKS.has(type):
			continue
		var node: Node2D = LevelBuilder.GIMMICKS[type].from_spec(types[type], null)
		check(node != null and node.get_script() == LevelBuilder.GIMMICKS[type],
			"and '%s' builds the piece it names" % type)
		if node != null:
			node.free()

## Every gap has to be crossable. The reaches come from _test_runner_arc, which
## flies the real body. This audit measures first jumps only; the separate
## movement probe covers triple jumps. One platform adds its own width plus
## another jump on the far side. This is not a proof of solo-route impossibility.
func _test_level_reachability() -> void:
	_current = "stage reachability"
	# Each walkable surface is recorded with two heights: the one you can step
	# ONTO it at, and the one you can step OFF it at. For static ground they are
	# the same. A lift's whole point is that they differ -- you board at the
	# bottom of its travel and leave at the top -- and collapsing the two into
	# one number made the climb in section E look like an impossible step up.
	var tops: Array[Dictionary] = []
	for r in Level01Data.ground():
		tops.append({"rect": r, "board": r.position.y, "exit": r.position.y})
	for g in Level01Data.gimmicks():
		var kind := String(g.get("type", ""))
		if kind != "moving_platform" and kind != "crumble":
			continue
		var centre: Vector2 = g["pos"]
		var span: Vector2 = g.get("span", Vector2(150, 26))
		var travel: Vector2 = g.get("travel", Vector2.ZERO)
		var left: float = centre.x - span.x * 0.5 + minf(0.0, travel.x)
		var right: float = centre.x + span.x * 0.5 + maxf(0.0, travel.x)
		var low: float = centre.y + maxf(0.0, travel.y) - span.y * 0.5
		var high: float = centre.y + minf(0.0, travel.y) - span.y * 0.5
		tops.append({
			"rect": Rect2(left, high, right - left, low - high + span.y),
			"board": low, "exit": high,
		})
	tops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["rect"] as Rect2).position.x < (b["rect"] as Rect2).position.x)

	# Taken from _test_runner_arc, which flies the real body rather than quoting
	# a constant. The literals are only a fallback for running this audit on its
	# own; when the arc test has run, its numbers win. The last figure is the one
	# that decides whether a gap can be crossed without the guardian.
	var plain_jump: float = _reach.get("plain", 193.0)
	var sprint_jump: float = _reach.get("sprint", 330.0)
	var unaided_max: float = _reach.get("unaided", 340.0)
	var apex_max: float = _reach.get("apex", 123.0)
	var one_platform := sprint_jump + Balance.PLATFORM_SIZE.x + sprint_jump
	var max_step_up := 100.0

	# Which stretches genuinely need the guardian is a question about the *bare*
	# ground: the assisted list above deliberately counts moving and collapsing
	# floors as walkable, which is what hides the very gaps those floors exist to
	# bridge. So this is measured separately, against the raw slabs.
	var bare := Level01Data.ground()
	bare.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var needs_help: Array[float] = []
	for i in range(bare.size() - 1):
		var raw_gap: float = bare[i + 1].position.x - (bare[i].position.x + bare[i].size.x)
		var raw_rise: float = bare[i].position.y - bare[i + 1].position.y
		# A gap that also climbs is harder than its width suggests: the arc has
		# to spend height it would otherwise spend on distance. Treating width
		# alone as the test would have called the climb in section E jumpable.
		var effective := raw_gap
		if raw_rise > 0.0:
			if raw_rise >= apex_max:
				effective = INF          # cannot be reached at any speed
			else:
				effective = raw_gap / maxf(1.0 - raw_rise / apex_max, 0.05)
		if effective > unaided_max:
			needs_help.append(bare[i].position.x + bare[i].size.x)

	for i in range(tops.size() - 1):
		var left: Rect2 = tops[i]["rect"]
		var right: Rect2 = tops[i + 1]["rect"]
		var gap: float = right.position.x - (left.position.x + left.size.x)
		if gap <= 0.0:
			continue   # abutting or overlapping surfaces
		check(gap <= one_platform,
			"gap at x=%.0f is %.0fpx, beyond even a platform assist (%.0fpx)"
				% [left.position.x + left.size.x, gap, one_platform])
		var step_up: float = float(tops[i]["exit"]) - float(tops[i + 1]["board"])
		if gap <= plain_jump:
			check(step_up <= max_step_up,
				"step up at x=%.0f is %.0fpx, above a plain jump" % [right.position.x, step_up])

	# The lessons have to survive the sprint. Section A exists to teach the
	# platform, and section D's collapsing floors exist to be the only route --
	# both stop teaching anything if a sprinting air dash can simply clear them.
	var section_a := needs_help.filter(func(x: float) -> bool: return x < 3200.0)
	check(not section_a.is_empty(),
		"section A has a gap beyond the measured first jump")
	var section_d := needs_help.filter(func(x: float) -> bool: return x > 8500.0)
	check(section_d.size() >= 3,
		"the back half exceeds first-jump estimates in at least three places (found %d)"
			% section_d.size())
	# Section B's crossing must still be the moving platform's job.
	var section_b := needs_help.filter(func(x: float) -> bool:
		return x > 3200.0 and x < 6400.0)
	check(not section_b.is_empty(), "section B's crossing exceeds a first-jump estimate")
	print("  gaps beyond first-jump estimates: %s" % str(needs_help))

## Pipes and block rows are solid now. They have to be solid *and* passable:
## every pipe clearable from flat ground, every floating block row high enough to
## run under, and none of them sitting on top of a spawn or a checkpoint.
func _test_solid_decor() -> void:
	_current = "solid decor"
	await _boot()
	var solids: Array[Rect2] = Level01Data.solid_decor()
	check(solids.size() >= 5, "the solid scenery is registered (%d rects)" % solids.size())

	var apex := 100.0            # simulated jump height from flat ground
	var runner_h := Balance.RUNNER_SIZE.y
	for rect in solids:
		var resting_on_ground := absf(rect.position.y + rect.size.y - Level01Data.GROUND_TOP) < 2.0
		if resting_on_ground:
			check(rect.size.y < apex - 8.0,
				"pipe at x=%.0f is %.0fpx tall, past the %.0fpx jump apex"
					% [rect.position.x, rect.size.y, apex])
		else:
			var headroom := Level01Data.GROUND_TOP - (rect.position.y + rect.size.y)
			check(headroom > runner_h + 6.0,
				"block row at x=%.0f leaves only %.0fpx of headroom (runner is %.0f)"
					% [rect.position.x, headroom, runner_h])

	# Nothing solid may overlap the spawn, a checkpoint or the goal.
	var spots: Array[Vector2] = [Level01Data.START, Level01Data.goal()]
	spots.append_array(Level01Data.checkpoints())
	for rect in solids:
		for spot in spots:
			check(not rect.grow(24.0).has_point(spot),
				"solid scenery at x=%.0f blocks a spawn/checkpoint at %s"
					% [rect.position.x, spot])

	# And the collider really is in the world: a body query at a pipe must hit.
	var space := main.get_world_2d().direct_space_state
	var probe := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 8)
	probe.shape = box
	probe.collision_mask = 1
	var pipe: Rect2 = solids[0]
	probe.transform = Transform2D(0.0, pipe.get_center())
	check(not space.intersect_shape(probe, 1).is_empty(),
		"the pipe at x=%.0f actually has a collider" % pipe.position.x)

## Every texture the renderers ask for has to exist. A missing sprite is
## otherwise invisible: Art.tex() returns null, the renderer quietly falls back
## to its vector path, and nobody notices until a screenshot looks wrong.
## The two ground enemies of the 1-1 set.
##
## `skin` is the one piece of enemy state that is NOT sent: it is level data,
## read the same way on both devices at build time. That makes it cheap and it
## makes it silent -- a misspelled skin draws the wrong picture rather than
## raising anything -- so the spelling is what gets checked here.
func _test_walker_skins() -> void:
	_current = "walker skins"
	var seen := {}
	var previous: int = Stage.current()
	Stage.use(Stage.Which.GREENFIELD)
	for spec in Stage.enemies():
		if String(spec.get("type", "")) != "walker":
			continue
		var skin := String(spec.get("skin", "walker"))
		seen[skin] = int(seen.get(skin, 0)) + 1
		check(Art.MANIFEST.has(skin),
			"walker skin %s is a registered texture" % skin)
	Stage.use(previous)

	# Both paintings arrived, so both are on the stage. If one of these ever
	# fails it means an edit quietly reduced the set back to one enemy.
	check(seen.has("walker"), "1-1 still uses the default walker skin")
	check(seen.has("walker_spiky"), "1-1 uses the second ground enemy too")
	check(seen.size() == 2,
		"and exactly those two (%s)" % ", ".join(PackedStringArray(seen.keys())))

func _test_assets() -> void:
	_current = "assets"
	var gone: Array = Art.missing()
	check(gone.is_empty(), "missing art files: %s" % ", ".join(PackedStringArray(gone)))

	# Art that is registered but has not been drawn yet (Art.PENDING) is exempt
	# from the line above, so the exemption itself is what needs auditing --
	# otherwise a key stays forgiven forever and the real check is off for it.
	var typos: Array = Art.pending_unknown()
	check(typos.is_empty(),
		"Art.PENDING names keys that are not in the manifest: %s"
			% ", ".join(PackedStringArray(typos)))
	var arrived: Array = Art.pending_but_present()
	check(arrived.is_empty(),
		"art has arrived for these -- delete them from Art.PENDING: %s"
			% ", ".join(PackedStringArray(arrived)))

	# The fonts must be real font resources, not the fallback stand-in.
	var ui_font: Font = Art.font(Art.FONT_UI)
	check(ui_font != null and ui_font != ThemeDB.fallback_font,
		"the UI font loaded (default fallback means the TTF is missing)")

	if not Balance.USE_TEXTURES:
		return
	# Spot-check that the key sprites actually decode and have sane dimensions.
	for key in ["runner_run", "runner_jump", "walker", "platform", "wall",
			"grass_tile", "dirt_tile", "turret", "flyer", "goal"]:
		var t: Texture2D = Art.tex(key)
		check(t != null, "texture '%s' loads" % key)
		if t != null:
			check(t.get_width() > 8 and t.get_height() > 8,
				"texture '%s' is not a stub (%dx%d)" % [key, t.get_width(), t.get_height()])

	# The grass lip is not a taste value -- it is measured off the tile. If the
	# artwork is ever replaced with one whose blades feather over a different
	# number of rows, this is what says so, rather than every character in the
	# game quietly floating again.
	var grass: Texture2D = Art.tex("grass_tile")
	if grass != null:
		var img := grass.get_image()
		# The row where the tile stops being blade tips and becomes ground:
		# four fifths of it opaque. A looser test finds the first stray solid
		# pixel in the tips, which is 6px higher and not where the eye reads
		# the surface.
		var solid := -1
		var samples := 0
		for x in range(0, img.get_width(), 4):
			samples += 1
		for y in range(img.get_height()):
			var opaque := 0
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.90:
					opaque += 1
			if float(opaque) > float(samples) * 0.8:
				solid = y
				break
		check(solid >= 0, "the grass tile has a solid part at all")
		if solid >= 0:
			var lip := Balance.GRASS_TILE_H * float(solid) / float(img.get_height())
			check(absf(lip - Balance.GRASS_LIP) < 3.0,
				"GRASS_LIP matches the artwork (tile goes solid at %.1fpx, lip is %.1fpx)"
					% [lip, Balance.GRASS_LIP])

	# The runner's poses are frames of one character, not eight sprites, and the
	# whole scheme rests on them sharing a canvas: same size, feet on the bottom
	# edge, figure centred. Import one at its own size and the runner changes
	# height and slides sideways every time they crouch.
	var poses := ["runner_idle", "runner_run", "runner_jump", "runner_fall",
		"runner_land", "runner_dash", "runner_reach", "runner_cheer"]
	# Vector2, not Vector2i: Texture2D.get_size() is a float pair. Comparing the
	# two is a PARSE error, and a script that fails to parse makes this scene
	# hang with no output at all rather than fail -- which is exactly why
	# check_scripts runs before the suite.
	var canvas := Vector2.ZERO
	for key in poses:
		var t: Texture2D = Art.tex(key)
		check(t != null, "pose '%s' exists" % key)
		if t == null:
			continue
		if canvas == Vector2.ZERO:
			canvas = t.get_size()
		check(t.get_size() == canvas,
			"pose '%s' is on the shared canvas (%s, expected %s)"
				% [key, t.get_size(), canvas])

## The game had no voice at all, and giving it one is mostly wiring: every
## sound is a listener on the event bus. So the thing worth checking is not
## whether a noise came out -- headless runs a dummy audio driver and cannot
## tell -- but whether each event reaches the sound it is supposed to.
func _test_the_game_has_a_voice() -> void:
	_current = "audio"
	await _boot()

	for key in Audio.KEYS:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % key),
			"the sound '%s' exists" % key)

	check(Audio.music_running(),
		"the stage loop and its drive layer are both running")

	# Let the runner come to rest first. They spawn in the air, and a landing
	# raises its own sound -- which overwrites the key this test is about to
	# read, on whichever row happens to coincide with the touchdown. It moved
	# from row to row between runs, which is what a race looks like.
	main.runner.velocity = Vector2.ZERO
	main.input_hub.move_axis = 0.0
	for _i in range(90):
		await get_tree().physics_frame
		if main.runner.is_on_floor():
			break
	# Audio's repeat guard uses wall time, while headless fixed-fps physics can
	# run much faster than wall time. Waiting a frame count made this assertion
	# fail precisely when rendering became faster.
	await _wait(Audio.REPEAT_GAP * 2.0)

	# Events in, sound names out. The gap between them is the whole feature.
	var wiring := [
		["jump", func() -> void: Events.runner_jumped.emit()],
		["land", func() -> void: Events.runner_landed.emit(true)],
		["coin", func() -> void: Events.coin_collected.emit(Vector2.ZERO)],
		["spring", func() -> void: Events.spring_bounced.emit(Vector2.ZERO)],
		["shot", func() -> void: Events.shot_fired.emit(Vector2.ZERO, Vector2.ONE, false)],
		["enemy_die", func() -> void: Events.enemy_killed.emit(null, "snipe")],
		["place_platform", func() -> void: Events.ability_used.emit(1, Vector2.ZERO)],
		["place_wall", func() -> void: Events.ability_used.emit(2, Vector2.ZERO)],
		["place_warp", func() -> void: Events.ability_used.emit(4, Vector2.ZERO)],
		["refuse", func() -> void: Events.ability_refused.emit(1, "gauge")],
		["scope_up", func() -> void: Events.scope_state_changed.emit(true, 3.0)],
		["scope_down", func() -> void: Events.scope_state_changed.emit(false, 3.0)],
		["switch", func() -> void: Events.switch_activated.emit("ancient_gate")],
		["checkpoint", func() -> void: Events.checkpoint_reached.emit(1)],
		["warp", func() -> void: Events.runner_warped.emit(Vector2.ZERO, Vector2.ONE)],
		["rescue_2", func() -> void: Events.rescue_scored.emit(2, Vector2.ZERO)],
	]
	for row in wiring:
		var want: String = row[0]
		Audio.last_key = ""
		# This loop verifies event-to-sound wiring, not repeat suppression. A real
		# landing can occur immediately before this synthetic landing in a fast
		# headless run, so isolate the key under test explicitly.
		Audio._last_played.erase(want)
		# The rate limiter drops a repeat of the SAME key inside 45ms; these are
		# all different keys, so each one gets through.
		(row[1] as Callable).call()
		await _frames(1)
		check(Audio.last_key == want,
			"the event for '%s' reaches it (got '%s')" % [want, Audio.last_key])

	# Losing a hit must sound different from getting one back: runner_damaged is
	# raised on respawn too, and a hurt noise for being healed reads as a bug.
	#
	# Start from a known number of hearts. Audio remembers the last one it was
	# told about, so if the runner happened to be hurt during an EARLIER test
	# this reads as "no change" and no hurt sound is due -- which is correct
	# behaviour and a broken check. Say the hearts are full first.
	Events.runner_damaged.emit(Balance.RUNNER_MAX_HP, Balance.RUNNER_MAX_HP)
	# And wait out the repeat limiter. Audio drops a repeat of the same sound
	# inside 45ms WITHOUT touching last_key, so if the runner happened to be hit
	# moments earlier -- which depends on where the patrols were during an
	# earlier test -- this check reads the suppression as a missing sound. That
	# is the intermittent failure that showed up once in eight verify runs and
	# could not be named at the time.
	await _wait(Audio.REPEAT_GAP * 3.0)
	Audio.last_key = ""
	Events.runner_damaged.emit(1, Balance.RUNNER_MAX_HP)
	await _frames(1)
	check(Audio.last_key == "hurt", "losing a hit is audible")
	Audio.last_key = ""
	Events.runner_damaged.emit(Balance.RUNNER_MAX_HP, Balance.RUNNER_MAX_HP)
	await _frames(1)
	check(Audio.last_key == "", "and getting one back is not")

	# A burst of the same sound in one frame is a click, not a burst.
	Audio.last_key = ""
	Events.coin_collected.emit(Vector2.ZERO)
	var first := Audio.last_key
	Audio.last_key = ""
	Events.coin_collected.emit(Vector2.ZERO)
	check(first == "coin" and Audio.last_key == "",
		"the same sound twice in a frame plays once")

## Nothing may float above the ground it is standing on, or sink into it.
##
## This is the arithmetic half of a complaint that was really about pixels:
## characters and enemies looked badly seated. Two separate causes, and this
## covers the one that can be checked without rendering -- a spawn position that
## does not put the bottom of the box on the surface. Physics hides it within a
## few frames, so the only time anyone sees it is the moment after a retry,
## which is also the moment everyone is looking.
##
## The other cause was the grass tile: its top quarter is feathered blade tips,
## so the SOLID ground was 11.5px below the line everything stood on. That one
## is checked against the artwork itself, in _test_assets.
func _test_everything_stands_on_the_ground() -> void:
	_current = "ground contact"
	var ground: Array[Rect2] = Level01Data.ground()
	var aerial := 0
	for e in Level01Data.enemies():
		# Flyers fly. Walkers and turrets are both supposed to be standing on
		# something -- turrets were exempted here on the grounds that they are
		# "mounted", and all five of the ones that are not hung 19px over their
		# ledge for it, close enough to look like a mistake and far enough that
		# their bursts passed over the runner's head. Only ONE is mounted.
		var kind := String(e.get("type", ""))
		if kind == "flyer":
			continue
		var box: Vector2 = Balance.WALKER_SIZE if kind == "walker" else Balance.TURRET_SIZE
		var at: Vector2 = e["pos"]
		var foot := at.y + box.y * 0.5
		var surface := INF
		for slab in ground:
			if at.x > slab.position.x and at.x < slab.position.x + slab.size.x:
				surface = minf(surface, slab.position.y)
		if surface == INF:
			# Nothing under it at all: that is the hanging turret, and it is the
			# only thing in the stage allowed to be there.
			aerial += 1
			check(kind == "turret",
				"only a turret may hang in the air (%s at x=%.0f)" % [kind, at.x])
			continue
		check(absf(foot - surface) < 1.5,
			"the %s at x=%.0f rests on its ledge (foot %.0f, ground %.0f)"
				% [kind, at.x, foot, surface])
	check(aerial == 1,
		"exactly one enemy hangs over a gap on purpose (%d do)" % aerial)

## Coins and bounce pads. Both are derived entirely from the runner's own
## position, which is what lets them cost nothing on the wire -- so the checks
## here are about the two ways that can go wrong: a pad that does not actually
## launch, and a spring or coin sitting somewhere the level did not intend.
func _test_pickups_and_pads() -> void:
	_current = "pickups"
	await _boot()
	var r: Runner = main.runner
	var g: Guardian = main.guardian

	# Every pad has ground under it, and every coin is reachable from the pad
	# below it. A spring floating in the air is a spring nobody ever touches.
	var ground: Array[Rect2] = Level01Data.ground()
	for pad in Level01Data.springs():
		var standing := false
		for slab in ground:
			if pad.x > slab.position.x and pad.x < slab.position.x + slab.size.x \
					and absf(pad.y - slab.position.y) < 2.0:
				standing = true
		check(standing, "the pad at x=%.0f stands on a ledge" % pad.x)

	# 900 against RUNNER_GRAVITY. Anything higher than this is a coin no bounce
	# can reach, which is worse than no coin at all.
	var reach := Balance.SPRING_VELOCITY * Balance.SPRING_VELOCITY \
		/ (2.0 * Balance.RUNNER_GRAVITY)
	for coin in Level01Data.coins():
		var best := 1e9
		for pad in Level01Data.springs():
			if absf(coin.x - pad.x) < 260.0:
				best = minf(best, pad.y - coin.y)
		if best < 1e8:
			check(best <= reach + 30.0,
				"the coin at x=%.0f is %.0fpx over its pad, which throws %.0fpx"
					% [coin.x, best, reach])

	# Nothing may sit inside solid geometry: a coin buried in a ledge or behind a
	# pipe is one the runner can see and never take.
	var solids: Array[Rect2] = Level01Data.ground()
	solids.append_array(Level01Data.solid_decor())
	for coin in Level01Data.coins():
		var buried := false
		for rect in solids:
			if rect.grow(6.0).has_point(coin):
				buried = true
		check(not buried, "the coin at %s is not buried in solid geometry" % coin)

	# The pad itself, driven for real: drop the runner onto one and watch what
	# the bounce does to their apex.
	var pad_at: Vector2 = Level01Data.springs()[0]
	r.global_position = pad_at + Vector2(0, -140)
	r.velocity = Vector2(0, 120)
	await _wait(0.6)
	var apex := r.global_position.y
	for i in range(50):
		await get_tree().physics_frame
		apex = minf(apex, r.global_position.y)
	check(apex < pad_at.y - 190.0,
		"a bounce throws the runner %.0fpx up, well past their own jump"
			% (pad_at.y - apex))

	# A coin is the runner's one way of paying the guardian back.
	g.gauge = 40.0
	var coins := get_tree().get_nodes_in_group("coin")
	check(coins.size() == Level01Data.coins().size(),
		"every coin in the data is in the world (%d of %d)"
			% [coins.size(), Level01Data.coins().size()])
	if not coins.is_empty():
		var target: Node2D = coins[0]
		r.global_position = target.global_position
		await _frames(3)
		check(not target.visible, "touching a coin takes it")
		check(g.gauge > 40.0 + Balance.COIN_GAUGE - 1.0,
			"and puts %.0f back into the shared gauge (%.0f)"
				% [Balance.COIN_GAUGE, g.gauge])

	# And a retry restores them, or the second attempt is quietly harder.
	main.level.reset_to_checkpoint()
	await _frames(3)
	check(get_tree().get_nodes_in_group("coin").size() == Level01Data.coins().size(),
		"a checkpoint reset puts the coins back")

## The guardian's fourth tool: a pair of gates the runner passes through.
##
## The rules that matter are the ones that stop it turning the runner into a
## passenger, so those are what this checks: two charges rather than one, a
## single pair at a time, and both mouths inside the same placement range every
## other construct obeys.
func _test_warp_pair() -> void:
	_current = "warp"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner
	# Somewhere flat and known, with the gates in the air beside the runner.
	r.global_position = Vector2(2600, 300)
	g.gauge = Balance.GAUGE_MAX
	await _frames(2)

	var here: Vector2 = r.global_position
	var far := here + Vector2(520, -60)
	g.select_slot(4)
	check(not g.scope_active, "picking the warp does not raise the scope")

	g.use_active(far)
	await _frames(2)
	var gates: Array = g.holograms_of(Hologram.Kind.WARP)
	check(gates.size() == 1, "the first press places one gate (%d)" % gates.size())
	check(gates.size() == 1 and not gates[0].linked,
		"a lone gate is not linked -- it goes nowhere yet")
	check(absf(g.gauge - (Balance.GAUGE_MAX - Balance.COST_WARP)) < 2.0,
		"and costs one charge (%.0f left)" % g.gauge)

	g.use_active(here + Vector2(-40, 0))
	await _frames(2)
	gates = g.holograms_of(Hologram.Kind.WARP)
	check(gates.size() == 2, "the second press completes the pair (%d)" % gates.size())
	for gate in gates:
		check(gate.linked, "both mouths report themselves linked")
	check(g.gauge < Balance.GAUGE_MAX - Balance.COST_WARP * 1.5,
		"a working pair costs two charges (%.0f left)" % g.gauge)

	# A gate is not a floor: the runner must be able to occupy the same space.
	var space := main.get_world_2d().direct_space_state
	var probe := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 10)
	probe.shape = box
	probe.collision_mask = Hologram.LAYER_HOLOGRAM
	probe.transform = Transform2D(0.0, far)
	check(space.intersect_shape(probe, 1).is_empty(),
		"a warp gate has no collider for the runner to stand on")

	# The trip. The runner is standing in the near mouth already.
	await _frames(4)
	check(absf(r.global_position.x - far.x) < 90.0,
		"the runner entering one mouth comes out of the other (x=%.0f, gate at %.0f)"
			% [r.global_position.x, far.x])

	# ...and stays there. Without the cooldown they arrive inside the far gate
	# and are sent straight back, every frame, forever.
	var landed: Vector2 = r.global_position
	await _frames(3)
	check(landed.distance_to(r.global_position) < 120.0,
		"and is not bounced straight back through (moved %.0f)"
			% landed.distance_to(r.global_position))

	# A third press starts a fresh pair rather than re-pointing the old one.
	g.gauge = Balance.GAUGE_MAX
	g.use_active(r.global_position + Vector2(300, -200))
	await _frames(2)
	gates = g.holograms_of(Hologram.Kind.WARP)
	check(gates.size() == 1,
		"a third press clears the old pair and starts a new one (%d gates)" % gates.size())

	# Refusals, in the same language the other abilities use.
	g.gauge = 1.0
	check(g.abilities[4].check(g, r.global_position + Vector2(120, 0)) == "gauge",
		"an empty gauge refuses a gate")
	g.gauge = Balance.GAUGE_MAX
	check(g.abilities[4].check(g, r.global_position + Vector2(9000, 0)) == "range",
		"and a gate cannot be placed off in a part of the stage nobody has reached")
	var underground := Vector2(r.global_position.x, Level01Data.GROUND_BASE - 60.0)
	check(g.abilities[4].check(g, underground) == "blocked",
		"a gate buried in the ground is refused")
	# The scope no longer refuses anything -- it is a magnifier, not a mode.
	# See _test_one_press_tools.
	g.set_scope(true)
	check(g.abilities[4].check(g, r.global_position + Vector2(120, 0)) == "",
		"a gate can be placed while the scope is up")
	g.set_scope(false)
	g.select_slot(1)
