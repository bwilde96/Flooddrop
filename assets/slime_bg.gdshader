shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.05, 0.15, 0.05, 1.0);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(random(i), random(i + vec2(1.0, 0.0)), f.x),
               mix(random(i + vec2(0.0, 1.0)), random(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    vec4 col = bg_color;
    
    // Slow rolling fog
    float n = noise(uv * 3.0 + vec2(TIME * 0.05, 0.0));
    float n2 = noise(uv * 5.0 - vec2(TIME * 0.1, TIME * 0.05));
    float fog = smoothstep(0.4, 0.8, n * n2) * 0.5;
    
    // Glowing spots (spores/mushrooms in bg)
    float spots = smoothstep(0.85, 0.95, noise(uv * 10.0 + TIME * 0.1));
    
    col.rgb += vec3(0.2, 0.8, 0.2) * fog;
    col.rgb += vec3(0.4, 1.0, 0.3) * spots * 0.6;
    
    // Darken edges
    float dist = distance(uv, vec2(0.5, 0.5));
    col.rgb *= smoothstep(0.8, 0.3, dist);
    
    COLOR = col;
}
