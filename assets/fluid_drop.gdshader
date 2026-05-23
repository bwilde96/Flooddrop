shader_type canvas_item;

uniform float drop_y = 20.0;
uniform float drop_radius = 32.0; 
uniform vec4 water_color : source_color = vec4(0.35, 0.78, 0.98, 1.0);
uniform float anchor_multiplier = 1.0;
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

// Hue to RGB conversion
vec3 hue2rgb(float hue) {
    float R = abs(hue * 6.0 - 3.0) - 1.0;
    float G = 2.0 - abs(hue * 6.0 - 2.0);
    float B = 2.0 - abs(hue * 6.0 - 4.0);
    return clamp(vec3(R,G,B), 0.0, 1.0);
}

void fragment() {
    vec2 pos = UV * vec2(120.0, 200.0);
    
    // Base shape distortion modifiers
    float dx_drop = pos.x - 60.0;
    float dy_drop = pos.y - drop_y;
    
    if (liquid_type == 7) {
        // Neon Plasma: Glitchy jagged edges
        dx_drop += sin(pos.y * 0.5 + TIME * 15.0) * 2.0;
    }
    
    // Smooth egg shape deformation
    float width_mod = 1.0 + (dy_drop / 120.0);
    dx_drop /= max(0.1, width_mod);
    
    // Ceiling anchor
    float dx_anchor = max(0.0, abs(pos.x - 60.0) - 30.0);
    float dy_anchor = max(0.0, pos.y - 0.0) * 2.5; 
    float distSq_anchor = dx_anchor * dx_anchor + dy_anchor * dy_anchor;
    float e1 = (200.0 / (distSq_anchor + 0.1)) * anchor_multiplier;
    
    // Falling drop energy
    float distSq_drop = dx_drop * dx_drop + dy_drop * dy_drop;
    float e2 = (drop_radius * drop_radius) / (distSq_drop + 0.1);
    float total_energy = e1 + e2;
    
    if (total_energy > 1.0) {
        vec4 col = water_color;
        
        vec2 gradient_center = vec2(60.0 - drop_radius * 0.3, drop_y - drop_radius * 0.3);
        float grad_factor = clamp(length(pos - gradient_center) / (drop_radius * 2.0), 0.0, 1.0);
        
        if (liquid_type == 0) {
            // 0 = WATER: Transparent, blue, specular highlight
            col = mix(vec4(1.0, 1.0, 1.0, 0.8), water_color, grad_factor);
            vec2 high_center = vec2(60.0 + drop_radius * 0.4, drop_y - drop_radius * 0.4);
            if (length(pos - high_center) < drop_radius * 0.35 && e2 > 1.5) {
                col = mix(col, vec4(1.0, 1.0, 1.0, 0.7), 0.8);
            }
        } 
        else if (liquid_type == 1) {
            // 1 = LAVA: Glowing core, dark hardened edges
            vec4 core_color = vec4(1.0, 0.9, 0.3, 1.0); // Bright yellow hot core
            vec4 crust_color = vec4(0.2, 0.05, 0.0, 1.0); // Dark red crust
            float dist_from_center = length(vec2(dx_drop, dy_drop)) / drop_radius;
            col = mix(core_color, water_color, dist_from_center * 1.5);
            // Edge hardening
            if (total_energy < 1.3) {
                col = mix(crust_color, col, (total_energy - 1.0) / 0.3);
            }
        }
        else if (liquid_type == 2) {
            // 2 = SLIME: Semi-transparent with internal bubbles
            col = mix(vec4(0.8, 1.0, 0.5, 0.8), water_color, grad_factor);
            float bubble_noise = noise(pos * 0.2 + vec2(0.0, TIME * -10.0));
            if (bubble_noise > 0.75) {
                col = mix(col, vec4(1.0, 1.0, 1.0, 0.6), 0.7); // Draw bubbles
            }
        }
        else if (liquid_type == 3) {
            // 3 = ACID: Neon glow, highly emissive
            col = mix(vec4(1.0, 1.0, 0.6, 1.0), water_color, grad_factor);
            // Glowing bright edge
            if (total_energy < 1.5) {
                col = mix(vec4(0.8, 1.0, 0.0, 1.0), col, (total_energy - 1.0) / 0.5);
            }
        }
        else if (liquid_type == 4) {
            // 4 = RAINBOW: Shifts hue
            float hue = fract(TIME * 0.5 + pos.y * 0.01);
            vec3 rgb = hue2rgb(hue);
            col = vec4(rgb, 1.0);
            vec2 high_center = vec2(60.0 + drop_radius * 0.4, drop_y - drop_radius * 0.4);
            if (length(pos - high_center) < drop_radius * 0.35 && e2 > 1.5) {
                col = mix(col, vec4(1.0, 1.0, 1.0, 0.7), 0.8);
            }
        }
        else if (liquid_type == 5) {
            // 5 = GALAXY: Parallax stars
            col = water_color; // Deep purple base
            float star_noise = rand(floor(pos * 0.5 + vec2(TIME * 2.0, TIME * 5.0)));
            if (star_noise > 0.98) {
                col = vec4(1.0, 1.0, 1.0, 1.0); // Bright stars
            }
            // Add a glowing nebula edge
            if (total_energy < 1.2) {
                col = mix(vec4(0.5, 0.1, 1.0, 1.0), col, (total_energy - 1.0) / 0.2);
            }
        }
        else if (liquid_type == 6) {
            // 6 = GOLD: Metallic horizontal reflection band
            col = mix(vec4(1.0, 1.0, 0.6, 1.0), water_color, grad_factor);
            // Sharp metallic horizon line
            float reflection = sin(pos.y * 0.2 + drop_y * 0.1);
            if (reflection > 0.8 && reflection < 0.9) {
                col = vec4(1.0, 1.0, 0.9, 1.0);
            } else if (reflection > 0.9) {
                col = mix(water_color, vec4(0.4, 0.3, 0.1, 1.0), 0.5);
            }
        }
        else if (liquid_type == 7) {
            // 7 = NEON PLASMA: Cyberpunk glitch look
            col = water_color;
            float scanline = sin(pos.y * 1.5 - TIME * 20.0);
            if (scanline > 0.5) {
                col = vec4(1.0, 0.0, 0.8, 1.0); // Magenta stripes
            }
            if (total_energy < 1.4) {
                col = mix(vec4(0.0, 1.0, 1.0, 1.0), col, (total_energy - 1.0) / 0.4); // Cyan glow
            }
        }
        
        // Smooth anti-aliased edge
        float alpha = clamp((total_energy - 1.0) * 20.0, 0.0, 1.0);
        col.a *= alpha;
        
        COLOR = col;
    } else {
        COLOR = vec4(0.0);
    }
}
