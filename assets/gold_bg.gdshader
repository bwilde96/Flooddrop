shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.15, 0.13, 0.05, 1.0);

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
    
    // Golden coins/glitter in background
    float glitter = random(floor(uv * 100.0));
    glitter *= smoothstep(0.8, 1.0, sin(uv.y * 50.0 + TIME * 2.0) * sin(uv.x * 50.0 + TIME));
    col.rgb += vec3(1.0, 0.8, 0.2) * glitter * 0.5;
    
    // Warm light shafts
    float n1 = noise(vec2(uv.x * 5.0 + TIME * 0.1, 0.0));
    float shafts = smoothstep(0.4, 0.8, n1);
    
    col.rgb += vec3(1.0, 0.9, 0.3) * shafts * 0.2;
    
    // Vignette
    float dist = distance(uv, vec2(0.5, 0.5));
    col.rgb *= smoothstep(0.9, 0.4, dist);
    
    COLOR = col;
}
