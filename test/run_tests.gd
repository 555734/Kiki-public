extends Node
## The logic half of verification.
##
## Runs as a scene, not via --script, because GDScript only resolves autoload
## names once the autoloads exist. Integration cases drive a real instance of
## main.tscn so they exercise the same code path the players do.
##
## Run:  godot --headless --path . res://test/run_tests.tscn

var _checks: int = 0
var _failures: Array[String] = []
var _current: String = ""
var main: Node2D = null

func _ready() -> void:
	await _run_all()
	print("\n--- %d checks, %d failed ---" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAIL  ", f)
	if _failures.is_empty():
		print("  all logic tests passed")
	get_tree().quit(0 if _failures.is_empty() else 1)

# ------------------------------------------------------------------ harness

func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_current, message])

func check_near(got: float, want: float, tol: float, message: String) -> void:
	_checks += 1
	if absf(got - want) > tol:
		_failures.append("%s: %s (got %.3f, want %.3f +/- %.3f)"
			% [_current, message, got, want, tol])

func check_range(got: float, low: float, high: float, message: String) -> void:
	_checks += 1
	if got < low or got > high:
		_failures.append("%s: %s (got %.2f, expected %.2f..%.2f)"
			% [_current, message, got, low, high])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## Filled in by _test_runner_arc and consumed by _test_level_reachability, so
## the stage audit is measured against what the runner can actually do rather
## than against a number somebody typed once. They had drifted 13px apart.
var _reach: Dictionary = {}

func _physics(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Waits real seconds. Frame counts are useless for anything time-based here:
## headless runs uncapped, so a "frame" can be a fraction of a millisecond and
## 30 of them are nowhere near half a second.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## Every test below measures against 1-1's geometry -- its gaps, its ledges, the
## coordinates its checkpoints sit at. The game opens on the co-op stage, so the
## stage is pinned here rather than left to whatever the game's default happens
## to be: a default that moves would silently re-aim two hundred checks at
## terrain that is not there.
func _boot(dismiss_home: bool = true) -> void:
	Stage.use(Stage.Which.GREENFIELD)
	if main != null:
		main.free()
	main = load("res://src/main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	# Production deliberately freezes the world behind the home screen. Logic
	# probes are already choosing their stage above, so dismiss home before they
	# begin driving the runner.
	var panel := main.get_node_or_null("NetPanel")
	if dismiss_home and panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true

func _run_all() -> void:
	await _test_gauge_rules()
	await _test_platform_limits()
	await _test_wall_limits()
	await _test_one_press_tools()
	await _test_a_tap_puts_it_where_you_pointed()
	await _test_a_swipe_scrolls_the_view()
	await _test_sniper()
	await _test_aiming_at_an_enemy_kills_it()
	await _test_the_rifle_helps_you_aim()
	await _test_runner_arc()
	await _test_four_ways_to_change_direction()
	await _test_dash()
	await _test_stomp_and_damage()
	await _test_wall_blocks_projectile()
	await _test_checkpoint_respawn()
	_test_level_reachability()
	_test_guardian_never_idle()
	_test_every_control_is_reachable_and_separate()
	_test_controls_can_be_resized()
	await _test_the_guardian_can_look_ahead()
	await _test_virtual_stick()
	await _test_solid_decor()
	await _test_enemies_hold_their_ground()
	_test_determinism()
	await _test_rescue_under_latency()
	await _test_rewind_never_harms()
	_test_rewind_is_bounded()
	await _test_loopback_link()
	_test_bandwidth_budget()
	await _test_host_answers_the_guardian()
	await _test_client_shows_the_host()
	await _test_a_dead_enemy_stays_dead_on_both_screens()
	await _test_connect_screen_responds_to_touch()
	_test_everything_stands_on_the_ground()
	await _test_the_game_has_a_voice()
	await _test_two_hits_end_the_run()
	await _test_pickups_and_pads()
	await _test_the_catch_is_graded()
	await _test_warp_pair()
	await _test_warp_over_the_wire()
	await _test_a_dropped_link_comes_back()
	await _test_a_slow_start_is_not_a_drop()
	await _test_reconnecting_twice_changes_nothing()
	await _test_shooting_the_trigger_launches_the_runner()
	await _test_a_platform_is_still_a_platform()
	await _test_the_guardian_wall_can_be_kicked_off()
	await _test_the_shieldbearer_needs_both_of_them()
	await _test_a_crystal_pays_the_guardian_once()
	await _test_the_runner_can_catch_an_edge()
	await _test_the_guardian_can_take_one_back()
	await _test_either_of_them_can_point()
	await _test_only_a_tap_counts_as_a_tap()
	await _test_the_finger_decides_where_it_landed()
	await _test_an_interruption_lets_go_of_everything()
	await _test_two_thumbs_do_not_interfere()
	await _test_auto_dash_is_a_real_choice()
	await _test_two_taps_make_one_session()
	await _test_the_link_records_what_happened()
	await _test_an_unmeasured_round_trip_says_so()
	await _test_a_link_that_never_opened_keeps_trying()
	await _test_a_new_room_ends_the_old_one()
	await _test_the_guest_clock_keeps_running()
	await _test_the_aim_stream_is_rationed()
	await _test_a_refused_handshake_is_visible()
	await _test_the_diagnostic_reports_every_step()
	await _test_device_ownership()
	await _test_three_names_for_who()
	_test_settings_survive_each_other()
	_test_assets()
	_test_walker_skins()

## Saving one setting must not delete the others.
##
## The connect screen wrote the relay URL by building a fresh ConfigFile and
## saving it -- a file containing exactly one key. The client id lives in that
## same file, so typing a relay address and pressing the button deleted this
## device's own name, and the next restart came back as somebody the relay had
## never met: a reconnect could not be recognised as a return, and the room
## handed out roles by arrival order again.
##
## The whole file is written and read here rather than mocked, because what
## broke was the file.
func _test_settings_survive_each_other() -> void:
	_current = "settings do not overwrite each other"
	var path := NetLink.SETTINGS_PATH
	var had := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_bytes(path) if had else PackedByteArray()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	NetLink._forced_id = ""      # so client_id() reads the file rather than a flag
	var first := NetLink.client_id()
	check(first.length() >= 8, "a device with no settings gives itself a name")

	# The thing that used to destroy it.
	NetLink.remember("relay", "wss://somewhere.example/relay")
	NetLink._forced_id = ""
	check(NetLink.client_id() == first,
		"saving a relay URL leaves the device's name alone (%s)" % NetLink.client_id())
	check(NetLink.recall("relay") == "wss://somewhere.example/relay",
		"and the relay URL is what was saved")

	# And the other way round, which was never broken but is the same rule.
	NetLink.remember("client_id", first)
	check(NetLink.recall("relay") == "wss://somewhere.example/relay",
		"writing the name leaves the relay URL alone")

	# A second write of the same key replaces rather than accumulates.
	NetLink.remember("relay", "wss://elsewhere.example/relay")
	check(NetLink.recall("relay") == "wss://elsewhere.example/relay",
		"and a setting can be changed")
	NetLink._forced_id = ""
	check(NetLink.client_id() == first, "the name is still there afterwards")

	check(NetLink.recall("never-set", "fallback") == "fallback",
		"a setting that was never written reads as its fallback")

	# Put the device back the way it was found.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup)
			f.close()
	NetLink._forced_id = ""

## Player, role, team: three different questions, and the game must never take
## one for another.
##
## Today all three line up -- two people, one team, one runner -- which is
## precisely what makes them easy to conflate, and code that conflates them
## reads fine right up until a third person arrives. Chapter 10 of the brief
## asks for team play later; this is the part worth building now.
func _test_three_names_for_who() -> void:
	_current = "player, role, team"
	var p := Party.new()
	p.seat("device-aaa", Party.ROLE_RUNNER)
	p.seat("device-bbb", Party.ROLE_GUARDIAN)
	check(p.size() == 2, "two people are in the game")
	check(p.role_of("device-aaa") == Party.ROLE_RUNNER, "one of them is the runner")
	check(p.role_of("device-bbb") == Party.ROLE_GUARDIAN, "the other is the guardian")
	check(p.allied("device-aaa", "device-bbb"), "and in co-op they are on one team")
	check(p.holder_of(Party.ROLE_RUNNER) == "device-aaa", "a role has exactly one holder")
	check(p.members(Party.TEAM_A).size() == 2, "the team has both of them in it")

	# Swapping seats does not make them different people. A pair who play 1-C
	# twice, one run each way round, is one pair.
	p.seat("device-aaa", Party.ROLE_GUARDIAN)
	p.seat("device-bbb", Party.ROLE_RUNNER)
	check(p.size() == 2, "swapping roles does not add anybody")
	check(p.role_of("device-aaa") == Party.ROLE_GUARDIAN, "the swap took")
	check(p.holder_of(Party.ROLE_RUNNER) == "device-bbb", "and the runner is the other one")
	check(p.allied("device-aaa", "device-bbb"), "they are still on the same team")

	# And a team is not a role. Two people on one side hold different roles;
	# two people in different roles are not thereby enemies.
	p.seat("device-ccc", Party.ROLE_RUNNER, Party.TEAM_B)
	check(not p.allied("device-aaa", "device-ccc"),
		"somebody on the other team is not an ally")
	check(p.role_of("device-ccc") == p.role_of("device-bbb"),
		"even though they play the same role")
	check(p.members(Party.TEAM_B) == ["device-ccc"], "and the other team has one member")

	# The identity that survives a restart is the device's, and it is not the
	# transport's answer to "who is the authority": a guardian's device is not
	# less of a player for not being the host.
	var mine := NetLink.client_id()
	check(mine.length() >= 8, "this device has a name that outlives the app (%s)" % mine)
	check(mine == NetLink.client_id(), "and asking twice gives the same one")
	p.clear()
	p.seat(mine, Party.ROLE_GUARDIAN)
	# Being the guardian is a seat in the game; being the host is a job in the
	# netcode. The party does not know or care about the second one, which is
	# the whole point of keeping them in different objects.
	check(p.role_of(mine) == Party.ROLE_GUARDIAN,
		"this device holds a seat whatever the transport decided")
	check(p.team_of(mine) == Party.TEAM_A, "and a team of one is still a team")
	p.forget(mine)
	check(not p.knows(mine), "somebody who leaves is gone")

	# And the part that matters: the real handshake fills this in. A structure
	# that is correct in isolation and never populated is a comment with a test
	# suite attached, so this drives HELLO and WELCOME over a real transport and
	# asks BOTH devices who they think is playing.
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var host_side: LoopbackTransport = pair[0]
	var guest_side: LoopbackTransport = pair[1]
	var host := HostSession.new()
	host.main = main
	host.transport = host_side
	add_child(host)
	await _frames(2)
	guest_side.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.hello("guest-device", Stage.current()))
	await _pump(pair, 4)
	check(host.party.size() == 2, "the host seats both people at the handshake")
	check(host.party.role_of("guest-device") == Party.ROLE_GUARDIAN,
		"the one who dialled in is the guardian")
	check(host.party.holder_of(Party.ROLE_RUNNER) == NetLink.client_id(),
		"and the host's own device is the runner")
	check(host.party.allied("guest-device", NetLink.client_id()),
		"co-op puts them on one team")
	host.queue_free()
	await _frames(2)

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

func _stompable_positions() -> Dictionary:
	var out: Dictionary = {}
	for n in get_tree().get_nodes_in_group("stompable"):
		if n is Node2D:
			out[int((n as Node2D).global_position.x)] = (n as Node2D).global_position.y
	return out

func _walkers_in_data() -> int:
	var count := 0
	for e in Level01Data.enemies():
		if String(e.get("type", "")) == "walker":
			count += 1
	return count

# ------------------------------------------------------------------ netcode

## The claim in docs/netcode.md section 4 is that moving platforms and lasers
## never have to be sent over the wire, because both devices can compute them
## from the tick. That is only true if they really are pure functions of the
## tick -- they used to accumulate `delta`, which drifts. This is the test that
## makes the zero-bandwidth claim honest.
func _test_determinism() -> void:
	_current = "tick determinism"
	var lift := MovingPlatform.new()
	lift.travel = Vector2(0, -140)
	lift.span = Vector2(150, 26)
	add_child(lift)
	lift.global_position = Vector2(1000, 200)
	lift._ready()

	var beam := Laser.new()
	beam.phase_offset = 0.37
	add_child(beam)

	var same := true
	var moved := false
	var toggled := false
	var first_beam := beam.is_on_at(0)
	for t in range(0, 600, 7):
		# Evaluate each tick twice, as two devices would.
		if lift.position_at(t) != lift.position_at(t):
			same = false
		if beam.is_on_at(t) != beam.is_on_at(t):
			same = false
		if lift.position_at(t) != lift.position_at(0):
			moved = true
		if beam.is_on_at(t) != first_beam:
			toggled = true
	check(same, "the same tick always yields the same platform and beam state")
	check(moved, "the lift actually moves (a constant would pass vacuously)")
	check(toggled, "the beam actually cycles (a constant would pass vacuously)")

	# Order must not matter either: evaluating the past after the present has to
	# give the same answer, because that is exactly what the rewind does.
	var forward := lift.position_at(120)
	var _ignored := lift.position_at(400)
	check(lift.position_at(120) == forward,
		"evaluating a past tick after a later one gives the same answer")
	lift.queue_free()
	beam.queue_free()

## The headline claim: a construct request delayed by 150ms still rescues a
## falling runner. Without the backdating this test fails by design -- the
## platform lands above a runner who has already gone past it.
func _test_rescue_under_latency() -> void:
	_current = "rescue under latency"
	await _boot()
	var r: Runner = main.runner
	var host := HostAuthority.new()
	host.runner = r
	host.measured_one_way = 0.075
	host.client_interp_buffer = 0.075
	add_child(host)

	# Drop the runner down an empty column, well clear of any real ground.
	r.global_position = Vector2(2100, 120)
	r.velocity = Vector2(0, 0)
	main.input_hub.move_axis = 0.0
	await _physics(1)

	# What the guardian saw. Nine ticks (150ms) later their request arrives.
	var view_tick := Clock.tick
	var seen_at := r.global_position
	await _physics(9)
	var fallen_to := r.global_position
	check(fallen_to.y > seen_at.y + 20.0,
		"the runner really did fall while the request was in flight (%.0fpx)"
			% (fallen_to.y - seen_at.y))

	# The guardian aimed just under the runner as they saw them.
	var size := Balance.PLATFORM_SIZE
	var target := seen_at + Vector2(0, Balance.RUNNER_SIZE.y * 0.5 + size.y * 0.5)
	var birth := host.accept_placement(target, size, view_tick)

	check(birth < Clock.tick, "the platform is stamped in the past, not now")
	check(host.rescues_backdated == 1, "the rescue was applied")
	var caught := r.global_position
	check(caught.y < fallen_to.y,
		"the runner ends up above where they had fallen to (%.0f -> %.0f)"
			% [fallen_to.y, caught.y])
	check(absf(caught.y - (target.y - size.y * 0.5 - Balance.RUNNER_SIZE.y * 0.5)) < 1.0,
		"the runner is standing on the platform's surface, not inside it")
	check(absf(r.velocity.y) < 1.0, "the fall is arrested")
	host.queue_free()

## The safety property. A rewind must never leave the runner worse off, because
## the runner is the host and being yanked backwards by someone else's latency
## is the one thing this design must not do.
func _test_rewind_never_harms() -> void:
	_current = "rewind never harms"
	await _boot()
	var r: Runner = main.runner
	var host := HostAuthority.new()
	host.runner = r
	host.measured_one_way = 0.075
	host.client_interp_buffer = 0.075
	add_child(host)

	# The runner is standing safely on the ground.
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	main.input_hub.move_axis = 0.0
	await _physics(40)
	check(r.is_on_floor(), "the runner is grounded before the late request")
	var before := r.global_position

	# A request arrives that would, if applied naively, put them somewhere lower.
	var view_tick := Clock.tick - 9
	var below := before + Vector2(0, 220.0)
	host.accept_placement(below, Balance.PLATFORM_SIZE, view_tick)
	check(r.global_position.distance_to(before) < 1.0,
		"a rewind that does not help leaves the runner exactly where they were")
	check(host.rescues_backdated == 0, "no rescue was claimed")

	check(not Rewind.is_improvement(false, Vector2(0, -500), Vector2(0, 0), false),
		"a replay that kills the runner is never an improvement")
	check(not Rewind.is_improvement(true, Vector2(0, 40), Vector2(0, 0), false),
		"a replay that ends up lower is never an improvement")
	check(not Rewind.is_improvement(true, Vector2(0, -40), Vector2(0, 0), true),
		"a replay that ends in a hazard is never an improvement")
	check(Rewind.is_improvement(true, Vector2(0, -40), Vector2(0, 0), false),
		"a replay that ends up higher and alive is an improvement")
	host.queue_free()

## The rewind window is the guardian's one lever for cheating: claim an ancient
## view tick and get an arbitrarily generous rescue. It is clamped twice -- by
## the hard cap, and by what the measured round trip can actually justify.
func _test_rewind_is_bounded() -> void:
	_current = "rewind bounds"
	var rw := Rewind.new()
	check(rw.allowed_rewind(1000, 900, 0.075, 0.075) <= Rewind.MAX_REWIND_TICKS,
		"a 100-tick claim is capped at the hard limit")
	# A 20ms link cannot justify 250ms of rewind however old the claim is.
	var on_a_fast_link := rw.allowed_rewind(1000, 900, 0.010, 0.020)
	check(on_a_fast_link < Rewind.MAX_REWIND_TICKS,
		"a fast link earns less rewind than the cap (%d ticks)" % on_a_fast_link)
	check(rw.allowed_rewind(1000, 1000, 0.075, 0.075) == 0,
		"a request with no lag rewinds nothing")
	check(rw.allowed_rewind(1000, 1200, 0.075, 0.075) == 0,
		"a view tick from the future rewinds nothing")

## The link the network tests are built on has to actually delay and drop
## things, or every test above it passes for the wrong reason.
func _test_loopback_link() -> void:
	_current = "loopback transport"
	var pair := LoopbackTransport.pair(0.075)
	var a: LoopbackTransport = pair[0]
	var b: LoopbackTransport = pair[1]
	a.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		PackedByteArray([1, 2, 3]))
	b.advance(0.05)
	check(b.poll().is_empty(), "nothing arrives before the latency has elapsed")
	b.advance(0.03)
	var got := b.poll()
	check(got.size() == 1, "the packet arrives once the latency has elapsed")
	check(PackedByteArray(got[0]["payload"]) == PackedByteArray([1, 2, 3]),
		"the payload survives the trip")

	# Loss applies to unreliable traffic only: a snapshot may vanish, a placement
	# command may not.
	var lossy := LoopbackTransport.pair(0.0, 1.0)
	var c: LoopbackTransport = lossy[0]
	var d: LoopbackTransport = lossy[1]
	for i in range(20):
		c.send(NetTransport.Channel.SNAPSHOT, NetTransport.Reliability.UNRELIABLE,
			PackedByteArray([0]))
		c.send(NetTransport.Channel.COMMAND, NetTransport.Reliability.RELIABLE_ORDERED,
			PackedByteArray([1]))
	d.advance(0.01)
	var arrived := d.poll()
	check(arrived.size() == 20, "total loss drops every unreliable packet and no reliable one")
	for p in arrived:
		check(int(p["channel"]) == NetTransport.Channel.COMMAND,
			"only the reliable channel survived")
	a.close(); b.close(); c.close(); d.close()

