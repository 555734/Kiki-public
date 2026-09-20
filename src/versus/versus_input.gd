class_name VersusInput
extends Node
## Two runners and a strike button each, from one keyboard.
##
## This is the LOCAL arrangement, for trying the mode out on one machine. In the
## four-device version each player has their own screen and their own ordinary
## `p1_*` controls, and this file is only how two of them share a desk.
##
## Physical keys are read directly rather than through the action map. Adding
## eight more actions to project.godot would put a second runner's bindings into
## configuration that the cooperative game also loads, and the arrow keys are
## already a second binding on `p1_left` -- so an action-based second player
## would drive the first one too.
##
## Keys, left runner then right runner:
##     A / D    move        <-  / ->
##     W        jump        UP
##     S        drop        DOWN
##     F        strike      SHIFT (right)
##     Q        sprint      CTRL (right)

class Pad:
	var left: Key
	var right: Key
	var up: Key
	var down: Key
	var strike: Key
	var sprint: Key
	var strike_seq: int = 0
	var _strike_was_down: bool = false

	func _init(l: Key, r: Key, u: Key, d: Key, s: Key, sp: Key) -> void:
		left = l
		right = r
		up = u
		down = d
		strike = s
		sprint = sp

var pads: Array[Pad] = []
var hubs: Array[InputHub] = []

func _init() -> void:
	pads.append(Pad.new(KEY_A, KEY_D, KEY_W, KEY_S, KEY_F, KEY_Q))
	pads.append(Pad.new(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_SHIFT, KEY_CTRL))

## Make the two hubs. They are Nodes, so the caller adds them to the tree; they
## are `scripted` so they never read the keyboard for themselves.
func make_hubs(parent: Node) -> void:
	hubs.clear()
	for i in range(2):
		var hub := InputHub.new()
		hub.name = "VersusHub%d" % i
		hub.scripted = true
		# Both runners own the whole screen in this mode; there is no divider
		# and no guardian half to keep clear of.
		hub.solo_role = "runner"
		parent.add_child(hub)
		hubs.append(hub)

## One poll. Returns the strike sequence for each side, which is what the rules
## read; the movement has already gone into the hubs.
func poll() -> Array[int]:
	var seqs: Array[int] = []
	for i in range(pads.size()):
		var p := pads[i]
		var axis := (1.0 if Input.is_physical_key_pressed(p.right) else 0.0) \
			- (1.0 if Input.is_physical_key_pressed(p.left) else 0.0)
		var axis_y := (1.0 if Input.is_physical_key_pressed(p.down) else 0.0) \
			- (1.0 if Input.is_physical_key_pressed(p.up) else 0.0)
		var jump := Input.is_physical_key_pressed(p.up)
		var sprint := Input.is_physical_key_pressed(p.sprint)
		if i < hubs.size():
			hubs[i].drive_runner(axis, axis_y, jump, sprint)

		var strike_down := Input.is_physical_key_pressed(p.strike)
		if strike_down and not p._strike_was_down:
			p.strike_seq += 1
		p._strike_was_down = strike_down
		seqs.append(p.strike_seq)
	return seqs
