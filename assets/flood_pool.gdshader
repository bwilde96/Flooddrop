shader_type canvas_item;

uniform float wave_speed = 1.5;
uniform float wave_freq = 5.0;
uniform float wave_amp = 0.03;
uniform vec4 top_color: source_color = vec4(0.35, 0.78, 0.98, 0.9);
uniform vec4 bottom_color: source_color = vec4(0.19, 0.38, 0.84, 0.95);
uniform int liquid_type = 0; // 0=Water, 1=Lava, 2=Slime, 3=Acid, 4=Rainbow, 5=Galaxy, 6=Gold, 7=Neon Plasma

// Simple random function
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// 2D Noise function
float noise(vec2 pos) {
    vec2 i = floor(pos);
    vec2 f = fract(pos);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Voronoi Cell Noise for Lava Cracks
vec2 voronoi_hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}
float voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float res = 8.0;
    for(int j=-1; j<=1; j++)
        for(int i=-1; i<=1; i++) {
            vec2 b = vec2(float(i), float(j));
            vec2 r = vec2(b) - f + voronoi_hash(n + b);
            float d = dot(r, r);
            res = min(res, d);
        }
    return sqrt(res);
}

vec3 hue2rgb(float hue) {
    float R = abs(hue * 6.0 - 3.0) - 1.0;
    float G = 2.0 - abs(hue * 6.0 - 2.0);
    float B = 2.0 - abs(hue * 6.0 - 4.0);
    return clamp(vec3(R,G,B), 0.0, 1.0);
}