## The bandwidth argument in docs/netcode.md only holds if a snapshot really is
## the size claimed there. This measures it instead of trusting the arithmetic,
## and checks that the quantisation survives a round trip closely enough that
## interpolation hides it.
func _test_bandwidth_budget() -> void:
	_current = "bandwidth"
	var quiet := Snapshot.quiet_size()
	check(quiet <= 14, "a steady-state snapshot fits the budget (%d bytes)" % quiet)
	print("  snapshot: %d B quiet, %.1f KB/s at 30Hz" % [quiet, quiet * 30.0 / 1024.0])

	var s := Snapshot.new()
	s.tick = 40000
	s.runner_position = Vector2(16480.0, -104.0)
	s.runner_velocity = Vector2(-372.5, 1100.0)
	s.runner_state = 3
	s.facing = -1
	s.on_floor = true
	s.invulnerable = true
	s.hp = 2
	s.gauge = 73.0
	s.movement_flags = 13
	var wire := s.encode()
	var back := Snapshot.decode(wire)

	check(back.movement_flags == s.movement_flags, "stance and special actions survive the wire")
	check(back.tick == s.tick, "the tick survives the wire")
	check(back.runner_position.distance_to(s.runner_position) < 0.3,
		"position round-trips within a third of a pixel (%.3f)"
			% back.runner_position.distance_to(s.runner_position))
	check(back.runner_velocity.distance_to(s.runner_velocity) < 0.5,
		"velocity round-trips closely enough for interpolation (%.3f)"
			% back.runner_velocity.distance_to(s.runner_velocity))
	check(back.runner_state == s.runner_state and back.facing == s.facing
			and back.on_floor and back.invulnerable and back.hp == 2,
		"the packed flag byte survives the wire")
	check(absf(back.gauge - s.gauge) <= 1.0, "the gauge survives the wire")

	# The far end of the stage has to fit too: the quantisation is only valid if
	# the whole level stays inside a signed 16-bit field.
	for x in [-1600.0, 0.0, 8000.0, 16700.0]:
		for y in [-104.0, 300.0, 1020.0]:
			var probe := Snapshot.new()
			probe.runner_position = Vector2(x, y)
			var rt := Snapshot.decode(probe.encode())
			check(absf(rt.runner_position.x - x) <= 0.25 and absf(rt.runner_position.y - y) <= 0.07,
				"(%.0f, %.0f) survives quantisation" % [x, y])

	# Out of range must clamp to the edge, never wrap: a wrapped coordinate puts
	# an entity on the opposite side of the stage, which reads as a teleport bug.
	var far := Snapshot.new()
	far.runner_position = Vector2(99999.0, 99999.0)
	var clamped := Snapshot.decode(far.encode())
	check(clamped.runner_position.x > 16700.0 and clamped.runner_position.y > 1020.0,
		"an out-of-range position clamps past the stage rather than wrapping")

	# Divergent enemies are the only thing that grows a snapshot, and even a
	# full screen of them has to stay inside one EOS packet.
	var busy := Snapshot.new()
	for i in range(20):
		busy.dirty_enemies.append({"id": i, "x": 1000.0 + i * 40.0, "y": 300.0, "hp": 1})
	var busy_size := busy.encode().size()
	check(busy_size < NetTransport.MAX_PACKET_BYTES,
		"even 20 divergent enemies fit one packet (%d of %d bytes)"
			% [busy_size, NetTransport.MAX_PACKET_BYTES])

## The whole chain, over a link with 150ms of latency in it: the guardian taps,
## the command is encoded, crosses the wire, the host validates it against the
## gauge, backdates it to the tick the guardian was actually looking at, spawns
## the construct, and reports it back. And the runner, who had already fallen
## past where the platform went, ends up standing on it.
##
## Driven from the far end of a LoopbackTransport rather than by standing up a
## second world, because the autoloads (Clock, Events, GameState) are singletons
## and two worlds in one process would share them.
func _test_host_answers_the_guardian() -> void:
	_current = "host answers the guardian"
	await _boot()
	var pair := LoopbackTransport.pair(0.075)      # 75ms each way = 150ms RTT
	var host_side: LoopbackTransport = pair[0]
	var guardian_side: LoopbackTransport = pair[1]

	var session := HostSession.new()
	session.main = main
	session.transport = host_side
	add_child(session)
	await _frames(2)
	session.authority.measured_one_way = 0.075
	session.authority.client_interp_buffer = 0.075

	var r: Runner = main.runner
	main.guardian.gauge = Balance.GAUGE_MAX
	r.global_position = Vector2(2100, 120)
	r.velocity = Vector2.ZERO
	main.input_hub.move_axis = 0.0
	await _pump(pair, 1)

	# What the guardian could see, and the tick they saw it at.
	var view_tick := Clock.tick
	var seen := r.global_position
	await _pump(pair, 9)
	var fallen := r.global_position
	check(fallen.y > seen.y + 20.0, "the runner fell while the command was in flight")

	var target := seen + Vector2(0, Balance.RUNNER_SIZE.y * 0.5 + Balance.PLATFORM_SIZE.y * 0.5)
	guardian_side.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.place(1, target, view_tick, 7))
	await _pump(pair, 12)

	var made: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
	check(made.size() == 1, "the host built the construct the guardian asked for")
	check(r.global_position.y < fallen.y,
		"the runner ends up above where they had fallen to (%.0f -> %.0f)"
			% [fallen.y, r.global_position.y])
	check(main.guardian.gauge < Balance.GAUGE_MAX,
		"the host charged the gauge rather than trusting the client")

	# And the answer came back, backdated, tagged with the sequence the client
	# used so it can retire the right ghost.
	var confirmed := false
	for packet in guardian_side.poll():
		# Filter by channel, not by the first byte. Snapshots share the link and
		# a snapshot whose leading tick byte happens to equal a message id will
		# decode as garbage -- which is exactly what this loop did at first.
		if int(packet["channel"]) != NetTransport.Channel.EVENT:
			continue
		var parsed := Protocol.reader(packet["payload"])
		if int(parsed[0]) != Protocol.Msg.HOLO_SPAWN:
			continue
		var b: StreamPeerBuffer = parsed[1]
		b.get_u16(); b.get_u8(); Protocol.get_pos(b)
		var birth := int(b.get_u32())
		var death := int(b.get_u32())
		check(int(b.get_u16()) == 7, "the confirmation carries the client's sequence")
		check(birth < Clock.tick, "the construct is stamped in the past")
		check(death - birth <= Clock.ticks_for(Balance.PLATFORM_LIFETIME),
			"backdating shortens the life rather than shifting it")
		confirmed = true
	check(confirmed, "a spawn confirmation reached the guardian")

	# A mismatched build must be told so. The two players will be on different
	# platforms and will update at different times, and a silent version skew
	# fails in ways that look like a broken connection.
	var stale := PackedByteArray([Protocol.Msg.HELLO, Protocol.VERSION + 1])
	guardian_side.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED, stale)
	# 16 frames, not 8. The link is 75ms each way and a frame is 16.7ms, so 8
	# frames is 133ms -- less than one round trip, and the reply had not arrived
	# yet when the check ran.
	await _pump(pair, 16)
	var refused := false
	var welcomed := false
	for packet in guardian_side.poll():
		if int(packet["channel"]) != NetTransport.Channel.EVENT:
			continue
		var kind := int(Protocol.reader(packet["payload"])[0])
		if kind == Protocol.Msg.NOTICE:
			refused = true
		if kind == Protocol.Msg.WELCOME:
			welcomed = true
	check(refused, "a mismatched protocol version is told so")
	check(not welcomed, "and is not welcomed in anyway")

	# A replayed packet must not build a second one.
	guardian_side.send(NetTransport.Channel.COMMAND,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.place(1, target, view_tick, 7))
	await _pump(pair, 8)
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() == 1,
		"a duplicate command is ignored rather than acted on twice")
	session.queue_free()

## The other half: a client fed real snapshots puts the runner where the host
## said, and turns a spawn message into an actual construct.
func _test_client_shows_the_host() -> void:
	_current = "client shows the host"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]

	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	check(not main.runner.is_physics_processing(),
		"the client stops simulating the runner it does not own")

	# Two snapshots a few ticks apart, straddling the render point.
	var base := Clock.tick - 6
	for i in range(2):
		var s := Snapshot.new()
		s.tick = base + i * 4
		s.runner_position = Vector2(5000.0 + float(i) * 80.0, 200.0)
		s.runner_velocity = Vector2(480.0, 0.0)
		s.hp = 3
		s.gauge = 55.0
		host_side.send(NetTransport.Channel.SNAPSHOT,
			NetTransport.Reliability.UNRELIABLE, s.encode())
	await _pump(pair, 4)

	var x: float = main.runner.global_position.x
	check(x >= 4999.0 and x <= 5081.0,
		"the runner is placed between the two snapshots (%.0f)" % x)
	check(absf(main.runner.global_position.y - 200.0) < 1.0,
		"and at the height the host reported")

	# Hermite has to actually curve. With equal endpoints and opposing tangents
	# a linear blend would sit still; this must not.
	var bowed := ClientSession._hermite(Vector2.ZERO, Vector2(0, -600),
		Vector2(100, 0), Vector2(0, 600), 0.5, 0.25)
	check(bowed.y < -1.0, "the arc bows instead of cutting the corner (%.1f)" % bowed.y)

	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.holo_spawn(42, int(Hologram.Kind.PLATFORM), Vector2(5200, 260),
			Clock.tick, Clock.tick + 120, 3))
	await _pump(pair, 3)
	var here: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
	check(here.size() == 1, "a spawn message becomes a real construct on the client")
	if here.size() == 1:
		check(here[0].net_id == 42, "carrying the id the host assigned")
		check(here[0].death_tick == Clock.tick + 120 or here[0].death_tick > Clock.tick,
			"and the host's expiry rather than a fresh one")
	session.queue_free()
	Clock.is_host = true

## Runs frames while moving packets along the simulated link.
func _pump(pair: Array, frames: int) -> void:
	for i in range(frames):
		for t in pair:
			(t as LoopbackTransport).advance(Clock.DT)
		await get_tree().physics_frame
		await get_tree().process_frame

## The half of the connect-screen bug that headless can see.
##
## Every button on it was dead on Android because a Control receives the mouse
## event Godot emulates from a touch, never the touch itself, and emulation was
## off. Whether a press actually lands cannot be checked here -- headless has no
## GUI picking, and even a synthetic mouse click does nothing -- so that half
## lives in test/ui_probe.tscn under xvfb. What is checkable here is the setting
## that was wrong and the input hand-off around it.
func _test_connect_screen_responds_to_touch() -> void:
	_current = "connect screen"
	await _boot(false)
	check(Input.is_emulating_mouse_from_touch(),
		"touch is emulated as mouse, or no button can ever be pressed")

	var panel: Node = main.get_node_or_null("NetPanel")
	check(panel != null, "the connect screen is shown at startup")
	if panel == null:
		return
	check(_find_button(panel, "1台") != null, "the local-play button exists")
	check(_find_button(panel, "部屋を作る") != null, "the internet host button exists")
	check(not main.input_hub.is_processing_unhandled_input(),
		"the game's input router stands down while the panel is up")

	panel.free()
	await _frames(2)
	check(main.input_hub.is_processing_unhandled_input(),
		"and gets its input back when the panel goes")

func _find_button(root: Node, contains: String) -> Button:
	if root is Button and String((root as Button).text).contains(contains):
		return root
	for child in root.get_children():
		var found := _find_button(child, contains)
		if found != null:
			return found
	return null

