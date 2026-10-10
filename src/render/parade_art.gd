class_name ParadeArt
extends RefCounted
## Original imagegen paintings, consumed as native atlas regions without
## rewriting the source PNGs. Regions exclude transparent atlas padding.
const FILES := {"background": "background", "gremlin": "gremlin_run",
	"mouth": "mouth_gate", "hammer": "hammer", "floor": "theatre_floor",
	"cast": "cast_v2", "devices": "machines_v2"}
static var _paintings: Dictionary = {}

static func painting(key: String) -> Texture2D:
	if not _paintings.has(key):
		_paintings[key] = load("res://assets/stage_1_9/%s.png" % FILES[key])
	return _paintings[key] as Texture2D

## Large atlases belong to 1-9; compiling shared renderers must not load them
## into every earlier stage. Warm only when this course is actually built.
static func warm() -> void:
	for key in FILES: painting(String(key))

static func floor_on(ci: CanvasItem, rect: Rect2) -> void:
	# A fixed top rim exactly matches the authored collision top.
	var count := maxi(1, ceili(rect.size.x / 480.0))
	var width := rect.size.x / count
	for i in count:
		ci.draw_texture_rect_region(painting("floor"),
			Rect2(rect.position + Vector2(i * width, 0), Vector2(width, maxf(52, rect.size.y))),
			Rect2(30, 227, 2112, 269))

static func gremlin_on(ci: CanvasItem, frame: int, height: float, facing: int,
		tint: Color = Color.WHITE) -> void:
	var width := height * 543.0 / 600.0
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	ci.draw_texture_rect_region(painting("gremlin"), Rect2(-width * 0.5, 22 - height, width, height),
		Rect2(posmod(frame, 4) * 543, 60, 543, 600), tint)
	ci.draw_set_transform(Vector2.ZERO)

static func mouth_on(ci: CanvasItem, frame: int, height: float) -> void:
	var width := height * 724.0 / 680.0
	ci.draw_texture_rect_region(painting("mouth"), Rect2(-width * 0.5, -height, width, height),
		Rect2(clampi(frame, 0, 2) * 724, 0, 724, 680))

static func actor_on(ci: CanvasItem, index: int, height: float, tint: Color = Color.WHITE) -> void:
	var row := index / 4
	var y := 0 if row == 0 else (384 if row == 1 else 694)
	var h := 384 if row == 0 else (310 if row == 1 else 330)
	var width := height * 384.0 / h
	ci.draw_texture_rect_region(painting("cast"), Rect2(-width * 0.5, 30 - height, width, height), Rect2((index % 4) * 384, y, 384, h), tint)

## Rectangles refer to the unchanged generated PNG, not resampled crops.
const DEVICE_REGIONS := [Rect2(0,0,278,365), Rect2(278,0,222,365),
	Rect2(500,0,287,365), Rect2(787,0,259,365), Rect2(1046,0,217,365),
	Rect2(1263,0,273,365), Rect2(0,365,280,317), Rect2(280,365,233,317),
	Rect2(513,365,262,317), Rect2(775,472,330,209), Rect2(1105,365,185,317),
	Rect2(1290,365,246,317), Rect2(0,682,256,342), Rect2(256,682,256,342),
	Rect2(512,740,324,260), Rect2(836,682,196,342), Rect2(1032,720,239,304),
	Rect2(1271,682,265,342)]

static func device_on(ci: CanvasItem, index: int, rect: Rect2) -> void:
	var region: Rect2 = DEVICE_REGIONS[index]
	var width := minf(rect.size.x, rect.size.y * region.size.x / region.size.y)
	ci.draw_texture_rect_region(painting("devices"), Rect2(rect.position + Vector2((rect.size.x - width) * 0.5, 0), Vector2(width, rect.size.y)), region)

static func cabin_on(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_texture_rect_region(painting("devices"), Rect2(at + Vector2(-55,-90), Vector2(110,110)), Rect2(1275,85,96,115))

static func bell_on(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_texture_rect_region(painting("devices"), Rect2(at + Vector2(-67,-55), Vector2(134,110)), Rect2(1315,457,185,186))

static func crate_on(ci: CanvasItem, rect: Rect2, tint: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(painting("devices"), rect, Rect2(888,480,125,111), tint)
