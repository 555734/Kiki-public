class_name Darkness
extends Node2D
## A room with no light in it but the guardian's finger.
##
## Everything inside `size` is drowned in black except a pool of light where
## the guardian is pointing and a faint glow round the runner. Nothing moves,
## nothing is hidden from the physics: it only decides what the two of them
## can SEE, so the runner has to wait for the light and the guardian has to
## light the way rather than look at the whole room. Spec ("darkness"): "pos"
## is the room's top-left corner, "size" its extent.

@export var size: Vector2 = Vector2(1200, 900)
var runner: Runner = null
var _rect: ColorRect
var _material: ShaderMaterial

const FEATHER := 90.0
const SHADER := """
shader_type canvas_item;
uniform vec2 rect_size;
uniform vec2 light_a;
uniform float radius_a;
uniform vec2 light_b;
uniform float radius_b;
uniform float feather;
varying vec2 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float a = 1.0 - smoothstep(0.45, 1.0, distance(local_pos, light_a) / radius_a);
	float b = 1.0 - smoothstep(0.30, 1.0, distance(local_pos, light_b) / radius_b);
	float lit = max(a, b * 0.8);
	vec2 edge = min(local_pos, rect_size - local_pos);
	float inside = smoothstep(0.0, feather, min(edge.x, edge.y));
	COLOR = vec4(0.01, 0.012, 0.03, 0.96 * inside * (1.0 - lit));
}
"""

static func from_spec(spec: Dictionary, runner_ref: Runner) -> Node2D:
	var dark := Darkness.new()
	dark.size = spec.get("size", Vector2(1200, 900))
	dark.runner = runner_ref
	return dark

func _ready() -> void:
	add_to_group("darkness")
	z_index = 60
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("rect_size", size)
	_material.set_shader_parameter("feather", FEATHER)
	_material.set_shader_parameter("radius_a", Balance.DARK_LIGHT_RADIUS)
	_material.set_shader_parameter("radius_b", Balance.DARK_RUNNER_GLOW)
	_rect = ColorRect.new()
	_rect.size = size
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

## Whether a point is somewhere the room is dark.
func covers(world: Vector2) -> bool:
	return Rect2(global_position, size).grow(-FEATHER * 0.5).has_point(world)

func _process(_delta: float) -> void:
	var light := GuardianHand.finger_point(get_tree())
	if light.x == INF:
		light = Vector2(-99999, -99999)
	_material.set_shader_parameter("light_a", light - global_position)
	var glow := Vector2(-99999, -99999)
	if runner != null and is_instance_valid(runner):
		glow = runner.global_position - global_position
	_material.set_shader_parameter("light_b", glow)
