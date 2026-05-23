shader_type canvas_item;

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
    vec3 col = vec3(0.02, 0.02, 0.1); // Deep space base
    
    // Nebula 1 (Purple)
    float n1 = noise(uv * 2.0 + vec2(TIME * 0.02, TIME * 0.01));
    float n2 = noise(uv * 4.0 - vec2(TIME * 0.01, 0.0));
    float nebula1 = smoothstep(0.4, 0.8, n1 * n2);
    col += vec3(0.4, 0.1, 0.6) * nebula1;
    
    // Nebula 2 (Cyan)
    float n3 = noise(uv * 3.0 - vec2(0.0, TIME * 0.02));
    float nebula2 = smoothstep(0.5, 0.9, n3);
    col += vec3(0.1, 0.4, 0.6) * nebula2 * 0.8;
    
    // Stars
    float star_val = random(floor(uv * 400.0));
    if (star_val > 0.99) {
        float twinkle = sin(TIME * 5.0 + star_val * 100.0) * 0.5 + 0.5;
        col += vec3(1.0) * twinkle;
    }
    
    COLOR = vec4(col, 1.0);
}