# ----------------------------------------------------------------- guardian

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
	# than half-applied.
	g.gauge = Balance.GAUGE_MAX
	g.select_slot(1)
	g.use_active(Vector2(600, 250))
	check_near(g.gauge, Balance.GAUGE_MAX - Balance.COST_PLATFORM, 1.0,
		"platform deducts its cost")

	var refusals: Array[String] = []
	var handler := func(_slot: int, reason: String) -> void: refusals.append(reason)
	Events.ability_refused.connect(handler)
	g.gauge = Balance.COST_PLATFORM - 1.0
	var alive_before: int = g.holograms_of(Hologram.Kind.PLATFORM).size()
	g.use_active(Vector2(800, 250))
	check(refusals.has("gauge"), "refuses when the gauge is short")
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == alive_before,
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

	# ...and the same for the wall, from a standing start, without selecting it.
	#
	# Somewhere else on purpose. This used to aim at the same point as the
	# platform above and pass anyway, because the reticle was stored as a SCREEN
	# point and the camera scrolled it off the platform between the two taps --
	# a test that only passed because of the bug it should have caught.
	var wall_at: Vector2 = main.runner.global_position + Vector2(-300, -120)
	hub.aim_at_world(wall_at)
	g.gauge = Balance.GAUGE_MAX
	var walls: int = g.holograms_of(Hologram.Kind.WALL).size()
	hub._touch_down(4, _place("slot_2", view, "shared"))
	hub._touch_move(4, main.get_viewport().get_canvas_transform() * wall_at)
	var wall_ghost: Vector2 = hub.aim_world()
	hub._touch_up(4)
	await _frames(3)
	var made: Array = g.holograms_of(Hologram.Kind.WALL)
	check(made.size() == walls + 1, "one drag from the wall button builds a wall")
	if made.size() > walls:
		check(made.back().global_position.distance_to(wall_ghost) < 2.0,
			"at the place the ghost was showing (%.0fpx)"
				% made.back().global_position.distance_to(wall_ghost))

	# The scope is its own button and a state, not a tool.
	check(not g.scope_active, "the scope is down to begin with")
	hub._touch_down(5, _place("scope", view, "shared"))
	hub._touch_up(5)
	await _frames(3)
	check(g.scope_active, "its button raises it")
	check(g.active_slot == 2, "without touching which tool is selected")

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

	hub._touch_down(6, _place("scope", view, "shared"))
	hub._touch_up(6)
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
	check(SniperAbility.ammo_for(Balance.COST_SNIPE * 2.0) == 2, "two shots' worth reads as 2")
	check(SniperAbility.ammo_for(Balance.COST_SNIPE - 1.0) == 0, "under one shot reads as 0")

	g.gauge = Balance.GAUGE_MAX
	g.select_slot(3)
	g.use_active(Vector2(500, 300))
	check_near(g.gauge, Balance.GAUGE_MAX - Balance.COST_SNIPE, 1.0, "a shot costs the gauge")
	check(sniper.cooldown > 0.0, "firing starts the cooldown")
	check(sniper.check(g, Vector2(500, 300)) == "cooldown", "no rapid fire")

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

# ------------------------------------------------------------------- runner

## Setting off, stopping, turning round, and steering in mid-air are four
## different acts, and each one is checked here against its own dial.
##
## They used to share a single acceleration. That is what makes this worth a
## test rather than a comment: with one number, making the turn-around crisp
## necessarily made a mid-air reversal instant, and a run-up stopped deciding
## anything. Nothing about the code said so.
func _test_four_ways_to_change_direction() -> void:
	_current = "four ways to change direction"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0

	var settle := func() -> void:
		r.global_position = Vector2(-400, 300)
		r.velocity = Vector2.ZERO
		hub.move_axis = 0.0
		hub.dash_held = false
		# Teleporting preserves the previous move_and_slide floor result.
		# physics_frame fires before body callbacks; allow a complete body
		# update before testing contact at the new position.
		await _physics(2)
		for _i in range(40):
			await get_tree().physics_frame
			if r.is_on_floor():
				break

	# 1. Setting off: from a standing start to full speed.
	await settle.call()
	hub.move_axis = 1.0
	var took := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		took += Clock.DT
		if absf(r.velocity.x) >= Balance.RUNNER_RUN_SPEED - 2.0:
			break
	check_range(took, 0.12, 0.20,
		"setting off reaches full speed in 0.12-0.20s (%.3fs)" % took)

	# 2. Stopping: letting go, at full speed, on the ground.
	hub.move_axis = 0.0
	var stopped := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		stopped += Clock.DT
		if absf(r.velocity.x) < 2.0:
			break
	check_range(stopped, 0.08, 0.15,
		"and stopping takes 0.08-0.15s (%.3fs)" % stopped)

	# 3. Turning: pressing the other way, at full speed. Has to be quicker than
	# letting go and setting off again, or a turn feels like ice.
	await settle.call()
	hub.move_axis = 1.0
	for _i in range(30):
		await get_tree().physics_frame
		if absf(r.velocity.x) >= Balance.RUNNER_RUN_SPEED - 2.0:
			break
	hub.move_axis = -1.0
	var turned := 0.0
	for _i in range(60):
		await get_tree().physics_frame
		turned += Clock.DT
		if r.velocity.x <= 0.0:
			break
	check(turned < stopped,
		"turning kills the old direction faster than letting go does (%.3fs vs %.3fs)"
			% [turned, stopped])
	check(turned < 0.12, "and quickly enough to feel like one movement (%.3fs)" % turned)

	# 4. Opposite input must reverse before landing, not merely slow the jump.
	await settle.call()
	hub.move_axis = 1.0
	hub.dash_held = true
	await _physics(40)
	var launch_speed: float = absf(r.velocity.x)
	check(launch_speed > Balance.RUNNER_RUN_SPEED,
		"a sprint is carrying more than walking speed (%.0f)" % launch_speed)
	hub.press_jump()
	hub.jump_held = true
	await _physics(4)
	hub.dash_held = false
	hub.move_axis = -1.0
	var reversed_after := -1.0
	var air_time := 0.0
	for _i in range(120):
		await get_tree().physics_frame
		air_time += Clock.DT
		if reversed_after < 0.0 and r.velocity.x < 0.0:
			reversed_after = air_time
		if r.is_on_floor():
			break
	hub.jump_held = false
	hub.move_axis = 0.0
	check(reversed_after > 0.0 and reversed_after <= 0.20,
		"opposite input reverses sprint momentum within 0.20s (%.3fs)" % reversed_after)

	# The ceiling. A head on it must end the rise there -- no clinging to it
	# while the button is still down, nothing added sideways.
	#
	# This is provided by move_and_slide's own collision response rather than by
	# anything in Runner: an explicit "zero the rise at a ceiling" block was
	# written here and turned out to change nothing, so it was deleted. The
	# checks stay, because the property is one the game depends on and the day
	# it stops being free is the day this needs to notice.
	await settle.call()
	var roof := StaticBody2D.new()
	roof.collision_layer = 1
	roof.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(400.0, 40.0)
	shape.shape = box
	roof.add_child(shape)
	# A block above the runner's head, well inside the jump's reach.
	roof.global_position = r.global_position + Vector2(0.0, -140.0)
	main.add_child(roof)
	await _physics(2)

	hub.move_axis = 0.0
	hub.press_jump()
	hub.jump_held = true
	var bonked := false
	var sideways := 0.0
	var stuck := 0
	for _i in range(70):
		await get_tree().physics_frame
		if r.is_on_ceiling():
			bonked = true
			sideways = maxf(sideways, absf(r.velocity.x))
			if r.velocity.y < -1.0:
				stuck += 1
		if bonked and r.is_on_floor():
			break
	hub.jump_held = false
	check(bonked, "the runner's head reaches the ceiling")
	check(stuck == 0,
		"and the rise stops there rather than pushing into it (%d frames of climb)"
			% stuck)
	check(sideways < 20.0,
		"without being thrown sideways (%.0fpx/s)" % sideways)
	check(r.is_on_floor(), "and they come back down")
	roof.queue_free()
	await _physics(2)

func _test_runner_arc() -> void:
	# The level's gaps are sized against these two numbers, so if the jump ever
	# drifts the stage silently becomes unfair. This is the guard on that.
	_current = "jump arc"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	# Well left of the spawn: flat, and clear of the pipe and block row, which
	# are solid now and would otherwise be measured instead of the jump.
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	await _physics(30)
	check(r.is_on_floor(), "the runner settles on the ground")

	var start := r.global_position
	var apex := start.y
	var rose_for := 0.0
	var time_to_apex := 0.0
	hub.move_axis = 1.0
	hub.press_jump()
	for i in range(90):
		await get_tree().physics_frame
		rose_for += Clock.DT
		if r.global_position.y < apex:
			apex = r.global_position.y
			time_to_apex = rose_for
		if i > 4 and r.is_on_floor():
			break
	var height := start.y - apex
	var reach := r.global_position.x - start.x
	hub.move_axis = 0.0
	hub.release_jump()

	# The DESIGN is a height and a duration -- see the block at the top of
	# balance.gd -- so this checks a height and a duration. It used to check a
	# band of pixels somebody had written down after a previous tuning pass,
	# which is a record of what the jump was, not of what it is meant to be.
	check_range(height / Balance.B, 3.0, 3.5,
		"a held jump goes 3 to 3.5 blocks up (%.2fB)" % (height / Balance.B))
	# The band the apex easing actually produces. RUNNER_TIME_TO_APEX is still
	# 0.33 and is not what moved; the easing near the top is the difference,
	# and a test still asking for the pre-easing number would be asking for the
	# gravity to be put back.
	check_range(time_to_apex, 0.34, 0.39,
		"and gets there in 0.34-0.39s (%.3fs)" % time_to_apex)
	check(absf(height - Balance.RUNNER_JUMP_HEIGHT) < Balance.B * 0.35,
		"which is the height the dial asks for (%.0f asked, %.0f measured)"
			% [Balance.RUNNER_JUMP_HEIGHT, height])
	# Every gap in the stage is sized against this figure.
	check(reach < 380.0, "a plain jump cannot clear a platform-width gap")

	# A tap has to be a real jump. The cut used to compound every frame the
	# button was up, so a 40ms press -- what a thumb actually does -- produced a
	# 31px hop against a 46px-tall runner. Now the opening window cannot be cut.
	await _physics(30)
	r.global_position = Vector2(-1000, 300)
	r.velocity = Vector2.ZERO
	hub.move_axis = 0.0
	await _physics(30)
	var floor_y := r.global_position.y
	var tap_apex := floor_y
	hub.press_jump()
	await _physics(3)          # ~50ms, then let go
	hub.release_jump()
	for i in range(90):
		await get_tree().physics_frame
		tap_apex = minf(tap_apex, r.global_position.y)
		if i > 4 and r.is_on_floor():
			break
	var tap_height := floor_y - tap_apex
	check(tap_height > Balance.RUNNER_SIZE.y * 1.5,
		"a 50ms tap clears more than the runner's own height (%.0fpx)" % tap_height)
	# The point of a variable jump is that the thumb picks the height. Too close
	# to the held one and there is no choice being made: at one tuning the two
	# came out 79% alike, because the uncuttable opening window covered half the
	# rise.
	check_range(tap_height / height, 0.45, 0.60,
		"and is 45-60%% of a held one, so the press chooses the height (%d%%)"
			% int(100.0 * tap_height / height))
	# Printed because these two numbers are quoted in the docs, and a doc that
	# quotes a number nothing measures goes stale without anyone noticing.
	print("  jump apex: 50ms tap %.0fpx, held %.0fpx (runner is %.0fpx tall), reach %.0fpx"
		% [tap_height, height, Balance.RUNNER_SIZE.y, reach])

	# The stage audit needs the sprinting arcs too, and it needs them measured.
	var sprint_arc := await _measure_arc(true, false)
	var repeat_arc := await _measure_arc(true, true)
	_reach = {
		"plain": reach,
		"apex": height,
		"sprint": sprint_arc["reach"],
		"unaided": maxf(sprint_arc["reach"], repeat_arc["reach"]),
	}
	check(float(_reach["sprint"]) > reach,
		"sprinting jumps further than walking (%.0f vs %.0f)" % [_reach["sprint"], reach])
	print("  jump reach: walk %.0fpx, sprint %.0fpx, sprint re-pressed in air %.0fpx"
		% [reach, sprint_arc["reach"], repeat_arc["reach"]])

## One jump from a standing start on the opening plateau, run to landing.
## Returns how far it travelled and how high it got.
func _measure_arc(sprint: bool, repress_sprint: bool) -> Dictionary:
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	hub.release_jump()
	hub.dash_held = false
	hub.move_axis = 0.0
	r.global_position = Vector2(-1450, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)
	# Let it get up to speed first: these are running jumps, which is how the
	# stage's gaps are meant to be taken.
	hub.move_axis = 1.0
	hub.dash_held = sprint
	await _physics(70)
	var start := r.global_position
	var apex := start.y
	hub.press_jump()
	var dashed := false
	for i in range(120):
		await get_tree().physics_frame
		apex = minf(apex, r.global_position.y)
		# Re-pressing sprint at the apex must not replace the jump with a burst.
		if repress_sprint and not dashed and not r.is_on_floor() and r.velocity.y >= 0.0:
			hub.press_dash()
			dashed = true
		if i > 4 and r.is_on_floor():
			break
	var out := {"reach": r.global_position.x - start.x, "apex": start.y - apex}
	hub.release_jump()
	hub.dash_held = false
	hub.move_axis = 0.0
	await _physics(20)
	return out

func _test_dash() -> void:
	_current = "sprint"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	# Far left of the start plateau: a held sprint covers well over a thousand
	# pixels during this test, and from nearer the middle it runs off the edge.
	r.global_position = Vector2(-1450, 300)
	r.velocity = Vector2.ZERO
	await _physics(30)

	# Walking speed first, so the sprint has something to be measured against.
	hub.move_axis = 1.0
	hub.dash_held = false
	await _physics(40)
	var walk := absf(r.velocity.x)
	check_near(walk, Balance.RUNNER_RUN_SPEED, 40.0, "walking tops out at the run speed")

	# Sprint is a held modifier: it must keep going for as long as it is held,
	# with no cooldown and no time limit. The old burst dash lasted 0.16s, so a
	# long hold is the thing worth checking.
	hub.dash_held = true
	await _physics(50)
	var sprint := absf(r.velocity.x)
	var expected := Balance.RUNNER_RUN_SPEED * Balance.RUNNER_SPRINT_MULTIPLIER
	check_near(sprint, expected, 45.0, "sprint reaches the multiplied speed")
	await _physics(90)
	check_near(absf(r.velocity.x), expected, 45.0, "sprint does not expire while held")
	check(r.is_on_floor(), "still grounded, so this is the sustained sprint path")

	# Releasing eases back to the walk rather than snapping.
	hub.dash_held = false
	await _physics(60)
	check_near(absf(r.velocity.x), Balance.RUNNER_RUN_SPEED, 40.0, "releasing returns to walk")
	hub.move_axis = 0.0

	# Re-pressing sprint in the air accelerates horizontally without stopping Y.
	await _wait(0.3)
	r.global_position = Vector2(-400, 60)
	r.velocity = Vector2(0.0, 100.0)
	hub.move_axis = 1.0
	await _physics(2)
	check(not r.is_on_floor(), "airborne for the sprint check")
	hub.press_dash()
	await _physics(2)
	check(r.state != Runner.State.DASH, "airborne sprint is not a burst state")
	check(r.velocity.y > 100.0, "sprint never zeros the fall")

	# Holding sprint on the ground is the same sustained modifier.
	hub.dash_held = true
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	await _physics(40)
	check(r.state != Runner.State.DASH, "a held sprint on the ground is not a dash state")
	hub.dash_held = false
	hub.move_axis = 0.0

