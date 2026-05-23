shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.15, 0.05, 0.05, 1.0);
uniform vec4 lava_color : source_color = vec4(0.9, 0.2, 0.0, 1.0);

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
    
    // Heat distortion
    vec2 dist_uv = uv + vec2(sin(uv.y * 10.0 + TIME) * 0.02, cos(uv.x * 10.0 + TIME) * 0.02);
    
    // Flowing lava river in background
    float river = smoothstep(0.4, 0.6, noise(dist_uv * vec2(3.0, 1.0) - vec2(0.0, TIME * 0.2)));
    float cracks = smoothstep(0.7, 0.8, noise(dist_uv * 15.0));
    
    col.rgb += lava_color.rgb * river * 0.5;
    col.rgb += vec3(1.0, 0.5, 0.0) * cracks * 0.8;
    
    COLOR = col;
}
