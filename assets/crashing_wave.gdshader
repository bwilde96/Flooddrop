shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec4 deep_ocean : source_color = vec4(0.0, 0.05, 0.2, 0.98);
uniform vec4 mid_ocean : source_color = vec4(0.0, 0.3, 0.5, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.0, 0.6, 0.7, 0.9);
uniform vec4 subsurface_glow : source_color = vec4(0.2, 0.9, 0.8, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Hash for noise
vec2 hash22(vec2 p) {
    vec3 p3 = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + vec3(33.33));
    return fract((p3.xx + p3.yz) * p3.zy);
}

// 2D Simplex Noise
float noise(vec2 p) {
    vec2 i = floor(p + (p.x + p.y) * 0.366025404);
    vec2 a = p - i + (i.x + i.y) * 0.211324865;
    vec2 o = step(a.yx, a.xy);    
    vec2 b = a - o + vec2(0.211324865);
    vec2 c = a - vec2(1.0) + vec2(2.0 * 0.211324865);

    vec3 h = max(vec3(0.5) - vec3(dot(a, a), dot(b, b), dot(c, c)), vec3(0.0));
    vec3 n = h * h * h * h * vec3(
        dot(a, hash22(i) * 2.0 - vec2(1.0)),
        dot(b, hash22(i + o) * 2.0 - vec2(1.0)),
        dot(c, hash22(i + vec2(1.0)) * 2.0 - vec2(1.0))
    );
    return dot(n, vec3(70.0));
}

// FBM
float fbm(vec2 p) {
    float f = 0.0;
    float w = 0.5;
    for (int i = 0; i < 4; i++) {
        f += w * noise(p);
        p *= 2.0;
        w *= 0.5;
    }
    return f;
}

// Voronoi
float voronoi(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    float res = 8.0;
    for(int j = -1; j <= 1; j++) {
        for(int i = -1; i <= 1; i++) {
            vec2 b = vec2(float(i), float(j));
            vec2 r = b - f + hash22(p + b);
            float d = dot(r, r);
            res = min(res, d);
        }
    }
    return sqrt(res);
}

void fragment() {
    float x = UV.x * 3.0; 
    float y = UV.y;
    float t = TIME * 1.5;
    
    float swell = 0.1 * sin(x * 3.0 + t) + 0.05 * sin(x * 8.0 - t * 1.2);
    float edge_fbm = fbm(vec2(x * 12.0 - t * 2.0, t)) * 0.15;
    float curl = pow(abs(sin(x * 4.0 + t * 1.5)), 4.0) * 0.08;
    
    float crest = swell + edge_fbm + curl + 0.2;
    float normalized_y = y - crest;
    
    if (normalized_y < 0.0) {
        float mist = fbm(vec2(x * 8.0 + t, y * 10.0 - t * 2.0));
        float mist_alpha = (1.0 - smoothstep(-0.15, 0.0, normalized_y)) * smoothstep(-0.3, -0.1, normalized_y) * mist * 0.6;
        mist_alpha = clamp(mist_alpha, 0.0, 1.0);
        COLOR = mix(vec4(0.0), foam_color, mist_alpha);
    } else {
        float displace = fbm(vec2(x * 15.0 - t, y * 10.0 + t * 1.5));
        
        float depth = clamp(normalized_y * 1.5, 0.0, 1.0);
        vec4 water_color = mix(shallow_color, mid_ocean, smoothstep(0.0, 0.4, depth));
        water_color = mix(water_color, deep_ocean, smoothstep(0.4, 1.0, depth));
        
        float sss = 1.0 - smoothstep(0.0, 0.15, normalized_y);
        water_color = mix(water_color, subsurface_glow, sss * (0.5 + 0.5 * displace));
        
        vec2 caustic_uv = vec2(x * 8.0 + t * 0.5, y * 10.0 - t);
        caustic_uv += vec2(displace * 1.5);
        float c = voronoi(caustic_uv);
        c = clamp(1.0 - c, 0.0, 1.0);
        c = c * c * c;
        
        float caustic_intensity = (1.0 - smoothstep(0.0, 0.8, depth)) * 0.6;
        water_color += vec4(c * caustic_intensity);
        
        float streaks = fbm(vec2(x * 20.0, y * 2.0 + t * 3.0));
        streaks = smoothstep(0.65, 0.9, streaks);
        float streak_mask = smoothstep(0.0, 0.3, normalized_y) * (1.0 - smoothstep(0.3, 0.8, normalized_y));
        
        float foam_thickness = 0.08 + 0.1 * abs(fbm(vec2(x * 12.0 + t * 2.0, t)));
        float foam_factor = 1.0 - smoothstep(0.0, max(0.01, foam_thickness), normalized_y);
        
        float foam_noise = fbm(vec2(x * 25.0 + t * 4.0, y * 25.0));
        foam_factor *= (0.4 + 0.6 * foam_noise);
        
        float total_foam = clamp(foam_factor + (streaks * streak_mask), 0.0, 1.0);
        
        if (normalized_y < 0.005) {
            total_foam = 1.0;
        }
        
        vec4 final_color = mix(water_color, foam_color, total_foam);
        
        vec2 uv_offset = vec2(displace, fbm(vec2(x * 10.0 + t, y * 15.0))) * 0.035 * (1.0 - total_foam);
        vec4 bg = texture(screen_texture, SCREEN_UV + uv_offset);
        
        float opacity = clamp(final_color.a + total_foam, 0.0, 1.0);
        COLOR = mix(bg, final_color, opacity);
    }
}