func _test_stomp_and_damage() -> void:
	_current = "contact"
	await _boot()
	var r: Runner = main.runner
	check(r.hp == Balance.RUNNER_MAX_HP, "the runner starts at full health")

	# Landing on a walker is not an attack. Every enemy contact is a hit, from
	# directly above as much as from the side -- see Runner._resolve_hazard. The
	# rifle is what kills things, and a runner who can clear a patrol by falling
	# on it does not need to ask anybody for one.
	var walker := Walker.new()
	walker.global_position = Vector2(-400, 300)
	main.add_child(walker)
	await _physics(20)
	r.global_position = walker.global_position + Vector2(0, -46)
	r.velocity = Vector2(0, 260)
	await _physics(20)
	check(is_instance_valid(walker), "landing on a walker does not kill it")
	check(r.hp == Balance.RUNNER_MAX_HP - 1, "and costs the runner health")
	check(r.is_invulnerable(), "so it reads as a hit, with the usual mercy window")
	walker.queue_free()

	# A flyer is not stompable either, and never was: chapter 2 keeps one threat
	# the runner cannot answer alone, and this is it.
	var flyer := Flyer.new()
	check(not flyer.is_in_group("stompable"), "the flyer is not stompable")
	flyer.free()

	# Damage and the mercy window on their own. The contact above leaves the
	# runner invulnerable for RUNNER_HURT_INVULN, so this waits that out rather
	# than measuring it through the tail of the hit before it.
	await _wait(Balance.RUNNER_HURT_INVULN + 0.1)
	r.hp = Balance.RUNNER_MAX_HP
	var before := r.hp
	r.take_damage(1)
	check(r.hp == before - 1, "damage lands")
	r.take_damage(1)
	check(r.hp == before - 1, "invulnerability absorbs the follow-up")

func _test_checkpoint_respawn() -> void:
	_current = "checkpoint"
	await _boot()
	var r: Runner = main.runner
	var points := Level01Data.checkpoints()
	check(points.size() >= 5, "the stage has at least five checkpoints")

	GameState.checkpoint_index = 2
	GameState.checkpoint_position = points[1]
	r.hp = 1
	r.die("test")
	await _frames(2)
	check(r.state == Runner.State.DEAD, "death is registered")

	# Retry must be quick -- chapter 3 asks for under three seconds.
	check(Balance.RESPAWN_DELAY < 3.0, "respawn delay is inside the design budget")
	await _wait(Balance.RESPAWN_DELAY + 0.25)
	check(r.hp == Balance.RUNNER_MAX_HP, "respawn restores health")
	check(r.global_position.distance_to(points[1]) < 60.0, "respawn lands at the checkpoint")
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).is_empty(),
		"constructs do not survive a reset")

# ------------------------------------------------------- stage design audits

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

## The virtual stick has to respond to a press, not only to a drag.
##
## It originally anchored wherever the thumb landed and derived the axis from the
## drag away from that point, so pressing and holding produced nothing: on a
## phone the runner moved only while the thumb was sliding and then stopped dead.
## These call the touch handlers directly, which is the only way to exercise the
## routing without a device.
func _test_virtual_stick() -> void:
	_current = "virtual stick"
	await _boot()
	var previous_touch_options := Options._cache.duplicate()
	Options._cache["responsive_touch"] = false
	Options._cache["stick_jump"] = true
	var hub: InputHub = main.input_hub
	hub.scripted = false
	var view := Vector2(main.get_viewport().get_visible_rect().size)
	var stick: Dictionary = ControlLayout.layout("shared", view, false)["stick"]
	var anchor: Vector2 = stick["center"]
	var travel: float = ControlLayout.stick_travel(stick)

	# A press to the right of the anchor moves right, with no drag at all.
	hub._touch_down(0, anchor + Vector2(travel, 0.0))
	check(hub.move_axis > 0.85, "press right of the anchor -> full right (%.2f)" % hub.move_axis)
	# Holding still must not decay: no further events arrive while a thumb rests.
	var held := hub.move_axis
	await _physics(20)
	check(is_equal_approx(hub.move_axis, held), "the axis survives a press-and-hold")
	hub._touch_up(0)
	check(is_zero_approx(hub.move_axis), "lifting off stops the runner")

	hub._touch_down(0, anchor - Vector2(travel, 0.0))
	check(hub.move_axis < -0.85, "press left of the anchor -> full left (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# Dead zone at the anchor itself, so a thumb resting dead centre is neutral.
	hub._touch_down(0, anchor)
	check(is_zero_approx(hub.move_axis), "the anchor itself is neutral")
	hub._touch_up(0)

	# Partial deflection is proportional rather than all-or-nothing.
	hub._touch_down(0, anchor + Vector2(travel * 0.5, 0.0))
	check(hub.move_axis > 0.25 and hub.move_axis < 0.8,
		"half deflection is partial speed (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# Pushing the stick up used to jump as well as steer, so that one thumb
	# could hold a direction and leave the ground. It cost more than it bought:
	# every steered jump became ambiguous, and a thumb aiming a diagonal got a
	# jump it had not asked for. Jump is the jump button's now -- Options
	# refuses to turn this back on -- so the stick steers however far up it goes.
	var jump_reach: float = travel * ControlLayout.STICK_JUMP_FRACTION
	check(not Options.stick_jump(), "the stick is not a jump source")
	Options.set_stick_jump(true)
	check(not Options.stick_jump(), "and cannot be talked into becoming one")
	hub._touch_down(0, anchor + Vector2(travel * 0.9, -jump_reach * 1.25))
	check(hub.move_axis > 0.6, "a diagonal still moves the runner (%.2f)" % hub.move_axis)
	check(not hub.jump_held, "pushing the stick right up does not hold jump")
	check(not hub.take_jump(), "and does not fire one either")
	hub._touch_move(0, anchor + Vector2(travel * 0.9, 0.0))
	check(hub.move_axis > 0.85, "and the runner keeps moving (%.2f)" % hub.move_axis)
	hub._touch_up(0)

	# The shallow diagonal gives the same answer, which is the point: there is
	# no height at which the stick stops being a stick.
	hub._touch_down(0, anchor + Vector2(travel * 0.9, -jump_reach * 0.5))
	check(not hub.jump_held, "a shallow diagonal does not jump")
	hub._touch_up(0)

	# And a press really does drive the runner, not just the input field.
	var r: Runner = main.runner
	r.global_position = Vector2(-400, 300)
	r.velocity = Vector2.ZERO
	await _physics(24)
	var start := r.global_position.x
	hub._touch_down(0, anchor + Vector2(travel, 0.0))
	await _physics(30)
	hub._touch_up(0)
	check(r.global_position.x - start > 60.0,
		"holding the stick actually moves the runner (%.0fpx)" % (r.global_position.x - start))
	hub.scripted = true
	Options._cache = previous_touch_options

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

## Two hits and the run is over.
##
## The number itself is one line of balance, but it only means anything if the
## hit actually lands both times and the second one ends the run -- and the
## invulnerability window after the first is exactly the thing that can quietly
## swallow the second. So this drives real damage through the runner rather
## than asserting the constant.
func _test_two_hits_end_the_run() -> void:
	_current = "two hits"
	await _boot()
	var r: Runner = main.runner
	check(Balance.RUNNER_MAX_HP == 2, "the runner has two hits in them")

	r.global_position = Vector2(2600, 300)
	await _frames(3)
	var died := [0]
	var watch := func(_cause: String) -> void: died[0] += 1
	Events.runner_died.connect(watch)

	r.take_damage(1)
	check(r.hp == 1, "the first hit leaves one (%d)" % r.hp)
	check(died[0] == 0, "and does not end the run")
	check(r.is_invulnerable(), "it opens the mercy window")

	# Inside the window a second hit must NOT count -- otherwise a turret burst
	# kills on the frame it touches and the window may as well not exist.
	r.take_damage(1)
	check(r.hp == 1, "a hit inside the mercy window is ignored (%d)" % r.hp)

	await _wait(Balance.RUNNER_HURT_INVULN + 0.1)
	check(not r.is_invulnerable(), "the window closes")
	r.take_damage(1)
	check(r.hp == 0, "the second real hit takes the last of it")
	check(died[0] == 1, "and ends the run")
	check(r.state == Runner.State.DEAD, "the runner is dead, not merely hurt")

	# The plate has to be up while the retry is waiting, and gone after it.
	check(main.hud.game_over() > 0.0, "GAME OVER is on screen")
	check(Balance.RESPAWN_DELAY < 3.0,
		"and the retry still lands inside the three-second budget (%.2fs)"
			% Balance.RESPAWN_DELAY)
	await _wait(Balance.RESPAWN_DELAY + 0.35)
	check(main.hud.game_over() <= 0.0, "the plate lifts when the retry begins")
	check(r.hp == Balance.RUNNER_MAX_HP,
		"and the runner comes back with both hits again (%d)" % r.hp)
	Events.runner_died.disconnect(watch)

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

## The client has to show a warp as an arrival, not as a 500px slide. It has no
## packet telling it one happened: it infers it from a jump no legal movement
## could produce, which is the same "derive it locally, send nothing" rule the
## moving platforms and lasers follow.
func _test_warp_over_the_wire() -> void:
	_current = "warp over the wire"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	# Pin the clock. _boot() resets it to zero, so "six ticks ago" is a negative
	# tick that the u16 on the wire turns into 65530 -- and which of the two
	# snapshots then looks older depends on how many frames the previous test
	# happened to burn. The client stops advancing the tick itself the moment it
	# is a client, so setting it here makes the whole exchange deterministic.
	Clock.tick = 400

	var warped := [false]
	var seen := func(_from: Vector2, _to: Vector2) -> void: warped[0] = true
	Events.runner_warped.connect(seen)

	var base := Clock.tick - 6
	var far := Vector2(9000.0, 200.0)
	for i in range(2):
		var s := Snapshot.new()
		s.tick = base + i * 4
		s.runner_position = Vector2(3000.0, 200.0) if i == 0 else far
		s.runner_velocity = Vector2(200.0, 0.0)
		s.hp = 3
		s.gauge = 55.0
		host_side.send(NetTransport.Channel.SNAPSHOT,
			NetTransport.Reliability.UNRELIABLE, s.encode())
	await _pump(pair, 4)

	check(main.runner.global_position.distance_to(far) < 2.0,
		"a jump no runner could make is snapped to, not interpolated across (%s)"
			% main.runner.global_position)
	check(warped[0], "and the arrival is announced locally, so both gates flash")
	Events.runner_warped.disconnect(seen)

	# A gate placed by the host arrives as an ordinary construct message: the
	# kind byte already carried three values, so the warp needed no new packet.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.holo_spawn(77, int(Hologram.Kind.WARP), Vector2(9100, 260),
			Clock.tick, Clock.tick + 300, 5))
	await _pump(pair, 3)
	var gates: Array = main.guardian.holograms_of(Hologram.Kind.WARP)
	check(gates.size() == 1, "a warp gate crosses the wire on the existing message")
	if gates.size() == 1:
		check(gates[0].net_id == 77, "with the id the host assigned")
	session.queue_free()
	Clock.is_host = true

## A dropped connection has to be survivable.
##
## On a phone this is not an edge case: the app goes into a pocket, Wi-Fi hands
## over to LTE, a call arrives. The game used to end the session on the first of
## those, which on a remote playtest means the playtest is over. Now the picture
## freezes, the client dials back, and the handshake replays everything it
## missed.
##
## The drop is simulated by cutting the packet flow, which is what a dropped
## link IS from the session's point of view -- silence for longer than the gap
## between two snapshots could ever be.
## Reconnect as many times as you like: the world has to come back the same.
##
## It did not. A reconnect replayed one spawn per live construct and this device
## had never thrown its own away, so every recovery doubled them -- and doubled
## again on the next one. Nothing in a stream of "this came into being" can
## remove a construct that expired while the link was down, move one the host
## rescued into a different place, or say that a launcher was fired in the gap.
##
## So the host sends its whole set and this device matches it exactly. Three
## recoveries here, with a wrong world set up before each one: too many, too
## few, in the wrong place, and a launcher whose state disagrees.
func _test_reconnecting_twice_changes_nothing() -> void:
	_current = "reconnect twice"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	Clock.tick = 1000

	var truth := [
		{"net_id": 4, "kind": int(Hologram.Kind.PLATFORM), "at": Vector2(2400, 300),
			"birth": 900, "death": 1500, "armed": false},
		{"net_id": 5, "kind": int(Hologram.Kind.PLATFORM), "at": Vector2(2900, 260),
			"birth": 950, "death": 1550, "armed": true},
		{"net_id": 6, "kind": int(Hologram.Kind.WALL), "at": Vector2(3300, 240),
			"birth": 980, "death": 1380, "armed": true},
	]

	for round_number in range(3):
		host_side.send(NetTransport.Channel.EVENT,
			NetTransport.Reliability.RELIABLE_ORDERED, Protocol.holo_list(truth))
		await _pump(pair, 4)

		var slabs: Array = main.guardian.holograms_of(Hologram.Kind.PLATFORM)
		var walls: Array = main.guardian.holograms_of(Hologram.Kind.WALL)
		check(slabs.size() == 2 and walls.size() == 1,
			"recovery %d leaves exactly the host's set (%d slabs, %d walls)"
				% [round_number + 1, slabs.size(), walls.size()])

		var by_id: Dictionary = {}
		for h in slabs + walls:
			by_id[h.net_id] = h
		var all_there := true
		var placed_right := true
		var lifetimes_right := true
		for row in truth:
			if not by_id.has(row["net_id"]):
				all_there = false
				continue
			var h: Hologram = by_id[row["net_id"]]
			if h.global_position.distance_to(row["at"]) > 1.0:
				placed_right = false
			if h.death_tick != row["death"] or h.birth_tick != row["birth"]:
				lifetimes_right = false
		check(all_there, "recovery %d has every one of them" % [round_number + 1])
		check(placed_right, "recovery %d puts each where the host has it" % [round_number + 1])
		check(lifetimes_right,
			"recovery %d keeps the remaining life the host says" % [round_number + 1])

		var spent: Hologram = by_id.get(4, null)
		var live: Hologram = by_id.get(5, null)
		check(spent != null and spent.trigger != null and not spent.trigger.armed,
			"recovery %d remembers the launcher that was already fired" % [round_number + 1])
		check(live != null and live.trigger != null and live.trigger.armed,
			"recovery %d leaves the unfired one armed" % [round_number + 1])

		# Now break it in a different way before the next recovery, so each
		# round is a real correction rather than a repeat of a world that
		# already matched.
		match round_number:
			0:
				# One too many, of a kind the host does not have.
				var extra := Hologram.create(Hologram.Kind.PLATFORM, Vector2(4000, 200))
				extra.net_id = 77
				main.guardian.spawn_hologram(extra)
			1:
				# One missing, one in the wrong place, one lying about its
				# launcher.
				if by_id.has(6):
					(by_id[6] as Hologram).expire()
				if by_id.has(5):
					(by_id[5] as Hologram).global_position = Vector2(1, 1)
				if by_id.has(4) and (by_id[4] as Hologram).trigger != null:
					(by_id[4] as Hologram).trigger.armed = true
		await _frames(2)

	session.queue_free()
	Clock.is_host = true
	await _frames(2)

