class_name Stage
extends RefCounted
## Which stage the game is playing, and the one place that answers it.
##
## Every builder and renderer asks this facade instead of naming a level-data
## class directly, so adding a stage cannot accidentally mix geometry from one
## map with enemies or checkpoints from another.

const HorrorDataScript = preload("res://src/levels/level_horror_data.gd")
const QuietDataScript = preload("res://src/levels/level_quiet_data.gd")
const KeeperDataScript = preload("res://src/levels/level_keeper_data.gd")
const SkyDataScript = preload("res://src/levels/level_sky_data.gd")

enum Which { GREENFIELD, CROSSING, WORKSHOP, HORROR, QUIET, KEEPER, SKY }

## A fresh launch starts at 1-1. The start panel can switch to 1-2 before play.
## Keeping 1-1 as the default means integrating a later stage never replaces the
## existing first stage again.
static var _which: int = Which.GREENFIELD

static func use(which: int) -> void:
	_which = which

static func current() -> int:
	return _which

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

## Stages that only work with one player per device. On a shared screen there is
## nobody to hide anything from, so the whole design collapses into a walk.
static func needs_two_devices() -> bool:
	return is_quiet()

# ------------------------------------------------------------------ constants

static func kill_y() -> float:
	if is_sky():
		return SkyDataScript.kill_y_value()
	if is_keeper():
		return KeeperDataScript.kill_y_value()
	if is_quiet():
		return QuietDataScript.kill_y_value()
	if is_horror():
		return HorrorDataScript.kill_y_value()
	if is_workshop():
		return Level03Data.KILL_Y
	return Level02Data.KILL_Y if is_crossing() else Level01Data.KILL_Y

static func start() -> Vector2:
	if is_sky():
		return SkyDataScript.start_position()
	if is_keeper():
		return KeeperDataScript.start_position()
	if is_quiet():
		return QuietDataScript.start_position()
	if is_horror():
		return HorrorDataScript.start_position()
	if is_workshop():
		return Level03Data.START
	return Level02Data.START if is_crossing() else Level01Data.START

static func stage_name() -> String:
	if is_sky():
		return SkyDataScript.stage_name_value()
	if is_keeper():
		return KeeperDataScript.stage_name_value()
	if is_quiet():
		return QuietDataScript.stage_name_value()
	if is_horror():
		return HorrorDataScript.stage_name_value()
	if is_workshop():
		return Level03Data.STAGE_NAME
	return Level02Data.STAGE_NAME if is_crossing() else Level01Data.STAGE_NAME

static func stage_number() -> String:
	if is_sky():
		return SkyDataScript.stage_number_value()
	if is_keeper():
		return KeeperDataScript.stage_number_value()
	if is_quiet():
		return QuietDataScript.stage_number_value()
	if is_horror():
		return HorrorDataScript.stage_number_value()
	if is_workshop():
		return Level03Data.STAGE_NUMBER
	return Level02Data.STAGE_NUMBER if is_crossing() else Level01Data.STAGE_NUMBER

static func objective() -> String:
	if is_sky():
		return SkyDataScript.objective_value()
	if is_keeper():
		return KeeperDataScript.objective_value()
	if is_quiet():
		return QuietDataScript.objective_value()
	if is_horror():
		return HorrorDataScript.objective_value()
	if is_workshop():
		return Level03Data.OBJECTIVE
	return Level02Data.OBJECTIVE if is_crossing() else Level01Data.OBJECTIVE

# ---------------------------------------------------------------------- data

static func ground() -> Array[Rect2]:
	if is_sky():
		return SkyDataScript.ground()
	if is_keeper():
		return KeeperDataScript.ground()
	if is_quiet():
		return QuietDataScript.ground()
	if is_horror():
		return HorrorDataScript.ground()
	if is_workshop():
		return Level03Data.ground()
	return Level02Data.ground() if is_crossing() else Level01Data.ground()

static func solid_decor() -> Array[Rect2]:
	if is_sky():
		return SkyDataScript.solid_decor()
	if is_keeper():
		return KeeperDataScript.solid_decor()
	if is_quiet():
		return QuietDataScript.solid_decor()
	if is_horror():
		return HorrorDataScript.solid_decor()
	if is_workshop():
		return Level03Data.solid_decor()
	return Level02Data.solid_decor() if is_crossing() else Level01Data.solid_decor()

