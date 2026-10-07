extends "res://test/logic/logic_suite.gd"
## Two devices: EOS rooms, the link, snapshots, rewind, reconnection, migration.

func _test_eos_contracts() -> void:
	_current = "EOS room and migration contracts"
	check(EosCoopLobby.valid_code("012345"), "leading-zero room codes are valid")
	check(not EosCoopLobby.valid_code("12345") and not EosCoopLobby.valid_code("12A456"),
		"room codes are exactly six decimal digits")
	check(EosCoopLobby.stage_identity_matches("1-3", 4, "1-3", 7),
		"EOS stage agreement uses the stable visible stage key")
	check(not EosCoopLobby.stage_identity_matches("1-2", 7, "1-3", 7),
		"EOS stage agreement rejects different visible stage keys")
	check(EosCoopLobby.stage_identity_matches("", 7, "1-3", 7),
		"EOS stage agreement accepts legacy integer attributes")
	var searched := LobbyAttrs.new()
	searched.attributes = [{"key": "ROOM_CODE", "value": "012345"},
		{"key": "STAGE_KEY", "value": "1-3"}, {"key": "STAGE", "value": 7},
		{"key": "STARTED", "value": 1}]
	check(EosCoopLobby._attribute_string(searched, EosCoopLobby.STAGE_KEY_ATTRIBUTE, "") == "1-3",
		"a searched room's upper-cased stage key is readable")
	check(EosCoopLobby._attribute_int(searched, "stage", -1) == 7,
		"a searched room's upper-cased stage id is readable")
	check(EosCoopLobby._attribute_int(searched, "started", 0) == 1,
		"a searched room's upper-cased started flag is readable")
	check(EosCoopLobby._attribute_int(searched, "build", -1) == -1,
		"a missing room attribute falls back")
	var blob := PackedByteArray()
	blob.resize(2505)
	for i in blob.size():
		blob[i] = i & 0xff
	var encoded := var_to_bytes({
		"version": MigrationState.VERSION,
		"captured_ms": Time.get_ticks_msec(),
		"stage": Stage.current(),
		"blob": blob,
	})
	var chunks := MigrationState.chunks(encoded, 7, 99)
	check(chunks.size() >= 3, "a large checkpoint is split across EOS-safe packets")
	var restored := PackedByteArray()
	var digest := PackedByteArray()
	for index in chunks.size():
		check(chunks[index].size() <= EosTransport.PAYLOAD_LIMIT,
			"migration chunk %d stays under the transport cap" % index)
		var parsed := Protocol.reader(chunks[index])
		check(parsed[0] == Protocol.Msg.MIGRATION_CHUNK, "chunk carries its message kind")
		var reader: StreamPeerBuffer = parsed[1]
		check(reader.get_u32() == 7 and reader.get_u32() == 99,
			"chunk carries generation and authority tick")
		check(reader.get_u16() == index and reader.get_u16() == chunks.size(),
			"chunk index and total are stable")
		check(reader.get_u16() == encoded.size(), "chunk carries complete payload size")
		var got_digest = reader.get_data(8)
		if digest.is_empty():
			digest = got_digest[1]
		check(got_digest[0] == OK and got_digest[1] == digest,
			"every chunk carries the same digest")
		var part = reader.get_data(reader.get_available_bytes())
		if part[0] == OK:
			restored.append_array(part[1])
	check(restored == encoded and MigrationState.digest(restored) == digest,
		"complete migration frame reassembles without corruption")
	var decoded := MigrationState.decode(restored)
	check(decoded.get("blob", PackedByteArray()) == blob,
		"decoded checkpoint preserves the authoritative bytes")

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
	# The host applies its own cost table rather than whatever the client
	# deducted. (The platform costs nothing now; this is still the host's sum.)
	check_near(main.guardian.gauge, Balance.GAUGE_MAX - Balance.COST_PLATFORM, 1.0,
		"the host charged the gauge by its own costs, not the client's")

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
	# 0.9.15 used wire 25 with the previous single-tier lava layout. Exercise that exact
	# older peer, not just +1: equal wire must never construct different stages.
	check(Protocol.VERSION > 25, "rebuilt lava rejects the previous wire 25")
	var stale := PackedByteArray([Protocol.Msg.HELLO, 25])
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
	# Through TranslationServer, as the report is: the test runs in whatever
	# locale the machine has.
	check(joined.contains(TranslationServer.translate("再接続回数: %d") % 2),
		"and counts the reconnections")
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
	# The report reads EOS and the live connection only; the relay dial it once
	# ran ([1/3]-[3/3]) went with the Cloudflare relay. Every line passes
	# through tr(), so it is compared in the machine's own locale.
	var t := func(text: String) -> String: return TranslationServer.translate(text)
	var panel := NetDiagnostics.new()
	add_child(panel)
	var waited := 0.0
	var done: String = t.call("=== ここまでをコピーして送ってください ===")
	while not panel.report().contains(done) and waited < 60.0:
		await get_tree().process_frame
		waited += 0.016
	var text := panel.report()
	check(text.contains(done), "the report finishes")
	check(text.contains(t.call("ビルド %s / 通信プロトコル v%d") % [Balance.BUILD_ID, Protocol.VERSION]),
		"it names the build and the protocol it speaks")
	check(text.contains("Godot "), "and the engine it ran on")
	check(text.contains("Product User ID"), "it reports the EOS sign-in")

	# The game's own connection has its own section. There is no game above
	# this panel here, so the one thing the report must NOT do is invent a
	# room mismatch: it has to say it does not know.
	check(text.contains(t.call("── いま動いているゲーム接続 ──")),
		"the game's own connection is reported in its own section")
	check(not text.contains(t.call("部屋が違")),
		"it does not assert a room mismatch it has no evidence for")
	check(text.contains(t.call("  この画面からゲーム本体が見つかりません（未確定）")),
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

## The copied report is meant to be pasted to whoever is helping: it says that
## the device signed in and is on a network, not who it is or where.
func _test_a_shared_report_hides_who_it_is() -> void:
	_current = "shared diagnostic"
	var puid := "0002a1b2c3d4e5f60718293a4b5c6d7e"
	var private := {
		puid: NetDiagnostics.short_id(puid),
		"192.168.1.23": "<IPv4>",
		"fd00::1:23": "<IPv6>",
	}
	var text := "  Product User ID: %s\nこの端末のIP 192.168.1.23, fd00::1:23\nseen %s again" % [puid, puid]
	var shared := NetDiagnostics.masked(text, private)
	check(not shared.contains(puid) and shared.contains("…6d7e"),
		"the product user id is cut to its last four characters, everywhere")
	check(not shared.contains("192.168.1.23") and not shared.contains("fd00::1:23")
		and shared.contains("<IPv4>") and shared.contains("<IPv6>"),
		"local addresses are replaced, keeping which kind they were")
	check(NetDiagnostics.masked(text, {}) == text, "nothing is changed without a reason")
	check(NetDiagnostics.short_id("abc") == "…", "a short id gives nothing away")

