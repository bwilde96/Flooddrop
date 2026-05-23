shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.08, 0.15, 0.18, 1.0);
uniform vec4 ray_color : source_color = vec4(0.35, 0.78, 0.98, 0.15);

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    
    // Background gradient
    vec4 final_color = bg_color;
    final_color.rgb -= uv.y * 0.1; // Darker at bottom
    
    // God rays
    float ray_angle = uv.x + uv.y * 0.5;
    float n1 = noise(vec2(ray_angle * 10.0 + TIME * 0.2, 0.0));
    float n2 = noise(vec2(ray_angle * 20.0 - TIME * 0.1, 0.0));
    
    float rays = smoothstep(0.4, 0.8, n1 * n2);
    
    // Fade rays near bottom
    rays *= smoothstep(1.0, 0.2, uv.y);
    
    final_color.rgb += ray_color.rgb * rays * ray_color.a;
    
    COLOR = final_color;
}
