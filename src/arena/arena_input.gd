class_name ArenaInput
extends RefCounted
## Four independent local inputs, one per fighter.
##
## docs/coin-battle-plan.md 4.3: four gamepads on one machine, with two buttons
## and a stick each. P1 is "その場で四人で遊べる最小版", so the thing this file
## has to get right is that seat 2's stick never moves seat 1's fighter.
##
## Godot's action map cannot do that without help. An action fires for ANY
## device unless every event in it pins a device id, so `p1_jump` would be four
## players' jump button. Rather than writing sixteen device-pinned actions into
## project.godot -- shared configuration, for a mode the menu does not even
## reach yet -- the pads are polled directly. That also means this file is the
## whole input story for the arena: nothing about it can be broken by an edit to
## the cooperative input map, and nothing it does can break that map.
##
## The keyboard is a fallback for exactly one seat, so the mode can be tried
## without four pads in the room. It takes the lowest-numbered seat that no pad
## claimed: with no pads that is fighter 1, with three pads it is fighter 4.

## Anything below this on the stick is nothing. Matches the 0.2 the cooperative
## actions use, with a little more margin because a worn pad resting at 0.22
## would otherwise walk a fighter off a shelf during the countdown.
const DEADZONE: float = 0.25

## Jump and "はじき". Two buttons, as the plan's touch layout also has to fit
## (4.3).
const PAD_JUMP: int = JOY_BUTTON_A
const PAD_ATTACK: int = JOY_BUTTON_X
const PAD_REMATCH: int = JOY_BUTTON_START

enum Kind { NONE, PAD, KEYBOARD }

## One seat's device and its edge-detection state.
##
## The sequences are what the rules read (ArenaCombat.try_attack, MotorInput):
## a count of presses rather than a level, so a tap that is already released by
## the time the tick runs is still a short hop instead of being lost (9.3).
class Seat:
	var kind: int = Kind.NONE
	var device: int = -1
	var jump_seq: int = 0
	var attack_seq: int = 0
	var _jump_was_down: bool = false
	var _attack_was_down: bool = false
	var _rematch_was_down: bool = false

var seats: Array[Seat] = []
## True once a seat asked for a rematch this frame. Cleared by reading it.
var _rematch_asked: bool = false

func _init() -> void:
	for i in range(4):
		seats.append(Seat.new())
	assign_devices()

## Work out who is holding what. Called at startup and whenever a pad is
## plugged in or pulled out, so a controller connected after launch still gets
## a seat.
func assign_devices() -> void:
	for s in seats:
		s.kind = Kind.NONE
		s.device = -1
	var pads := Input.get_connected_joypads()
	pads.sort()
	for i in range(mini(pads.size(), seats.size())):
		seats[i].kind = Kind.PAD
		seats[i].device = pads[i]
	for s in seats:
		if s.kind == Kind.NONE:
			s.kind = Kind.KEYBOARD
			break

## A line for the HUD, so a player can see why their pad is doing nothing.
func seat_label(actor: int) -> String:
	var s := seats[actor]
	if s.kind == Kind.PAD:
		return "PAD %d" % s.device
	if s.kind == Kind.KEYBOARD:
		return "KEYBOARD"
	return "NO DEVICE"

## The four intents for one tick, in the shape ArenaMatchState.tick_match wants.
##
## A seat with no device reports an idle intent rather than being skipped: the
## match always has four fighters, and one standing still is a clearer thing to
## look at than one that vanishes.
func poll() -> Array:
	var out: Array = []
	for i in range(seats.size()):
		out.append(_poll_seat(seats[i]))
	return out

func _poll_seat(s: Seat) -> Dictionary:
	var axis := 0.0
	var jump_down := false
	var attack_down := false
	var rematch_down := false

	if s.kind == Kind.PAD:
		axis = Input.get_joy_axis(s.device, JOY_AXIS_LEFT_X)
		if absf(axis) < DEADZONE:
			axis = 0.0
		# The d-pad is not an axis, and on some pads it is the only thing that
		# reports cleanly.
		if Input.is_joy_button_pressed(s.device, JOY_BUTTON_DPAD_LEFT):
			axis = -1.0
		elif Input.is_joy_button_pressed(s.device, JOY_BUTTON_DPAD_RIGHT):
			axis = 1.0
		jump_down = Input.is_joy_button_pressed(s.device, PAD_JUMP)
		attack_down = Input.is_joy_button_pressed(s.device, PAD_ATTACK)
		rematch_down = Input.is_joy_button_pressed(s.device, PAD_REMATCH)
	elif s.kind == Kind.KEYBOARD:
		var left := Input.is_physical_key_pressed(KEY_A) \
			or Input.is_physical_key_pressed(KEY_LEFT)
		var right := Input.is_physical_key_pressed(KEY_D) \
			or Input.is_physical_key_pressed(KEY_RIGHT)
		axis = (1.0 if right else 0.0) - (1.0 if left else 0.0)
		jump_down = Input.is_physical_key_pressed(KEY_SPACE) \
			or Input.is_physical_key_pressed(KEY_W)
		attack_down = Input.is_physical_key_pressed(KEY_J) \
			or Input.is_physical_key_pressed(KEY_SHIFT)
		rematch_down = Input.is_physical_key_pressed(KEY_R)

	# Edges, not levels.
	if jump_down and not s._jump_was_down:
		s.jump_seq += 1
	if attack_down and not s._attack_was_down:
		s.attack_seq += 1
	if rematch_down and not s._rematch_was_down:
		_rematch_asked = true
	s._jump_was_down = jump_down
	s._attack_was_down = attack_down
	s._rematch_was_down = rematch_down

	return {
		"axis": axis,
		"jump_held": jump_down,
		"jump_seq": s.jump_seq,
		"attack_seq": s.attack_seq,
	}

## Did anybody press rematch since this was last asked? Reading clears it, so a
## held button starts one match rather than every tick's worth.
func take_rematch() -> bool:
	var asked := _rematch_asked
	_rematch_asked = false
	return asked

## Four idle intents. Used during the countdown and the result screen, where
## the rules still tick but nobody should be able to move.
static func idle() -> Array:
	var out: Array = []
	for i in range(4):
		out.append({"axis": 0.0, "jump_held": false, "jump_seq": 0,
			"attack_seq": 0})
	return out
