class_name Sigil
extends RefCounted
## The marks on a locked gate and its switches, and the rule about who may read
## which.
##
## This is the one place in the game where information runs the other way. Every
## other veil takes something away from the runner; this takes the gate's demand
## away from the GUARDIAN and leaves the switches' marks with the runner. So:
##
##   the guardian  "it wants a square"
##   the runner    "square... that's the high one on the right"
##   the guardian  "right, shooting"
##
## Neither half is worth anything alone, which is the point. A runner who could
## see both would just say which switch; a guardian who could see both would
## just shoot it, and either way one of the two players would have stopped
## playing.

const NONE := 0
const TRIANGLE := 1
const SQUARE := 2
const CIRCLE := 3

## Gate id -> the mark that opens it. Filled in by the gates themselves as they
## enter the tree and emptied as they leave, so a checkpoint rebuild cannot
## leave a stale answer behind.
static var _wanted: Dictionary = {}

static func demand(gate_id: String, mark: int) -> void:
	if mark > NONE:
		_wanted[gate_id] = mark

static func forget(gate_id: String) -> void:
	_wanted.erase(gate_id)

static func wanted(gate_id: String) -> int:
	return int(_wanted.get(gate_id, NONE))

## Is this the switch the gate is asking for? A gate with no demand is an
## ordinary gate and any of its switches opens it, which is what every stage
## before this one has.
static func opens(gate_id: String, mark: int) -> bool:
	var want := wanted(gate_id)
	return want == NONE or want == mark

## Which player this screen belongs to, borrowed from the live veil field so
## there is one answer to "who am I" rather than two.
static func eye() -> String:
	if VeilField.current != null and is_instance_valid(VeilField.current):
		return VeilField.current.eye()
	return Veil.eye(null)

## May this device draw a mark meant for `who`? A shared screen shows both,
## because there is nobody on it to keep a secret from.
static func shown_to(who: String) -> bool:
	var seen := eye()
	return seen == "" or seen == who

static func name_of(mark: int) -> String:
	match mark:
		TRIANGLE: return "▲"
		SQUARE: return "■"
		CIRCLE: return "●"
	return "–"

## Drawn rather than drawn FROM: three shapes at this size need no texture, and
## a placeholder is the right thing until somebody has confused two of them out
## loud and said which pair it was.
static func draw_mark(on: CanvasItem, mark: int, at: Vector2, radius: float,
		colour: Color) -> void:
	match mark:
		TRIANGLE:
			var tri := PackedVector2Array([
				at + Vector2(0.0, -radius),
				at + Vector2(radius * 0.92, radius * 0.72),
				at + Vector2(-radius * 0.92, radius * 0.72)])
			on.draw_colored_polygon(tri, colour)
		SQUARE:
			var half := radius * 0.82
			on.draw_rect(Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0),
				colour)
		CIRCLE:
			on.draw_circle(at, radius * 0.92, colour)