static func decor() -> Array[Dictionary]:
	if is_sky():
		return SkyDataScript.decor()
	if is_keeper():
		return KeeperDataScript.decor()
	if is_quiet():
		return QuietDataScript.decor()
	if is_horror():
		return HorrorDataScript.decor()
	if is_workshop():
		return Level03Data.decor()
	return Level02Data.decor() if is_crossing() else Level01Data.decor()

static func hazards() -> Array[Dictionary]:
	if is_sky():
		return SkyDataScript.hazards()
	if is_keeper():
		return KeeperDataScript.hazards()
	if is_quiet():
		return QuietDataScript.hazards()
	if is_horror():
		return HorrorDataScript.hazards()
	if is_workshop():
		return Level03Data.hazards()
	return Level02Data.hazards() if is_crossing() else Level01Data.hazards()

static func enemies() -> Array[Dictionary]:
	if is_sky():
		return SkyDataScript.enemies()
	if is_keeper():
		return KeeperDataScript.enemies()
	if is_quiet():
		return QuietDataScript.enemies()
	if is_horror():
		return HorrorDataScript.enemies()
	if is_workshop():
		return Level03Data.enemies()
	return Level02Data.enemies() if is_crossing() else Level01Data.enemies()

static func gimmicks() -> Array[Dictionary]:
	if is_sky():
		return SkyDataScript.gimmicks()
	if is_keeper():
		return KeeperDataScript.gimmicks()
	if is_quiet():
		return QuietDataScript.gimmicks()
	if is_horror():
		return HorrorDataScript.gimmicks()
	if is_workshop():
		return Level03Data.gimmicks()
	return Level02Data.gimmicks() if is_crossing() else Level01Data.gimmicks()

## Regions one of the two players cannot see into. Empty for every stage that
## shows both players the same world, which is all of them until 1-V.
static func veils() -> Array[Dictionary]:
	if is_sky():
		return SkyDataScript.veils()
	if is_keeper():
		return KeeperDataScript.veils()
	if is_quiet():
		return QuietDataScript.veils()
	if is_horror():
		return HorrorDataScript.veils()
	if is_workshop():
		return Level03Data.veils()
	return Level02Data.veils() if is_crossing() else Level01Data.veils()

static func checkpoints() -> Array[Vector2]:
	if is_sky():
		return SkyDataScript.checkpoints()
	if is_keeper():
		return KeeperDataScript.checkpoints()
	if is_quiet():
		return QuietDataScript.checkpoints()
	if is_horror():
		return HorrorDataScript.checkpoints()
	if is_workshop():
		return Level03Data.checkpoints()
	return Level02Data.checkpoints() if is_crossing() else Level01Data.checkpoints()

static func goal() -> Vector2:
	if is_sky():
		return SkyDataScript.goal()
	if is_keeper():
		return KeeperDataScript.goal()
	if is_quiet():
		return QuietDataScript.goal()
	if is_horror():
		return HorrorDataScript.goal()
	if is_workshop():
		return Level03Data.goal()
	return Level02Data.goal() if is_crossing() else Level01Data.goal()

static func coins() -> Array[Vector2]:
	if is_sky():
		return SkyDataScript.coins()
	if is_keeper():
		return KeeperDataScript.coins()
	if is_quiet():
		return QuietDataScript.coins()
	if is_horror():
		return HorrorDataScript.coins()
	if is_workshop():
		return Level03Data.coins()
	return Level02Data.coins() if is_crossing() else Level01Data.coins()

static func springs() -> Array[Vector2]:
	if is_sky():
		return SkyDataScript.springs()
	if is_keeper():
		return KeeperDataScript.springs()
	if is_quiet():
		return QuietDataScript.springs()
	if is_horror():
		return HorrorDataScript.springs()
	if is_workshop():
		return Level03Data.springs()
	return Level02Data.springs() if is_crossing() else Level01Data.springs()

static func crystals() -> Array[Vector2]:
	if is_sky():
		return SkyDataScript.crystals()
	if is_keeper():
		return KeeperDataScript.crystals()
	if is_quiet():
		return QuietDataScript.crystals()
	if is_horror():
		return HorrorDataScript.crystals()
	if is_workshop():
		return Level03Data.crystals()
	return Level02Data.crystals() if is_crossing() else Level01Data.crystals()

## Where the pit sensor goes. Wide enough to catch the whole active stage.
static func pit_centre_x() -> float:
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