func _test_a_dropped_link_comes_back() -> void:
	_current = "reconnect"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	Clock.tick = 600

	var banner := [""]
	var watch := func(text: String) -> void: banner[0] = text
	Events.link_state.connect(watch)

	# A construct placed while the link is up, so there is something to miss.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.holo_spawn(9, int(Hologram.Kind.PLATFORM), Vector2(3000, 260),
			Clock.tick, Clock.tick + 600, 0))
	await _pump(pair, 3)
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() == 1,
		"a construct arrives while the link is up")
	check(banner[0] == "", "and nothing is said about the link")

	# Now go quiet. Frames keep running; no packets move.
	await _wait(ClientSession.SILENCE_IS_A_DROP + 0.4)
	check(banner[0] != "", "silence longer than a snapshot gap is reported (%s)" % banner[0])
	check(session.is_processing(), "the session stays alive rather than ending")
	check(is_instance_valid(main.runner), "and so does the world")

	# The client keeps asking. Anything it sends now is a HELLO.
	await _wait(ClientSession.RETRY_EVERY + 0.3)
	var asked := false
	for p in host_side.poll():
		var parsed := Protocol.reader(p["payload"])
		if int(parsed[0]) == Protocol.Msg.HELLO:
			asked = true
	check(asked, "it keeps trying to say hello")

	# The host answers a repeat HELLO the same way it answers the first, which
	# is the whole recovery: welcome, then everything that was missed.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "host-test"))
	await _pump(pair, 3)
	# The link is back but the world has not been handed over yet, and the
	# banner has to say which of those two is true. A guardian told they are
	# connected, whose next placement is then refused, has been lied to.
	check(session.restoring(), "the link coming back is not the world coming back")
	check(banner[0] != "", "and the banner says so (%s)" % banner[0])
	var refused := [""]
	var no := func(_slot: int, reason: String) -> void: refused[0] = reason
	Events.ability_refused.connect(no)
	session.request_use(1, Vector2(3400, 200), -1)
	await _pump(pair, 2)
	Events.ability_refused.disconnect(no)
	check(refused[0] == "restoring", "building is held until the world is back")

	# The host's whole set, which is the recovery.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.holo_list([
			{"net_id": 9, "kind": int(Hologram.Kind.PLATFORM), "at": Vector2(3000, 260),
				"birth": Clock.tick, "death": Clock.tick + 600, "armed": true},
			{"net_id": 11, "kind": int(Hologram.Kind.WALL), "at": Vector2(3200, 240),
				"birth": Clock.tick, "death": Clock.tick + 400, "armed": true},
		]))
	await _pump(pair, 4)
	check(not session.restoring(), "the list is what ends the restore")
	check(banner[0] == "", "the banner clears when the world is back (%s)" % banner[0])
	check(main.guardian.holograms_of(Hologram.Kind.WALL).size() == 1,
		"and the client is caught up on what it missed")
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() == 1,
		"without a second copy of what it already had")

	Events.link_state.disconnect(watch)
	session.queue_free()
	Clock.is_host = true
	await _frames(2)
	await _test_the_host_replays_what_was_missed()

## The other half: the HOST has to answer a repeat hello with everything the
## returning client could not have worked out for itself.
##
## Driven through a real HostSession rather than by hand, because the hand-fed
## version of this passed with the replay deleted -- the test was replaying the
## constructs itself and proving only that the client could receive them.
func _test_the_host_replays_what_was_missed() -> void:
	_current = "resync"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var host_side: LoopbackTransport = pair[0]
	var guardian_side: LoopbackTransport = pair[1]
	var session := HostSession.new()
	session.main = main
	session.transport = host_side
	add_child(session)
	await _frames(2)

	# A world with something in it: a construct, and a gate already shot open.
	var g: Guardian = main.guardian
	g.gauge = Balance.GAUGE_MAX
	main.runner.global_position = Vector2(2600, 300)
	await _frames(2)
	g.select_slot(1)
	g.use_active(main.runner.global_position + Vector2(200, -120))
	var opened := ""
	for node in get_tree().get_nodes_in_group("switch"):
		node.take_damage(1, "snipe")
		opened = String(node.get("switch_id"))
		break
	await _pump(pair, 3)
	guardian_side.poll()   # drain everything sent so far

	# The returning client says hello again. That is the entire recovery.
	guardian_side.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED, Protocol.hello(NetLink.client_id(), Stage.current()))
	await _pump(pair, 3)

	var welcomed := false
	var constructs := 0
	var lists := 0
	var switches: Array[String] = []
	for p in guardian_side.poll():
		var parsed := Protocol.reader(p["payload"])
		var kind: int = parsed[0]
		var b: StreamPeerBuffer = parsed[1]
		if kind == Protocol.Msg.WELCOME:
			welcomed = true
		elif kind == Protocol.Msg.HOLO_LIST:
			# ONE message carrying the whole set, not one per construct. The
			# difference is the point: a list can say "and nothing else", which
			# is what a client holding stale copies needs to hear.
			constructs += b.get_u8()
			lists += 1
		elif kind == Protocol.Msg.WORLD:
			if b.get_u8() == Protocol.World.SWITCH:
				Protocol.get_pos(b); Protocol.get_pos(b); b.get_u8()
				switches.append(b.get_utf8_string())
	check(welcomed, "a repeat hello is welcomed like the first")
	check(lists == 1, "and the world comes back as one list (%d)" % lists)
	check(constructs >= 1,
		"with the live constructs in it (%d)" % constructs)
	check(opened == "" or switches.has(opened),
		"and so is a gate that was already open (%s in %s)" % [opened, switches])

	session.queue_free()
	Clock.is_host = true

## Online, each device shows and routes only its own half of the game.
##
## This is the bug behind "the guardian's platform, wall and scope cannot be
## put anywhere, they will not move from where they started". On the runner's
## device the guardian's ability bar was still drawn and still hit-tested, and
## the build ghost was still drawn from a reticle that nothing local could
## move. So a thumb on that bar selected an ability and built a slab at
## whatever point the cursor had been initialised to -- every time, the same
## place. Reproduced with the router itself, which is where it lived.
func _test_device_ownership() -> void:
	_current = "device ownership"
	await _boot()
	var hub: InputHub = main.input_hub
	var g: Guardian = main.guardian
	var view: Vector2 = main.get_viewport().get_visible_rect().size

	hub.solo_role = ""
	check(hub.owns_runner_controls() and hub.owns_guardian_controls(),
		"a shared screen owns both halves")
	check(hub.shows_guardian_cursor(), "and draws the guardian's cursor")

	# --- the runner's device ---
	hub.solo_role = "runner"
	hub.remote_aim = false
	check(hub.owns_runner_controls() and not hub.owns_guardian_controls(),
		"the runner's device owns only the runner's controls")
	check(not hub.shows_guardian_cursor(),
		"and draws no guardian cursor before any aim has arrived")

	g.select_slot(1)
	var aim_before: Vector2 = hub.aim_screen
	for slot in [2, 3]:
		# Where those buttons WOULD be if this device showed them. It does not,
		# so the touch has to fall through to nothing.
		hub._touch_down(7, _place("slot_%d" % slot, view, "guardian"))
		hub._touch_up(7)
	check(hub.take_slot_choice() == -1,
		"a thumb on the guardian's ability bar does nothing on the runner's device")
	hub._touch_down(8, Vector2(view.x * 0.70, view.y * 0.40))
	hub._touch_up(8)
	check(hub.aim_screen == aim_before,
		"and a drag past the old divider does not move the guardian's reticle")

	# The runner's own controls still work, at the solo positions.
	var cluster: Dictionary = hub.cluster(view)
	var anchor: Vector2 = cluster["stick"]["center"]
	hub._touch_down(0, anchor
		+ Vector2(ControlLayout.stick_travel(cluster["stick"]), 0.0))
	check(hub.move_axis > 0.5, "the stick still drives the runner")
	hub._touch_up(0)
	hub._touch_down(1, cluster["jump"]["center"])
	check(hub.take_jump(), "and the jump button, now on the far side, still fires")
	hub._touch_up(1)

	# Once the guardian's aim is arriving over the wire there is something real
	# to draw, and the runner should see it: that ghost is their warning.
	hub.remote_aim = true
	check(hub.shows_guardian_cursor(),
		"a runner whose partner is aiming sees the incoming platform")

	# --- the guardian's device: the mirror image ---
	hub.solo_role = "guardian"
	hub.move_axis = 0.0
	hub.aim_active = false
	hub._touch_down(2, anchor)
	check(is_equal_approx(hub.move_axis, 0.0),
		"the guardian's device has no runner stick to catch a thumb")
	hub._touch_up(2)
	# The guardian's own tools ARE on the left now -- they have two thumbs and
	# both should be doing something -- so "the left side aims" is no longer
	# true, and the empty part of the screen is what has to aim.
	check(ControlLayout.hit("guardian", view, false, anchor) != "",
		"the guardian's left hand has controls of its own where the stick was")
	hub.aim_active = false
	hub._touch_down(2, Vector2(view.x * 0.5, view.y * 0.38))
	check(hub.aim_active, "and the clear middle of the screen aims")
	hub._touch_up(2)
	hub.solo_role = ""

## Every control, in every mode, on every shape of screen anyone will hold.
##
## This replaces two narrower audits: one checked the runner's cluster and one
## checked that the guardian's buttons stayed on their side of the divider.
## Neither checked the guardian's buttons against EACH OTHER, which is the
## thing that matters once they are on a thumb arc rather than in a row -- and
## neither ran against a layout the player had moved themselves.
func _test_every_control_is_reachable_and_separate() -> void:
	_current = "control layout"
	ControlLayout.forget()
	# 16:9, a tall phone, the squarest tablet anyone ships, and two odd ones.
	var screens := [Vector2(1280, 720), Vector2(2340, 1080), Vector2(960, 720),
		Vector2(2400, 1080), Vector2(1600, 720)]
	for view in screens:
		for mode in ControlLayout.MODES:
			_audit_layout(String(mode), view, "%s %dx%d" % [mode, view.x, view.y])

	# On a shared screen the runner's controls must stay out of the guardian's
	# half, and the guardian's out of the runner's: there is a second person's
	# thumb over there.
	for view in screens:
		var shared := ControlLayout.layout("shared", view, false)
		var divider: float = ControlLayout.DIVIDER * view.x
		for id in ["stick", "jump", "sprint"]:
			var place: Dictionary = shared[id]
			var reach: float = float(place["radius"]) \
				* (ControlLayout.STICK_CAPTURE if id == "stick" else 1.0)
			check(place["center"].x + reach < divider,
				"shared %dx%d: the runner's %s stays left of the divider"
					% [view.x, view.y, id])
		for id in ["slot_1", "slot_2", "slot_3", "slot_4", "scope"]:
			check(shared[id]["center"].x - float(shared[id]["radius"]) > divider,
				"shared %dx%d: the guardian's %s stays right of it"
					% [view.x, view.y, id])

	# A layout the player has moved is still a layout the router agrees with.
	var view := Vector2(1280, 720)
	ControlLayout.set_place("guardian", "slot_1", Vector2(0.42, 0.33))
	var moved: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check(moved["center"].distance_to(Vector2(0.42 * 1280.0, 0.33 * 720.0)) < 1.0,
		"a moved button is where it was put (%s)" % moved["center"])
	check(ControlLayout.hit("guardian", view, false, moved["center"]) == "slot_1",
		"and a thumb there presses it")
	check(ControlLayout.has_custom("guardian"), "the layout counts as customised")
	ControlLayout.reset("guardian")
	check(not ControlLayout.has_custom("guardian"), "and resetting clears it")
	var back: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check(back["center"].distance_to(moved["center"]) > 50.0,
		"reset really puts it back where it started")

	# A setting that does not survive the app closing is not a setting.
	ControlLayout.set_place("runner", "jump", Vector2(0.33, 0.44))
	ControlLayout.save()
	ControlLayout.reload()
	var kept: Dictionary = ControlLayout.layout("runner", view, false)["jump"]
	check(kept["center"].distance_to(Vector2(0.33 * 1280.0, 0.44 * 720.0)) < 1.0,
		"a moved control is still there after a reload (%s)" % kept["center"])
	ControlLayout.reset("runner")
	ControlLayout.save()
	ControlLayout.reload()
	check(not ControlLayout.has_custom("runner"), "and a reset survives one too")

	# Mirroring for a role swap has to move the runner's half to the far side.
	var normal: Vector2 = ControlLayout.layout("shared", view, false)["stick"]["center"]
	var swapped: Vector2 = ControlLayout.layout("shared", view, true)["stick"]["center"]
	check(normal.x < view.x * 0.5 and swapped.x > view.x * 0.5,
		"a role swap moves the stick to the other edge")
	ControlLayout.forget()

## No control off the screen, none overlapping another, and every one of them
## inside a thumb's reach of the corner it belongs to.
func _audit_layout(mode: String, view: Vector2, tag: String) -> void:
	var places := ControlLayout.layout(mode, view, false)
	check(not places.is_empty(), "%s: has controls at all" % tag)
	var ids: Array = places.keys()
	for i in ids.size():
		var a: Dictionary = places[ids[i]]
		var ar: float = float(a["radius"]) \
			* (ControlLayout.STICK_CAPTURE if a["kind"] == "stick" else 1.0)
		var c: Vector2 = a["center"]
		check(c.x - ar >= -1.0 and c.x + ar <= view.x + 1.0
				and c.y - ar >= -1.0 and c.y + ar <= view.y + 1.0,
			"%s: %s is fully on the screen (%s r=%.0f)" % [tag, ids[i], c, ar])
		# Reachable without moving the hand: a thumb sweeps roughly the screen's
		# height from the corner it rests in.
		var corner := Vector2(0.0 if c.x < view.x * 0.5 else view.x, view.y)
		check(c.distance_to(corner) < view.y * 1.05,
			"%s: %s is within a thumb's reach of its corner (%.0fpx of %.0f)"
				% [tag, ids[i], c.distance_to(corner), view.y * 1.05])
		for j in range(i + 1, ids.size()):
			var b: Dictionary = places[ids[j]]
			var br: float = float(b["radius"]) \
				* (ControlLayout.STICK_CAPTURE if b["kind"] == "stick" else 1.0)
			check(c.distance_to(b["center"]) > ar + br,
				"%s: %s and %s do not overlap (%.0fpx apart, need %.0f)"
					% [tag, ids[i], ids[j], c.distance_to(b["center"]), ar + br])

## Where a control actually is, from the same table the game uses.
func _place(id: String, view: Vector2, mode: String = "guardian") -> Vector2:
	return ControlLayout.layout(mode, view, false)[id]["center"]
func _test_the_catch_is_graded() -> void:
	_current = "rescue grading"
	await _boot()

	# Late: the slab arrives just above them.
	var late := await _catch(-200.0, 0.30, 120.0)
	check(late["landed"], "the runner lands on the platform placed under them")
	check_range(float(late["age"]), 0.0, float(Balance.RESCUE_TIERS[2]),
		"a slab placed 120px under a falling runner is landed on within the top window")
	check(int(late["tier"]) == 3, "the latest catch scores PERFECT (got %d)" % late["tier"])
	check_near(float(late["refund"]), float(Balance.RESCUE_REFUND[3]), 0.6,
		"a PERFECT catch refunds its tier's gauge")

	# Middling.
	var mid := await _catch(-200.0, 0.30, 560.0)
	check_range(float(mid["age"]), float(Balance.RESCUE_TIERS[2]),
		float(Balance.RESCUE_TIERS[1]),
		"a slab 560px down is reached in the middle window")
	check(int(mid["tier"]) == 2, "the middling catch scores GREAT (got %d)" % mid["tier"])
	check_near(float(mid["refund"]), float(Balance.RESCUE_REFUND[2]), 0.6,
		"a GREAT catch refunds its tier's gauge")

	# Early, but still a catch: 1250px is inside PLACE_MAX_RANGE, and at terminal
	# velocity that is over a second of falling.
	var early := await _catch(-900.0, 0.30, 1250.0)
	check_range(float(early["age"]), float(Balance.RESCUE_TIERS[1]),
		float(Balance.RESCUE_TIERS[0]),
		"a slab 1250px down is reached in the bottom window")
	check(int(early["tier"]) == 1, "the early catch still scores NICE (got %d)" % early["tier"])
	check_near(float(early["refund"]), float(Balance.RESCUE_REFUND[1]), 0.6,
		"a NICE catch refunds its tier's gauge")

	check(float(Balance.RESCUE_REFUND[3]) > float(Balance.RESCUE_REFUND[1]),
		"leaving it later is worth more gauge, or the grade rewards nothing")

	# A drop too short to be a rescue. The age here is inside the PERFECT window,
	# so the only thing keeping it from scoring is RESCUE_MIN_FALL -- which is
	# the check that stops the runner farming grades by hopping on and off a
	# slab the guardian left lying about.
	var hop := await _catch(-200.0, 0.0, 53.0)
	check(hop["landed"], "the short drop still lands on the platform")
	check(float(hop["impact"]) < Balance.RESCUE_MIN_FALL,
		"the short drop is below the rescue threshold (%.0f)" % hop["impact"])
	check_range(float(hop["age"]), 0.0, float(Balance.RESCUE_TIERS[2]),
		"...and it is not the platform's age that disqualifies it")
	check(int(hop["tier"]) == 0, "stepping onto a slab is not a rescue")
	check_near(float(hop["refund"]), 0.0, 0.6, "and it refunds nothing")

	# A slab that has been lying there is not a catch either, however hard the
	# runner hits it.
	var stale := await _catch(-200.0, 0.30, 400.0, 2.0)
	check(stale["landed"], "the runner lands on the aged platform")
	check(float(stale["impact"]) >= Balance.RESCUE_MIN_FALL,
		"the fall onto the aged platform is a real fall (%.0f)" % stale["impact"])
	check(float(stale["age"]) > float(Balance.RESCUE_TIERS[0]),
		"the platform is older than the widest window (%.2fs)" % stale["age"])
	check(int(stale["tier"]) == 0, "an old slab scores nothing")

	# The grade is read off placed_tick, not birth_tick. HostSession moves
	# birth_tick into the past to compensate for the guardian's latency; if the
	# grade followed it, a guardian on a bad line would be marked down for lag
	# the host had already forgiven. Backdated by 1.5s, this would grade NICE
	# instead of PERFECT.
	var lagged := await _catch(-200.0, 0.30, 120.0, 0.0, 90)
	check(int(lagged["birth_age_ticks"]) >= 90,
		"the construct really was backdated (%d ticks)" % lagged["birth_age_ticks"])
	check(int(lagged["tier"]) == 3,
		"a backdated construct is graded on when the guardian pressed, not on its birth tick (got %d)"
			% lagged["tier"])

	# What the clear screen reports.
	check(GameState.rescue_tiers[3] > 0 and GameState.rescue_tiers[2] > 0
			and GameState.rescue_tiers[1] > 0,
		"every grade reached the run summary")
	check(GameState.best_catch().begins_with(Balance.RESCUE_NAMES[3]),
		"the summary reports the best catch of the run (got '%s')" % GameState.best_catch())

