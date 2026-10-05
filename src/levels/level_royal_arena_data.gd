extends RefCounted
## Versus owns its geometry; common hooks keep the stage contract complete.
static func stage_name_value() -> String: return "ROYAL ARENA"
static func stage_number_value() -> String: return "VS"
static func painted_2d_value() -> bool: return true
static func kill_y_value() -> float: return Level01Data.kill_y_value()
static func start_position() -> Vector2: return Level01Data.start_position()
static func objective_value() -> String: return Level01Data.objective_value()
static func ground() -> Array[Rect2]: return Level01Data.ground()
static func solid_decor() -> Array[Rect2]: return Level01Data.solid_decor()
static func decor() -> Array[Dictionary]: return Level01Data.decor()
static func hazards() -> Array[Dictionary]: return Level01Data.hazards()
static func enemies() -> Array[Dictionary]: return Level01Data.enemies()
static func gimmicks() -> Array[Dictionary]: return Level01Data.gimmicks()
static func veils() -> Array[Dictionary]: return Level01Data.veils()
static func checkpoints() -> Array[Vector2]: return Level01Data.checkpoints()
static func goal() -> Vector2: return Level01Data.goal()
static func coins() -> Array[Vector2]: return Level01Data.coins()
static func springs() -> Array[Vector2]: return Level01Data.springs()
static func crystals() -> Array[Vector2]: return Level01Data.crystals()
