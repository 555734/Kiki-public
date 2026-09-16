extends Node
## The authoritative tick clock.
##
## Everything in the game that varies with time and has to agree across two
## devices reads its time from here instead of accumulating its own `delta`.
## Two reasons, and the second is the one that matters:
##
## 1. Accumulated floats drift. A moving platform that adds `delta` every frame
##    ends up in a slightly different place on a device that dropped a frame.
## 2. If a thing is a pure function of the tick, **it never has to be sent over
##    the network.** Moving platforms, laser phases and untouched enemy patrols
##    all collapse to zero bytes per frame. See docs/netcode.md section 4.
##
## The host advances the tick from its own physics loop. A client sets the tick
## from the snapshots it receives and interpolates between them, so both sides
## evaluate the same functions at the same tick and get identical answers.

## Physics runs at 60Hz; one tick is one physics frame.
const HZ: int = 60
const DT: float = 1.0 / float(HZ)

## Ticks since the run started. Authoritative on the host, followed on a client.
var tick: int = 0

## True on the machine that owns the simulation. Offline play is a host with no
## clients, which is why single player needs no special case anywhere.
var is_host: bool = true

## What the host's tick is believed to be right now. A client sets this from
## every snapshot it receives; -1 means there is nothing to follow.
var follow_target: int = -1

## Further out of step than this and the clock is SET rather than steered. A
## gap this large is a resync, not drift, and easing across it would take a
## second of visibly wrong time.
const RESYNC_JUMP: int = 30

func _ready() -> void:
	process_priority = -100   # advance before anything reads it

## The tick advances on BOTH machines, every frame.
##
## It used to advance only on the host, which made a client's clock a staircase:
## it moved only when a packet happened to carry a new time. Because that packet
## was the once-a-second pong, the guardian's whole world stood still for a
## second and then jumped sixty ticks -- everything they saw was on average half
## a second old, and they reported it as exactly that. Snapshots arrive thirty
## times a second and are the right thing to follow, but the fix is not to
## follow them harder: a clock has to RUN. This one runs locally and is steered
## towards the host's, which is what keeps it smooth between packets and honest
## across them.
func _physics_process(_delta: float) -> void:
	tick += 1
	if is_host or follow_target < 0:
		return
	# The host's clock did not stop while we were not being told about it.
	follow_target += 1
	var error := follow_target - tick
	if absi(error) > RESYNC_JUMP:
		tick = follow_target
	elif error > 0:
		tick += 1        # run a frame fast to close the gap
	elif error < 0:
		tick -= 1        # or hold still for one, to fall back

## Snapshots carry the tick in sixteen bits to save three bytes thirty times a
## second. Sixteen bits wrap every eighteen minutes, so the full value has to be
## reconstructed from the one we already believe -- otherwise a session that
## lasts past the wrap sees the host's clock leap backwards by eighteen minutes.
static func widen(low16: int, near: int) -> int:
	var candidate := (near & ~0xFFFF) | (low16 & 0xFFFF)
	if candidate - near > 32768:
		candidate -= 65536
	elif near - candidate > 32768:
		candidate += 65536
	return candidate

## Seconds since the run started, optionally shifted by a per-entity phase.
## This is the function every time-varying entity should call.
func seconds(phase_offset: float = 0.0) -> float:
	return float(tick) * DT + phase_offset

## Seconds at an arbitrary tick -- used by the rewind buffer when it replays the
## past, so entities evaluated during a resimulation see the past, not the now.
func seconds_at(at_tick: int, phase_offset: float = 0.0) -> float:
	return float(at_tick) * DT + phase_offset

func reset(to_tick: int = 0) -> void:
	tick = to_tick

## How many ticks a duration in seconds is, rounded up: used for expiry stamps
## so a hologram never dies a frame early on one device and a frame late on the
## other.
static func ticks_for(seconds_value: float) -> int:
	return int(ceil(seconds_value * float(HZ)))
