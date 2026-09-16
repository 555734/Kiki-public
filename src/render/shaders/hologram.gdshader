shader_type canvas_item;
// The cyan hex-grid slab the guardian conjures, as seen in the mockups.
// Deliberately written for the gl_compatibility renderer too, so the same
// shader runs on the oldest Android devices we are willing to support.

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint : source_color = vec4(0.208, 0.839, 1.0, 1.0);
uniform vec2 rect_size = vec2(150.0, 26.0);
uniform float cell_px = 15.0;      // hex cell size in pixels
uniform float border_px = 2.5;
uniform float scan_speed = 0.9;
uniform float expiring : hint_range(0.0, 1.0) = 0.0;

const vec2 HEX_R = vec2(1.0, 1.7320508);

// Distance to the edge of the hexagon containing p (p already cell-local).
float hex_dist(vec2 p) {
    p = abs(p);
    return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

// Nearest hex centre offset for a point on a unit hex lattice.
vec2 hex_local(vec2 p) {
    vec2 h = HEX_R * 0.5;
    vec2 a = mod(p, HEX_R) - h;
    vec2 b = mod(p - h, HEX_R) - h;
    return dot(a, a) < dot(b, b) ? a : b;
}

void fragment() {
    vec2 px = UV * rect_size;

    // --- hex lattice ---
    vec2 gv = hex_local(px / cell_px);
    float d = hex_dist(gv);
    float aa = fwidth(d) + 0.001;
    float lattice = smoothstep(0.50 - aa * 2.0, 0.50, d);

    // --- border: distance to the nearest edge of the slab, in pixels ---
    vec2 edge = min(px, rect_size - px);
    float edge_d = min(edge.x, edge.y);
    float border = 1.0 - smoothstep(border_px, border_px + 1.5, edge_d);

    // --- travelling scan band, so a live hologram never looks like a decal ---
    float scan = smoothstep(0.90, 1.0, fract(UV.x * 0.5 - TIME * scan_speed));
    scan += smoothstep(0.90, 1.0, fract(UV.y * 0.9 - TIME * scan_speed * 0.6)) * 0.5;

    float body = 0.34;
    float glow = lattice * 0.42 + border * 0.95 + scan * 0.22;

    vec3 col = tint.rgb * (0.75 + glow * 0.65);
    float a = clamp(body + glow, 0.0, 1.0);

    // Blink faster and faster as the lifetime runs out. The runner has to be
    // able to see "this is about to go away" without reading a timer.
    float warn = expiring * (0.5 + 0.5 * sin(TIME * mix(6.0, 34.0, expiring)));
    col = mix(col, vec3(1.0, 0.86, 0.35), warn * 0.55);
    a *= 1.0 - warn * 0.35;

    COLOR = vec4(col, a * fade);
}
