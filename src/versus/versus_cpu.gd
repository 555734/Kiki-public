class_name VersusCpu
extends RefCounted
## The practice partner in 「1台でためす」 on a phone: P2, played by the game.
##
## Deliberately a gentle one. It goes for the nearest loose star (or for you,
## when there is none), jumps when the star is above it or a wall is in the
## way, and now and then takes a shot at you -- slowly, and not very well. It
## is there so that one person can learn the mode, not to beat them.
##
## It drives P2 the way a player would, through P2's InputHub, so its runner
## moves by exactly the game's rules; and it shoots through the match like a
## player's tap does, so a shot is checked for cover the same way.

## Seconds between shots, at random within this range.
const SHOT_EVERY := Vector2(2.6, 4.6)
## It only shoots at you when you are this close, the short way round.
const SHOT_RANGE := 520.0
## How far off a shot lands, at most: the aim assist forgives some of it.
const SHOT_SCATTER := 70.0

var _rng := RandomNumberGenerator.new()
var _jump_hold: int = 0
var _stuck: int = 0
var _last_x: float = 0.0
var _shot_in: int = 0
## How many shots it has taken, for the probes.
var shots: int = 0

func _init(seed_value: int = 4711) -> void:
	_rng.seed = seed_value
	_shot_in = _next_shot()

func _next_shot() -> int:
	return int(_rng.randf_range(SHOT_EVERY.x, SHOT_EVERY.y) * 60.0)

## One tick: steer `me` through `hub`, and maybe shoot at `you` through
## `rules` as `side`. `stars` are the loose stars' positions.
func think(me: Runner, hub: InputHub, you: Vector2, stars: Array[Vector2],
		rules: VersusMatch, side: int) -> void:
	var at := me.global_position
	var goal := you
	var best := INF
	for star in stars:
		var seen := VersusStageData.nearest_image(star, at)
		var d := seen.distance_to(at)
		if d < best:
			best = d
			goal = seen
	if stars.is_empty():
		goal = VersusStageData.nearest_image(you, at)

	var dx := goal.x - at.x
	var axis := 0.0 if absf(dx) < 14.0 else signf(dx)
	# Stuck against something while trying to go somewhere: jump it.
	if axis != 0.0 and absf(at.x - _last_x) < 0.5:
		_stuck += 1
	else:
		_stuck = 0
	_last_x = at.x
	if me.is_on_floor() and _jump_hold == 0:
		var above := at.y - goal.y > 40.0 and absf(dx) < 180.0
		if above or _stuck > 18:
			_jump_hold = 20 if above else 14
			_stuck = 0
	var jump := _jump_hold > 0
	_jump_hold = maxi(0, _jump_hold - 1)
	hub.drive_runner(axis, 0.0, jump, false)

	_shot_in -= 1
	if _shot_in <= 0 and rules != null and rules.phase == VersusMatch.Phase.PLAYING:
		_shot_in = _next_shot()
		var target := VersusStageData.nearest_image(you, at)
		if target.distance_to(at) <= SHOT_RANGE:
			var miss := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) \
				* SHOT_SCATTER
			rules.shoot(side, target + miss)
			shots += 1
