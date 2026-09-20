class_name VersusLaunch
## What the start screen chose, carried across the scene change.
##
## Static rather than an autoload: the cooperative game's autoload list is part
## of every stage's boot, and adding to it for a mode that is not on that path
## would make every co-op launch carry the versus mode's state. A handful of
## statics is enough to survive a change_scene_to_file, which is all this has
## to do.

enum How { NONE, SOLO, HOST, JOIN }

static var how: int = How.NONE
static var code: String = ""
static var relay: String = ""
static var seat: int = 0
static var room_mode: int = VersusRoster.RoomMode.TEAM_SPLIT

static func clear() -> void:
	how = How.NONE
	code = ""
	relay = ""
	seat = 0
	room_mode = VersusRoster.RoomMode.TEAM_SPLIT

static func chosen() -> bool:
	return how != How.NONE
