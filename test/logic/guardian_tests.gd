extends "res://test/logic/logic_suite.gd"
## The guardian's tools: gauge, platforms, walls, the rifle, triggers, pings.

func _test_gauge_rules() -> void:
	_current = "gauge"
	await _boot()
	var g: Guardian = main.guardian
	check_near(g.gauge, Balance.GAUGE_MAX, 0.01, "starts full")

	# Regeneration rate, measured over a real half second.
	g.gauge = 0.0
	await _wait(0.5)
	check_near(g.gauge, Balance.GAUGE_REGEN_PER_SEC * 0.5,
		Balance.GAUGE_REGEN_PER_SEC * 0.25, "regenerates at the documented rate")

	# Cost is deducted, and a tool that cannot be afforded is refused rather
	# than half-applied. The platform and the shot are free now (Balance), so
	# the wall is the tool that still spends.
	check(Balance.COST_WALL > 0.0, "the wall is the tool that still costs")
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(2)
	g.use_active(Vector2(600, 250))
	check_near(g.gauge, Balance.GAUGE_MAX - Balance.COST_WALL, 1.0,
		"a wall deducts its cost")

	var refusals: Array[String] = []
	var handler := func(_slot: int, reason: String) -> void: refusals.append(reason)
	Events.ability_refused.connect(handler)
	g.gauge = Balance.COST_WALL - 1.0
	var alive_before: int = g.holograms_of(Hologram.Kind.WALL).size()
	g.use_active(Vector2(800, 250))
	check(refusals.has("gauge"), "refuses when the gauge is short")
	check(g.holograms_of(Hologram.Kind.WALL).size() == alive_before,
		"a refused build creates nothing")
	check(g.gauge >= 0.0, "gauge never goes negative")
	Events.ability_refused.disconnect(handler)

func _test_platform_limits() -> void:
	_current = "platform"
	await _boot()
	var g: Guardian = main.guardian
	g.select_slot(1)
	g.gauge = Balance.GAUGE_MAX

	g.use_active(Vector2(400, 240))
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(650, 240))
	await _frames(2)
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == Balance.PLATFORM_MAX_ALIVE,
		"two platforms may coexist")

	var oldest: Hologram = g.holograms_of(Hologram.Kind.PLATFORM)[0]
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(900, 240))
	await _frames(2)
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == Balance.PLATFORM_MAX_ALIVE,
		"a third placement does not exceed the cap")
	check(not is_instance_valid(oldest), "the oldest platform is the one recycled")

	# Lifetime, driven by moving the clock rather than waiting five seconds --
	# and by the clock rather than a fake delta, because a construct's life is
	# measured in ticks now so that two devices expire it on the same frame.
	var holo: Hologram = g.holograms_of(Hologram.Kind.PLATFORM)[0]
	holo.set_process(false)
	check_near(holo.remaining_time(), Balance.PLATFORM_LIFETIME, 0.6, "starts with a full life")
	Clock.tick += Clock.ticks_for(Balance.PLATFORM_LIFETIME * 0.5)
	check_near(holo.remaining_time(), Balance.PLATFORM_LIFETIME * 0.5, 0.6, "life ticks down")
	Clock.tick = holo.death_tick
	holo.set_process(true)
	await _frames(2)
	check(not is_instance_valid(holo), "expires once its lifetime is spent")

	# A construct the host backdated to rescue a falling runner has to come with
	# *less* life left, not a full one starting late -- otherwise a laggy client
	# quietly buys longer platforms than a local player gets.
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(1200, 240))
	await _frames(2)
	var fresh: Hologram = g.holograms_of(Hologram.Kind.PLATFORM).back()
	var full := fresh.remaining_time()
	fresh.birth_tick -= 9
	fresh.death_tick -= 9
	check(fresh.remaining_time() < full - 0.1,
		"a backdated construct expires earlier, not later (%.2f vs %.2f)"
			% [fresh.remaining_time(), full])

func _test_wall_limits() -> void:
	_current = "wall"
	await _boot()
	var g: Guardian = main.guardian
	g.select_slot(2)
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(600, 220))
	await _frames(2)
	var first: Array = g.holograms_of(Hologram.Kind.WALL)
	check(first.size() == 1, "one wall stands")
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(760, 220))
	await _frames(2)
	check(g.holograms_of(Hologram.Kind.WALL).size() == Balance.WALL_MAX_ALIVE,
		"only one wall at a time")
	check(Balance.WALL_LIFETIME < Balance.PLATFORM_LIFETIME,
		"the wall is the shorter-lived of the two")

## One press of an ability button uses that ability. There is no select step.
##
## This replaces a test that asserted the opposite of half of it -- that the
## scope refused to let you build. That refusal existed because raising the
## scope WAS how you chose the sniper; with a button per tool it would only
## mean an ability button that ignores the first press, which is the thing this
## whole change was asked for to remove.
func _test_one_press_tools() -> void:
	_current = "one press per tool"
	await _boot()
	var g: Guardian = main.guardian
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	main.runner.global_position = Vector2(2600, 300)
	await _frames(3)
	var at: Vector2 = main.runner.global_position + Vector2(220, -120)
	hub.aim_at_world(at)

	# A single tap on the platform tile has to leave a platform behind it.
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(3)                       # deliberately NOT the platform
	var before: int = g.holograms_of(Hologram.Kind.PLATFORM).size()
	# Dragged onto the target. A TAP means "you decide" now, and this check is
	# about the guardian deciding.
	hub._touch_down(3, _place("slot_1", view, "shared"))
	hub._touch_move(3, main.get_viewport().get_canvas_transform() * at)
	# What the ghost was showing: the thumb, minus the lift that keeps a 26px
	# slab out from under the finger placing it. "Built where you saw it" is
	# the property that matters, and the raw thumb point is not that.
	var ghost: Vector2 = hub.aim_world()
	hub._touch_up(3)
	await _frames(3)
	var built: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(built.size() == before + 1,
		"one drag from the platform button builds a platform (%d -> %d)"
			% [before, built.size()])
	check(g.active_slot == 1, "and the cursor follows the tool that was used")
	if built.size() > before:
		check(built.back().global_position.distance_to(ghost) < 2.0,
			"and it is built where the ghost was (%.0fpx)"
				% built.back().global_position.distance_to(ghost))

	# The wall has no button any more (ControlLayout: the guardian's screens
	# carry the platform and the shot only), so there is no drag to test here.

	# The scope is a state, not a tool. Its touch button is retired; the key
	# (p2_scope -> press_scope) is what raises it now.
	check(not g.scope_active, "the scope is down to begin with")
	var tool_before: int = g.active_slot
	hub.press_scope()
	await _frames(3)
	check(g.scope_active, "pressing scope raises it")
	check(g.active_slot == tool_before, "without touching which tool is selected")

	# And it no longer refuses anything. Somewhere clear: the two constructs
	# just built are sitting on `at`, and "blocked" is a different rule.
	g.gauge = Balance.GAUGE_MAX
	# Well away from the platform at `at` and the wall at `wall_at`: "blocked" is
	# a different rule and must not be what this check is measuring.
	var clear_spot: Vector2 = main.runner.global_position + Vector2(40, -300)
	check((g.abilities[1] as GuardianAbility).check(g, clear_spot) == "",
		"building is allowed while the scope is up (got '%s')"
			% (g.abilities[1] as GuardianAbility).check(g, clear_spot))
	check((g.abilities[4] as GuardianAbility).check(g, clear_spot) == "",
		"and so is a warp gate")

	hub.press_scope()
	await _frames(3)
	check(not g.scope_active, "a second press lowers it again")

	# Selecting the sniper must NOT raise the scope any more: they are separate
	# controls, and one press of slot 3 is a shot.
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(3)
	check(not g.scope_active, "choosing the sniper no longer raises the scope")

	# A tool button CHOOSES. It does not build and it does not spend, however
	# long it is held or however it is let go.
	hub.aim_at_world(main.runner.global_position + Vector2(0, -360))
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(2)
	var held: int = g.holograms_of(Hologram.Kind.PLATFORM).size()
	var purse: float = g.gauge
	hub._touch_down(7, _place("slot_1", view, "shared"))
	await _frames(3)
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == held,
		"holding a tool builds nothing")
	check(hub.held_slot() == 1, "but the guardian is holding it (%d)" % hub.held_slot())
	hub._touch_up(7)
	await _frames(3)
	check(hub.held_slot() == -1, "and lets go of it on release")
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == held,
		"letting go of the BUTTON still builds nothing")
	check(is_equal_approx(g.gauge, purse), "and spends nothing")
	check(g.active_slot == 1, "what it did was choose the tool (%d)" % g.active_slot)

