class_name Stage
extends RefCounted
## Which stage the game is playing, and the one place that answers it.
##
## Every builder and renderer asks this facade instead of naming a level-data
## class directly, so adding a stage cannot accidentally mix geometry from one
## map with enemies or checkpoints from another.
##
## Each stage is one data script (see _DATA_FILES), and every accessor here
## just asks the current one. A data script answers the same static functions
## as every other (REQUIRED, checked by the logic tests) and may declare any of
## the optional traits below; a stage that says nothing gets the default. So a
## new stage is a new data file and one line in _DATA_FILES -- not a new branch
## in every function of this file.


## New stages go on the END: the value is what travels in the handshake.
enum Which { GREENFIELD, CROSSING, WORKSHOP, HORROR, QUIET, KEEPER, SKY, SKYWARD_RUINS, SEA, SWAMP, DESERT, TOWER, CAVE, ROYAL_ARENA }

## A fresh launch starts at 1-1. The start panel can switch to 1-2 before play.
## Keeping 1-1 as the default means integrating a later stage never replaces the
## existing first stage again.
static var _which: int = Which.GREENFIELD

## Each stage's data script is compiled the first time that stage is asked
## about, not at launch: five level scripts the start screen never needs were
## part of the startup compile.
static var _data_scripts: Dictionary = {}

static func _data(file: String) -> Script:
	if not _data_scripts.has(file):
		_data_scripts[file] = load("res://src/levels/%s.gd" % file)
	return _data_scripts[file]

## The data script behind each stage, keyed by Which.
const _DATA_FILES := {
	Which.GREENFIELD: "level_01_data",
	Which.CROSSING: "level_02_data",
	Which.WORKSHOP: "level_03_data",
	Which.HORROR: "level_horror_data",
	Which.QUIET: "level_quiet_data",
	Which.KEEPER: "level_keeper_data",
	Which.SKY: "level_sky_data",
	Which.SKYWARD_RUINS: "level_skyward_ruins_data",
	Which.SEA: "level_sea_data",
	Which.SWAMP: "level_swamp_data",
	Which.DESERT: "level_desert_data",
	Which.TOWER: "level_tower_data",
	Which.CAVE: "level_cave_data",
	Which.ROYAL_ARENA: "level_royal_arena_data",
}

## The current stage's data script.
static func data() -> Script:
	return _data(_DATA_FILES[_which])

## An optional rule the current stage's data may declare. A stage that says
## nothing gets `fallback`, so a new rule never needs an entry in every file --
## and shared code never needs to ask which stage it is in.
static func _rule(method: String, fallback: Variant, args: Array = []) -> Variant:
	var script := data()
	return script.callv(method, args) if script.has_method(method) else fallback

static func use(which: int) -> void:
	_which = which

static func current() -> int:
	return _which

## Every function a stage's data script must answer. The scalar ones end in
## _value or _position for the same reason the data files always named them so:
## a static function cannot share a name with the constant it wraps.
const REQUIRED: Array[String] = [
	"kill_y_value", "start_position", "stage_name_value", "stage_number_value",
	"objective_value", "ground", "solid_decor", "decor", "hazards", "enemies",
	"gimmicks", "veils", "checkpoints", "goal", "coins", "springs", "crystals",
]


# ------------------------------------------------------------------- traits
# What a stage is like, as opposed to what is in it. Each is optional in the
# data script; the fallback is what most stages are.

## Whether this stage's world is drawn by the 3D view. 1-1 and 1-2 keep their
## original painted 2D art -- terrain, props, enemies, pickups and backdrop --
## and only the runner is a 3D model over it; the low-poly recipes were a worse
## picture of those two stages than the art they replaced. Later painted
## stages declare painted_2d_value() too.
static func world_3d() -> bool:
	return Balance.USE_3D and not bool(_rule("painted_2d_value", false))

static func is_crossing() -> bool:
	return _which == Which.CROSSING

static func is_workshop() -> bool:
	return _which == Which.WORKSHOP

static func is_horror() -> bool:
	return _which == Which.HORROR

## The asymmetric-information stage. Both devices build it, as they build every
## stage; what differs is which parts each one paints. See Veil.
static func is_quiet() -> bool:
	return _which == Which.QUIET

## The boss arena. The one stage where the runner never has to reach anywhere --
## see docs/stage-keeper.md.
static func is_keeper() -> bool:
	return _which == Which.KEEPER

## The flight stage. The one stage where the runner cannot walk to the goal --
## see docs/stage-sky.md.
static func is_sky() -> bool:
	return _which == Which.SKY

static func is_skyward_ruins() -> bool:
	return _which == Which.SKYWARD_RUINS

## The first sea stage: beaches, rocks and piers over open water. Painted 2D,
## like 1-1 and 1-2 -- see world_3d().
static func is_sea() -> bool:
	return _which == Which.SEA

static func is_swamp() -> bool:
	return _which == Which.SWAMP

static func is_desert() -> bool:
	return _which == Which.DESERT

static func is_tower() -> bool:
	return _which == Which.TOWER

static func is_cave() -> bool:
	return _which == Which.CAVE

## The sea's surface on a stage that has one (1-4), or INF.
static func water_y() -> float:
	return float(_rule("water_y_value", INF))

## Unit vector in the direction the stage asks the team to make progress.
## It is shared by camera framing and directional pursuit.
static func progress_direction() -> Vector2:
	return _rule("progress_direction_value", Vector2.RIGHT)

