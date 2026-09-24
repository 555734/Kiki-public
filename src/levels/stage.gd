class_name Stage
extends RefCounted
## Which stage the game is playing, and the one place that answers it.
##
## Every builder and renderer asks this facade instead of naming a level-data
## class directly, so adding a stage cannot accidentally mix geometry from one
## map with enemies or checkpoints from another.


## New stages go on the END: the value is what travels in the handshake.
enum Which { GREENFIELD, CROSSING, WORKSHOP, HORROR, QUIET, KEEPER, SKY, SKYWARD_RUINS, SEA }

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
		and _which != Which.SEA

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

## The sea's surface on a stage that has one (1-4), or INF.
static func water_y() -> float:
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

static func stage_number() -> String:
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

static func coins() -> Array[Vector2]:
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
