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

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec2 uv = UV;
    
    // Shifting pastel rainbow background
    float hue = fract(uv.x * 0.5 + uv.y * 0.5 + TIME * 0.1);
    vec3 bg = hsv2rgb(vec3(hue, 0.5, 0.9)); // Pastel
    
    // Soft clouds
    float n1 = noise(uv * 3.0 + vec2(TIME * 0.05, 0.0));
    float n2 = noise(uv * 6.0 - vec2(TIME * 0.02, 0.0));
    float clouds = smoothstep(0.4, 0.8, n1 * n2);
    
    bg = mix(bg, vec3(1.0), clouds * 0.6);
    
    COLOR = vec4(bg, 1.0);
}