func _test_sniper() -> void:
	_current = "sniper"
	await _boot()
	var g: Guardian = main.guardian
	var sniper: SniperAbility = g.abilities[3]

	# The magazine readout is derived from the gauge, not a second resource.
	check(SniperAbility.ammo_for(Balance.GAUGE_MAX) == Balance.SNIPE_AMMO_DISPLAY_CAP,
		"a full gauge shows a full magazine")
	check(SniperAbility.ammo_for(0.0) == Balance.SNIPE_AMMO_DISPLAY_CAP,
		"shots are unlimited, so the magazine never reads empty")

	g.gauge = Balance.GAUGE_MAX
	g.select_slot(3)
	g.use_active(Vector2(500, 300))
	check_near(g.gauge, Balance.GAUGE_MAX - Balance.COST_SNIPE, 1.0, "a shot costs the gauge")
	check(sniper.check(g, Vector2(500, 300)) == "", "rapid fire: no cooldown after a shot")

	# A shot lands on the enemy under the reticle.
	var walker := Walker.new()
	walker.global_position = Vector2(600, 300)
	main.add_child(walker)
	await _physics(2)
	g.gauge = Balance.GAUGE_MAX
	sniper.cooldown = 0.0
	g.use_active(walker.global_position)
	await _frames(2)
	check(not is_instance_valid(walker), "a sniped walker dies")

func _test_wall_blocks_projectile() -> void:
	# "I ate that shot for you" is one of the moments chapter 1 is built around.
	_current = "wall stops fire"
	await _boot()
	var g: Guardian = main.guardian
	GameState.shots_blocked = 0
	g.select_slot(2)
	g.gauge = Balance.GAUGE_MAX
	g.use_active(Vector2(700, 250))
	await _physics(2)

	var shot := Projectile.new()
	shot.direction = Vector2.RIGHT
	shot.global_position = Vector2(560, 250)
	main.add_child(shot)
	await _physics(60)
	check(GameState.shots_blocked >= 1, "the wall counted a blocked shot")
	check(not is_instance_valid(shot), "the projectile was consumed")

## Chapter 8 makes "the guardian is never bored" an explicit success condition,
## so it is measured rather than assumed: no stretch of the stage may leave the
## guardian with nothing to look at for more than ten seconds of running.
func _test_guardian_never_idle() -> void:
	_current = "guardian pacing"
	var tasks: Array[float] = []
	for e in Level01Data.enemies():
		tasks.append((e["pos"] as Vector2).x)
	for g in Level01Data.gimmicks():
		tasks.append((g["pos"] as Vector2).x)
	# A gap wider than a dash jump is a request for a platform, so it counts.
	var slabs := Level01Data.ground()
	for i in range(slabs.size() - 1):
		var gap: float = slabs[i + 1].position.x - (slabs[i].position.x + slabs[i].size.x)
		if gap > 300.0:
			tasks.append(slabs[i].position.x + slabs[i].size.x + gap * 0.5)
	tasks.sort()

	var idle_budget := 10.0 * Balance.RUNNER_RUN_SPEED   # px covered in ten seconds
	check(not tasks.is_empty(), "the stage has anything for the guardian to do")
	var worst := 0.0
	var worst_at := 0.0
	for i in range(tasks.size() - 1):
		var span: float = tasks[i + 1] - tasks[i]
		if span > worst:
			worst = span
			worst_at = tasks[i]
	check(worst <= idle_budget,
		"longest quiet stretch is %.0fpx (%.1fs) starting at x=%.0f, budget %.1fs"
			% [worst, worst / Balance.RUNNER_RUN_SPEED, worst_at, 10.0])
	print("  guardian pacing: %d tasks, longest quiet stretch %.1fs"
		% [tasks.size(), worst / Balance.RUNNER_RUN_SPEED])

