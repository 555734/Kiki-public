class_name Spring
extends Node2D
## A bounce pad. Launches the runner far higher than their own jump, which makes
## it the one piece of scenery that changes what they can reach unaided.
##
## Deliberately placed away from the gaps that exist to teach the guardian's
## platform: a spring that crossed one of those would answer the question the
## level is asking. These sit under the coins instead, where the reward for
## using them is the guardian's gauge rather than progress.

## Drawn size, at the painted pad's own aspect so it is not squashed at rest.
const WIDTH := 76.0
const HEIGHT := 65.0
## Trigger height above the base. Deliberately low: the pad has no collider, so
## there is no "landing on it" -- the runner cannot stand on a trigger. Touching
## it is what fires it, which is how a spring in a platformer behaves anyway,
## and it means a runner walking into one along the ground bounces rather than
## strolling through the artwork.
const PAD_Y := 30.0
## How long the pad ignores the runner after firing, so one landing is one
## bounce rather than one per frame of contact.
const REARM := 0.25

var runner: Runner = null

var _cooldown: float = 0.0
var _squash: float = 0.0

func _ready() -> void:
	z_index = 4
	# After the runner has moved this frame, so the velocity set here survives
	# into the next move_and_slide instead of being overwritten by it.
	process_priority = 10

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_squash = maxf(0.0, _squash - delta * 4.0)
	queue_redraw()
	if runner == null or not is_instance_valid(runner):
		return

	# Cosmetic, and derived rather than sent: on the guardian's device the runner
	# is a puppet driven by snapshots, so the pad reads the launch out of the
	# motion it can already see instead of waiting for a packet that says so.
	if _near(runner) and runner.velocity.y < -Balance.SPRING_VELOCITY * 0.5:
		_squash = 1.0

	if not Clock.is_host or _cooldown > 0.0:
		return
	if runner.velocity.y < -1.0:
		return
	if not _near(runner):
		return
	runner.bounce(Balance.SPRING_VELOCITY)
	_cooldown = REARM
	_squash = 1.0
	Events.spring_bounced.emit(global_position)

## Feet on the pad, give or take. Generous downward so a fast fall cannot pass
## through the trigger band between two frames.
func _near(who: Runner) -> bool:
	var feet := who.global_position.y + Balance.RUNNER_SIZE.y * 0.5
	var top := global_position.y - PAD_Y
	if feet < top - 20.0 or feet > top + 40.0:
		return false
	return absf(who.global_position.x - global_position.x) \
		<= (WIDTH + Balance.RUNNER_SIZE.x) * 0.5

func _draw() -> void:
	# Squash on the way down, stretch a little wider with it: the pad is the only
	# thing on screen that tells the runner how hard it just threw them.
	var h := HEIGHT * (1.0 - _squash * 0.34)
	var w := WIDTH * (1.0 + _squash * 0.16)
	var rect := Rect2(-w * 0.5, -h, w, h)
	if Art.draw_stretched(self, "spring", rect):
		return
	DrawUtil.rounded_rect(self, rect, 6.0, Color("d13b3b"))
	draw_rect(Rect2(rect.position.x, rect.position.y, w, h * 0.34), Color("f6c945"))
