class_name Difficulty
extends RefCounted
## How fast the chasing enemies are. HARD is the speed the stages were tuned
## at; NORMAL and EASY slow every chaser down by the same factor.
##
## Only the host's value matters in online play -- the chaser runs on the
## host and its position is sent to the guest -- but the guest adopts the
## host's choice from the room so both screens say the same thing.

enum Level { EASY, NORMAL, HARD }
const LABELS := ["イージー", "ノーマル", "ハード"]
const SCALES := [0.6, 0.8, 1.0]
const PATH := "user://game.cfg"

static var level: int = Level.HARD
static var _loaded := false

static func current() -> int:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(PATH) == OK:
			level = clampi(int(cfg.get_value("game", "chase", Level.HARD)), 0, 2)
	return level

static func chase_scale() -> float:
	return SCALES[current()]

## `save` is false when the value comes from someone else's room.
static func set_level(value: int, save: bool = true) -> void:
	_loaded = true
	level = clampi(value, 0, 2)
	if not save:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep any other keys; a missing file is fine
	cfg.set_value("game", "chase", level)
	cfg.save(PATH)