## Whether the stage's platform gimmicks (moving, blinking, crumbling...) can
## be jumped through from below. A stage-wide default; a gimmick spec can still
## say `"one_way"` for itself.
static func platforms_one_way() -> bool:
	return bool(_rule("platforms_one_way", false))

## Whether a piece of the stage's own ground can be jumped through from below.
static func ground_is_one_way(rect: Rect2) -> bool:
	return bool(_rule("ground_one_way", false, [rect]))

## Stages that only work with one player per device. On a shared screen there is
## nobody to hide anything from, so the whole design collapses into a walk.
static func needs_two_devices() -> bool:
	return bool(_rule("needs_two_devices_value", false))

## The side-scrolling stages lock their goal until the runner has picked up
## the key, which sits on the ground part-way along. It is what stops a team
## from reaching the goal on guardian platforms without ever landing.
static func needs_key() -> bool:
	return bool(_rule("needs_key_value", false))

## Where the pit sensor goes. Wide enough to catch the whole active stage.
static func pit_centre_x() -> float:
	return float(_rule("pit_centre_x_value", 0.0))

# ---------------------------------------------------------------- constants

static func kill_y() -> float:
	return data().kill_y_value()

static func start() -> Vector2:
	return data().start_position()

static func stage_name() -> String:
	return data().stage_name_value()

## The stages a player who has not bought the full game can start on their own.
##
## Deliberately a property OF the stage list and not a gate INSIDE use(): every
## probe in test/ calls Stage.use() directly to inspect a stage's geometry, and
## a stage that refused to load without an entitlement would take the whole
## suite down with it. Locking happens where a player starts a game -- the menu
## and the room-creation path -- not where the data is read.
##
## 1-1 and 1-2 are free; everything from 1-3 to 1-8 is the full game.
## tools/release-check.sh compares this with the store listing's paid range.
const FREE_STAGES: Array[int] = [
	Which.GREENFIELD, Which.HORROR,
]

static func is_free(which: int = -1) -> bool:
	return FREE_STAGES.has(_which if which < 0 else which)

static func stage_number() -> String:
	return data().stage_number_value()

static func objective() -> String:
	return data().objective_value()

# ---------------------------------------------------------------------- data

static func ground() -> Array[Rect2]:
	return data().ground()

static func solid_decor() -> Array[Rect2]:
	return data().solid_decor()

static func decor() -> Array[Dictionary]:
	return data().decor()

static func hazards() -> Array[Dictionary]:
	return data().hazards()

static func enemies() -> Array[Dictionary]:
	return data().enemies()

static func gimmicks() -> Array[Dictionary]:
	return data().gimmicks()

## Regions one of the two players cannot see into. Empty for every stage that
## shows both players the same world, which is all of them until 1-V.
static func veils() -> Array[Dictionary]:
	return data().veils()

static func checkpoints() -> Array[Vector2]:
	return data().checkpoints()

static func goal() -> Vector2:
	return data().goal()

static func coins() -> Array[Vector2]:
	return data().coins()

static func springs() -> Array[Vector2]:
	return data().springs()

static func crystals() -> Array[Vector2]:
	return data().crystals()

## How a room-built climb is meant to be climbed (see ClimbBuilder); empty
## for every other stage.
static func route() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_rule("route", []))
	return out

## Where the key rests. A stage may place it itself (the climbs keep it on the
## top bank, beside the goal); otherwise it goes on the lowest ground under a
## point ~60% of the way from start to goal, nudged along until it is on a
## floor with no hazard on it.
static func key_position() -> Vector2:
	if data().has_method("key_position"):
		return data().key_position()
	var s := start()
	var g := goal()
	var base_x := lerpf(s.x, g.x, 0.6)
	var rects := ground()
	var bad := hazards()
	for step in range(0, 40):
		for sgn in [1.0, -1.0]:
			var x: float = base_x + sgn * float(step) * 60.0
			var best := Rect2()
			var found := false
			for r in rects:
				if r.size.x < 120.0 or x < r.position.x + 40.0 or x > r.end.x - 40.0:
					continue
				if not found or r.position.y > best.position.y:
					best = r
					found = true
			if not found:
				continue
			var p := Vector2(x, best.position.y - 4.0)
			var clear := true
			for h in bad:
				var hr := Rect2(Vector2(h["pos"]) - Vector2(h["size"]) * 0.5 - Vector2(60, 60),
					Vector2(h["size"]) + Vector2(120, 120))
				if hr.has_point(p):
					clear = false
					break
			for cp in checkpoints():
				if absf(cp.x - p.x) < 110.0:
					clear = false
			if clear:
				return p
	return Vector2(base_x, s.y)

## Crows patrolling high above the course, for a team trying to fly the whole
## stage on platforms. A fixed set per stage -- it does not depend on the
## chosen difficulty, so both devices number the enemies the same way; the
## difficulty sets how fast they sweep instead.
static func sky_crows() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if progress_direction() != Vector2.RIGHT or not needs_key():
		return out
	var rects := ground()
	var x := start().x + 600.0
	var end_x := goal().x - 200.0
	while x < end_x:
		var top := start().y
		for r in rects:
			if r.end.x > x - 350.0 and r.position.x < x + 350.0:
				top = minf(top, r.position.y)
		out.append(Vector2(x, top - 330.0))
		x += 900.0
	return out