## The move the whole co-op idea is for.
##
## The guardian puts a slab across the gap, the runner gets on it and points the
## way they want to go, and the guardian shoots the trigger. Neither of them can
## do it alone and neither is waiting on the other. Driven here the way a player
## drives it -- choose the rifle, tap the trigger -- rather than by calling the
## launch directly, because the aiming is half of what is under test.
func _test_shooting_the_trigger_launches_the_runner() -> void:
	_current = "launch pad"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner

	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	main._respawn_timer = -1.0
	r.global_position = Vector2(2600, 120)
	r.velocity = Vector2.ZERO
	await _physics(2)
	var slab_at := Vector2(2600, 230)
	g.select_slot(1)
	g.use_active(slab_at)
	await _physics(4)
	var slabs: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(slabs.size() == 1, "the guardian's slab is there")
	if slabs.is_empty():
		return
	var slab: Hologram = slabs.back()
	var trigger: LaunchTrigger = slab.trigger
	check(trigger != null, "and it carries a trigger")
	if trigger == null:
		return
	check(trigger.armed, "which starts armed")
	check(not trigger.loaded(), "but is not loaded with nobody on the slab")

	# --- a shot with nobody aboard does not spend it ---
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	g.select_slot(3)
	await _tap_world(trigger.global_position)
	check(trigger.armed, "a shot with nobody on it leaves the trigger armed")
	# Two separate guards, and the rifle's is the outer one: with nobody aboard
	# the trigger is not a candidate at all, so the check above passes without
	# ever reaching the trigger's own refusal. This is that inner guard.
	trigger.take_damage(1, "snipe")
	check(trigger.armed, "and a direct hit on it does nothing either")
	check(main.runner.velocity.is_zero_approx() or main.runner.velocity.y >= 0.0,
		"nobody is thrown by it")

	# --- the runner gets on ---
	for _i in range(90):
		await get_tree().physics_frame
		if r.is_on_floor():
			break
	check(r.is_on_floor(), "the runner lands on something")
	check(trigger.loaded(), "and the trigger reads as loaded")
	check(trigger.is_shootable_now(), "so the rifle will lock onto it")

	# --- and the launch goes the way the RUNNER is facing ---
	r.facing = 1
	var from := r.global_position
	var launched := [Vector2.ZERO, false]
	var watch := func(at: Vector2) -> void:
		launched[0] = at
		launched[1] = true
	Events.runner_launched.connect(watch)
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	await _tap_world(trigger.global_position)
	check(launched[1], "shooting the trigger launches them")
	check(r.velocity.y < 0.0, "upwards (%.0f)" % r.velocity.y)
	check(r.velocity.x > 0.0, "and forward, the way they faced (%.0f)" % r.velocity.x)
	check(not trigger.armed, "and the trigger is spent")

	# --- one slab, one launch: a second shot does nothing ---
	var speed_before := r.velocity
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	await _tap_world(trigger.global_position)
	check(r.velocity.distance_to(speed_before) < 260.0,
		"a second shot does not throw them again")

	# --- it carries further than the runner's own jump ---
	var reach := 0.0
	for _i in range(200):
		await get_tree().physics_frame
		reach = maxf(reach, r.global_position.x - from.x)
		if r.is_on_floor() and reach > 10.0:
			break
	var jump_reach: float = Balance.RUNNER_RUN_SPEED \
		* (2.0 * absf(Balance.RUNNER_JUMP_VELOCITY) / Balance.RUNNER_GRAVITY)
	check(reach > jump_reach,
		"and clears more ground than a running jump (%.0fpx against %.0fpx)"
			% [reach, jump_reach])

	Events.runner_launched.disconnect(watch)
	g.clear_constructs()
	await _frames(2)

## The runner's half of the gauge, and the one thing they can do FOR the
## guardian. Everything else in this game flows the other way.
func _test_a_crystal_pays_the_guardian_once() -> void:
	_current = "crystal"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner

	GameState.crystals_taken.clear()
	# The crystal is the host's to award, so say so rather than inheriting
	# whatever the previous test left behind.
	Clock.is_host = true
	main._respawn_timer = -1.0
	var crystal := Crystal.new()
	crystal.runner = r
	crystal.net_id = 7
	crystal.amount = Balance.CRYSTAL_GAUGE
	crystal.global_position = Vector2(2600, 260)
	main.add_child(crystal)
	await _frames(2)

	g.gauge = 20.0
	var paid := [0, 0.0]
	var watch := func(_id: int, _at: Vector2, amount: float) -> void:
		paid[0] += 1
		paid[1] = amount
	Events.crystal_taken.connect(watch)

	r.global_position = crystal.global_position
	r.velocity = Vector2.ZERO
	await _frames(6)
	check(paid[0] == 1, "touching it collects it once (%d)" % paid[0])
	check(is_equal_approx(float(paid[1]), Balance.CRYSTAL_GAUGE),
		"and says what it was worth (%.0f)" % float(paid[1]))
	check(crystal.taken(), "the crystal is gone")
	check(g.gauge > 20.0, "and the gauge went up (%.0f)" % g.gauge)

	# Standing on the spot is not a second crystal, and neither is a resend.
	var after: float = g.gauge
	await _frames(10)
	check(paid[0] == 1, "standing on it does not pay again (%d)" % paid[0])
	# Regeneration still runs, so this is about the absence of a second PAYOUT
	# rather than a frozen number.
	check(g.gauge < after + Balance.CRYSTAL_GAUGE * 0.5,
		"and the gauge does not climb by another crystal (%.1f -> %.1f)"
			% [after, g.gauge])
	check(not GameState.take_crystal(7),
		"the run remembers it, so a resend cannot pay twice")

	# The handshake carries the whole set as one mask, so a guardian who
	# reconnects late does not get a burst of collect events.
	var mask: int = GameState.crystal_mask()
	check(mask & (1 << 7) != 0, "the mask names it")
	GameState.apply_crystal_mask(0)
	check(GameState.crystals_taken.is_empty(), "a mask can be applied")
	GameState.apply_crystal_mask(mask)
	check(GameState.crystals_taken.has(7), "and round-trips")

	Events.crystal_taken.disconnect(watch)
	crystal.queue_free()
	GameState.crystals_taken.clear()
	await _frames(2)

## Taking back the thing you just put down. No refund: this is for a wall across
## the wrong doorway, not for changing your mind about the cost.
func _test_the_guardian_can_take_one_back() -> void:
	_current = "undo"
	await _boot()
	var g: Guardian = main.guardian
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	main.runner.global_position = Vector2(2600, 300)
	await _physics(4)

	# A wall: the tool that still costs, so "no refund" means something.
	g.select_slot(2)
	g.use_active(Vector2(2600, 180))
	await _physics(3)
	check(g.holograms_of(Hologram.Kind.WALL).size() == 1, "a wall is placed")
	var spent: float = g.gauge
	check(spent < Balance.GAUGE_MAX, "and paid for (%.0f)" % spent)

	check(g.undo_last(), "it can be taken back")
	await _physics(3)
	check(g.holograms_of(Hologram.Kind.WALL).is_empty(), "and it is gone")
	# The gauge regenerates on its own, so this is not an equality: what must
	# not happen is the COST coming back.
	check(g.gauge < spent + Balance.COST_WALL * 0.5,
		"with no refund (%.1f against %.1f spent)" % [g.gauge, spent])
	check(not g.undo_last(), "a second undo does nothing")

	# The gate pair is excluded: revoking half a pair leaves a doorway to
	# nowhere, which is worse than the mistake it would be fixing.
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(4)
	g.use_active(Vector2(2500, 280))
	await _physics(3)
	var gates: int = g.holograms_of(Hologram.Kind.WARP).size()
	check(gates >= 1, "a gate is placed (%d)" % gates)
	check(not g.undo_last(), "a gate is not undone")
	check(g.holograms_of(Hologram.Kind.WARP).size() == gates, "and is still there")

	g.clear_constructs()
	await _frames(2)

