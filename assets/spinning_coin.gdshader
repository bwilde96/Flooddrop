shader_type canvas_item;

uniform vec4 coin_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);
uniform float spin_speed = 5.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV - center;
    
    // Animate spinning by squishing X
    float spin = TIME * spin_speed;
    float cos_spin = cos(spin);
    float sin_spin = sin(spin);
    
    float scale_x = abs(cos_spin);
    // Avoid division by zero to prevent rendering artifacts
    scale_x = max(scale_x, 0.05);
    
    vec2 front_uv = vec2(uv.x / scale_x, uv.y);
    float dist = length(front_uv);
    
    vec4 final_color = vec4(0.0);
    
    // Coin size control
    float coin_radius = 0.35;
    
    // 1. Draw the "Side Edge" of the coin (visible when rotating)
    // We calculate a back circle offset slightly based on the rotation direction.
    float edge_offset = sign(sin_spin) * 0.04 * (1.0 - scale_x); 
    vec2 back_uv = vec2((uv.x - edge_offset) / scale_x, uv.y);
    float back_dist = length(back_uv);
    
    if (back_dist < coin_radius) {
        final_color = coin_color;
        final_color.rgb *= 0.5; // Darker edge for shadow depth
        
        // Add vertical ridges to the edge!
        float ridges = sin(uv.y * 200.0);
        if (ridges > 0.0) final_color.rgb *= 0.7;
        
        final_color.a = 1.0;
    }
    
    // 2. Draw the "Front Face" of the coin on top
    if (dist < coin_radius) {
        // Base color
        final_color = coin_color;
        
        // Outer lip (bright)
        if (dist > coin_radius - 0.02) {
            final_color.rgb += vec3(0.2);
        }
        
        // Inner rim groove (dark)
        if (dist > coin_radius - 0.06 && dist < coin_radius - 0.02) {
            final_color.rgb *= 0.6;
        }
        
        // Ring of dots (Minting detail)
        float angle = atan(front_uv.y, front_uv.x);
        if (dist > coin_radius - 0.1 && dist < coin_radius - 0.07) {
            float dots = sin(angle * 40.0);
            if (dots > 0.5) final_color.rgb += vec3(0.3); // Raised dots
            else final_color.rgb *= 0.8; // Recessed space
        }
        
        // Center Face Detail (Sunburst / Profile abstraction)
        float sunburst = cos(angle * 12.0) * 0.05;
        if (dist < 0.15 + sunburst) {
            final_color.rgb += vec3(0.15); // Raised center crest
            if (dist > 0.13 + sunburst) {
                final_color.rgb -= vec3(0.3); // Deep inner bevel
            }
        }
        
        // Smooth metallic sheen that preserves contrast
        float sheen = (uv.x + uv.y + 0.5) * 0.8;
        final_color.rgb *= mix(vec3(0.7), vec3(1.4), clamp(sheen, 0.0, 1.0));
        
        // Add a glowing rim at the absolute edge of the front face
        if (dist > coin_radius - 0.01) {
            final_color.rgb += vec3(0.5) * (dist - (coin_radius - 0.01)) * 100.0;
        }
        
        final_color.a = 1.0;
    }
    
    // 3. Outer Glow Aura
    if (final_color.a == 0.0) {
        float glow_dist = length(uv);
        if (glow_dist < coin_radius + 0.1) {
            float glow_intensity = smoothstep(coin_radius + 0.1, coin_radius - 0.05, glow_dist);
            final_color = vec4(coin_color.rgb, glow_intensity * 0.5);
        }
    }
    
    COLOR = clamp(final_color, 0.0, 1.0);
}
