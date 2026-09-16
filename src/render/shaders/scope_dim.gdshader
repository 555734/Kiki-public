shader_type canvas_item;
// Dims the world *outside* the scope ring.
//
// This shader is the reason the scope is a ring and not a full-screen zoom.
// Two people share one display, so anything that blacks out the screen blinds
// the runner. Chapter 9 lists "the runner dies to things they cannot see" as a
// top risk, so `max_alpha` is clamped by the caller to Balance.SCOPE_DIM_MAX_ALPHA
// and the hole is generously feathered.

uniform vec2 centre_px = vec2(640.0, 360.0);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float radius_px = 190.0;
uniform float max_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 px = UV * screen_size;
    float dist = distance(px, centre_px);
    float hole = smoothstep(radius_px * 0.92, radius_px * 1.7, dist);
    COLOR = vec4(0.0, 0.015, 0.05, hole * max_alpha * amount);
}
