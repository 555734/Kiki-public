shader_type canvas_item;
// Circular mask for the magnified region, plus the chromatic fringe and edge
// falloff that make it read as glass rather than as a cropped screenshot.

uniform float radius_px = 190.0;
uniform vec2 rect_size = vec2(384.0, 384.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec2 px = UV * rect_size;
    vec2 centre = rect_size * 0.5;
    vec2 d = px - centre;
    float dist = length(d);
    float r = radius_px * amount;

    if (dist > r) {
        COLOR = vec4(0.0);
    } else {
        // Slight chromatic separation toward the rim.
        float t = dist / max(r, 0.001);
        vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
        vec2 off = dir * t * t * 2.4 / rect_size;
        vec4 src = texture(TEXTURE, UV);
        vec4 c;
        c.r = texture(TEXTURE, UV + off).r;
        c.g = src.g;
        c.b = texture(TEXTURE, UV - off).b;
        // Keep the source alpha. The magnified viewport is transparent wherever
        // the world drew nothing (the sky lives on a CanvasLayer the SubViewport
        // cannot see), and forcing alpha to 1 here painted those gaps black.
        c.a = src.a * smoothstep(1.0, 0.965, t);
        // Darken toward the rim like a real optic, and feather the edge.
        c.rgb *= mix(1.0, 0.72, smoothstep(0.55, 1.0, t));
        COLOR = c;
    }
}