## Pointing at somewhere. The smallest piece of communication there is, and the
## one this game most needed across a network.
func _test_either_of_them_can_point() -> void:
	_current = "ping"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var said: Array = []
	var watch := func(at: Vector2, kind: int, from_runner: bool) -> void:
		said.append({"at": at, "kind": kind, "runner": from_runner})
	Events.pinged.connect(watch)

	# The guardian's ping button is retired (ControlLayout); the runner's is
	# the one on screen, and it carries both meanings.
	hub.solo_role = "runner"
	await _frames(2)
	var stood_at: Vector2 = main.runner.global_position
	hub._touch_down(33, _place("ping", view, "runner"))
	hub._touch_up(33)
	await _frames(4)
	check(said.size() == 1, "the runner's button points at something (%d)" % said.size())
	if said.size() > 0:
		check(bool(said[0]["runner"]), "and it is marked as theirs")
		check(int(said[0]["kind"]) == 1, "a tap means 'here'")
		check(Vector2(said[0]["at"]).distance_to(stood_at) < 40.0,
			"pointing at where they are (%.0fpx)"
				% Vector2(said[0]["at"]).distance_to(stood_at))

	# Held, it means the other thing. One button, two things, and the
	# difference is how long the thumb stays on it.
	said.clear()
	hub._touch_down(32, _place("ping", view, "runner"))
	hub.touch.ping.down_ms -= InputHub.PING_HOLD_MS + 40
	hub._touch_up(32)
	await _frames(4)
	check(said.size() == 1 and int(said[0]["kind"]) == 2,
		"holding it means 'wait'")

	Events.pinged.disconnect(watch)
	hub.solo_role = ""
	await _frames(2)

## The enemy neither of them can beat alone.
##
## The runner cannot hurt it and the guardian cannot reach anything that matters
## until the runner has pulled it round. Driven through the rifle the way a
## player drives it, because which side the reticle lands on IS the mechanic.
func _test_the_shieldbearer_needs_both_of_them() -> void:
	_current = "shield bearer"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner

	main._respawn_timer = -1.0
	var bearer := Shieldbearer.new()
	bearer.runner = r
	bearer.global_position = Vector2(2600, 280)
	main.add_child(bearer)
	await _physics(20)
	check(is_instance_valid(bearer), "a shield-bearer is in the world")
	check(bearer.hp == Balance.SHIELDBEARER_HP,
		"with %d points of life" % bearer.hp)

	# --- it faces whoever is next to it ---
	r.global_position = bearer.global_position + Vector2(-200.0, 0.0)
	await _physics(4)
	check(bearer.facing_now() == -1, "it turns towards the runner on its left")
	# Mid-turn the soft spot is shut: the shield is sweeping across it.
	r.global_position = bearer.global_position + Vector2(200.0, 0.0)
	await _physics(2)
	check(bearer.turning(), "crossing to the other side starts it turning")
	check(not bearer.exposed(), "and the soft spot is shut while it turns")
	check(not bearer._weak.is_shootable_now(),
		"so the rifle will not lock onto it mid-turn")

	await _wait(Balance.SHIELDBEARER_TURN_TIME + 0.15)
	check(bearer.facing_now() == 1, "it settles facing the runner")
	check(bearer.exposed(), "and the soft spot opens")
	check(bearer.open_for() > 0.0,
		"for a stated length of time (%.1fs)" % bearer.open_for())

	# --- a shot into the plate is refused, not missed ---
	var blocked := [0]
	var watch_block := func(_at: Vector2) -> void: blocked[0] += 1
	Events.shot_blocked.connect(watch_block)
	var life: int = bearer.hp
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	g.select_slot(3)
	await _tap_world(bearer._shield.global_position)
	check(bearer.hp == life, "a shot into the plate does no damage")
	check(blocked[0] == 1, "and says so, rather than reading as a miss (%d)" % blocked[0])

	# --- the soft spot, on its back, does ---
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	var aimed_at: Vector2 = bearer._weak.global_position
	await _tap_world(aimed_at)
	check(bearer.hp == life - Balance.SNIPE_DAMAGE,
		"a shot into the soft spot hurts it (%d -> %d)" % [life, bearer.hp])

	# --- and it shuts again on its own ---
	#
	# This is the whole difference between an enemy that needs two players and
	# one that needs none. The rule used to be "open unless mid-turn", which is
	# open BY DEFAULT: a guardian could shoot one in the back the moment it came
	# on screen, and the runner -- whose entire job here is to drag it round --
	# never had to be involved at all.
	await _wait(Balance.SHIELDBEARER_OPEN_TIME + 0.2)
	check(not bearer.exposed(), "the soft spot shuts again on its own")
	check(not bearer._weak.is_shootable_now(), "and the rifle stops locking onto it")

	# The runner stands still on one side -- which is the whole point: the
	# guardian is on their own here, and nothing the runner is doing is opening
	# anything. Pinned rather than merely placed, because a runner still walking
	# across would pull the enemy round and hand the guardian the window this
	# check exists to deny them.
	main.input_hub.move_axis = 0.0
	r.velocity = Vector2.ZERO
	var alone: int = bearer.hp
	var ever_open := false
	var survived := true
	for _i in range(4):
		# Stop the moment it dies rather than reading a freed node on the next
		# turn of the loop: a runtime error here would abandon the rest of this
		# function and take seven checks with it, reported as zero failures.
		if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
			survived = false
			break
		r.global_position = bearer.global_position + Vector2(200.0, 0.0)
		r.velocity = Vector2.ZERO
		await _physics(2)
		if bearer.exposed():
			ever_open = true
		g.gauge = Balance.GAUGE_MAX
		(g.abilities[3] as SniperAbility).cooldown = 0.0
		g.select_slot(3)
		await _tap_world(bearer._weak.global_position)
	if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
		survived = false
	check(not ever_open, "with nobody moving, the soft spot never opens by itself")
	check(survived and bearer.hp == alone,
		"and the guardian alone cannot kill it, however many shots they take")

	# That the runner can open it again is proved by the rest of this test,
	# which crosses back and finishes the enemy off. Left here, the crossing
	# would put the world in the state the next block is about to create for
	# itself, and the check below it would be reading its own setup.


	# --- and the assist does not reach into a shut one ---
	#
	# The runner crosses, the enemy starts turning, and a shot that lands near
	# the soft spot must NOT be pulled onto it. Getting this wrong would spend
	# the guardian's shot on a target that was never going to give.
	r.global_position = bearer.global_position + Vector2(-200.0, 0.0)
	await _physics(2)
	check(bearer.turning(), "the runner pulls it round again")
	var mid: int = bearer.hp
	blocked[0] = 0
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0
	var near_weak: Vector2 = bearer._weak.global_position + Vector2(0.0, -30.0)
	check((g.abilities[3] as SniperAbility).target_at(g, near_weak) == null
			or not ((g.abilities[3] as SniperAbility).target_at(g, near_weak) is Shieldbearer.WeakPoint),
		"the assist does not reach into a shut soft spot")
	await _tap_world(near_weak)
	check(bearer.hp == mid, "so a shot beside it while shut does no damage")

	# --- the runner cannot simply stomp it ---
	check(not bearer.is_in_group("stompable"),
		"and the runner has no way to do it alone")

	# --- and enough of them finish it ---
	await _wait(Balance.SHIELDBEARER_TURN_TIME + 0.15)
	var gone := false
	for _i in range(Balance.SHIELDBEARER_HP + 1):
		if not is_instance_valid(bearer) or bearer.is_queued_for_deletion():
			gone = true
			break
		g.gauge = Balance.GAUGE_MAX
		(g.abilities[3] as SniperAbility).cooldown = 0.0
		var spot: Vector2 = bearer._weak.global_position
		await _tap_world(spot)
	if not gone:
		gone = not is_instance_valid(bearer) or bearer.is_queued_for_deletion()
	check(gone, "enough shots into the back finish it")

	Events.shot_blocked.disconnect(watch_block)
	if is_instance_valid(bearer) and not bearer.is_queued_for_deletion():
		bearer.queue_free()
	await _frames(2)

