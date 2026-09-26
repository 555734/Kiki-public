class_name Stage
extends RefCounted
## Which stage the game is playing, and the one place that answers it.
##
## Every builder and renderer asks this facade instead of naming a level-data
## class directly, so adding a stage cannot accidentally mix geometry from one
## map with enemies or checkpoints from another.


## New stages go on the END: the value is what travels in the handshake.
enum Which { GREENFIELD, CROSSING, WORKSHOP, HORROR, QUIET, KEEPER, SKY, SKYWARD_RUINS, SEA, SWAMP }

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

static func use(which: int) -> void:
	_which = which

static func current() -> int:
	return _which

## Whether this stage's world is drawn by the 3D view. 1-1 and 1-2 keep their
## original painted 2D art -- terrain, props, enemies, pickups and backdrop --
## and only the runner is a 3D model over it; the low-poly recipes were a worse
## picture of those two stages than the art they replaced.
static func world_3d() -> bool:
	return Balance.USE_3D and _which != Which.GREENFIELD and _which != Which.HORROR \
		and _which != Which.SEA and _which != Which.SWAMP

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

## The sea's surface on a stage that has one (1-4), or INF.
static func water_y() -> float:
	if is_swamp():
		return _data("level_swamp_data").water_y_value()
	if is_sea():
		return _data("level_sea_data").water_y_value()
	return INF

## Unit vector in the direction the stage asks the team to make progress.
## It is shared by camera framing and directional pursuit.
static func progress_direction() -> Vector2:
	return Vector2.UP if is_skyward_ruins() else Vector2.RIGHT

## Stages that only work with one player per device. On a shared screen there is
## nobody to hide anything from, so the whole design collapses into a walk.
static func needs_two_devices() -> bool:
	return is_quiet()

# ------------------------------------------------------------------ constants

static func kill_y() -> float:
	if is_swamp():
		return _data("level_swamp_data").kill_y_value()
	if is_sea():
		return _data("level_sea_data").kill_y_value()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").kill_y_value()
	if is_sky():
		return _data("level_sky_data").kill_y_value()
	if is_keeper():
		return _data("level_keeper_data").kill_y_value()
	if is_quiet():
		return _data("level_quiet_data").kill_y_value()
	if is_horror():
		return _data("level_horror_data").kill_y_value()
	if is_workshop():
		return Level03Data.KILL_Y
	return Level02Data.KILL_Y if is_crossing() else Level01Data.KILL_Y

static func start() -> Vector2:
	if is_swamp():
		return _data("level_swamp_data").start_position()
	if is_sea():
		return _data("level_sea_data").start_position()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").start_position()
	if is_sky():
		return _data("level_sky_data").start_position()
	if is_keeper():
		return _data("level_keeper_data").start_position()
	if is_quiet():
		return _data("level_quiet_data").start_position()
	if is_horror():
		return _data("level_horror_data").start_position()
	if is_workshop():
		return Level03Data.START
	return Level02Data.START if is_crossing() else Level01Data.START

static func stage_name() -> String:
	if is_swamp():
		return _data("level_swamp_data").stage_name_value()
	if is_sea():
		return _data("level_sea_data").stage_name_value()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").stage_name_value()
	if is_sky():
		return _data("level_sky_data").stage_name_value()
	if is_keeper():
		return _data("level_keeper_data").stage_name_value()
	if is_quiet():
		return _data("level_quiet_data").stage_name_value()
	if is_horror():
		return _data("level_horror_data").stage_name_value()
	if is_workshop():
		return Level03Data.STAGE_NAME
	return Level02Data.STAGE_NAME if is_crossing() else Level01Data.STAGE_NAME

## The stages a player who has not bought the full game can start on their own.
##
## Deliberately a property OF the stage list and not a gate INSIDE use(): every
## probe in test/ calls Stage.use() directly to inspect a stage's geometry, and
## a stage that refused to load without an entitlement would take the whole
## suite down with it. Locking happens where a player starts a game -- the menu
## and the room-creation path -- not where the data is read.
##
## 1-1 teaches running and jumping; 1-2 is the first stage that cannot be
## finished without the guardian, which is the thing being sold. Someone who
## has played both has seen what the full game is.
const FREE_STAGES: Array[int] = [Which.GREENFIELD, Which.HORROR]

static func is_free(which: int = -1) -> bool:
	return FREE_STAGES.has(_which if which < 0 else which)

