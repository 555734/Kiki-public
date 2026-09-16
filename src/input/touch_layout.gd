class_name TouchLayout
extends RefCounted
## What is left of the old layout table: the zones that are not round buttons.
##
## Every control's PLACE now lives in ControlLayout, which the input router, the
## HUD and the layout editor all read. This file used to hold a second copy of
## those numbers, and the two drifted -- a button drawn where it could not be
## pressed is the one bug a player cannot work around.

## Fraction of the width reserved for the runner when the screen is shared.
const DIVIDER: float = ControlLayout.DIVIDER

## Guardian: aiming works anywhere past the divider that is not a control.
const AIM_ZONE := Rect2(DIVIDER, 0.00, 1.0 - DIVIDER, 1.00)

## Zoom slider, only interactive while the scope is engaged.
const ZOOM_SLIDER := Rect2(0.955, 0.22, 0.040, 0.36)

## There is no lift, for any tool.
##
## There used to be one for everything except the rifle: the target sat about a
## fingertip ABOVE the finger, so a 26px slab would not hide under the thumb
## placing it. Measured on the rifle it was 74 world pixels, against a walker 42
## pixels tall -- every shot went cleanly over its head. The same offset applied
## to the constructs was the same fault in slower motion: what got built was
## never quite where the player pointed. Point at the thing, get the thing
## there; the ghost is how you see what the thumb is covering.

const SLOT_COUNT: int = 4

## Push the stick up past this fraction of its travel and the runner jumps.
const STICK_JUMP_FRACTION: float = ControlLayout.STICK_JUMP_FRACTION

## Mirrors an x fraction when the two players trade sides at a checkpoint.
static func flip_x(value: float, mirrored: bool) -> float:
	return 1.0 - value if mirrored else value

static func hit_rect(point: Vector2, rect: Rect2, size: Vector2, mirrored: bool) -> bool:
	var x0 := flip_x(rect.position.x, mirrored)
	var x1 := flip_x(rect.position.x + rect.size.x, mirrored)
	var px := point.x / size.x
	var py := point.y / size.y
	return px >= minf(x0, x1) and px <= maxf(x0, x1) \
		and py >= rect.position.y and py <= rect.position.y + rect.size.y