## Guardian walls remain kickable alongside ordinary terrain.
func _test_the_guardian_wall_can_be_kicked_off() -> void:
	_current = "wall jump"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub

	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	main._respawn_timer = -1.0
	r.global_position = Vector2(2600, 300)
	r.velocity = Vector2.ZERO
	await _physics(20)
	check(r.is_on_floor(), "the runner is standing on the stage")

	# A wall just to their right, with its foot on the ground the runner is
	# standing on. Guessing the height gets it refused as "blocked" -- a wall is
	# 190px tall and the ground here is not where it looks.
	var feet: float = r.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var wall_at := Vector2(2664.0, feet - Balance.WALL_SIZE.y * 0.5 - 2.0)
	g.select_slot(2)
	g.use_active(wall_at)
	await _physics(4)
	check(g.holograms_of(Hologram.Kind.WALL).size() == 1,
		"the guardian's wall is up (%s)" % g._last_refusal)

	var kicks: Array[int] = [0]
	var watch := func(_at: Vector2, _away: int) -> void: kicks[0] += 1
	Events.runner_wall_jumped.connect(watch)

	var reached := await _press_into_the_wall(r, hub, 1.0)
	check(reached, "the runner gets onto the wall in the air")
	check(r.can_wall_jump(), "and the wall reads as kickable")

	hub.press_jump()
	await _physics(3)
	check(kicks[0] == 1, "pressing jump kicks off it (%d)" % kicks[0])
	check(r.velocity.y < 0.0, "upwards (%.0f)" % r.velocity.y)
	check(r.velocity.x < 0.0, "and away from the wall (%.0f)" % r.velocity.x)

	# Ordinary terrain contacts and repeated fresh contacts are covered by
	# movement_probe's isolated wall fixture. The old per-wall cap and the
	# terrain exclusion were deliberate restrictions; both are now removed.

	Events.runner_wall_jumped.disconnect(watch)
	g.clear_constructs()
	await _frames(2)

## The other direction, and the ordinary jump the slab still has to allow.
func _test_a_platform_is_still_a_platform() -> void:
	_current = "launch pad, the rest"
	await _boot()
	var g: Guardian = main.guardian
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub

	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	main._respawn_timer = -1.0
	r.global_position = Vector2(2600, 120)
	r.velocity = Vector2.ZERO
	await _physics(2)
	g.select_slot(1)
	g.use_active(Vector2(2600, 230))
	await _physics(4)
	for _i in range(90):
		await get_tree().physics_frame
		if r.is_on_floor():
			break
	var slab: Hologram = g.holograms_of(Hologram.Kind.PLATFORM).back()

	# Facing the other way sends them the other way.
	r.facing = -1
	await _physics(2)
	check(slab.trigger.loaded(), "still loaded facing the other way")
	var away := Runner.launch_velocity(r.facing)
	check(away.x < 0.0, "and the launch would go left (%.0f)" % away.x)

	# A platform the guardian placed is still something to stand on and jump
	# off normally -- the trigger is an extra, not a replacement.
	var before := r.global_position.y
	hub.press_jump()
	hub.jump_held = true
	await _physics(10)
	hub.jump_held = false
	check(r.global_position.y < before - 20.0,
		"and an ordinary jump off it still works (%.0fpx)" % (before - r.global_position.y))
	check(slab.trigger.armed, "without spending the trigger")

	g.clear_constructs()
	await _frames(2)

## The guardian can look along the stage -- but never away from the runner.
##
## Chapter 6 wants the guardian reading ahead of the runner, and the camera's
## own lead only buys a fraction of a screen. The bound is the point: a view
## that can leave the runner behind turns the support player into a spectator
## of a different part of the level.
func _test_the_guardian_can_look_ahead() -> void:
	_current = "look ahead"
	await _boot()
	var hub: InputHub = main.input_hub
	main.runner.global_position = Vector2(2600, 300)
	main.runner.velocity = Vector2.ZERO
	await _physics(6)
	check(is_zero_approx(main.guardian_pan), "the view starts on the runner")

	# Push right for a while.
	hub.pan_axis = 1.0
	await _physics(30)
	check(main.guardian_pan > 100.0,
		"holding the look button moves the view along (%.0fpx)" % main.guardian_pan)
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var half := view.x * 0.5 / Balance.CAMERA_ZOOM

	# ...and keep pushing. It has to stop somewhere short of losing the runner.
	await _physics(240)
	check(main.guardian_pan < half - 1.0,
		"it stops before the runner would leave the screen (%.0f of %.0f)"
			% [main.guardian_pan, half])
	check(main.guardian_pan <= Balance.GUARDIAN_PAN_MAX + 0.5,
		"and never past the design ceiling (%.0f)" % main.guardian_pan)
	var pushed: float = main.guardian_pan

	# Letting go LEAVES IT THERE. It used to ease back, which made holding the
	# button down the only way to keep looking at anything.
	hub.pan_axis = 0.0
	await _physics(120)
	check(absf(main.guardian_pan - pushed) < 1.0,
		"letting go leaves the view where it was put (%.0f -> %.0f)"
			% [pushed, main.guardian_pan])

	# And a flick off the button scrubs it, so a long look is one gesture
	# rather than a thumb held down.
	var before_flick: float = main.guardian_pan
	hub._pan_drag = -300.0
	await _physics(3)
	check(main.guardian_pan < before_flick - 100.0,
		"a flick moves the view without holding anything (%.0f -> %.0f)"
			% [before_flick, main.guardian_pan])

	# Both arrows at once is a standstill, not a fight.
	hub.touch.pan.fingers[1] = -1.0
	hub.touch.pan.fingers[2] = 1.0
	hub.touch.pan.refresh()
	check(is_zero_approx(hub.pan_axis), "two thumbs on opposite arrows cancel")
	hub.touch.pan.fingers.clear()
	hub.touch.pan.refresh()

	# A retry puts the view back on the runner: whatever was being looked at,
	# the checkpoint is what matters now.
	hub.pan_axis = -1.0
	await _physics(120)
	check(main.guardian_pan < -50.0, "pushed the other way")
	hub.pan_axis = 0.0
	main._do_respawn()
	check(is_zero_approx(main.guardian_pan), "a respawn returns the view to the runner")

