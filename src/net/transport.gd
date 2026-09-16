class_name NetTransport
extends RefCounted
## What the netcode is written against, so none of it depends on EOS.
##
## EOS has no first-party Godot support, and this environment cannot reach Epic
## to test an integration. Writing the netcode directly against the EOS SDK
## would make the whole thing unverifiable here. Instead everything above this
## interface -- rewind, interpolation, reconciliation, bandwidth budgets -- is
## written against these four methods, and there are two implementations:
##
##   LoopbackTransport  in-process, with injected latency and packet loss.
##                      Runs headlessly, which is how the rescue is tested.
##   EOSTransport       EOS_P2P_SendPacket / EOS_P2P_ReceivePacket.
##
## Swapping EOS for something else later is a one-file job. See
## docs/netcode.md section 12.

## Channels, mapped onto EOS P2P channel ids. Kept in one place because the
## reliability choice per channel is a design decision, not an implementation
## detail -- see docs/netcode.md section 7.
enum Channel {
	SNAPSHOT = 0,   ## host -> client, 30Hz, unreliable: a lost one is replaced in 33ms
	EVENT = 1,      ## host -> client, reliable ordered: spawns, deaths, gates
	COMMAND = 2,    ## client -> host, reliable ordered: place, fire
	AIM = 3,        ## client -> host, unreliable: carries its own redundancy
	CONTROL = 4,    ## both ways, reliable ordered: ping, handshake, resync
}

enum Reliability { UNRELIABLE, RELIABLE_UNORDERED, RELIABLE_ORDERED }

## EOS caps a P2P packet at 1170 bytes. Anything we design has to fit, which is
## why the resync payload is budgeted rather than assumed.
const MAX_PACKET_BYTES: int = 1170

func send(_channel: int, _reliability: int, _payload: PackedByteArray) -> void:
	push_error("NetTransport.send is abstract")

## Returns every packet that has arrived since the last call, oldest first, as
## {"channel": int, "payload": PackedByteArray}.
func poll() -> Array[Dictionary]:
	return []

func is_connected_to_peer() -> bool:
	return false

func close() -> void:
	pass
