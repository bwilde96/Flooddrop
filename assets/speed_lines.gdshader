shader_type canvas_item;

uniform float speed = 0.0;
uniform float darkness = 0.0;
uniform vec4 line_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);

uniform float reveal_progress = 0.0; // 0.0 to 1.0

// 2D Simplex Noise for soft, organic beams
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404; 
    const float K2 = 0.211324865; 
    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

float fbm(vec2 uv) {
    float f = 0.0;
    float weight = 0.5;
    vec2 p = uv;
    for(int i = 0; i < 3; i++) {
        f += weight * noise(p);
        p = p * 2.02 + vec2(0.1, TIME * 0.1);
        weight *= 0.5;
    }
    return f * 0.5 + 0.5;
}

void fragment() {
    vec2 uv = UV;
    
    // Stretch UVs vertically to create flowing light beams
    float stretch = 1.0 + (speed * 2.0);
    float move_y = TIME * speed * 1.5;
    
    // Smooth, glowing foreground beams
    vec2 beam_uv1 = vec2(uv.x * 2.0, (uv.y + move_y) * 2.0 / stretch);
    // Slower, wider background aura
    vec2 beam_uv2 = vec2(uv.x * 3.0 + 10.0, (uv.y + move_y * 1.2) * 3.0 / stretch);
    
    float b1 = fbm(beam_uv1);
    float b2 = fbm(beam_uv2);
    
    // Combine for a magical, flowing glow
    float final_beam = (b1 * 0.7) + (b2 * 0.5);
    
    // Smooth contrast for glowing edges
    final_beam = smoothstep(0.2, 0.8, final_beam);
    
    vec3 color = line_color.rgb * final_beam * 1.5; // Overdrive for magical glow
    
    // Vignette Tunnel (Deep, rich color instead of pure black until the very end)
    vec2 center_dist = uv - vec2(0.5);
    float vignette = length(center_dist);
    
    float v_edge = mix(1.0, 0.2, pow(darkness, 0.7));
    float v_center = mix(0.1, 0.0, darkness);
    float tunnel = smoothstep(v_edge, v_center, vignette);
    
    // Fade to black based on darkness, but keep the edges colored longer
    vec3 edge_color = line_color.rgb * 0.2;
    vec3 mixed_color = mix(edge_color, color, tunnel);
    
    color = mix(mixed_color, vec3(0.0), pow(darkness, 1.5));
    
    // Alpha must be 1.0 to hide the map underneath, but starts transparent
    float alpha = clamp(speed, 0.0, 1.0);
    
    // "Light fading in" effect
    // As reveal_progress goes 0 -> 1, threshold goes 0 -> 2.5
    float threshold = reveal_progress * 2.5; 
    // At reveal 0.5: smoothstep(0.25, 1.25, vignette). Center is clear (0), edges are black (1)
    // At reveal 1.0: smoothstep(1.5, 2.5, vignette). All is clear (0)
    float soft_mask = smoothstep(threshold - 1.0, threshold, vignette);
    
    alpha *= soft_mask;
    
    COLOR = vec4(color, alpha);
}
