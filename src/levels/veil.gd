class_name Veil
extends RefCounted
## A region of the stage that one of the two players cannot see into.
##
## The whole asymmetric-information design rests on one measured fact: in Godot,
## `visible = false` stops a node being DRAWN and does nothing at all to its
## collision. A hidden floor is still solid, a hidden walker still hurts, a
## hidden Area2D still reports its overlaps. So "the guardian can see it and the
## runner cannot" is a local drawing decision on each device -- not a second
## simulation, not a second copy of the level, and nothing on the wire.
##
## Regions rather than objects, for three reasons. A region's BOUNDARY can be
## drawn, so the runner knows they are blind instead of being ambushed; a region
## is one line of level data, so a new asymmetric stage needs no new machinery;
## and a region can hide several layers at once, which is how a section gets to
## say "the ground here is yours to find, but the things moving in it are mine".
##
## Nothing here is drawn faintly or in outline. A veiled layer is absent.

## The layers a veil can hide. Strings rather than an enum so a veil row reads
## like the rest of the level data ({"type": "walker"}, {"kind": "pipe"}).
const TERRAIN := "terrain"
const ENEMIES := "enemies"
const HAZARDS := "hazards"
const GIMMICKS := "gimmicks"
const PICKUPS := "pickups"
const HOLOGRAMS := "holograms"
## Not a thing in the world: the ping markers the two players drop for each
## other. A marker that names an exact world position inside a veil would do the
## talking, which is the one thing this design cannot afford. See §6.3.
const MARKS := "marks"

const LAYERS := [TERRAIN, ENEMIES, HAZARDS, GIMMICKS, PICKUPS, HOLOGRAMS, MARKS]

## Whose eyes a veil is closed to.
const RUNNER := "runner"
const GUARDIAN := "guardian"

## Development override for a single machine.
##
## Online, this device's role is decided by which end of the link it is
## (InputHub.solo_role). Offline both roles are on one screen and nothing is
## hidden from anybody, which is correct for play and useless for building a
## stage: an author has to be able to see what the runner will see. Probes use
## it for the same reason, and it is the only way the automated suite can put
## both points of view side by side.
static var _forced_eye: String = ""

static func force_eye(role: String) -> void:
	_forced_eye = role

static func forced_eye() -> String:
	return _forced_eye

## Which player this device's screen belongs to, or "" for a shared screen.
static func eye(hub: InputHub) -> String:
	if _forced_eye != "":
		return _forced_eye
	return hub.solo_role if hub != null else ""

## Does this veil close `layer` to `who`?
static func closes(veil: Dictionary, layer: String, who: String) -> bool:
	if who == "":
		return false            # one shared screen: there is nobody to hide from
	if String(veil.get("from", RUNNER)) != who:
		return false
	return layer in veil.get("hides", [])

## Is a point inside the region?
static func holds(veil: Dictionary, at: Vector2) -> bool:
	var rect: Rect2 = veil.get("rect", Rect2())
	return rect.has_point(at)

## Is a whole slab of ground inside the region?
##
## Deliberately the top EDGE and not the centre. A slab is drawn from its
## surface down to the bottom of the world, so a floor that merely passes
## through a veil would vanish entirely if this asked about containment -- and
## the one thing worse than a hidden platform is a hidden platform plus the
## visible ground either side of it disappearing with it. Both top corners
## inside means "this surface is the veil's business"; a long floor crossing the
## region keeps at least one corner outside and stays drawn.
static func holds_surface(veil: Dictionary, slab: Rect2) -> bool:
	var rect: Rect2 = veil.get("rect", Rect2())
	return rect.has_point(slab.position) \
		and rect.has_point(Vector2(slab.position.x + slab.size.x, slab.position.y))
