extends CanvasLayer
## Parallax background: gradient sky, drifting clouds, rounded hills, a distant
## castle and a near bush line -- the mockups' backdrop.
##
## This is drawn in screen space with the camera offset applied by hand rather
## than with ParallaxBackground, because every layer is procedural: at any
## moment only the handful of shapes actually on screen need to be emitted, so a
## 9,000px stage costs the same as a 900px one.

## Camera height at which the horizon sits on REFERENCE_GROUND of the screen.
## Roughly where the camera is with the runner standing on the main ground line.
const REFERENCE_CAM_Y := 337.0
const REFERENCE_GROUND := 0.63

const LAYERS := [
	{"rate": 0.06, "kind": "clouds"},
	{"rate": 0.16, "kind": "hills_far"},
	{"rate": 0.24, "kind": "castle"},
	{"rate": 0.38, "kind": "hills_near"},
	{"rate": 0.55, "kind": "bushes"},
]

var camera: Camera2D = null

var _canvas: Control = null
var _gradient: GradientTexture2D = null
var _time: float = 0.0

func _ready() -> void:
	layer = -10
	_gradient = GradientTexture2D.new()
	var g := Gradient.new()
	# 1-S is above the clouds at dawn: dark blue overhead going to gold at the
	# cloud line, which is the reverse of every other stage's pale-at-the-bottom
	# daylight.
	if Stage.is_skyward_ruins():
		# Bright midday blue, deepening overhead, like the painted sheets.
		g.set_color(0, Color("3d8fe0"))
		g.set_color(1, Color("dff3ff"))
		g.add_point(0.55, Color("8ccdf4"))
	elif Stage.is_sky():
		g.set_color(0, Balance.C_DAWN_TOP)
		g.set_color(1, Balance.C_DAWN_LOW)
		g.add_point(0.62, Balance.C_DAWN_MID)
	else:
		g.set_color(0, Balance.C_SKY_TOP)
		g.set_color(1, Balance.C_SKY_BOTTOM)
		g.add_point(0.55, Balance.C_SKY_TOP.lerp(Balance.C_SKY_BOTTOM, 0.55))
	_gradient.gradient = g
	if Balance.USE_3D:
		if Stage.is_horror() or Stage.is_keeper():
			g.set_color(0,Color("172237"))
			g.set_color(1,Color("536175"))
			g.set_color(2,Color("344453"))
		elif not Stage.is_sky() and not Stage.is_skyward_ruins():
			g.set_color(0,Color("449ee0"))
			g.set_color(1,Color("c9e7e2"))
			g.set_color(2,Color("84cbdc"))
	_gradient.fill_from = Vector2(0, 0)
	_gradient.fill_to = Vector2(0, 1)
	_gradient.width = 4
	_gradient.height = 256

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_script(preload("res://src/render/sky_canvas.gd"))
	add_child(_canvas)
	_canvas.sky = self

func _process(delta: float) -> void:
	_time += delta
	if _canvas != null:
		_canvas.queue_redraw()

func gradient() -> GradientTexture2D:
	return _gradient

func time() -> float:
	return _time

func scroll() -> float:
	return camera.global_position.x if camera != null else 0.0

func vertical() -> float:
	return camera.global_position.y if camera != null else REFERENCE_CAM_Y