void fragment() {
    float current_wave_speed = wave_speed;
    float current_wave_freq = wave_freq;
    float current_wave_amp = wave_amp;
    
    if (liquid_type == 1 || liquid_type == 6) { // Lava, Gold (Thick)
        current_wave_speed *= 0.5;
        current_wave_amp *= 0.5;
    } else if (liquid_type == 2) { // Slime
        current_wave_speed *= 0.8;
        current_wave_amp *= 1.5; // High wobble
    } else if (liquid_type == 3) { // Acid
        current_wave_speed *= 2.0;
        current_wave_freq *= 1.5;
    } else if (liquid_type == 7) { // Neon Plasma
        current_wave_speed *= (sin(TIME * 10.0) > 0.0) ? 3.0 : 0.1; // Stutter
    }
    
    float time_val = TIME * current_wave_speed;
    float phase = UV.x * current_wave_freq + time_val;
    float wave = sin(phase) * current_wave_amp;
    float edge = current_wave_amp + wave;
    
    if (UV.y < edge) {
        COLOR.a = 0.0;
    } else {
        // Depth gradient (0.0 at surface, 1.0 at bottom)
        float depth = clamp((UV.y - edge) / (1.0 - edge), 0.0, 1.0);
        
        // FAKE 3D SURFACE NORMAL
        // Derivative of sin(x) is cos(x)
        float dw_dx = cos(phase) * current_wave_amp * current_wave_freq;
        // Y normal points up, X normal tilts with the wave, Z normal faces screen
        vec3 normal = normalize(vec3(-dw_dx, 1.0, 0.4));
        
        // Lighting Setup
        vec3 light_dir = normalize(vec3(-0.6, 1.0, 0.8)); // Light coming from top-left-front
        vec3 view_dir = vec3(0.0, 0.0, 1.0);
        vec3 half_vector = normalize(light_dir + view_dir);
        
        float diffuse = max(0.0, dot(normal, light_dir));
        float specular = pow(max(0.0, dot(normal, half_vector)), 64.0);
        
        vec4 final_color = vec4(0.0);
        vec2 world_pos = UV * vec2(100.0, 100.0);
        
        // ----------------------------------------------------
        // LIQUID TYPES WITH 3D MATERIALS
        // ----------------------------------------------------
        
        if (liquid_type == 0) {
            // WATER: High opacity, caustic ripples on surface
            float caustics = sin(world_pos.x * 0.2 + TIME * 2.0) * sin(world_pos.y * 0.2 + TIME * 1.5);
            vec4 col = mix(vec4(0.1, 0.3, 0.5, 1.0), vec4(0.0, 0.1, 0.3, 1.0), depth);
            col += caustics * 0.1 * (1.0 - depth); // Caustics only near surface
            final_color = col + vec4(1.0) * specular * 2.0 * (1.0 - depth);
        }
        else if (liquid_type == 1) {
            // LAVA: Voronoi cracking crust with molten core glowing through
            vec4 core_color = vec4(1.0, 0.8, 0.0, 1.0);
            vec4 crust_color = vec4(0.1, 0.0, 0.0, 1.0);
            
            float v = voronoi(world_pos * 0.15 + vec2(TIME * -0.2, 0.0));
            float cracks = smoothstep(0.7, 0.9, v);
            
            // Crust covers the surface, core glows from below
            vec4 surf_color = mix(crust_color, core_color, cracks);
            final_color = mix(surf_color, core_color, depth * 0.5); // Gets brighter deeper down
            
            // Glowing hot rim on the waves
            final_color += vec4(1.0, 0.3, 0.0, 0.0) * diffuse * (1.0 - depth) * 1.5;
            final_color += vec4(1.0, 0.5, 0.2, 0.0) * pow(max(0.0, dot(normal, half_vector)), 4.0) * 0.3 * (1.0 - depth);
        }
        else if (liquid_type == 2) {
            // SLIME: Thick jelly, large slow bubbles
            vec4 volume = mix(vec4(0.4, 0.8, 0.1, 0.98), vec4(0.1, 0.4, 0.0, 0.98), depth);
            
            float bubble_noise = noise(world_pos * 0.2 + vec2(0.0, TIME * -3.0));
            if (bubble_noise > 0.8) {
                volume = mix(volume, vec4(0.6, 1.0, 0.3, 1.0), 0.8);
            }
            
            float jelly_spec = pow(max(0.0, dot(normal, half_vector)), 12.0);
            final_color = volume + vec4(0.8, 1.0, 0.8, 0.0) * jelly_spec * (1.0 - depth);
        }
        else if (liquid_type == 3) {
            // ACID: Toxic neon emissive glow, fizzing surface
            vec4 volume = mix(vec4(0.8, 1.0, 0.0, 1.0), vec4(0.2, 0.8, 0.0, 1.0), depth);
            
            float fizz = noise(world_pos * 1.0 + vec2(TIME * 5.0, TIME * 10.0));
            if (fizz > 0.7 && depth < 0.2) {
                volume = mix(volume, vec4(1.0, 1.0, 0.5, 1.0), 0.8);
            }
            
            // Bright neon surface glow
            final_color = volume + vec4(1.0, 1.0, 0.0, 0.0) * diffuse * (1.0 - depth) * 1.5;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5 * (1.0 - depth);
        }
        else if (liquid_type == 4) {
            // RAINBOW: Iridescent pearlescent color dependent on viewing angle and surface depth
            float hue = fract((1.0 - depth) * 1.5 + UV.x * 0.5 + TIME * 0.5);
            vec4 pearl = vec4(hue2rgb(hue), 0.95);
            
            final_color = pearl * (diffuse * 0.8 + 0.2);
            final_color += vec4(1.0) * specular * 1.5 * (1.0 - depth);
        }
        else if (liquid_type == 5) {
            // GALAXY: Deep space volume with scrolling parallax stars
            vec4 deep_space = vec4(0.05, 0.0, 0.1, 1.0);
            
            float nebula = noise(world_pos * 0.05 + vec2(TIME * 0.2, TIME * -0.5));
            vec4 cloud_color = mix(vec4(0.8, 0.1, 0.6, 1.0), vec4(0.1, 0.4, 0.9, 1.0), sin(TIME)*0.5+0.5);
            deep_space = mix(deep_space, cloud_color, nebula * 0.8);
            
            if (rand(floor(world_pos * 0.3 + vec2(TIME, TIME * 2.0))) > 0.98) deep_space += vec4(1.0);
            if (rand(floor(world_pos * 0.7 + vec2(TIME * 3.0, TIME * 4.0))) > 0.99) deep_space += vec4(0.8);
            
            final_color = deep_space;
            // Glowing purple surface rim
            final_color += vec4(0.6, 0.2, 1.0, 0.0) * diffuse * (1.0 - depth) * 1.5;
            final_color += vec4(1.0) * specular * 0.4 * (1.0 - depth);
        }
        else if (liquid_type == 6) {
            // GOLD: Hyper-metallic reflection
            vec4 gold_base = vec4(0.6, 0.4, 0.1, 1.0);
            vec4 gold_light = vec4(1.0, 0.8, 0.3, 1.0);
            
            // Reflect the fake environment
            float reflection = smoothstep(0.5, 1.0, normal.y + normal.x * 0.5);
            final_color = mix(gold_base, gold_light, reflection);
            // Darken with depth
            final_color = mix(final_color, gold_base * 0.5, depth);
            
            float metal_spec = pow(max(0.0, dot(normal, half_vector)), 128.0) * 3.0;
            final_color += vec4(1.0, 0.9, 0.6, 0.0) * metal_spec * (1.0 - depth);
        }
        else if (liquid_type == 7) {
            // NEON PLASMA: Cyberpunk grid and scanlines
            vec4 magenta = vec4(1.0, 0.0, 0.8, 1.0);
            vec4 cyan = vec4(0.0, 1.0, 1.0, 1.0);
            vec4 dark = vec4(0.05, 0.0, 0.1, 1.0);
            
            float grid_x = step(0.1, fract(world_pos.x * 0.2));
            float grid_y = step(0.1, fract(world_pos.y * 0.2));
            vec4 volume = (grid_x * grid_y == 1.0) ? dark : magenta;
            
            float scanline = sin(world_pos.y * 2.0 - TIME * 30.0);
            if (scanline > 0.8) volume = cyan;
            
            final_color = mix(volume * (diffuse + 0.4), dark, depth);
            final_color += cyan * diffuse * (1.0 - depth) * 2.0;
            final_color += vec4(1.0) * specular * (1.0 - depth);
        }
        
        COLOR = clamp(final_color, 0.0, 1.0);
    }
}