## Reported as "even when I hit an enemy I cannot kill it".
##
## Putting a thumb on an enemy and letting go has to kill it. That sounds like
## it needs no test until you remember that the thumb's position and the shot's
## position are not the same number: tools dragged out of their button are
## aimed a fingertip ABOVE the thumb, so the slab being placed is not hidden
## under the hand placing it. For a slab that is right. For a rifle it means
## every shot goes over the target's head -- 43 world pixels over, and a walker
## is 42 tall, so the shot misses cleanly every time.
func _test_aiming_at_an_enemy_kills_it() -> void:
	_current = "shooting what you point at"
	await _boot()
	var g: Guardian = main.guardian
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size

	var walker: Node2D = null
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			walker = n as Node2D
			break
	check(walker != null, "there is a walker to shoot at")
	if walker == null:
		return
	# Stand the runner next to it so the camera frames it and it is in range.
	main.runner.global_position = walker.global_position + Vector2(-160, -60)
	main.camera.global_position = main.runner.global_position
	await _frames(8)
	g.gauge = Balance.GAUGE_MAX
	(g.abilities[3] as SniperAbility).cooldown = 0.0

	# The place the thumb is about to land on, in world coordinates, taken NOW.
	# It used to be recovered afterwards by inverting the canvas transform, but
	# the camera keeps moving through the four frames in between, so the answer
	# drifted a few pixels each run and the check failed roughly whenever the
	# machine was busy. The thumb goes on the walker; the walker is where it is.
	var pointed_at: Vector2 = walker.global_position
	var on_screen: Vector2 = main.get_viewport().get_canvas_transform() * pointed_at
	# The gesture: thumb on the snipe button, drag onto the enemy, let go.
	hub._touch_down(3, _place("slot_3", view, "shared"))
	hub._touch_move(3, on_screen)
	hub._touch_up(3)
	await _frames(4)
	check(not is_instance_valid(walker) or walker.is_queued_for_deletion(),
		"a thumb put on an enemy kills it")

	# And the aim really is where the thumb was, not somewhere above it.
	check(g.aim_world().distance_to(pointed_at) < 6.0,
		"the rifle is aimed where the thumb is (%.0fpx off)"
			% g.aim_world().distance_to(pointed_at))

## The rifle finds what you are pointing near, not only what you are exactly on.
##
## A thumb is not a mouse: the old rule wanted the reticle within 26px of a
## body, which on a phone is about a fingertip, against a moving target, with
## the same thumb that had just come off a button. That is not a decision, it
## is a tax -- and chapter 4 says the decision the rifle exists for is WHAT to
## shoot, not whether the thumb landed.
func _test_the_rifle_helps_you_aim() -> void:
	_current = "aim assist"
	await _boot()
	var g: Guardian = main.guardian
	var rifle: SniperAbility = g.abilities[3]
	var walker: Node2D = null
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			walker = n as Node2D
			break
	check(walker != null, "there is a walker to shoot at")
	if walker == null:
		return
	main.runner.global_position = walker.global_position + Vector2(-200, -60)
	await _frames(6)
	var at: Vector2 = walker.global_position

	# Dead on, and a comfortable miss, both find it.
	check(rifle.target_at(g, at) == walker, "a shot dead on the enemy finds it")
	check(rifle.target_at(g, at + Vector2(70, -40)) == walker,
		"and one a thumb's width off still does")
	# But not from the next postcode. The assist is a helping hand, not a homing
	# missile -- an enemy the guardian is not looking at must stay unshot.
	check(rifle.target_at(g, at + Vector2(360, 0)) != walker,
		"an enemy nowhere near the reticle is not stolen onto")

	# The preview says which one, before the trigger.
	var locked := rifle.preview(g, at + Vector2(70, -40))
	check(locked.has("lock"), "the reticle reports a lock while one is available")
	if locked.has("lock"):
		check((locked["lock"] as Vector2).distance_to(walker.global_position) < 1.0,
			"and the lock is on the enemy that would be hit")
	check(not rifle.preview(g, at + Vector2(900, 0)).has("lock"),
		"and reports none when there is nothing to hit")

	# Firing near it kills it, and the tracer ends on the body rather than
	# beside it -- a shot that lands next to a dying enemy reads as a bug.
	var shot := [Vector2.ZERO, false]
	var watch := func(_from: Vector2, to: Vector2, hit: bool) -> void:
		shot[0] = to
		shot[1] = hit
	Events.shot_fired.connect(watch)
	g.gauge = Balance.GAUGE_MAX
	rifle.cooldown = 0.0
	var body := walker.global_position
	g.select_slot(3)
	g.use_active(at + Vector2(70, -40))
	await _frames(4)
	Events.shot_fired.disconnect(watch)
	check(bool(shot[1]), "a shot aimed near an enemy connects")
	check((shot[0] as Vector2).distance_to(body) < 1.0,
		"and the tracer ends on the enemy, not where the thumb was")
	check(not is_instance_valid(walker) or walker.is_queued_for_deletion(),
		"and the enemy dies")