static func stage_number() -> String:
	if is_swamp():
		return _data("level_swamp_data").stage_number_value()
	if is_sea():
		return _data("level_sea_data").stage_number_value()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").stage_number_value()
	if is_sky():
		return _data("level_sky_data").stage_number_value()
	if is_keeper():
		return _data("level_keeper_data").stage_number_value()
	if is_quiet():
		return _data("level_quiet_data").stage_number_value()
	if is_horror():
		return _data("level_horror_data").stage_number_value()
	if is_workshop():
		return Level03Data.STAGE_NUMBER
	return Level02Data.STAGE_NUMBER if is_crossing() else Level01Data.STAGE_NUMBER

static func objective() -> String:
	if is_swamp():
		return _data("level_swamp_data").objective_value()
	if is_sea():
		return _data("level_sea_data").objective_value()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").objective_value()
	if is_sky():
		return _data("level_sky_data").objective_value()
	if is_keeper():
		return _data("level_keeper_data").objective_value()
	if is_quiet():
		return _data("level_quiet_data").objective_value()
	if is_horror():
		return _data("level_horror_data").objective_value()
	if is_workshop():
		return Level03Data.OBJECTIVE
	return Level02Data.OBJECTIVE if is_crossing() else Level01Data.OBJECTIVE

# ---------------------------------------------------------------------- data

static func ground() -> Array[Rect2]:
	if is_swamp():
		return _data("level_swamp_data").ground()
	if is_sea():
		return _data("level_sea_data").ground()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").ground()
	if is_sky():
		return _data("level_sky_data").ground()
	if is_keeper():
		return _data("level_keeper_data").ground()
	if is_quiet():
		return _data("level_quiet_data").ground()
	if is_horror():
		return _data("level_horror_data").ground()
	if is_workshop():
		return Level03Data.ground()
	return Level02Data.ground() if is_crossing() else Level01Data.ground()

static func solid_decor() -> Array[Rect2]:
	if is_swamp():
		return _data("level_swamp_data").solid_decor()
	if is_sea():
		return _data("level_sea_data").solid_decor()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").solid_decor()
	if is_sky():
		return _data("level_sky_data").solid_decor()
	if is_keeper():
		return _data("level_keeper_data").solid_decor()
	if is_quiet():
		return _data("level_quiet_data").solid_decor()
	if is_horror():
		return _data("level_horror_data").solid_decor()
	if is_workshop():
		return Level03Data.solid_decor()
	return Level02Data.solid_decor() if is_crossing() else Level01Data.solid_decor()

static func decor() -> Array[Dictionary]:
	if is_swamp():
		return _data("level_swamp_data").decor()
	if is_sea():
		return _data("level_sea_data").decor()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").decor()
	if is_sky():
		return _data("level_sky_data").decor()
	if is_keeper():
		return _data("level_keeper_data").decor()
	if is_quiet():
		return _data("level_quiet_data").decor()
	if is_horror():
		return _data("level_horror_data").decor()
	if is_workshop():
		return Level03Data.decor()
	return Level02Data.decor() if is_crossing() else Level01Data.decor()

static func hazards() -> Array[Dictionary]:
	if is_swamp():
		return _data("level_swamp_data").hazards()
	if is_sea():
		return _data("level_sea_data").hazards()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").hazards()
	if is_sky():
		return _data("level_sky_data").hazards()
	if is_keeper():
		return _data("level_keeper_data").hazards()
	if is_quiet():
		return _data("level_quiet_data").hazards()
	if is_horror():
		return _data("level_horror_data").hazards()
	if is_workshop():
		return Level03Data.hazards()
	return Level02Data.hazards() if is_crossing() else Level01Data.hazards()

static func enemies() -> Array[Dictionary]:
	if is_swamp():
		return _data("level_swamp_data").enemies()
	if is_sea():
		return _data("level_sea_data").enemies()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").enemies()
	if is_sky():
		return _data("level_sky_data").enemies()
	if is_keeper():
		return _data("level_keeper_data").enemies()
	if is_quiet():
		return _data("level_quiet_data").enemies()
	if is_horror():
		return _data("level_horror_data").enemies()
	if is_workshop():
		return Level03Data.enemies()
	return Level02Data.enemies() if is_crossing() else Level01Data.enemies()

static func gimmicks() -> Array[Dictionary]:
	if is_swamp():
		return _data("level_swamp_data").gimmicks()
	if is_sea():
		return _data("level_sea_data").gimmicks()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").gimmicks()
	if is_sky():
		return _data("level_sky_data").gimmicks()
	if is_keeper():
		return _data("level_keeper_data").gimmicks()
	if is_quiet():
		return _data("level_quiet_data").gimmicks()
	if is_horror():
		return _data("level_horror_data").gimmicks()
	if is_workshop():
		return Level03Data.gimmicks()
	return Level02Data.gimmicks() if is_crossing() else Level01Data.gimmicks()