## Drops the runner down the 600px gap between the slabs at 1900 and 2500, has
## the guardian build `drop` pixels beneath them `fall_for` seconds into the
## fall, and reports what the catch was worth.
##
## `age_it` holds the construct in place for that many seconds first, by parking
## the runner back on solid ground; `backdate` moves its birth tick into the past
## the way a laggy placement does on the host.
func _catch(from_y: float, fall_for: float, drop: float,
		age_it: float = 0.0, backdate: int = 0) -> Dictionary:
	var r: Runner = main.runner
	var g: Guardian = main.guardian
	for old in g.holograms_of(Hologram.Kind.PLATFORM):
		old.expire()
	await _physics(2)

	var out := {"tier": 0, "age": 0.0, "refund": 0.0, "impact": 0.0,
		"landed": false, "birth_age_ticks": 0, "gauge_before": 0.0}
	# Through the dictionary rather than through a local: a GDScript lambda
	# captures by VALUE, so a plain `var before` would be frozen at whatever it
	# held when the lambda was made -- which is how the first run of this test
	# reported the entire gauge as the refund.
	var seen := func(tier: int, _at: Vector2) -> void:
		out["tier"] = tier
		out["refund"] = g.gauge - float(out["gauge_before"])
	Events.rescue_scored.connect(seen)

	r.global_position = Vector2(2100.0, from_y)
	r.velocity = Vector2.ZERO
	main.input_hub.move_axis = 0.0
	await _physics(1)
	await _physics(int(fall_for / Clock.DT))

	# Room for the refund without hitting the ceiling of the gauge, which would
	# hide the difference between the tiers.
	g.gauge = 50.0
	g.select_slot(1)
	var at := r.global_position + Vector2(0.0, drop)
	g.use_active(at)
	var live: Array = g.holograms_of(Hologram.Kind.PLATFORM)
	if live.is_empty():
		Events.rescue_scored.disconnect(seen)
		return out
	var holo: Hologram = live[live.size() - 1]
	if backdate > 0:
		# Exactly what HostSession._do_place does: the life is shortened, the
		# placement stamp is left alone.
		holo.birth_tick = Clock.tick - backdate
		holo.death_tick = holo.birth_tick + Clock.ticks_for(holo.lifetime)
	if age_it > 0.0:
		# Park the runner on the start plateau while the slab gets old, so the
		# waiting is not itself a fall.
		var parked := r.global_position
		r.global_position = Vector2(-400.0, 300.0)
		await _wait(age_it)
		r.global_position = parked
		r.velocity = Vector2(0.0, maxf(0.0, r.velocity.y))
		await _physics(1)

	var placed_at: int = holo.placed_tick
	out["birth_age_ticks"] = placed_at - holo.birth_tick
	for i in range(240):
		# Read after the frame, not before it: impact_speed() is set from the
		# velocity the runner had going into move_and_slide, so on the frame
		# they touch down it holds exactly the number the grader saw.
		out["gauge_before"] = g.gauge
		await _physics(1)
		out["impact"] = r.impact_speed()
		if r.is_on_floor():
			out["landed"] = true
			break
	out["age"] = float(Clock.tick - placed_at) * Clock.DT
	Events.rescue_scored.disconnect(seen)
	return out

## Reported as "we cannot connect, on the same Wi-Fi or apart".
##
## The reconnect watchdog counts silence and calls four seconds of it a dropped
## link. That is right once packets have been flowing -- and completely wrong
## before the first one ever arrives, which is the whole of the time between
## one player pressing their button and the other pressing theirs. Reading a
## six-letter code out loud takes longer than four seconds, so the joining
## device declared the link dead before the link had ever been alive, started
## re-dialling, and on the relay a re-dial takes the SECOND slot of a two-slot
## room while the first is still open -- so the retry cannot succeed either.
func _test_a_slow_start_is_not_a_drop() -> void:
	_current = "slow start"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)

	var banner := [""]
	var watch := func(text: String) -> void: banner[0] = text
	Events.link_state.connect(watch)

	# Nobody answers. This is the other player still reading the code out.
	await _wait(ClientSession.SILENCE_IS_A_DROP + 1.2)
	check(banner[0] == "",
		"waiting to be let in is not a dropped connection (said '%s')" % banner[0])
	check(session.is_processing(), "and the session is still trying")

	# They press their button. It has to work as if no time had passed.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "host-test"))
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.holo_spawn(21, int(Hologram.Kind.PLATFORM), Vector2(3000, 260),
			Clock.tick, Clock.tick + 600, 0))
	await _pump(pair, 4)
	check(banner[0] == "", "and still nothing is said about the link")
	check(main.guardian.holograms_of(Hologram.Kind.PLATFORM).size() == 1,
		"the game starts normally once the other side arrives")

	# Only NOW does silence mean something, because the link has been up.
	await _wait(ClientSession.SILENCE_IS_A_DROP + 0.4)
	check(banner[0] != "",
		"once it HAS been connected, silence is still reported as a drop")

	Events.link_state.disconnect(watch)
	session.queue_free()
	Clock.is_host = true
	await _frames(2)

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

## Three seconds on the edge, which is three seconds for the other player.
func _test_the_runner_can_catch_an_edge() -> void:
	_current = "ledge"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0

	# A block with a clear top, in open air, on the terrain layer -- the only
	# layer an edge is looked for on.
	var block := StaticBody2D.new()
	block.collision_layer = 1
	block.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(180.0, 240.0)
	shape.shape = box
	block.add_child(shape)
	block.global_position = Vector2(2600.0, 120.0)
	main.add_child(block)
	await _physics(2)

	var lip: float = block.global_position.y - 120.0
	var grabs := [0]
	var watch := func(_at: Vector2) -> void: grabs[0] += 1
	Events.runner_grabbed_ledge.connect(watch)

	var caught := await _fall_past_the_edge(r, hub, block, lip)
	check(caught, "falling past the edge catches it")
	check(r.hanging(), "the runner is hanging")
	check(r.grip_left() > 0.8, "with a full grip (%.2f)" % r.grip_left())
	check(r.velocity.is_zero_approx(), "and is not moving")

	# It runs out.
	await _wait(Balance.LEDGE_HANG_TIME * 0.5)
	var half := r.grip_left()
	check(half < 0.7 and half > 0.2, "the grip runs down (%.2f)" % half)
	await _wait(Balance.LEDGE_HANG_TIME * 0.6)
	check(not r.hanging(), "and lets go when it is gone")

	# Jumping off it works, and the same edge does not give a second rest.
	r.global_position = Vector2(2600.0, 300.0)
	r.velocity = Vector2.ZERO
	await _physics(20)
	var again := await _fall_past_the_edge(r, hub, block, lip)
	check(again, "the edge can be caught again after touching the ground")
	if again:
		var height := r.global_position.y
		hub.press_jump()
		await _physics(6)
		check(not r.hanging(), "pressing jump leaves the edge")
		check(r.global_position.y < height, "upwards (%.0fpx)" % (height - r.global_position.y))

	# Letting go and catching the same lip again is not an infinite rest.
	var before: int = grabs[0]
	var third := await _fall_past_the_edge(r, hub, block, lip)
	check(not third or grabs[0] == before,
		"the same edge does not catch twice without touching down")

	Events.runner_grabbed_ledge.disconnect(watch)
	hub.move_axis = 0.0
	block.queue_free()
	await _frames(2)

