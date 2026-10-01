class_name VersusEnemies
## The star battle's enemies, as numbers: where each one is is a pure
## function of the match tick, so every device draws it in the same place
## without a byte on the wire (the same idea as co-op's MovingPlatform). Only
## whether one is down is the host's, and it travels in the snapshot.
##
## A walker paces its floor from x0 to x1 and back; a flyer does the same in
## the air with a slow bob. The specs come from VersusStageData.enemy_specs().

const WALKER_SIZE := Vector2(44.0, 42.0)   # as co-op's Balance.WALKER_SIZE
const FLYER_SIZE := Vector2(46.0, 34.0)    # as co-op's Balance.FLYER_SIZE
## Pixels a second along its patrol.
const WALKER_SPEED: float = 70.0
const FLYER_SPEED: float = 95.0
const FLYER_BOB: float = 26.0

static func size_of(spec: Dictionary) -> Vector2:
	return FLYER_SIZE if String(spec["kind"]) == "flyer" else WALKER_SIZE

## 0..1..0 along the patrol, and which way it is heading (+1 right).
static func _along(spec: Dictionary, tick: int) -> Vector2:
	var length := maxf(1.0, float(spec["x1"]) - float(spec["x0"]))
	var speed := FLYER_SPEED if String(spec["kind"]) == "flyer" else WALKER_SPEED
	var t := fposmod(float(tick) / 60.0 * speed / (2.0 * length) + float(spec["phase"]), 1.0)
	var s := t * 2.0 if t < 0.5 else 2.0 - t * 2.0
	return Vector2(s, 1.0 if t < 0.5 else -1.0)

## Centre of the body at `tick`.
static func position_of(spec: Dictionary, tick: int) -> Vector2:
	var a := _along(spec, tick)
	var x := lerpf(float(spec["x0"]), float(spec["x1"]), a.x)
	if String(spec["kind"]) == "flyer":
		var bob := sin(float(tick) / 60.0 * 2.2 + float(spec["phase"]) * TAU) * FLYER_BOB
		return Vector2(x, float(spec["y"]) + bob)
	return Vector2(x, float(spec["y"]) - WALKER_SIZE.y * 0.5)

static func facing_of(spec: Dictionary, tick: int) -> int:
	return int(_along(spec, tick).y)

static func body_of(spec: Dictionary, tick: int) -> Rect2:
	var size := size_of(spec)
	return Rect2(position_of(spec, tick) - size * 0.5, size)
