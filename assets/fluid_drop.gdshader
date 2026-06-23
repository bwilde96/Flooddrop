shader_type canvas_item;

uniform float drop_y = 20.0;
uniform float drop_radius = 32.0; 
uniform vec4 water_color : source_color = vec4(0.35, 0.78, 0.98, 1.0);
uniform float anchor_multiplier = 1.0;
uniform int liquid_type = 0; // 0=Water, 1=Lava, 2=Slime, 3=Acid, 4=Rainbow, 5=Galaxy, 6=Gold, 7=Neon Plasma
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform bool is_slime_shape = false;

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
    
    float stretch = 120.0;
    if (liquid_type == 2 || is_slime_shape) {
        // Slime: Heavy, bulbous, gelatinous sphere
        stretch = 180.0; // Very gentle sag, keeps it mostly round
        
        // Heavy, slow rolling jiggle
        dx_drop += sin(pos.y * 0.08 - TIME * 6.0) * 2.5;
        dy_drop += cos(pos.x * 0.1 + TIME * 4.0) * 1.5;
    }
    else if (liquid_type == 7) {
        dx_drop += sin(pos.y * 0.5 + TIME * 15.0) * 2.0; // Cyberpunk Glitch
    }
    
    // Smooth egg shape deformation
    float width_mod = 1.0 + (dy_drop / stretch);
    dx_drop /= max(0.1, width_mod);
    
    // Smooth dome ceiling anchor
    float dx_anchor = (pos.x - 60.0) * 0.7;
    float dy_anchor = max(0.0, pos.y) * 2.0; 
    float distSq_anchor = dx_anchor * dx_anchor + dy_anchor * dy_anchor;
    float e1 = (300.0 / (distSq_anchor + 0.1)) * anchor_multiplier;
    
    // Falling drop energy
    float distSq_drop = dx_drop * dx_drop + dy_drop * dy_drop;
    float e2 = (drop_radius * drop_radius) / (distSq_drop + 0.1);
    float total_energy = e1 + e2;
    
    if (total_energy > 1.0) {
        vec4 base_color = water_color;
        
        // Drop normal
        float safe_radius = max(0.1, drop_radius);
        vec2 offset = vec2(dx_drop, dy_drop) / safe_radius;
        float dist_sq = clamp(dot(offset, offset), 0.0, 1.0);
        float z_drop = sqrt(1.0 - dist_sq);
        vec3 normal_drop = vec3(offset.x, offset.y, z_drop);
        
        // Anchor normal (mathematically correct ellipsoid gradient)
        float nx_anchor_n = dx_anchor / 17.32; // sqrt(300)
        float ny_anchor_n = dy_anchor / 17.32;
        float nz_anchor_n = sqrt(max(0.0, 1.0 - nx_anchor_n*nx_anchor_n - ny_anchor_n*ny_anchor_n));
        vec3 normal_anchor = normalize(vec3(nx_anchor_n * 0.7, ny_anchor_n * 2.0, nz_anchor_n));
        
        vec3 normal = normalize(normal_drop * e2 + normal_anchor * e1);
        float z = normal.z;
        
        vec3 light_dir = normalize(vec3(-0.6, -0.8, 1.0));
        vec3 view_dir = vec3(0.0, 0.0, 1.0);
        vec3 half_vector = normalize(light_dir + view_dir);
        
        float diffuse = max(0.0, dot(normal, light_dir));
        float specular = pow(max(0.0, dot(normal, half_vector)), 48.0) * 1.5;
        float fresnel = pow(1.0 - max(0.0, dot(normal, view_dir)), 3.0);
        
        vec4 final_color = vec4(0.0);
        
        if (liquid_type == 0) {
            // WATER: True Optical Refraction Lens
            vec2 refracted_uv = SCREEN_UV - normal.xy * 0.08 * z; 
            vec4 bg_refraction = texture(screen_texture, refracted_uv);
            
            vec4 tint = vec4(water_color.rgb, 1.0);
            vec4 volume = mix(bg_refraction, tint, 0.2 + fresnel * 0.5);
            
            float inner_shadow = smoothstep(0.0, 0.5, -normal.y - normal.x * 0.5) * 0.4;
            
            final_color = volume - vec4(inner_shadow);
            final_color += vec4(1.0) * specular * 3.0;
            final_color += vec4(1.0) * fresnel * 0.8;
        } 
        else if (liquid_type == 1) {
            // LAVA: Voronoi cracking, intense core glow
            vec4 core_color = vec4(1.0, 0.8, 0.0, 1.0);
            vec4 crust_color = vec4(0.1, 0.0, 0.0, 1.0);
            
            float v = voronoi(pos * 0.15 + vec2(0.0, TIME * -0.5));
            float cracks = smoothstep(0.7, 0.9, v);
            
            final_color = mix(crust_color, core_color, cracks);
            final_color += vec4(1.0, 0.3, 0.0, 0.0) * fresnel * 1.5; 
            final_color += vec4(1.0, 0.5, 0.2, 0.0) * pow(max(0.0, dot(normal, half_vector)), 4.0) * 0.2;
        }
        else if (liquid_type == 2) {
            // SLIME: Bulbous ooze with suspended toxic bubbles
            vec4 core_color = vec4(0.02, 0.15, 0.0, 0.98); // Dark, dense internal fluid
            vec4 edge_color = vec4(0.4, 0.95, 0.15, 0.85); // Bright, toxic translucent edge
            
            // Depth-based scattering (z = 1 at center, 0 at edge)
            float depth = pow(z, 1.5);
            vec4 base_volume = mix(edge_color, core_color, depth);
            
            // Generate slow moving cellular bubbles inside the slime
            float v = voronoi(pos * 0.05 + vec2(sin(TIME * 0.5), TIME * -1.5));
            // Create soft "nuclei" or bubbles from the voronoi noise
            float bubbles = smoothstep(0.3, 0.8, 1.0 - v); 
            
            // Bubbles are only visible deep inside the slime (z > 0.4)
            vec4 bubble_color = vec4(0.6, 1.0, 0.2, 1.0);
            vec4 volume = mix(base_volume, bubble_color, bubbles * smoothstep(0.4, 1.0, z) * 0.8);
            
            // Soft rim illumination from ambient diffuse
            volume = mix(volume, vec4(0.6, 1.0, 0.3, 1.0), diffuse * 0.4);
            
            // Slime refraction (distorts heavily because it's thick jelly)
            vec2 refracted_uv = SCREEN_UV - normal.xy * 0.07 * z; 
            vec4 bg_refraction = texture(screen_texture, refracted_uv);
            volume = mix(bg_refraction * vec4(0.7, 1.0, 0.5, 1.0), volume, 0.85);
            
            // Oily double specular
            float jelly_spec_broad = pow(max(0.0, dot(normal, half_vector)), 16.0) * 0.6;
            float jelly_spec_sharp = pow(max(0.0, dot(normal, half_vector)), 128.0) * 2.0;
            
            // Backlit subsurface scattering glow
            float sss = pow(max(0.0, dot(normal, -light_dir)), 3.0) * 0.6;
            
            final_color = volume;
            final_color += vec4(0.5, 1.0, 0.2, 0.0) * sss;
            final_color += vec4(0.9, 1.0, 0.9, 0.0) * (jelly_spec_broad + jelly_spec_sharp);
            final_color += vec4(0.4, 1.0, 0.4, 0.0) * fresnel * 0.8;
        }
        else if (liquid_type == 3) {
            // ACID/NEUTRALIZER: Highly emissive glowing core, fizzing surface
            vec4 dark_col = vec4(water_color.rgb * 0.3, 1.0);
            vec4 light_col = vec4(water_color.rgb * 1.2, 1.0);
            vec4 volume = mix(dark_col, light_col, diffuse);
            
            // Fizzing micro-bubbles
            float fizz = noise(pos * 1.0 + vec2(TIME * 5.0, TIME * 10.0));
            
            // Jittery refraction
            vec2 refracted_uv = SCREEN_UV - normal.xy * 0.05 * z;
            refracted_uv += vec2(fizz * 0.02); // Distort refraction with fizz
            vec4 bg_refraction = texture(screen_texture, refracted_uv);
            
            volume = mix(bg_refraction * vec4(1.0, 1.5, 0.5, 1.0), volume, 0.6);
            
            if (fizz > 0.7) {
                volume = mix(volume, vec4(1.0, 1.0, 1.0, 1.0), 0.8);
            }
            
            // Blinding toxic neon rim
            final_color = volume + vec4(water_color.rgb, 0.0) * fresnel * 2.0;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5;
        }
        else if (liquid_type == 4) {
            // RAINBOW: Iridescent pearlescent color dependent on viewing angle (Fresnel/Z-depth)
            // Color shifts based on how much it's facing away from the camera. Highly emissive for Blackout.
            float hue = fract((1.0 - z) * 1.5 + TIME * 1.5); // Sped up the color shifting
            vec4 pearl = vec4(hue2rgb(hue), 0.95);
            
            final_color = pearl; // Ignore diffuse so it glows in the dark
            final_color += vec4(1.0) * specular * 1.5;
            final_color += vec4(hue2rgb(fract(hue + 0.5)), 0.0) * fresnel * 2.0; // Strong glowing edge
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
            
            // Fake environmental reflection by sampling the screen
            vec2 refl_uv = SCREEN_UV;
            refl_uv.y = clamp(1.0 - refl_uv.y, 0.0, 1.0); // Flip Y to fake a mirror reflection
            refl_uv += normal.xy * 0.1 * z; // Distort with droplet sphere
            vec4 bg_refl = texture(screen_texture, refl_uv);
            
            final_color = mix(gold_base, bg_refl * gold_light, reflection);
            
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
            
            // Energy distortion (gravitational lensing)
            vec2 lens_uv = SCREEN_UV - normal.xy * 0.1 * z;
            if (grid_x * grid_y == 0.0) lens_uv += vec2(0.01, -0.01); 
            vec4 bg_distortion = texture(screen_texture, lens_uv);
            
            volume = mix(volume * (diffuse + 0.4), bg_distortion * cyan, 0.6);
            
            final_color = volume + cyan * fresnel * 2.0;
            final_color += vec4(1.0) * specular;
        }
        else if (liquid_type == 8) {
            // 8 = BOMB (Volatile Plasma)
            vec4 core = vec4(1.0, 0.8, 0.2, 1.0);
            vec4 edge = vec4(1.0, 0.1, 0.0, 1.0);
            
            float plasma = noise(pos * 0.15 + vec2(TIME * -5.0, TIME * 8.0));
            vec4 volume = mix(edge, core, plasma * (1.0 - dist_sq));
            
            // Plasma lens refraction
            vec2 lens_uv = SCREEN_UV - normal.xy * 0.08 * z;
            lens_uv += vec2((plasma - 0.5) * 0.05); // Heat distortion
            vec4 bg_refraction = texture(screen_texture, lens_uv);
            
            final_color = mix(volume, bg_refraction * vec4(1.2, 0.8, 0.2, 1.0), 0.5);
            
            final_color += vec4(1.0, 0.4, 0.0, 0.0) * fresnel * 2.5;
            final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5;
        }
        else if (liquid_type == 9) {
            // 9 = FREEZE (Glacial Crystal)
            vec4 ice_base = vec4(0.4, 0.8, 1.0, 0.9);
            vec4 ice_dark = vec4(0.1, 0.4, 0.8, 0.9);
            
            // Angular facet noise for ice crystals
            float facet = step(0.5, fract(sin(dot(floor(pos * 0.2), vec2(12.9898,78.233))) * 43758.5453));
            vec4 volume = mix(ice_dark, ice_base, diffuse + facet * 0.3);
            
            // Ice refraction (crystal clear but heavily faceted)
            vec2 lens_uv = SCREEN_UV - normal.xy * 0.06 * z;
            lens_uv += vec2(facet * 0.04); // Facets sharply bend light
            vec4 bg_refraction = texture(screen_texture, lens_uv);
            
            final_color = mix(volume, bg_refraction * vec4(0.8, 0.9, 1.0, 1.0), 0.7); // mostly clear ice
            
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
            vec4 volume = mix(mag * (diffuse + 0.2), cyan, grid * (sin(TIME * 10.0) * 0.5 + 0.5));
            
            // Hologram light bending
            vec2 lens_uv = SCREEN_UV - normal.xy * 0.05 * z;
            lens_uv += vec2(grid * 0.02); 
            vec4 bg_refraction = texture(screen_texture, lens_uv);
            
            final_color = mix(volume, bg_refraction * mag, 0.5);
            
            final_color += cyan * fresnel * 2.5;
        }
        else if (liquid_type == 11) {
            // 11 = DRAIN (Swirling Void)
            vec4 void_core = vec4(0.0, 0.0, 0.0, 1.0);
            vec4 void_edge = vec4(0.1, 0.8, 0.2, 1.0);
            
            // Swirl math
            float angle = atan(offset.y, offset.x) + (1.0 - dist_sq) * TIME * 15.0;
            float swirl = sin(angle * 5.0) * 0.5 + 0.5;
            
            vec4 volume = mix(void_core, void_edge, swirl * dist_sq);
            
            // Extreme gravitational lensing swirling around the center
            vec2 swirl_dir = vec2(-offset.y, offset.x);
            vec2 lens_uv = SCREEN_UV + swirl_dir * 0.15 * dist_sq;
            lens_uv -= normal.xy * 0.05 * z; // lens
            vec4 bg_refraction = texture(screen_texture, lens_uv);
            
            // Core is black, edge is refracted
            final_color = mix(void_core, bg_refraction, dist_sq * 0.8);
            final_color += volume;
            
            final_color += void_edge * fresnel * 3.0; // Intense glowing ring
        }
        
        // Smooth anti-aliased edge
        float alpha = clamp((total_energy - 1.0) * 20.0, 0.0, 1.0);
        final_color.a *= alpha;
        
        COLOR = clamp(final_color, 0.0, 1.0);
    } else {
        vec4 glow = vec4(0.0);
        if (liquid_type == 3 || liquid_type == 6) {
            float glow_intensity = smoothstep(0.3, 1.0, total_energy);
            glow = vec4(water_color.rgb, glow_intensity * 0.6); // 60% opacity max at the edge
        }
        COLOR = glow;
    }
}
