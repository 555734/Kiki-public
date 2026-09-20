class_name VersusTransport
extends RefCounted
## What a four-peer link has to be able to do.
##
## Deliberately a NEW interface rather than a wider NetTransport. The
## cooperative one cannot be stretched: `send(channel, reliability, payload)`
## has no destination and `poll()` returns packets with no sender, so it is
## point-to-point in its type signature and not merely in its implementation
## (src/net/transport.gd:35-40). Raising a peer limit would not have given it an
## addressing story; it would have given it a broadcast bus with no way to send
## one client a correction meant only for them.
##
## docs/coin-battle-plan.md:259-273 asks for exactly this shape, and says in the
## same breath not to replace the co-op layer with it. Both are true here: this
## file is additive and `src/net/*` is untouched.

## Same split as the co-op link, for the same reasons: snapshots may be dropped,
## commands may not.
enum Channel { SNAPSHOT = 0, INPUT = 1, COMMAND = 2, CONTROL = 3 }
enum Reliability { UNRELIABLE = 0, RELIABLE = 1 }

## The relay's per-message cap, which everything here has to fit inside.
const MAX_PACKET_BYTES: int = 1170

## The host is always this peer id. Seats are assigned by the host and are a
## different thing entirely -- see VersusRoster.
const HOST_PEER: int = 0

func send_to(_peer_id: int, _channel: int, _reliability: int,
		_payload: PackedByteArray) -> void:
	pass

func broadcast(_channel: int, _reliability: int,
		_payload: PackedByteArray) -> void:
	pass

## Everything that has arrived since the last call, as
## {"from": int, "channel": int, "payload": PackedByteArray}.
##
## `from` is the part the co-op interface could not express, and it is what
## makes four peers possible at all: without it the host cannot tell whose
## input a packet is.
func poll() -> Array[Dictionary]:
	return []

## Who this transport can currently reach. Not a count and not a bool: with
## four peers "is anyone there" is not a useful question -- "is seat 3 still
## there" is.
func peers() -> Array[int]:
	return []

func local_peer() -> int:
	return -1

func is_host() -> bool:
	return local_peer() == HOST_PEER

func close() -> void:
	pass