## Regions one of the two players cannot see into. Empty for every stage that
## shows both players the same world, which is all of them until 1-V.
static func veils() -> Array[Dictionary]:
	if is_swamp():
		return _data("level_swamp_data").veils()
	if is_sea():
		return _data("level_sea_data").veils()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").veils()
	if is_sky():
		return _data("level_sky_data").veils()
	if is_keeper():
		return _data("level_keeper_data").veils()
	if is_quiet():
		return _data("level_quiet_data").veils()
	if is_horror():
		return _data("level_horror_data").veils()
	if is_workshop():
		return Level03Data.veils()
	return Level02Data.veils() if is_crossing() else Level01Data.veils()

static func checkpoints() -> Array[Vector2]:
	if is_swamp():
		return _data("level_swamp_data").checkpoints()
	if is_sea():
		return _data("level_sea_data").checkpoints()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").checkpoints()
	if is_sky():
		return _data("level_sky_data").checkpoints()
	if is_keeper():
		return _data("level_keeper_data").checkpoints()
	if is_quiet():
		return _data("level_quiet_data").checkpoints()
	if is_horror():
		return _data("level_horror_data").checkpoints()
	if is_workshop():
		return Level03Data.checkpoints()
	return Level02Data.checkpoints() if is_crossing() else Level01Data.checkpoints()

static func goal() -> Vector2:
	if is_swamp():
		return _data("level_swamp_data").goal()
	if is_sea():
		return _data("level_sea_data").goal()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").goal()
	if is_sky():
		return _data("level_sky_data").goal()
	if is_keeper():
		return _data("level_keeper_data").goal()
	if is_quiet():
		return _data("level_quiet_data").goal()
	if is_horror():
		return _data("level_horror_data").goal()
	if is_workshop():
		return Level03Data.goal()
	return Level02Data.goal() if is_crossing() else Level01Data.goal()

## The side-scrolling stages lock their goal until the runner has picked up
## the key, which sits on the ground part-way along. It is what stops a team
## from reaching the goal on guardian platforms without ever landing.
static func needs_key() -> bool:
	return _which == Which.GREENFIELD or _which == Which.HORROR \
		or _which == Which.SEA or _which == Which.SWAMP

## Where the key rests: on the lowest ground under a point ~60% of the way from
## start to goal, nudged along until it is on a floor with no hazard on it.
static func key_position() -> Vector2:
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

static func coins() -> Array[Vector2]:
	if is_swamp():
		return _data("level_swamp_data").coins()
	if is_sea():
		return _data("level_sea_data").coins()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").coins()
	if is_sky():
		return _data("level_sky_data").coins()
	if is_keeper():
		return _data("level_keeper_data").coins()
	if is_quiet():
		return _data("level_quiet_data").coins()
	if is_horror():
		return _data("level_horror_data").coins()
	if is_workshop():
		return Level03Data.coins()
	return Level02Data.coins() if is_crossing() else Level01Data.coins()

static func springs() -> Array[Vector2]:
	if is_swamp():
		return _data("level_swamp_data").springs()
	if is_sea():
		return _data("level_sea_data").springs()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").springs()
	if is_sky():
		return _data("level_sky_data").springs()
	if is_keeper():
		return _data("level_keeper_data").springs()
	if is_quiet():
		return _data("level_quiet_data").springs()
	if is_horror():
		return _data("level_horror_data").springs()
	if is_workshop():
		return Level03Data.springs()
	return Level02Data.springs() if is_crossing() else Level01Data.springs()

static func crystals() -> Array[Vector2]:
	if is_swamp():
		return _data("level_swamp_data").crystals()
	if is_sea():
		return _data("level_sea_data").crystals()
	if is_skyward_ruins():
		return _data("level_skyward_ruins_data").crystals()
	if is_sky():
		return _data("level_sky_data").crystals()
	if is_keeper():
		return _data("level_keeper_data").crystals()
	if is_quiet():
		return _data("level_quiet_data").crystals()
	if is_horror():
		return _data("level_horror_data").crystals()
	if is_workshop():
		return Level03Data.crystals()
	return Level02Data.crystals() if is_crossing() else Level01Data.crystals()

## Where the pit sensor goes. Wide enough to catch the whole active stage.
static func pit_centre_x() -> float:
	if is_swamp():
		return 4200.0
	if is_sea():
		return 4700.0
	if is_skyward_ruins():
		return 0.0
	if is_sky():
		return 4000.0
	if is_keeper():
		return 200.0
	if is_quiet():
		return 1200.0
	if is_horror():
		return 4600.0
	if is_workshop():
		return 5000.0
	return 5000.0 if is_crossing() else 9000.0