## Drops the runner beside the block, moving into it, and waits for a grab.
func _fall_past_the_edge(r: Runner, hub: InputHub, block: Node2D, lip: float) -> bool:
	# Beside the block with their hands just above its lip, not above the block
	# -- start them higher and they simply land on top of it, which is what the
	# first version of this did.
	r.global_position = Vector2(block.global_position.x - 120.0, lip - 20.0)
	r.velocity = Vector2(0.0, Balance.LEDGE_MIN_FALL_SPEED + 40.0)
	r.facing = 1
	hub.move_axis = 1.0
	for _i in range(120):
		await get_tree().physics_frame
		if r.hanging():
			return true
		if r.is_on_floor():
			return false
	return false

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

	g.select_slot(1)
	g.use_active(Vector2(2600, 180))
	await _physics(3)
	check(g.holograms_of(Hologram.Kind.PLATFORM).size() == 1, "a platform is placed")
	var spent: float = g.gauge
	check(spent < Balance.GAUGE_MAX, "and paid for (%.0f)" % spent)

	check(g.undo_last(), "it can be taken back")
	await _physics(3)
	check(g.holograms_of(Hologram.Kind.PLATFORM).is_empty(), "and it is gone")
	# The gauge regenerates on its own, so this is not an equality: what must
	# not happen is the COST coming back.
	check(g.gauge < spent + Balance.COST_PLATFORM * 0.5,
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

	hub.solo_role = "guardian"
	await _frames(2)
	var where: Vector2 = main.runner.global_position + Vector2(220.0, -90.0)
	hub.aim_at_world(where)
	await _frames(2)
	hub._touch_down(31, _place("ping", view, "guardian"))
	hub._touch_up(31)
	await _frames(4)
	check(said.size() == 1, "the guardian's button points at something (%d)" % said.size())
	if said.size() > 0:
		check(Vector2(said[0]["at"]).distance_to(where) < 2.0,
			"at the reticle, not at the button")
		check(int(said[0]["kind"]) == 1, "and it means 'here'")

	# Held, it means the other thing. One button, two things, and the
	# difference is how long the thumb stays on it.
	said.clear()
	hub._touch_down(32, _place("ping", view, "guardian"))
	hub._ping_down_ms -= InputHub.PING_HOLD_MS + 40
	hub._touch_up(32)
	await _frames(4)
	check(said.size() == 1 and int(said[0]["kind"]) == 2,
		"holding it means 'wait'")

	# The runner has one too, and theirs marks where they are.
	said.clear()
	hub.solo_role = "runner"
	await _frames(2)
	var stood_at: Vector2 = main.runner.global_position
	hub._touch_down(33, _place("ping", view, "runner"))
	hub._touch_up(33)
	await _frames(4)
	check(said.size() == 1, "the runner can point too (%d)" % said.size())
	if said.size() > 0:
		check(bool(said[0]["runner"]), "and it is marked as theirs")
		check(Vector2(said[0]["at"]).distance_to(stood_at) < 40.0,
			"pointing at where they are (%.0fpx)"
				% Vector2(said[0]["at"]).distance_to(stood_at))

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

## Jumps, then holds a direction until the runner is airborne and against one of
## the guardian's walls. Returns whether it got there.
func _press_into_the_wall(r: Runner, hub: InputHub, direction: float) -> bool:
	hub.move_axis = direction
	if r.is_on_floor():
		hub.press_jump()
		hub.jump_held = true
		await _physics(6)
		hub.jump_held = false
	for _i in range(50):
		await get_tree().physics_frame
		if r.can_wall_jump():
			return true
		if r.is_on_floor():
			hub.press_jump()
			hub.jump_held = true
			await _physics(6)
			hub.jump_held = false
	return false

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

## A tap is a tap; a drag of the reticle is not, and neither is a swipe of the
## view. All three end in the same _touch_up.
## Two thumbs, four ways they can tread on each other.
##
## Each of these is one line of the brief, and each is checked on its own so a
## failure says which. They pass today -- the hub records what a finger is for
## when it lands and never re-reads it -- and that is exactly why they are
## worth writing down: the property is invisible, so nothing stops it being
## lost.
func _test_two_thumbs_do_not_interfere() -> void:
	_current = "two thumbs"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = ""
	var stick_at: Vector2 = Vector2(ControlLayout.layout("shared", view, false)["stick"]["center"])
	var jump_at := _place("jump", view, "shared")

	# 1. Jumping while moving must not interrupt the moving.
	hub._touch_down(71, stick_at + Vector2(70.0, 0.0))
	await _physics(2)
	var walking := hub.move_axis
	check(absf(walking) > 0.1, "the stick is moving the runner (%.2f)" % walking)
	hub._touch_down(72, jump_at)
	await _physics(2)
	check(hub.jump_held, "jumping with the other thumb works")
	check(absf(hub.move_axis - walking) < 0.01,
		"and does not interrupt the walking (%.2f -> %.2f)" % [walking, hub.move_axis])

	# 2. Letting go of one must not release the other.
	hub._touch_up(72, jump_at)
	await _physics(2)
	check(not hub.jump_held, "letting go of jump releases jump")
	check(absf(hub.move_axis) > 0.1,
		"and leaves the stick held (%.2f)" % hub.move_axis)

	# 3. A finger that slides off its control keeps doing its own job. What a
	# touch is FOR is decided where it lands; re-deciding it mid-gesture is how
	# a thumb drifting off the stick starts placing platforms.
	hub._touch_move(71, jump_at)
	await _physics(2)
	check(absf(hub.move_axis) > 0.1,
		"a thumb sliding off the stick is still the stick (%.2f)" % hub.move_axis)
	check(not hub.jump_held,
		"and does not become the jump button it slid onto")
	hub._touch_up(71, jump_at)
	await _physics(2)
	check(absf(hub.move_axis) < 0.01, "releasing it stops the runner")

	# 4. A finger that starts on the controls never places anything, however
	# far it travels before letting go.
	hub.solo_role = "guardian"
	var button := _place("slot_1", view, "guardian")
	hub.take_place_at()
	hub._touch_down(73, button)
	hub._touch_move(73, button + Vector2(10.0, -10.0))
	await _physics(2)
	hub._touch_up(73, _place("scope", view, "guardian"))
	var latched := hub.take_place_at()
	check(latched.x == INF,
		"a thumb that starts and ends on the controls places nothing")
	hub.solo_role = ""

## Auto-dash gives the sprint away, and the brief asks what that costs.
##
## It costs stopping distance: a runner who is always at top speed needs longer
## to stop, and the narrow places are exactly where that matters. So this checks
## both halves -- that it works, and that it does not quietly make a one-block
## perch impossible to stand on.
func _test_auto_dash_is_a_real_choice() -> void:
	_current = "auto dash"
	await _boot()
	var r: Runner = main.runner
	var hub: InputHub = main.input_hub
	main._respawn_timer = -1.0
	Options.forget()

	var run_to_speed := func() -> float:
		r.global_position = Vector2(-400, 300)
		r.velocity = Vector2.ZERO
		hub.move_axis = 0.0
		hub.dash_held = false
		for _i in range(40):
			await get_tree().physics_frame
			if r.is_on_floor():
				break
		hub.move_axis = 1.0
		await _physics(60)
		return absf(r.velocity.x)

	check(not Options.auto_dash(), "it is off by default")
	var held_off: float = await run_to_speed.call()
	check(absf(held_off - Balance.RUNNER_RUN_SPEED) < 12.0,
		"and without it, holding nothing walks (%.0f)" % held_off)

	Options.set_auto_dash(true)
	var auto_on: float = await run_to_speed.call()
	check(auto_on > Balance.RUNNER_RUN_SPEED * 1.3,
		"with it on, moving is sprinting without holding anything (%.0f)" % auto_on)

	# The cost, measured: how far past letting go does the runner travel? If
	# that is more than a block, a one-block perch is not somewhere you can
	# stand, and the setting has quietly made the game harder in a place the
	# player cannot see.
	hub.move_axis = 0.0
	var from := r.global_position.x
	for _i in range(60):
		await get_tree().physics_frame
		if absf(r.velocity.x) < 1.0:
			break
	var ran_on: float = absf(r.global_position.x - from)
	check(ran_on < Balance.B,
		"and stopping still fits inside one block (%.0fpx of %.0f)"
			% [ran_on, Balance.B])

	# Survives being written and read back, which is what a setting means.
	Options.reload()
	check(Options.auto_dash(), "the setting is remembered")
	Options.set_auto_dash(false)
	Options.reload()
	check(not Options.auto_dash(), "and can be turned back off")
	hub.move_axis = 0.0

## A phone call in the middle of a jump must not leave the runner running.
##
## Android does not reliably send a release for a finger that is down when the
## app goes away -- a call, the task switcher, the screen locking. Without
## something to catch that, the stick stays held: the runner keeps walking in
## whatever direction the thumb was pointing, off whatever they were standing
## on, and comes back to a control that is stuck until it is touched again.
##
## Nothing the player was NOT holding is disturbed. Losing the reticle or the
## chosen tool to a phone call would be its own small betrayal.
func _test_an_interruption_lets_go_of_everything() -> void:
	_current = "interrupted mid-gesture"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = ""

	# A thumb on the stick and another on jump, which is the normal way to play.
	var stick: Dictionary = ControlLayout.layout("shared", view, false)["stick"]
	hub._touch_down(61, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	hub._touch_down(62, _place("jump", view, "shared"))
	await _physics(3)
	check(absf(hub.move_axis) > 0.1, "the stick is held (%.2f)" % hub.move_axis)
	check(hub.jump_held, "and so is jump")

	# Remember what was NOT being held, so the recovery can be checked for
	# taking too much with it.
	main.guardian.select_slot(2)
	var chosen: int = main.guardian.active_slot
	hub.aim_at_world(Vector2(4321.0, 210.0))
	var aimed := hub.aim_point

	hub.release_everything()
	await _physics(3)
	check(absf(hub.move_axis) < 0.01,
		"the app going away lets go of the stick (%.2f)" % hub.move_axis)
	check(not hub.jump_held, "and of jump")
	check(not hub.dash_held, "and of sprint")

	# Coming back, the controls answer again rather than needing to be
	# un-stuck. A release that left the finger registered would swallow this.
	hub._touch_down(63, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	await _physics(3)
	check(absf(hub.move_axis) > 0.1,
		"and the stick works again afterwards (%.2f)" % hub.move_axis)
	hub._touch_up(63, Vector2(stick["center"]) + Vector2(60.0, 0.0))
	await _physics(2)

	check(main.guardian.active_slot == chosen,
		"the tool the guardian had chosen is still chosen")
	check(hub.aim_point.distance_to(aimed) < 1.0,
		"and the reticle has not moved")
	check(hub.take_place_at().x == INF,
		"and nothing was placed on the way out")

## Where the finger comes up is where it goes.
##
## A touch release is its own event and it carries its own position. That
## position was being dropped -- _touch_up took an index and nothing else -- so
## a commit read the shared reticle, which is wherever the last DRAG event left
## it. Drag slowly and every sample lands near the lift and nothing looks wrong.
## Move quickly and the finger covers real distance between the last sample and
## coming up, so the construct appears behind the thumb.
##
## The latch is read with no frame in between, because the guardian consumes it
## every frame: awaiting first would be asking the game what it did rather than
## what the input decided.
func _test_the_finger_decides_where_it_landed() -> void:
	_current = "placing where the finger lifted"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"
	main.runner.global_position = Vector2(2600, 300)
	main.runner.velocity = Vector2.ZERO
	await _physics(6)
	var to_world := func(p: Vector2) -> Vector2:
		return main.get_viewport().get_canvas_transform().affine_inverse() * p
	# Real events through the real entry point. Calling _touch_up(index, where)
	# by hand would skip _unhandled_input, which is the exact line that was
	# throwing the release position away -- a test that skips it cannot see the
	# bug at all.
	var down := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = at
		e.pressed = true
		hub._unhandled_input(e)
	var drag := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenDrag.new()
		e.index = i
		e.position = at
		hub._unhandled_input(e)
	var up := func(i: int, at: Vector2) -> void:
		var e := InputEventScreenTouch.new()
		e.index = i
		e.position = at
		e.pressed = false
		hub._unhandled_input(e)

	# A tap: down and up at one place. The release is the ONLY position this
	# gesture ever reports, so a handler that ignores it has nothing at all.
	var spot := Vector2(view.x * 0.62, view.y * 0.52)
	down.call(42, spot)
	await _physics(1)
	up.call(42, spot)
	var tapped := hub.take_place_at()
	check(tapped.x != INF, "a tap on open ground commits")
	if tapped.x != INF:
		check(tapped.distance_to(to_world.call(spot)) < 2.0,
			"exactly where the finger came up (%.1fpx off)"
				% tapped.distance_to(to_world.call(spot)))

	# The same tap, but the finger drifts a few pixels before lifting -- a thumb
	# on glass always does. Still a tap, and it goes where the thumb ENDED.
	var began := Vector2(view.x * 0.50, view.y * 0.46)
	var ended := began + Vector2(7.0, -5.0)
	down.call(44, began)
	await _physics(1)
	up.call(44, ended)
	var drifted := hub.take_place_at()
	check(drifted.x != INF, "a tap that drifts a little is still a tap")
	if drifted.x != INF:
		check(drifted.distance_to(to_world.call(ended)) < 2.0,
			"and lands under the lift, not under the touch-down (%.1fpx off)"
				% drifted.distance_to(to_world.call(ended)))

	# Dragging out of a tool button and letting go: the one gesture that places
	# after real travel, and the one where a stale reticle is most visible. The
	# sample is taken early and the finger comes up a long way past it.
	var button := _place("slot_1", view, "guardian")
	var sampled := button + Vector2(30.0, -20.0)
	# Clear of every control: letting go back ON one is the cancel, and a test
	# that drops onto the scope button is testing the cancel by accident.
	var dropped := Vector2(view.x * 0.55, view.y * 0.25)
	check(ControlLayout.hit("guardian", view, false, dropped) == "",
		"the drop point is open ground, not a button")
	down.call(43, button)
	drag.call(43, sampled)
	await _physics(2)
	up.call(43, dropped)
	var built := hub.take_place_at()
	check(built.x != INF, "dragging out of a tool button commits too")
	if built.x != INF:
		check(built.distance_to(to_world.call(dropped)) < 2.0,
			"at the point the thumb let go (%.1fpx off)"
				% built.distance_to(to_world.call(dropped)))
		check(built.distance_to(to_world.call(sampled)) > 40.0,
			"and not at the last place it was sampled")

	hub.solo_role = ""

func _test_only_a_tap_counts_as_a_tap() -> void:
	_current = "tap, not drag"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"

	var start := Vector2(view.x * 0.6, view.y * 0.45)
	hub._touch_down(1, start)
	hub._touch_up(1)
	check(hub.take_place_at().x != INF, "a finger down and up in one place is a tap")

	hub._touch_down(2, start)
	hub._touch_move(2, start + Vector2(0.0, -140.0))
	hub._touch_up(2)
	check(hub.take_place_at().x == INF, "dragging the reticle is not")

	hub._touch_down(3, start)
	for i in range(6):
		hub._touch_move(3, start + Vector2(-40.0 * float(i + 1), 0.0))
	hub._touch_up(3)
	check(hub.take_place_at().x == INF, "and neither is swiping the view")
	hub.solo_role = ""
	await _frames(2)

## One tap, one attempt.
##
## The room holds two seats. A second tap on Join used to build a second
## ClientSession with its own socket, and that socket took the other player's
## seat -- so an impatient thumb locked its own partner out of the room.
func _test_two_taps_make_one_session() -> void:
	_current = "one attempt"
	await _boot()
	# Somewhere that will never answer, so nothing real is dialled. What is
	# under test is the guard, which runs before any of that matters.
	const NOWHERE := "wss://198.51.100.1:9"
	var first: String = main._dial_relay(NOWHERE, "AAAAAA", "guest")
	check(first == "", "the first tap starts an attempt (%s)" % first)
	check(main.link.busy(), "and the link says it is busy")
	var one: Node = main.client_session
	check(is_instance_valid(one), "with one session")

	var second: String = main._dial_relay(NOWHERE, "AAAAAA", "guest")
	check(second != "", "the second tap is refused (%s)" % second)
	check(main.client_session == one, "and the first session is still the only one")
	var sessions := 0
	for child in main.get_children():
		if child is ClientSession or child is HostSession:
			sessions += 1
	check(sessions == 1, "exactly one session node exists (%d)" % sessions)

	main._end_any_session()
	await _frames(2)
	check(not main.link.busy(), "ending it frees the link")
	check(main.client_session == null, "and clears the session")

	# ...and now a fresh one can start, without restarting the app.
	var third: String = main._dial_relay(NOWHERE, "BBBBBB", "host")
	check(third == "", "a new room can be made straight away (%s)" % third)
	check(main.host_session != null, "as the host this time")
	main._end_any_session()
	await _frames(2)

## Waiting for the other player and a broken link are different states, and the
## report has to be able to tell them apart -- reading one as the other is what
## sent a player to compare six characters that already matched.
func _test_the_link_records_what_happened() -> void:
	_current = "link record"
	var link := NetLink.new()
	add_child(link)
	check(not link.busy(), "a fresh link is not busy")
	check(link.phase == NetLink.Phase.IDLE, "and is idle")

	link.begin("ABC123", "guest")
	check(link.phase == NetLink.Phase.DIALLING, "beginning an attempt dials")
	check(link.busy(), "which is busy")
	check(link.attempt_id != "", "and has an id to tell it from the next one")

	link.relay_role = "host"
	link.enter(NetLink.Phase.WAITING_PEER, "部屋が空でした")
	check(link.phase == NetLink.Phase.WAITING_PEER, "then waits for a partner")
	check(link.joined_at_ms >= 0, "and remembers when it got in")

	link.enter(NetLink.Phase.PLAYING)
	check(link.handshaken_at_ms >= 0, "and when the game was agreed")

	link.reconnects += 2
	var lines := link.lines()
	var joined := "\n".join(lines)
	check(joined.contains("ABC123"), "the report names the room")
	check(joined.contains("guest") and joined.contains("host"),
		"and both the role asked for and the one given")
	check(joined.contains("再接続回数: 2"), "and counts the reconnections")
	check(link.journal_lines().size() >= 3, "the journal kept the transitions")

	link.finish()
	check(not link.busy(), "finishing frees it")
	link.queue_free()
	await _frames(2)

## Zero milliseconds and "never measured" are different facts.
func _test_an_unmeasured_round_trip_says_so() -> void:
	_current = "rtt"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var session := ClientSession.new()
	session.main = main
	session.transport = pair[0]
	add_child(session)
	await _frames(2)
	check(session.round_trip() < 0.0,
		"a session that has never had a pong reports no measurement (%.3f)"
			% session.round_trip())
	session.queue_free()
	Clock.is_host = true
	await _frames(2)

## A link that never came up has to keep trying.
##
## The slow-start rule above says silence before the first packet is not a
## dropped connection, because it is usually the other player still reading the
## code out. That is right, and it was applied one step too widely: it also
## silenced the case where THIS device's own socket is not open. A phone that
## dialled the relay and got nothing then sat in a dead room forever -- the
## report off the device read "room 5QK2TN, 0 received, 0 sent, connection
## closed" -- and the only way back was to force-quit the game. The two cases
## are told apart by the one question that matters: is our own link up.
func _test_a_link_that_never_opened_keeps_trying() -> void:
	_current = "dead link"
	await _boot()
	var dead := DeadLink.new()
	var session := ClientSession.new()
	session.main = main
	session.transport = dead
	add_child(session)
	await _frames(2)

	var banner := [""]
	var watch := func(text: String) -> void: banner[0] = text
	Events.link_state.connect(watch)

	check(dead.redials == 0, "nothing is re-dialled straight away")
	await _wait(ClientSession.SILENCE_IS_A_DROP + ClientSession.RETRY_EVERY + 1.0)
	check(dead.redials > 0,
		"a socket that never opened is re-dialled (%d attempts)" % dead.redials)
	check(banner[0] != "", "and the player is told (said '%s')" % banner[0])

	Events.link_state.disconnect(watch)
	session.queue_free()
	Clock.is_host = true
	await _frames(2)

## Starting a second session must end the first one.
##
## A join that failed left its ClientSession running -- polling a dead
## transport, still wired to the guardian's command router -- and pressing
## "make a room" afterwards simply added a HostSession beside it. Two sessions,
## two transports, and Clock.is_host set by whichever woke up last. Restarting
## the app was the only thing that cleared it, which is exactly what a player
## should never have to do.
func _test_a_new_room_ends_the_old_one() -> void:
	_current = "no leftovers"
	await _boot()
	var first := LoopbackTransport.pair(0.0)
	main._become_client(first[0])
	await _frames(2)
	var stale: Node = main.client_session
	check(is_instance_valid(stale), "a guardian session exists")
	check(main.guardian.command_router == stale, "and the guardian talks to it")
	check(not main.runner.is_physics_processing(),
		"and the runner has become a puppet")

	var second := LoopbackTransport.pair(0.0)
	main._become_host(second[0])
	await _frames(4)
	check(not is_instance_valid(stale) or stale.is_queued_for_deletion(),
		"starting a room throws the old session away")
	check(main.client_session == null, "and forgets it")
	check(main.guardian.command_router == null,
		"and unhooks the guardian from it")
	check(main.runner.is_physics_processing(),
		"and the runner simulates again on the device that now owns the world")
	check(Clock.is_host, "and this device is the host, unambiguously")

	main._end_any_session()
	await _frames(2)

## A build mismatch has to reach the player who can act on it.
##
## The host refuses the handshake and says why. That refusal used to arrive
## after the connect screen had closed -- the screen closed when the RELAY said
## both devices were present, which is earlier -- so the message flashed over
## the HUD for about a second on top of a game that was never going to start.
func _test_a_refused_handshake_is_visible() -> void:
	_current = "refused handshake"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)

	var shaken := [0]
	session.handshaken.connect(func() -> void: shaken[0] += 1)
	var notices: Array[String] = []
	var heard := func(text: String) -> void: notices.append(text)
	Events.notice.connect(heard)

	# What a mismatched host sends: a reason, and no welcome.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.notice("バージョンが違います（相手 1 / こちら 2）"))
	await _pump(pair, 3)
	check(shaken[0] == 0, "a refusal is not a handshake")
	check(notices.size() == 1 and notices[0].contains("バージョン"),
		"and the reason reaches the game, in words (%s)" % str(notices))

	# A real welcome is the thing the connect screen waits for, and it happens
	# exactly once however many times the host repeats it.
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "host-test"))
	await _pump(pair, 3)
	check(shaken[0] == 1, "a welcome is (%d)" % shaken[0])
	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "host-test"))
	await _pump(pair, 3)
	check(shaken[0] == 1, "and a repeat does not re-open the screen")

	Events.notice.disconnect(heard)
	session.queue_free()
	Clock.is_host = true
	await _frames(2)

