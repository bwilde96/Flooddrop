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
    
    float wave = sin(UV.x * current_wave_freq + TIME * current_wave_speed) * current_wave_amp;
    float edge = current_wave_amp + wave;
    
    if (UV.y < edge) {
        COLOR.a = 0.0;
    } else {
        float t = clamp((UV.y - edge) / (1.0 - edge), 0.0, 1.0);
        vec4 col = mix(top_color, bottom_color, t);
        
        // Procedural Textures based on liquid type
        if (liquid_type == 1) { // Lava
            vec4 core_color = vec4(1.0, 0.9, 0.3, 1.0);
            vec4 crust_color = vec4(0.2, 0.05, 0.0, 1.0);
            float dist_from_top = UV.y - edge;
            if (dist_from_top < 0.05) {
                // Crust at the top
                col = mix(crust_color, col, dist_from_top / 0.05);
            } else {
                col = mix(core_color, col, t);
            }
        }
        else if (liquid_type == 2) { // Slime
            float bubble_noise = noise(UV * 20.0 + vec2(0.0, TIME * -2.0));
            if (bubble_noise > 0.75) {
                col = mix(col, vec4(1.0, 1.0, 1.0, 0.6), 0.5);
            }
        }
        else if (liquid_type == 3) { // Acid
            float dist_from_top = UV.y - edge;
            if (dist_from_top < 0.1) {
                col = mix(vec4(0.8, 1.0, 0.0, 1.0), col, dist_from_top / 0.1);
            }
        }
        else if (liquid_type == 4) { // Rainbow
            float hue = fract(TIME * 0.2 + UV.x * 0.5 - UV.y * 0.5);
            col = vec4(hue2rgb(hue), 0.8);
        }
        else if (liquid_type == 5) { // Galaxy
            float star_noise = rand(floor(UV * 100.0 + vec2(TIME * 0.5, TIME * 2.0)));
            if (star_noise > 0.98) {
                col = vec4(1.0, 1.0, 1.0, 1.0);
            }
            float dist_from_top = UV.y - edge;
            if (dist_from_top < 0.1) {
                col = mix(vec4(0.5, 0.1, 1.0, 1.0), col, dist_from_top / 0.1);
            }
        }
        else if (liquid_type == 6) { // Gold
            float reflection = sin(UV.y * 20.0 - wave * 10.0);
            if (reflection > 0.8 && reflection < 0.9) {
                col = vec4(1.0, 1.0, 0.9, 1.0);
            } else if (reflection > 0.9) {
                col = mix(col, vec4(0.4, 0.3, 0.1, 1.0), 0.5);
            }
        }
        else if (liquid_type == 7) { // Neon Plasma
            float scanline = sin(UV.y * 50.0 - TIME * 10.0);
            if (scanline > 0.5) {
                col = vec4(1.0, 0.0, 0.8, 1.0);
            }
            float dist_from_top = UV.y - edge;
            if (dist_from_top < 0.1) {
                col = mix(vec4(0.0, 1.0, 1.0, 1.0), col, dist_from_top / 0.1);
            }
        }
        
        COLOR = col;
    }
}
