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
        dx_drop += sin(pos.y * 0.5 + TIME * 15.0) * 2.0; // Cyberpunk Glitch
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
        vec4 base_color = water_color;
        
        vec2 offset = vec2(dx_drop, dy_drop) / drop_radius;
        float dist_sq = clamp(dot(offset, offset), 0.0, 1.0);
        float z = sqrt(1.0 - dist_sq);
        vec3 normal = normalize(vec3(offset.x, offset.y, z));
        
        if (e1 > e2) {
            normal = normalize(vec3(pos.x - 60.0, -20.0, z * 20.0));
        }
        
        vec3 light_dir = normalize(vec3(-0.6, -0.8, 1.0));
        vec3 view_dir = vec3(0.0, 0.0, 1.0);
        vec3 half_vector = normalize(light_dir + view_dir);
        
        float diffuse = max(0.0, dot(normal, light_dir));
        float specular = pow(max(0.0, dot(normal, half_vector)), 48.0) * 1.5;
        float fresnel = pow(1.0 - max(0.0, dot(normal, view_dir)), 3.0);
        
        vec4 final_color = vec4(0.0);
        
        if (liquid_type == 0) {
            // WATER: High opacity, deep volume, caustic ripples
            float caustics = sin(pos.x * 0.1 + TIME * 2.0) * sin(pos.y * 0.1 + TIME * 1.5);
            // Use the passed-in water_color so special drops (Bomb, Drain, etc) keep their unique colors!
            vec4 dark_color = vec4(water_color.rgb * 0.3, 1.0);
            vec4 light_color = vec4(water_color.rgb * 0.8, 1.0);
            vec4 volume = mix(dark_color, light_color, diffuse + caustics * 0.1);
            final_color = volume + vec4(1.0, 1.0, 1.0, 0.0) * specular * 1.5 + vec4(clamp(light_color.rgb + 0.4, 0.0, 1.0), 0.0) * fresnel;
        } 
        else if (liquid_type == 1) {
            // LAVA: Voronoi cracking, intense core glow
            vec4 core_color = vec4(1.0, 0.8, 0.0, 1.0); // Bright molten yellow
            vec4 crust_color = vec4(0.1, 0.0, 0.0, 1.0); // Pitch black/red rock
            
            float v = voronoi(pos * 0.15 + vec2(0.0, TIME * -0.5));
            // v is close to 1.0 at the edges of the cells
            float cracks = smoothstep(0.7, 0.9, v);
            
            final_color = mix(crust_color, core_color, cracks);
            // Edges glow orange from heat
            final_color += vec4(1.0, 0.3, 0.0, 0.0) * fresnel * 1.5; 
            // Dim rough specular
            final_color += vec4(1.0, 0.5, 0.2, 0.0) * pow(max(0.0, dot(normal, half_vector)), 4.0) * 0.2;
        }
        else if (liquid_type == 2) {
            // SLIME: Extremely thick, large bubbles, wide specular
            vec4 volume = mix(vec4(0.1, 0.4, 0.0, 0.98), vec4(0.4, 0.8, 0.1, 0.98), diffuse);
            
            // Big slow bubbles
            float bubble_noise = noise(pos * 0.1 + vec2(0.0, TIME * -3.0));
            if (bubble_noise > 0.8) {
                volume = mix(volume, vec4(0.6, 1.0, 0.3, 1.0), 0.8);
            }
            // Wide jelly specular
            float jelly_spec = pow(max(0.0, dot(normal, half_vector)), 12.0) * 1.0;
            final_color = volume + vec4(0.8, 1.0, 0.8, 0.0) * jelly_spec + vec4(0.2, 0.9, 0.2, 0.0) * fresnel * 0.8;
        }
        else if (liquid_type == 3) {
            // ACID: Toxic highly emissive glowing yellow-green, fizzing surface
            vec4 volume = mix(vec4(0.2, 0.8, 0.0, 1.0), vec4(0.8, 1.0, 0.0, 1.0), diffuse);
            
            // Fizzing micro-bubbles
            float fizz = noise(pos * 1.0 + vec2(TIME * 5.0, TIME * 10.0));
            if (fizz > 0.7) {
                volume = mix(volume, vec4(1.0, 1.0, 0.5, 1.0), 0.8);
            }
            
            // Blinding toxic neon rim
            final_color = volume + vec4(1.0, 1.0, 0.0, 0.0) * fresnel * 2.0;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5;
        }
        else if (liquid_type == 4) {
            // RAINBOW: Iridescent pearlescent color dependent on viewing angle (Fresnel/Z-depth)
            // Color shifts based on how much it's facing away from the camera
            float hue = fract((1.0 - z) * 1.5 + TIME * 0.5);
            vec4 pearl = vec4(hue2rgb(hue), 0.95);
            
            final_color = pearl * (diffuse * 0.8 + 0.2);
            final_color += vec4(1.0) * specular * 1.5;
            final_color += vec4(hue2rgb(fract(hue + 0.5)), 0.0) * fresnel * 1.2; // Opposite hue on edge
        }
        else if (liquid_type == 5) {
            // GALAXY: Deep space, swirling dense nebula, multiple star layers
            vec4 deep_space = vec4(0.05, 0.0, 0.1, 1.0);
            
            // Nebula clouds
            float nebula = noise(pos * 0.05 + vec2(TIME * 0.2, TIME * -0.5));
            vec4 cloud_color = mix(vec4(0.8, 0.1, 0.6, 1.0), vec4(0.1, 0.4, 0.9, 1.0), sin(TIME)*0.5+0.5);
            deep_space = mix(deep_space, cloud_color, nebula * 0.8);
            
            // Layer 1 big stars
            if (rand(floor(pos * 0.3 + vec2(TIME, TIME * 2.0))) > 0.98) deep_space += vec4(1.0);
            // Layer 2 small fast stars
            if (rand(floor(pos * 0.7 + vec2(TIME * 3.0, TIME * 4.0))) > 0.99) deep_space += vec4(0.8);
            
            final_color = deep_space;
            final_color += vec4(0.6, 0.2, 1.0, 0.0) * fresnel * 2.0; // Stardust edge
            final_color += vec4(1.0) * specular * 0.4;
        }
        else if (liquid_type == 6) {
            // GOLD: Hyper-metallic reflection mapping
            vec4 gold_base = vec4(0.8, 0.5, 0.1, 1.0); // Bronze shadow
            vec4 gold_light = vec4(1.0, 0.9, 0.4, 1.0); // Bright gold
            
            // Environment mapping using the Y and X normal
            float reflection = smoothstep(-0.3, 0.3, normal.y + normal.x * 0.5);
            final_color = mix(gold_base, gold_light, reflection);
            
            // Ultra-sharp anisotropic-like specular
            float metal_spec = pow(max(0.0, dot(normal, half_vector)), 128.0) * 3.0;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * metal_spec;
            final_color += gold_light * fresnel;
        }
        else if (liquid_type == 7) {
            // NEON PLASMA: Cyberpunk Matrix aesthetic. Digital grid overlay.
            vec4 magenta = vec4(1.0, 0.0, 0.8, 1.0);
            vec4 cyan = vec4(0.0, 1.0, 1.0, 1.0);
            vec4 dark = vec4(0.05, 0.0, 0.1, 1.0);
            
            // Digital Hex/Grid pattern
            float grid_x = step(0.1, fract(pos.x * 0.2));
            float grid_y = step(0.1, fract(pos.y * 0.2));
            vec4 volume = (grid_x * grid_y == 1.0) ? dark : magenta;
            
            // Scanline glitch
            float scanline = sin(pos.y * 2.0 - TIME * 30.0);
            if (scanline > 0.8) volume = cyan;
            
            final_color = volume * (diffuse + 0.4) + cyan * fresnel * 2.0;
            final_color += vec4(1.0) * specular;
        }
        else if (liquid_type == 8) {
            // 8 = BOMB (Volatile Plasma)
            vec4 core = vec4(1.0, 0.8, 0.2, 1.0);
            vec4 edge = vec4(1.0, 0.1, 0.0, 1.0);
            
            float plasma = noise(pos * 0.15 + vec2(TIME * -5.0, TIME * 8.0));
            final_color = mix(edge, core, plasma * (1.0 - dist_sq));
            
            final_color += vec4(1.0, 0.4, 0.0, 0.0) * fresnel * 2.5;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5;
        }
        else if (liquid_type == 9) {
            // 9 = FREEZE (Glacial Crystal)
            vec4 ice_base = vec4(0.4, 0.8, 1.0, 0.9);
            vec4 ice_dark = vec4(0.1, 0.4, 0.8, 0.9);
            
            // Angular facet noise for ice crystals
            float facet = step(0.5, fract(sin(dot(floor(pos * 0.2), vec2(12.9898,78.233))) * 43758.5453));
            final_color = mix(ice_dark, ice_base, diffuse + facet * 0.3);
            
            float sharp_spec = pow(max(0.0, dot(normal, half_vector)), 128.0) * 2.0;
            final_color += vec4(1.0) * sharp_spec;
            final_color += vec4(0.6, 0.9, 1.0, 0.0) * fresnel * 1.5;
        }
        else if (liquid_type == 10) {
            // 10 = SHIELD (Cyber-Hologram)
            vec4 mag = vec4(0.8, 0.2, 1.0, 0.8);
            vec4 cyan = vec4(0.2, 0.8, 1.0, 1.0);
            
            // Hex grid logic (simple criss-cross)
            float grid = max(step(0.8, fract((pos.x + pos.y) * 0.1)), step(0.8, fract((pos.x - pos.y) * 0.1)));
            final_color = mix(mag * (diffuse + 0.2), cyan, grid * (sin(TIME * 10.0) * 0.5 + 0.5));
            
            final_color += cyan * fresnel * 2.5;
        }
        else if (liquid_type == 11) {
            // 11 = DRAIN (Swirling Void)
            vec4 void_core = vec4(0.0, 0.0, 0.0, 1.0);
            vec4 void_edge = vec4(0.1, 0.8, 0.2, 1.0);
            
            // Swirl math
            float angle = atan(offset.y, offset.x) + (1.0 - dist_sq) * TIME * 15.0;
            float swirl = sin(angle * 5.0) * 0.5 + 0.5;
            
            final_color = mix(void_core, void_edge, swirl * dist_sq);
            final_color += void_edge * fresnel * 3.0; // Intense glowing ring
        }
        
        // Smooth anti-aliased edge
        float alpha = clamp((total_energy - 1.0) * 20.0, 0.0, 1.0);
        final_color.a *= alpha;
        
        COLOR = clamp(final_color, 0.0, 1.0);
    } else {
        COLOR = vec4(0.0);
    }
}
