class_name VeilField
extends Node2D
## Applies this stage's veils to THIS device's screen, and nothing else.
##
## Every veil is a drawing decision. Collision, physics, the snapshot and the
## host's authority are all untouched, which is what makes the two players'
## worlds the same world -- they simply are not shown the same parts of it. The
## automated proof of that is veil_probe's first check: the same input replayed
## through runner eyes and guardian eyes has to produce the same trajectory to
## within a thousandth of a pixel.
##
## Ground is handled apart from everything else because the engine already
## draws it apart from everything else: terrain.gd paints a list of rectangles
## and LevelBuilder builds the collision bodies from its own copy of that list.
## Filtering one leaves the other alone, which is the whole trick.

## The one live field, for the few places that cannot reasonably be handed a
## reference -- the ping markers, which are spawned by Fx from a global signal
## and have no idea which level they are in. Stage does the same thing with the
## stage selection, and for the same reason: there is exactly one of these.
static var current: VeilField = null

var veils: Array[Dictionary] = []
var hub: InputHub = null
var runner: Runner = null

## How long a reveal lasts. Long enough to read a shape; short enough that it
## cannot be used as a way to see, only as a way to understand what happened.
const REVEAL_TIME: float = 1.2

var _terrain: Node2D = null
var _all_slabs: Array[Rect2] = []
var _watched: Array[Dictionary] = []
var _reveal_left: float = 0.0
var _was_on_ground: bool = true

func _ready() -> void:
	current = self
	Events.runner_died.connect(_on_runner_died)

func _exit_tree() -> void:
	if current == self:
		current = null

## Which player this screen belongs to. "" is a shared screen, where nothing is
## hidden from anybody.
func eye() -> String:
	return Veil.eye(hub)

## Is `layer` closed to this device's player at this point?
func hides(layer: String, at: Vector2) -> bool:
	if _reveal_left > 0.0:
		return false
	var who := eye()
	if who == "":
		return false
	for veil in veils:
		if Veil.closes(veil, layer, who) and Veil.holds(veil, at):
			return true
	return false

## The named regions covering a point, for the debug overlay and for probes
## that want to say WHICH veil they are testing.
func regions_at(at: Vector2) -> Array[String]:
	var names: Array[String] = []
	for veil in veils:
		if Veil.holds(veil, at):
			names.append(String(veil.get("name", "?")))
	return names

# ------------------------------------------------------------------- ground

## Hand over the terrain painter and every slab there is. What gets drawn is
## recomputed from this whenever a veil lifts; what gets collided with was built
## from Stage.ground() and is never touched.
func take_terrain(node: Node2D, slabs: Array[Rect2]) -> void:
	_terrain = node
	_all_slabs = slabs.duplicate()
	_repaint_ground()

func _repaint_ground() -> void:
	if _terrain == null or not is_instance_valid(_terrain):
		return
	_terrain.slabs = drawn_slabs()
	_terrain.queue_redraw()

## The slabs this device paints. Public because the probe asserts on it.
func drawn_slabs() -> Array[Rect2]:
	var who := eye()
	if who == "" or _reveal_left > 0.0:
		return _all_slabs.duplicate()
	var out: Array[Rect2] = []
	for slab in _all_slabs:
		var hidden := false
		for veil in veils:
			if Veil.closes(veil, Veil.TERRAIN, who) and Veil.holds_surface(veil, slab):
				hidden = true
				break
		if not hidden:
			out.append(slab)
	return out

# ------------------------------------------------------------------ entities

## Register something that can be veiled. `moving` decides whether its position
## is re-tested every frame -- true for enemies and moving floors, false for the
## things that were put down once and stay there.
func watch(node: Node2D, layer: String, moving: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return
	var entry := {"node": node, "layer": layer, "moving": moving}
	_watched.append(entry)
	_apply(entry)

## Whether a watched entry still points at something.
##
## Untyped on purpose. Assigning a freed instance to a typed local is itself the
## error ("Trying to assign invalid previously freed instance"), so the check
## has to happen before anything types it -- and enemies are freed under this
## list all the time, every time one is shot.

## Everything dynamic is thrown away and rebuilt at a checkpoint, so the list of
## things to watch is thrown away with it.
func forget_watched() -> void:
	_watched.clear()

func _alive(entry: Dictionary) -> bool:
	var node = entry.get("node")
	return node != null and is_instance_valid(node)

func _apply(entry: Dictionary) -> void:
	if not _alive(entry):
		return
	var node: Node2D = entry["node"]
	node.visible = not hides(String(entry["layer"]), node.global_position)

func _apply_all() -> void:
	_prune()
	for entry in _watched:
		_apply(entry)

func _prune() -> void:
	var live: Array[Dictionary] = []
	for entry in _watched:
		if _alive(entry):
			live.append(entry)
	_watched = live

# ------------------------------------------------------------------- reveal

## Lift every veil on this screen for a moment.
##
## This is not a courtesy, it is the mechanism that makes a miscommunication
## worth having. Without it a botched jump is "that was unfair"; with it the
## runner sees, at the instant they land in the wrong place, exactly what the
## guardian had been trying to describe -- and the pair come back with better
## words for it. It fires on death and on landing inside a veil that was hiding
## the GROUND, which is the only layer whose absence can be what went wrong.
func reveal_for(seconds: float = REVEAL_TIME) -> void:
	if eye() == "":
		return
	var was := _reveal_left > 0.0
	_reveal_left = maxf(_reveal_left, seconds)
	if not was:
		_refresh()

func revealing() -> bool:
	return _reveal_left > 0.0

func _on_runner_died(_cause: String) -> void:
	reveal_for()

func _refresh() -> void:
	_repaint_ground()
	_apply_all()

func _process(delta: float) -> void:
	if _reveal_left > 0.0:
		_reveal_left = maxf(0.0, _reveal_left - delta)
		if _reveal_left <= 0.0:
			_refresh()
		return

	_prune()
	for entry in _watched:
		if bool(entry["moving"]):
			_apply(entry)

	_watch_for_a_bad_landing()

## A landing inside ground-hiding dark. Whether they made it or missed it, this
## is the moment the shape of the place is worth seeing.
func _watch_for_a_bad_landing() -> void:
	if runner == null or not is_instance_valid(runner):
		return
	var grounded: bool = runner.on_ground()
	var landed := grounded and not _was_on_ground
	_was_on_ground = grounded
	if landed and hides(Veil.TERRAIN, runner.global_position):
		reveal_for()
