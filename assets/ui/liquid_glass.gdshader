shader_type canvas_item;
// Liquid Glass — the game's unified UI surface (docs/DESIGN_SYSTEM.md).
// A dark glass vessel holding glowing accent liquid with a live waveline.

uniform vec2 rect_size = vec2(300.0, 64.0);
uniform float corner_radius = 32.0;   // = height/2 for capsules
uniform vec4 accent : source_color = vec4(0.22, 0.9, 1.0, 1.0);
uniform float fill_level : hint_range(0.0, 1.0) = 0.2; // liquid height fraction
uniform float glass_alpha : hint_range(0.0, 1.0) = 0.92;
uniform float brightness = 1.0;       // press/hover boost, disabled dim
uniform float wave_amp = 2.4;
uniform float wave_speed = 1.0;

float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * rect_size;
	vec2 b = rect_size * 0.5;
	float r = min(corner_radius, min(b.x, b.y));
	float d = sd_rbox(p, b, r);
	float shape = 1.0 - smoothstep(-1.0, 1.0, d);

	// Glass body: blue-tinted ink, lighter toward the top (light enters from above)
	vec3 col = mix(vec3(0.075, 0.11, 0.175), vec3(0.022, 0.038, 0.066), UV.y);

	// --- Liquid fill with a living surface ---
	float surf_y = (0.5 - fill_level) * rect_size.y; // p.y of the liquid surface
	float wave = sin(p.x * 0.045 + TIME * 1.9 * wave_speed) * wave_amp
		+ sin(p.x * 0.011 - TIME * 1.2 * wave_speed) * wave_amp * 0.6;
	float liq = p.y - (surf_y + wave); // > 0 under the surface
	float in_liq = smoothstep(0.0, 2.0, liq);

	// Deep liquid darkens with depth; glows near its own surface
	float depth = clamp(liq / max(rect_size.y * 0.9, 1.0), 0.0, 1.0);
	vec3 liq_col = mix(accent.rgb * 0.75, accent.rgb * 0.32, depth);
	col = mix(col, liq_col, in_liq * 0.92);

	// Bright surface line + soft bloom-friendly glow above and below it
	float surf_glow = exp(-abs(liq) * 0.14);
	col += accent.rgb * surf_glow * 0.42;
	col += vec3(1.0) * exp(-abs(liq) * 0.55) * 0.22;

	// --- Glasswork ---
	// Meniscus: a bright inner line hugging the top edge, curving with the corners
	float edge_band = smoothstep(3.2, 0.4, abs(d + 2.2));
	float top_weight = smoothstep(0.55, 0.05, UV.y);
	col += vec3(0.85, 0.97, 1.0) * edge_band * top_weight * 0.38;

	// Soft accent rim everywhere else (light through the vessel walls)
	col += accent.rgb * edge_band * 0.16 * (1.0 - top_weight * 0.7);

	// Key-light specular blob, top-left (matches the droplet shader's light)
	float spec = exp(-length((UV - vec2(0.16, 0.14)) * vec2(2.4, 3.4)) * 3.2);
	col += vec3(1.0) * spec * 0.10;

	col *= brightness;
	COLOR = vec4(col, shape * glass_alpha);
}
