extends Node
## Four real processes, four real sockets, one real relay, one real match.
##
## The loopback probe proves the design and the ws probe proves the plumbing.
## This is the two together: four operating-system processes that were told
## nothing about each other, meeting in a room and playing a match, with each
## one asserting only what IT can see. Neither side is told what the other is
## doing, which is the whole point -- an agreement that both halves were
## written to expect is not an agreement.
##
## Driven by tools/versus4.sh. Arguments:
##   --live-role=host|runner|guardian
##   --live-code=XXXXXX
##   --live-relay=ws://...

var failures: Array[String] = []
var role: String = "host"
var code: String = ""
var relay: String = "ws://localhost:8787"

var link := VersusWsTransport.new()
var host: VersusHost = null
var client: VersusClient = null
var _ticks: int = 0
var _built_once: bool = false
## Wall clock, not ticks. A real socket needs real time, and this probe must
## never be run with --fixed-fps: that mode runs as fast as the CPU allows, so
## a timeout counted in ticks expires before the connection has had a
## millisecond to happen. It did, on the first run of this file.
var _opened_at: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("  [%s] ok    %s" % [role, label])
	else:
		failures.append(label)
		print("  [%s] FAIL  %s" % [role, label])

func _ready() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--live-role="):
			role = arg.split("=", true, 1)[1]
		elif arg.begins_with("--live-code="):
			code = arg.split("=", true, 1)[1]
		elif arg.begins_with("--live-relay="):
			relay = arg.split("=", true, 1)[1]
	_opened_at = Time.get_ticks_msec()
	var err := link.open_room(relay, code, "live-" + role + str(Time.get_ticks_usec() % 9999))
	if not err.is_empty():
		_bail("could not dial: " + err)

func _physics_process(_delta: float) -> void:
	link.poll_socket()
	_ticks += 1

	if host == null and client == null:
		if not link.is_open():
			if Time.get_ticks_msec() - _opened_at > 15000:
				_bail("no relay answered at %s in 15s" % relay)
			return
		if role == "host":
			if link.local_peer() != VersusTransport.HOST_PEER:
				_bail("someone else is index %d" % link.local_peer())
				return
			host = VersusHost.new()
			host.start(link, _world(), 4242)
		else:
			client = VersusClient.new()
			var want := VersusRoster.SEAT_B_RUNNER if role == "runner" \
				else (VersusRoster.SEAT_A_GUARDIAN if link.local_peer() == 2
					else VersusRoster.SEAT_B_GUARDIAN)
			client.start(link, want)
		return

	if host != null:
		host.step(_seat_for(0))
		if _ticks == 420:
			check(host.roster.can_play(),
				"both runners are seated: %s" % host.roster.describe())
			check(host.roster.filled() == 4, "and so are both guardians")
		if _ticks == 900:
			check(host.builds.size() >= 1,
				"a guardian's platform arrived and was built (%d)" % host.builds.size())
			check(host.world.floor_below(Vector2(7220.0, 60.0), 500.0) < INF,
				"and it is real ground in the host's world")
			check(host.match_rules.ledger.conserved(),
				"the ledger held for %d ticks of live play" % host.match_rules.tick)
			_finish()
		return

	if client != null:
		var mine = _seat_for(1) if role == "runner" else null
		client.step(mine)
		if role == "guardian" and client.connected and not _built_once \
				and _ticks > 500:
			_built_once = true
			client.request_build(Vector2(7220.0, 150.0), 1)
		if _ticks == 420:
			check(client.connected, "seated by the host as %s"
				% (VersusRoster.seat_name(client.seat) if client.seat >= 0 else "?"))
			check(client.seen_world, "and receiving the world")
		if _ticks == 900:
			check(client.coins.size() == VersusRules.COIN_TOTAL,
				"all %d coins arrived" % VersusRules.COIN_TOTAL)
			check(client.builds.size() >= 1,
				"and the platform one of the guardians built (%d)" % client.builds.size())
			check(client.collision().floor_below(Vector2(7220.0, 60.0), 500.0) < INF,
				"which is ground on this screen too")
			_finish()

## A runner wandering its own half, so coins actually get picked up.
func _seat_for(team: int) -> VersusMatch.Seat:
	var s := VersusMatch.Seat.new()
	s.team = team
	var sweep := sin(float(_ticks) * 0.02 + float(team) * PI) * 800.0
	s.position = Vector2(7450.0 + sweep, 200.0)
	s.facing = 1 if sweep < 0.0 else -1
	s.alive = true
	s.can_act = true
	s.strike_seq = 0
	return s

func _world() -> ArenaStage:
	Stage.use(Stage.Which.GREENFIELD)
	var rects: Array[Rect2] = Stage.ground()
	rects.append_array(Stage.solid_decor())
	return ArenaStage.new(rects)

func _bail(why: String) -> void:
	print("  [%s] FAIL  %s" % [role, why])
	link.close()
	get_tree().quit(1)

func _finish() -> void:
	link.close()
	print("[%s] %d checks failed" % [role, failures.size()])
	for f in failures:
		push_error("versus live probe [%s]: %s" % [role, f])
	get_tree().quit(1 if failures.size() > 0 else 0)