## The diagnostic has to produce a report even when everything fails, because
## that is the only time anyone runs it. Pointed at a dead port on purpose.
func _test_the_diagnostic_reports_every_step() -> void:
	_current = "diagnostic"
	var panel := NetDiagnostics.new()
	# Port 9 is the discard port: refused immediately, so this costs no time.
	panel.relay = "http://127.0.0.1:9"
	add_child(panel)
	var waited := 0.0
	while not panel.report().contains("===") and waited < 60.0:
		await get_tree().process_frame
		waited += 0.016
	var text := panel.report()
	check(text.contains("==="), "the report finishes even with nothing reachable")
	for step in ["[1/3]", "[2/3]", "[3/3]"]:
		check(text.contains(step), "the report covers step %s" % step)
	check(text.contains("中継URL http://127.0.0.1:9"),
		"it records which relay it was pointed at")
	check(text.contains("端末 ") and text.contains("Godot "),
		"and which device and build it ran on")
	check(text.split("\n").size() > 15,
		"the report is long enough to diagnose from (%d lines)"
			% text.split("\n").size())
	# The failures have to be EXPLAINED, not just numbered. Naming the actual
	# sentences: a first version of this asked only whether an arrow appeared
	# anywhere, and the arrows in the step headings made it pass with every
	# explanation deleted.
	check(text.contains("この端末からインターネットに出られていないか"),
		"an unreachable relay is explained in words")
	check(text.contains("WebSocketがつながりません"),
		"and so is a WebSocket that will not open")
	check(text.contains("テザリング"),
		"with something the player can actually try next")

	# The two connections have to be told apart.
	#
	# Steps 1-3 open a BRAND NEW socket from this device. Passing them proves
	# the network and the relay can carry a connection; it says nothing about
	# the one the game is holding, which may have been made minutes ago, to a
	# different room, and be dead. A report that ran the three steps and
	# concluded "your connection is fine" was answering a question nobody asked.
	check(text.contains("いま動いているゲーム接続"),
		"the game's own connection is reported separately from the test dial")
	var own := text.find("[3/3]")
	var live := text.find("いま動いているゲーム接続")
	check(own >= 0 and live > own,
		"and after it, so the reader knows which is which")

	# And where the evidence runs out, it says so rather than picking the
	# likeliest story. There is no session at all in this test, so the one
	# thing the report must NOT do is tell the player their room code is wrong.
	check(not text.contains("部屋が違"),
		"it does not assert a room mismatch it has no evidence for")
	check(text.contains("未確定"),
		"it says outright when something is undetermined")

	panel.queue_free()
	await _frames(2)

## Reported as "there is about half a second of lag".
##
## It was not the network. The relay measures 33ms round trip from here under
## the game's own traffic. The clock was the problem: it advanced only on the
## host, so on the guardian's device it moved only when a packet happened to
## carry a new time -- and the packet that did was the once-a-second pong. The
## whole world stood still for a second and then jumped sixty ticks, which
## averages out to exactly the half second that was reported.
func _test_the_guest_clock_keeps_running() -> void:
	_current = "guest clock"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	check(not Clock.is_host, "the guest is not the host")

	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(5000, "host-test"))
	await _pump(pair, 3)
	check(Clock.tick >= 5000, "a welcome sets the clock (%d)" % Clock.tick)

	# Now go quiet on the CONTROL channel, exactly as the real link does between
	# pongs, and watch the clock. It has to keep moving on its own.
	var before := Clock.tick
	await _physics(30)
	var moved := Clock.tick - before
	check(moved >= 25,
		"the clock runs between packets (%d ticks in 30 frames)" % moved)

	# And it follows the host rather than drifting away from it. A snapshot
	# arrives saying the host is well ahead; the clock has to close that gap.
	var s := Snapshot.new()
	s.tick = Clock.tick + 20
	s.runner_position = main.runner.global_position
	s.runner_velocity = Vector2.ZERO
	s.hp = Balance.RUNNER_MAX_HP
	host_side.send(NetTransport.Channel.SNAPSHOT, NetTransport.Reliability.UNRELIABLE,
		s.encode())
	var target := s.tick
	await _pump(pair, 2)
	await _physics(40)
	check(Clock.tick >= target,
		"it catches up to a host that is ahead (%d vs %d)" % [Clock.tick, target])

	# Sixteen bits on the wire wrap every eighteen minutes. Widening has to
	# survive that, or a long session sees the host leap back in time.
	check(Clock.widen(3, 65530) == 65539,
		"a tick that has wrapped widens forwards (%d)" % Clock.widen(3, 65530))
	check(Clock.widen(65530, 65539) == 65530,
		"and one just before the wrap stays put (%d)" % Clock.widen(65530, 65539))

	session.queue_free()
	Clock.is_host = true
	Clock.follow_target = -1
	await _frames(2)

## The guardian's reticle is sent on a clock of its own, not once per rendered
## frame. Per frame is 60 messages a second on one phone and 120 on another,
## all of them queued ahead of the snapshots the same device is waiting for.
func _test_the_aim_stream_is_rationed() -> void:
	_current = "aim rate"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)

	host_side.poll()
	# Count against simulation time. Fixed-fps headless runs may execute 50-80
	# frames per wall second depending on the machine, but the network throttle
	# is driven by frame delta and must remain about 20 per simulated second.
	var frames := Engine.physics_ticks_per_second
	var aims := 0
	for _i in frames:
		await _pump(pair, 1)
		for p in host_side.poll():
			if int(p["channel"]) == NetTransport.Channel.AIM:
				aims += 1
	var elapsed := float(frames) / float(Engine.physics_ticks_per_second)
	var rate := float(aims) / maxf(elapsed, 0.001)
	check_range(rate, 8.0, 30.0,
		"the aim stream is around 20 a second, not one per frame (%.0f/s)" % rate)

	session.queue_free()
	Clock.is_host = true
	Clock.follow_target = -1
	await _frames(2)

## Sizes are a setting too. Hands differ more than screens do.
func _test_controls_can_be_resized() -> void:
	_current = "control size"
	ControlLayout.forget()
	var view := Vector2(1280, 720)
	var before: float = ControlLayout.layout("guardian", view, false)["slot_1"]["radius"]

	ControlLayout.set_size("guardian", "slot_1", 1.5)
	var bigger: Dictionary = ControlLayout.layout("guardian", view, false)["slot_1"]
	check_near(float(bigger["radius"]), before * 1.5, 0.5,
		"a resized control is the size it was set to")
	# The hit area has to grow with the drawing, which is the whole reason the
	# two come from one table.
	var edge: Vector2 = bigger["center"] + Vector2(before * 1.3, 0.0)
	check(ControlLayout.hit("guardian", view, false, edge) == "slot_1",
		"and a thumb on the new edge presses it")

	# Moving it afterwards must not silently undo the size, and vice versa.
	ControlLayout.set_place("guardian", "slot_1", Vector2(0.5, 0.5))
	check_near(ControlLayout.size_of("guardian", "slot_1"), 1.5, 0.01,
		"moving a control keeps its size")
	ControlLayout.set_size("guardian", "slot_1", 0.8)
	var moved: Vector3 = ControlLayout.saved_place("guardian", "slot_1")
	check(is_equal_approx(moved.x, 0.5) and is_equal_approx(moved.y, 0.5),
		"and resizing keeps its place (%s)" % moved)

	# Clamped at both ends: too small to hit, or big enough to swallow its
	# neighbours, are both layouts nobody can use.
	ControlLayout.set_size("guardian", "slot_1", 9.0)
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MAX,
		0.01, "a size is capped at the top")
	ControlLayout.set_size("guardian", "slot_1", 0.01)
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MIN,
		0.01, "and at the bottom")

	ControlLayout.save()
	ControlLayout.reload()
	check_near(ControlLayout.size_of("guardian", "slot_1"), ControlLayout.SIZE_MIN,
		0.01, "a size survives a reload")
	ControlLayout.reset("guardian")
	ControlLayout.save()
	check_near(ControlLayout.size_of("guardian", "slot_1"), 1.0, 0.01,
		"and reset returns it to the default")
	ControlLayout.forget()

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
	hub._pan_fingers[1] = -1.0
	hub._pan_fingers[2] = 1.0
	hub._refresh_pan()
	check(is_zero_approx(hub.pan_axis), "two thumbs on opposite arrows cancel")
	hub._pan_fingers.clear()
	hub._refresh_pan()

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

## Reported as "I thought I killed it but it just stopped and never went away",
## and, in the same breath, "characters are floating off the ground".
##
## One cause. Enemies were identified over the wire by their POSITION IN A LIST
## -- the index into get_nodes_in_group("enemy") -- and that list gets shorter
## every time one of them dies. So the first kill shifts every later enemy's id
## by one, and from then on the guardian's device moves each enemy to a
## different enemy's position: a walker lands on a flyer's height and hangs in
## the air. Meanwhile the dead one is never removed on the guardian's side at
## all, because the message that says it died only played a sound.
func _test_a_dead_enemy_stays_dead_on_both_screens() -> void:
	_current = "dead enemies"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var host_side: LoopbackTransport = pair[0]
	var guest_side: LoopbackTransport = pair[1]
	var host := HostSession.new()
	host.main = main
	host.transport = host_side
	add_child(host)
	await _frames(2)

	var enemies: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node2D:
			enemies.append(n as Node2D)
	check(enemies.size() >= 3, "the stage has enemies to work with (%d)" % enemies.size())
	if enemies.size() < 3:
		host.queue_free()
		return

	# Every enemy carries a name of its own that does not depend on who else is
	# alive. That is the whole fix, so it is what the check names.
	var ids: Dictionary = {}
	for e in enemies:
		# Read defensively. A missing property comes back null, and int(null) is
		# a runtime error that ABORTS the test without failing it -- which is
		# how the first run of this reported "0 failed" while checking nothing.
		var raw = e.get("net_id")
		check(raw != null, "%s carries a net_id at all" % e.name)
		var id: int = int(raw) if raw != null else -1
		check(id >= 0, "every enemy has a stable id (%s has %d)" % [e.name, id])
		check(not ids.has(id), "and the ids are unique (%d seen twice)" % id)
		ids[id] = e

	var doomed: Node2D = enemies[0]
	var survivor: Node2D = enemies[2]
	var survivor_id: int = int(survivor.get("net_id")) \
		if survivor.get("net_id") != null else -1
	var survivor_where: Vector2 = survivor.global_position

	doomed.take_damage(99, "snipe")
	await _frames(3)
	check(not is_instance_valid(doomed) or doomed.is_queued_for_deletion(),
		"the host removes the one that died")

	# The survivor's id must not have moved just because someone else died.
	var after = survivor.get("net_id")
	check(after != null and int(after) == survivor_id,
		"a death does not renumber the enemies that are left (%d -> %s)"
			% [survivor_id, str(after)])
	check(survivor.global_position.distance_to(survivor_where) < 40.0,
		"and does not teleport them anywhere (%.0fpx)"
			% survivor.global_position.distance_to(survivor_where))

	host.queue_free()
	Clock.is_host = true
	await _frames(2)
	await _test_the_guardian_sees_the_enemy_go()

## The other half, on the guardian's device: the message that says an enemy died
## has to actually remove it, not merely play a noise over a corpse that stays
## standing there for the rest of the run.
func _test_the_guardian_sees_the_enemy_go() -> void:
	_current = "dead enemies (guest)"
	await _boot()
	var pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = pair[0]
	var host_side: LoopbackTransport = pair[1]
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)

	var victim: Node2D = null
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Node2D:
			victim = n as Node2D
			break
	check(victim != null, "the guest has enemies on screen")
	if victim == null:
		session.queue_free()
		return
	var raw = victim.get("net_id")
	check(raw != null, "the enemy has a net_id to be named by")
	var id: int = int(raw) if raw != null else 0

	host_side.send(NetTransport.Channel.EVENT, NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.world(Protocol.World.ENEMY_DIE, victim.global_position,
			Vector2.ZERO, id))
	await _pump(pair, 4)
	check(not is_instance_valid(victim) or victim.is_queued_for_deletion(),
		"the enemy is gone from the guardian's screen too")

	session.queue_free()
	Clock.is_host = true
	await _frames(2)

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
	# Positions cross as 16 bits each: x in half-pixels, y in eighths. A
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
	hub._touch_down(11, _place("scope", view, "shared"))
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

## A tap on a WORLD point: converted to the screen the way a finger would find
## it, so the whole screen-to-world path is exercised rather than bypassed.
##
## The camera is brought to the point first when it would otherwise be off the
## edge. A finger cannot touch what is not on the screen, so a test that pokes
## an off-screen coordinate is testing nothing -- and the camera lags the runner
## by design, so simply moving the runner is not enough to bring it into view.
func _tap_world(point: Vector2) -> void:
	var rect: Rect2 = main.get_viewport().get_visible_rect()
	var screen: Vector2 = main.get_viewport().get_canvas_transform() * point
	# On screen is not enough: on a shared screen the left of it belongs to the
	# runner, and a guardian's touch there is ignored by design. Bring the
	# camera round until the point is somewhere a guardian could actually put a
	# thumb, which is what a guardian would do.
	if not rect.grow(-40.0).has_point(screen) \
			or not TouchLayout.hit_rect(screen, TouchLayout.AIM_ZONE, rect.size, false):
		main.camera.global_position = point
		await _physics(2)
		screen = main.get_viewport().get_canvas_transform() * point
	main.input_hub._touch_down(21, screen)
	main.input_hub._touch_up(21)
	await _frames(4)

func _test_a_swipe_scrolls_the_view() -> void:
	_current = "swipe to scroll"
	await _boot()
	var hub: InputHub = main.input_hub
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	hub.solo_role = "guardian"
	main.runner.global_position = Vector2(2600, 300)
	main.runner.velocity = Vector2.ZERO
	await _physics(6)
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

	# A long sideways drag scrolls, and stops moving the reticle while it does.
	hub._touch_down(2, start)
	var aimed: Vector2 = hub.aim_world()
	for i in range(6):
		hub._touch_move(2, start + Vector2(-40.0 * float(i + 1), 0.0))
	await _physics(4)
	hub._touch_up(2)
	check(main.guardian_pan > 60.0,
		"a long sideways swipe scrolls the view (%.0f)" % main.guardian_pan)
	check(hub.aim_world().distance_to(aimed) < 20.0,
		"and the reticle stays on the ground it was on (%.0fpx)"
			% hub.aim_world().distance_to(aimed))
	hub.solo_role = ""


## A transport that dials and never comes up. Two lines of behaviour, which is
## all the watchdog reads: the link is not open, and re-dialling is counted.
class DeadLink extends NetTransport:
	var redials: int = 0

	func poll() -> Array[Dictionary]:
		return []

	func send(_channel: int, _reliability: int, _payload: PackedByteArray) -> void:
		pass

	func is_connected_to_peer() -> bool:
		return false

	func is_link_open() -> bool:
		return false

	func reconnect() -> String:
		redials += 1
		return ""