## Choose the tool, tap the ground, get it there.
##
## This test asserted the opposite twice. First that a tap resolved through a
## set of placement rules -- a floor under a falling runner, a wall towards the
## nearest threat -- on the reasoning that the decision worth making is WHICH
## TOOL and not where. Then that pressing the button itself built at the
## reticle. Both took the place the player had already pointed at and used a
## different one, and both came back off the device as "I press the button and
## it appears somewhere else".
func _test_a_tap_puts_it_where_you_pointed() -> void:
	_current = "tap to place"
	await _boot()
	var g: Guardian = main.guardian
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	var r: Runner = main.runner

	# --- the button chooses and builds nothing ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(2)
	r.global_position = Vector2(2100, 120)
	r.velocity = Vector2(0, 600)
	var pointed_at := Vector2(2100, -400)
	hub.aim_at_world(pointed_at)
	await _physics(2)
	var purse: float = g.gauge
	hub._touch_down(3, _place("slot_1", view, "shared"))
	hub._touch_up(3)
	await _frames(4)
	check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"choosing a tool builds nothing")
	check(is_equal_approx(g.gauge, purse), "and spends nothing")
	check(g.active_slot == 1, "it chose the tool (%d)" % g.active_slot)

	# --- then a tap on the world builds it, exactly there ---
	await _tap_world(pointed_at)
	var slabs: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	check(slabs.size() == 1, "a tap on the world builds one (%d)" % slabs.size())
	if slabs.size() > 0:
		var at: Vector2 = slabs.back().global_position
		check(at.distance_to(pointed_at) < 1.0,
			"exactly where it was pointed (%.2fpx off)" % at.distance_to(pointed_at))
		check(at.y < r.global_position.y,
			"even when that is above a falling runner rather than under them")

	# --- and the ghost promised that place before the tap ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	hub.aim_at_world(pointed_at)
	await _physics(2)
	var ghost: Dictionary = g.preview_of(1, true)
	check(ghost.has("rect")
			and (ghost["rect"] as Rect2).get_center().distance_to(pointed_at) < 1.0,
		"and the ghost was already sitting there")

	# --- the same tap, with the camera somewhere else and zoomed ---
	#
	# Screen to world goes through the canvas transform, so a camera that has
	# moved or changed zoom between the aim and the commit must not drag the
	# target with it. It used to: the reticle was kept as a screen point.
	for zoom in [Balance.CAMERA_ZOOM, Balance.CAMERA_ZOOM * 1.6, Balance.CAMERA_ZOOM * 0.7]:
		g.clear_constructs()
		g.gauge = Balance.GAUGE_MAX
		main.camera.zoom = Vector2.ONE * zoom
		main.camera.global_position = r.global_position + Vector2(140.0, -60.0)
		await _physics(2)
		var screen := Vector2(view.x * 0.62, view.y * 0.38)
		var want: Vector2 = main.get_viewport().get_canvas_transform().affine_inverse() * screen
		hub._touch_down(9, screen)
		hub._touch_up(9)
		await _frames(4)
		var built: Array = g.holograms_of(Hologram.Kind.PLATFORM)
		check(built.size() == 1, "zoom %.2f: a tap builds one (%d)" % [zoom, built.size()])
		if built.size() > 0:
			var off: float = built.back().global_position.distance_to(want)
			check(off < 1.0, "zoom %.2f: under the finger (%.2fpx)" % [zoom, off])
	main.camera.zoom = Vector2.ONE * Balance.CAMERA_ZOOM

	# --- the wire rounds it, and by how much is known ---
	#
	# Positions cross as 16 bits each: x in half-pixels, y in quarters. A
	# placement is allowed to move by that rounding and no more, and the number
	# is here so a change to the packing cannot quietly loosen it.
	var worst := 0.0
	for sample in [Vector2(2100.25, -400.06), Vector2(0.9, 0.4), Vector2(16000.3, 300.7),
			Vector2(-19.2, -83.1), Vector2(7777.77, 123.45)]:
		var wire := Protocol.place(1, sample, 0, 1)
		var parsed := Protocol.reader(wire)
		var b: StreamPeerBuffer = parsed[1]
		b.get_u8()                       # slot
		var back := Protocol.get_pos(b)
		worst = maxf(worst, absf(back.x - sample.x))
		worst = maxf(worst, absf(back.y - sample.y))
	check(worst <= 0.25 + 0.0001,
		"the wire moves a placement by at most a quarter pixel (%.4f)" % worst)

	# --- a tap on the controls is not a placement ---
	g.clear_constructs()
	g.gauge = Balance.GAUGE_MAX
	var kept: float = g.gauge
	# A tap (no drag) on a tool button chooses the tool; it places nothing.
	hub._touch_down(11, _place("slot_1", view, "shared"))
	hub._touch_up(11)
	await _frames(4)
	check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"a tap on a control builds nothing in the world")
	check(is_equal_approx(g.gauge, kept), "and spends nothing")

	# --- the rifle is pointed the same way ---
	var walker: Node2D = null
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			walker = n as Node2D
			break
	check(walker != null, "there is something to shoot")
	if walker != null:
		r.global_position = walker.global_position + Vector2(-150, -40)
		r.velocity = Vector2.ZERO
		main.camera.global_position = r.global_position
		await _physics(3)
		g.gauge = Balance.GAUGE_MAX
		(g.abilities[3] as SniperAbility).cooldown = 0.0
		g.select_slot(3)
		await _tap_world(walker.global_position)
		check(not is_instance_valid(walker) or walker.is_queued_for_deletion(),
			"a tap on an enemy with the rifle chosen kills it")

	# --- and it spares one the reticle is nowhere near ---
	var other: Node2D = null
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D and is_instance_valid(n) and not n.is_queued_for_deletion():
			other = n as Node2D
			break
	if other != null:
		r.global_position = other.global_position + Vector2(-150, -40)
		main.camera.global_position = r.global_position
		await _physics(3)
		g.gauge = Balance.GAUGE_MAX
		(g.abilities[3] as SniperAbility).cooldown = 0.0
		await _tap_world(other.global_position + Vector2(0, -900))
		check(is_instance_valid(other) and not other.is_queued_for_deletion(),
			"...and spares the one it is pointing away from")

func _test_shot_drag_keeps_the_view() -> void:
	_current = "shot drag keeps the view"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"
	main.runner.global_position = Vector2(2600, 300)
	main.runner.velocity = Vector2.ZERO
	await _physics(6)
	# With the platform tool chosen a drag on the world DRAWS the platform
	# (trace mode); the other tool aims without moving the view.
	main.guardian.select_slot(1)
	await _physics(2)
	check(hub.trace_mode, "with the platform tool a drag draws")
	main.guardian.select_slot(3)
	await _physics(2)
	check(not hub.trace_mode, "and with the shot it does not")
	main.guardian_pan = 0.0

	# A small touch aims and does NOT scroll: putting the reticle somewhere
	# precise must never turn into a camera move.
	var start := Vector2(view.x * 0.5, view.y * 0.45)
	hub._touch_down(1, start)
	hub._touch_move(1, start + Vector2(12, 4))
	await _physics(3)
	check(absf(main.guardian_pan) < 1.0,
		"a small drag aims and leaves the view alone (%.1f)" % main.guardian_pan)
	hub._touch_up(1)

	# A long sideways drag still aims, without moving the camera.
	hub._touch_down(2, start)
	var aimed: Vector2 = hub.aim_world()
	for i in range(6):
		hub._touch_move(2, start + Vector2(-40.0 * float(i + 1), 0.0))
	await _physics(4)
	hub._touch_up(2)
	check(absf(main.guardian_pan) < 1.0,
		"a long shot drag keeps the camera still (%.0f)" % main.guardian_pan)
	check(hub.aim_world().distance_to(aimed) > 100.0,
		"and the reticle follows the aiming finger (%.0fpx)"
			% hub.aim_world().distance_to(aimed))
	hub.solo_role = ""

# ------------------------------------------------------------------ the hand

## Where a finger would have to go to touch `point`, with the camera brought
## round first if the point is off screen or on the runner's side -- the same
## rule as _tap_world.
func _finger_on(point: Vector2) -> Vector2:
	# Hold the camera still for the whole gesture -- main's follow would move
	# the world under a finger that is still down -- and put the point high
	# in the middle of the screen, clear of every control.
	main.set_physics_process(false)
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	var want := Vector2(rect.size.x * 0.58, rect.size.y * 0.36)
	main.camera.global_position = point - (want - rect.size * 0.5) / main.camera.zoom
	main.camera.force_update_scroll()
	return main.get_viewport().get_canvas_transform() * point

