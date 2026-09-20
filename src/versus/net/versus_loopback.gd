class_name VersusLoopback
extends VersusTransport
## Four transports wired to each other in one process, with latency, jitter and
## loss in between.
##
## The reason the four-peer design can be tested at all. `src/net/loopback_
## transport.gd` does this for two, and its `pair()` builds a mutual
## single-pointer link -- `a.peer = b; b.peer = a` -- which has no concept of
## "which of the others". This is a bus with addressing.
##
## Delivery is driven by `advance(delta)`, not by wall-clock time, so a headless
## probe runs it deterministically and as fast as the CPU allows. A test that
## fails has to fail every time, or it is not a test.

var latency: float = 0.0        ## one-way, seconds
var jitter: float = 0.0         ## uniform +/-, seconds
var loss: float = 0.0           ## 0..1, unreliable channels only

var _id: int = -1
var _bus: Array = []            ## every VersusLoopback in the mesh
var _clock: float = 0.0
var _inbox: Array[Dictionary] = []
var _ready: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _open: bool = true

func _init(peer_id: int = -1, seed_value: int = 12345) -> void:
	_id = peer_id
	_rng.seed = seed_value * 7919 + peer_id

## A mesh of `count` peers. Peer 0 is the host by convention (HOST_PEER).
static func mesh(count: int, one_way_latency: float = 0.0,
		packet_loss: float = 0.0, packet_jitter: float = 0.0,
		seed_value: int = 12345) -> Array:
	var all: Array = []
	for i in range(count):
		var t := VersusLoopback.new(i, seed_value)
		t.latency = one_way_latency
		t.loss = packet_loss
		t.jitter = packet_jitter
		all.append(t)
	for t in all:
		t._bus = all
	return all

func local_peer() -> int:
	return _id

func peers() -> Array[int]:
	var out: Array[int] = []
	for t in _bus:
		if t._id != _id and t._open:
			out.append(t._id)
	return out

func send_to(peer_id: int, channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	if not _open:
		return
	for t in _bus:
		if t._id == peer_id:
			_deliver(t, channel, reliability, payload)
			return

func broadcast(channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	if not _open:
		return
	for t in _bus:
		if t._id != _id:
			_deliver(t, channel, reliability, payload)

func _deliver(to: VersusLoopback, channel: int, reliability: int,
		payload: PackedByteArray) -> void:
	if not to._open:
		return
	# Only unreliable channels drop. A reliable one arrives late, exactly as it
	# would over a real link.
	if reliability == Reliability.UNRELIABLE and _rng.randf() < loss:
		return
	var delay := latency
	if jitter > 0.0:
		delay += _rng.randf_range(-jitter, jitter)
	to._inbox.append({
		"at": to._clock + maxf(0.0, delay),
		"from": _id,
		"channel": channel,
		"payload": payload,
	})

func advance(delta: float) -> void:
	_clock += delta
	var flying: Array[Dictionary] = []
	for p in _inbox:
		if float(p["at"]) <= _clock:
			_ready.append(p)
		else:
			flying.append(p)
	_inbox = flying
	_ready.sort_custom(func(x, y): return float(x["at"]) < float(y["at"]))

func poll() -> Array[Dictionary]:
	var out := _ready
	_ready = []
	return out

func in_flight() -> int:
	return _inbox.size()

## Pull one peer off the link, to test what the others do about it.
func close() -> void:
	_open = false
	_inbox.clear()
	_ready.clear()
