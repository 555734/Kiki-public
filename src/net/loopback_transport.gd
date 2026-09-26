class_name LoopbackTransport
extends NetTransport
## Two transports wired to each other in one process, with a latency and loss
## model in between.
##
## This is what makes the network design testable without a network. A test can
## say "150ms one way, 5% loss, 30ms of jitter" and then assert that the runner
## still gets rescued -- which is the only claim in docs/netcode.md that would
## otherwise have to be taken on trust.
##
## Delivery is driven by `advance(delta)` rather than by wall-clock time, so a
## headless test runs it deterministically and as fast as the CPU allows.

var latency: float = 0.0        ## one-way, seconds
var jitter: float = 0.0         ## uniform +/- , seconds
var loss: float = 0.0           ## 0..1, applied to unreliable channels only
var peer: LoopbackTransport = null
## Stands in for an EOS lobby's answer to peer_identity().
##
## The entitlement exchange asks the transport who the other device is, because
## asking the packet would be asking the thing under test. There is no lobby in
## a loopback pair, so a test that wants to drive the friend pass sets this the
## way EOS would have. Production never touches it: EosTransport overrides
## peer_identity() and reads the real lobby.
var stub_identity: Dictionary = {"puid": "", "room_kind": ""}

var _clock: float = 0.0
var _inbox: Array[Dictionary] = []     ## {"at": float, "channel": int, "payload": ...}
var _ready_queue: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

## Deterministic by default: a test that fails should fail every time.
func _init(seed_value: int = 12345) -> void:
	_rng.seed = seed_value

func peer_identity() -> Dictionary:
	return stub_identity

static func pair(one_way_latency: float, packet_loss: float = 0.0,
		packet_jitter: float = 0.0) -> Array[LoopbackTransport]:
	var a := LoopbackTransport.new(1)
	var b := LoopbackTransport.new(2)
	a.peer = b
	b.peer = a
	for t in [a, b]:
		t.latency = one_way_latency
		t.loss = packet_loss
		t.jitter = packet_jitter
	return [a, b]

func send(channel: int, reliability: int, payload: PackedByteArray) -> void:
	if peer == null:
		return
	# Only unreliable channels drop. Reliable ones are EOS's problem in
	# production and arrive here, late, exactly as they would there.
	if reliability == Reliability.UNRELIABLE and _rng.randf() < loss:
		return
	var delay := latency
	if jitter > 0.0:
		delay += _rng.randf_range(-jitter, jitter)
	peer._inbox.append({
		"at": peer._clock + maxf(0.0, delay),
		"channel": channel,
		"payload": payload,
	})

## Advances the link. Anything whose delivery time has come moves to the queue
## that `poll` drains.
func advance(delta: float) -> void:
	_clock += delta
	var still_flying: Array[Dictionary] = []
	for p in _inbox:
		if float(p["at"]) <= _clock:
			_ready_queue.append(p)
		else:
			still_flying.append(p)
	_inbox = still_flying
	# Jitter can reorder arrivals; ordered channels are re-sorted, unreliable
	# ones are left scrambled because that is what the real link does.
	_ready_queue.sort_custom(func(x, y): return float(x["at"]) < float(y["at"]))

func poll() -> Array[Dictionary]:
	var out := _ready_queue
	_ready_queue = []
	return out

func is_connected_to_peer() -> bool:
	return peer != null

func close() -> void:
	peer = null
	_inbox.clear()
	_ready_queue.clear()

## How many packets are still on the wire. Used by tests to wait for quiet.
func in_flight() -> int:
	return _inbox.size()