## Down at `from`, through `steps` moves to `to` one frame apart, then up.
func _stroke(from: Vector2, to: Vector2, steps: int, hold_frames: int = 0) -> void:
	main.input_hub._touch_down(22, from)
	await _frames(1 + hold_frames)
	for i in range(1, steps + 1):
		main.input_hub._touch_move(22, from.lerp(to, float(i) / float(steps)))
		await _frames(1)
	main.input_hub._touch_up(22, to)
	await _frames(3)

func _test_the_hand_slings_the_runner() -> void:
	_current = "hand: slingshot"
	await _boot()
	var r: Runner = main.runner
	main._respawn_timer = -1.0
	# Open field with nothing overhead, so the throw is the only thing measured.
	r.global_position = Vector2(-900, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)
	check(r.is_on_floor(), "the runner is standing")
	var start_y := r.global_position.y
	var at := _finger_on(r.global_position)
	check(not GuardianHand.target_at(main.guardian, r.global_position).is_empty(),
		"a finger on the standing runner takes hold of them")
	# Pull back down and to the left, let go: up and to the right.
	await _stroke(at, at + Vector2(-110, 150), 4)
	await _physics(2)
	check(r.velocity.y < -400.0, "letting go throws the runner up (vy %.0f)" % r.velocity.y)
	check(r.velocity.x > 0.0, "away from the pull (vx %.0f)" % r.velocity.x)
	var peak := r.global_position.y
	for i in 40:
		await _physics(1)
		peak = minf(peak, r.global_position.y)
	check(start_y - peak > Balance.RUNNER_JUMP_HEIGHT * 1.3,
		"higher than the runner can jump (%.0fpx)" % (start_y - peak))
	check(GuardianHand.sling_velocity(Vector2.ZERO, Vector2(0, 10)) == Vector2.ZERO,
		"a pull too short to mean anything does nothing")

func _test_the_hand_flicks_a_walker() -> void:
	_current = "hand: flick"
	await _boot()
	var walker: Enemy = null
	for n in get_tree().get_nodes_in_group("flickable"):
		if n is Walker:
			walker = n
			break
	check(walker != null, "1-1 has a walker to flick")
	if walker == null:
		return
	walker.set_physics_process(false)
	var at := _finger_on(walker.global_position)
	await _stroke(at, at + Vector2(260, -160), 2)
	await _frames(2)
	check(not is_instance_valid(walker) or walker.is_queued_for_deletion(),
		"a flicked walker is gone")

func _test_a_swipe_sweeps_fliers_away() -> void:
	_current = "hand: swipe"
	await _boot()
	var g: Guardian = main.guardian
	g.clear_constructs()
	g.select_slot(1)
	await _frames(2)
	var flyer := Flyer.new()
	flyer.global_position = Vector2(900, 150)
	main.add_child(flyer)
	await _frames(2)
	flyer.set_physics_process(false)
	var at := _finger_on(flyer.global_position)
	await _stroke(at + Vector2(-140, 20), at + Vector2(140, -20), 4)
	check(not is_instance_valid(flyer) or flyer.is_queued_for_deletion(),
		"a quick stroke through a flier sweeps it away")
	check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"and the swipe is not also a platform")

func _test_a_caught_bullet_goes_home() -> void:
	_current = "hand: catch"
	await _boot()
	var turret := Turret.new()
	turret.global_position = Vector2(1300, 200)
	main.add_child(turret)
	await _frames(2)
	turret.set_physics_process(false)
	var shot := Projectile.new()
	shot.direction = Vector2.LEFT
	shot.source = turret
	shot.global_position = Vector2(1000, 200)
	main.add_child(shot)
	await _frames(1)
	check(shot.net_id >= 0, "a bullet has a name to be sent by")
	var at := _finger_on(shot.global_position)
	main.input_hub._touch_down(22, at)
	await _frames(3)
	check(shot.state == Projectile.State.HELD, "a finger on a bullet pinches it")
	main.input_hub._touch_move(22, at + Vector2(-30, 0))
	await _frames(1)
	main.input_hub._touch_up(22, at + Vector2(-30, 0))
	await _frames(2)
	check(is_instance_valid(shot) and shot.state == Projectile.State.THROWN,
		"letting go sends it back")
	for i in 90:
		await _physics(1)
		if not is_instance_valid(turret) or turret.is_queued_for_deletion():
			break
	check(not is_instance_valid(turret) or turret.is_queued_for_deletion(),
		"and it takes its own turret with it")

func _test_the_hand_holds_a_boulder() -> void:
	_current = "hand: boulder"
	await _boot()
	var trap: CaveTrap = CaveTrap.from_spec({"kind": "boulder", "travel": 145.0, "period": 3.5}, null)
	trap.hand_id = 90
	trap.global_position = Vector2(900, 200)
	main.add_child(trap)
	await _frames(2)
	var before_tick := Clock.tick - 5
	var before := trap.head_at(before_tick)
	var at := _finger_on(trap.hand_point())
	main.input_hub._touch_down(22, at)
	await _physics(3)
	var held := trap.hand_point()
	await _physics(20)
	check(trap.hold.held_at(Clock.tick), "a finger on the boulder holds it")
	check(trap.hand_point().distance_to(held) < 1.0,
		"and it does not move while held (%.1fpx)" % trap.hand_point().distance_to(held))
	main.input_hub._touch_up(22, at)
	await _physics(30)
	check(not trap.hold.held_at(Clock.tick), "letting go lets it go")
	check(trap.hand_point().distance_to(held) > 5.0, "and it rolls on")
	check(trap.head_at(before_tick) == before,
		"a hold never changes where it was before the hold (a past tick)")
	var timeline := HoldTimeline.new(1.0)
	timeline.begin(100)
	check(timeline.held_at(100 + Clock.HZ - 1) and not timeline.held_at(100 + Clock.HZ),
		"a hold nobody lets go of ends by itself")
	check(timeline.local_tick(500) == 500 - Clock.HZ, "and only costs the time it held")

func _test_a_held_gate_lets_the_runner_under() -> void:
	_current = "hand: gate"
	await _boot()
	var gate: LiftGate = LiftGate.from_spec({"height": 420.0}, null)
	gate.hand_id = 91
	gate.global_position = Vector2(900, 400)
	main.add_child(gate)
	await _frames(2)
	check(not gate.passable_at(Clock.tick), "a gate starts shut")
	check(LiftGate.stop_x(get_tree(), 700.0, 950.0, 330.0, Clock.tick, 70.0) != INF,
		"and a shut gate stops the pursuer")
	var at := _finger_on(gate.hand_point())
	main.input_hub._touch_down(22, at)
	await _physics(40)
	check(gate.passable_at(Clock.tick), "held, it goes up far enough to pass under")
	check(LiftGate.stop_x(get_tree(), 700.0, 950.0, 330.0, Clock.tick, 70.0) == INF,
		"and lets the pursuer through too")
	main.input_hub._touch_up(22, at)
	await _physics(20)
	check(not gate.passable_at(Clock.tick), "let go, it drops")
