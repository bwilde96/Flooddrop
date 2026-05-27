shader_type canvas_item;

uniform float wave_speed = 1.5;
uniform float wave_freq = 5.0;
uniform float wave_amp = 0.03;
uniform vec4 top_color: source_color = vec4(0.35, 0.78, 0.98, 0.9);
uniform vec4 bottom_color: source_color = vec4(0.19, 0.38, 0.84, 0.95);
uniform int liquid_type = 0; // 0=Water, 1=Lava, 2=Slime, 3=Acid, 4=Rainbow, 5=Galaxy, 6=Gold, 7=Neon Plasma
uniform float flood_height = 1280.0; // Dynamic height passed from script to prevent UV stretching
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Simple random function
float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// 2D Simplex Noise
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
           -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289_2(i);
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
  + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m ;
  m = m*m ;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

// Fractal Brownian Motion
float fbm(vec2 x) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    // Rotate to reduce axial bias
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.50)));
    for (int i = 0; i < 3; ++i) {
        v += a * snoise(x);
        x = rot * x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Voronoi Cell Noise for Lava Cracks / Water Caustics
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
    
    float dist_to_surface = UV.y - edge;
    
    // Smooth anti-aliased edge
    float alpha = smoothstep(-0.002, 0.002, dist_to_surface);
    
    // Depth gradient (0.0 at surface, 1.0 at bottom)
    float depth = clamp(dist_to_surface / (1.0 - edge), 0.0, 1.0);
    
    // 3D BEVEL AND NORMALS
    float bevel_size = 0.06; // Size of the curved lip at the top
    float y_tilt = clamp(1.0 - (dist_to_surface / bevel_size), 0.0, 1.0); // 1.0 at edge, 0.0 below bevel
    
    // Derivative of sin(x) is cos(x) for the wave slope
    float dw_dx = cos(phase) * current_wave_amp * current_wave_freq;
    
    // Z points towards camera, Y points UP near surface, X tilts with wave
    float z = sqrt(max(0.0, 1.0 - y_tilt*y_tilt - dw_dx*dw_dx));
    vec3 normal = normalize(vec3(-dw_dx, -y_tilt, z));
    
    // Calculate world_pos using flood_height to completely prevent UV stretching!
    vec2 world_pos = vec2(UV.x * 720.0, UV.y * flood_height) * 0.01;
    
    // Acid Normal Perturbation (Sizzling/Boiling)
    if (liquid_type == 3) {
        float boil = fbm(world_pos * 4.0 + vec2(TIME * 8.0, -TIME * 12.0));
        normal = normalize(normal + vec3(boil * 0.3, boil * 0.3, 0.0));
    }
    
    // Lighting Setup
    vec3 light_dir = normalize(vec3(-0.6, -0.8, 0.8)); // Light coming from top-left-front (pointing down)
    vec3 view_dir = vec3(0.0, 0.0, 1.0);
    vec3 half_vector = normalize(light_dir + view_dir);
    
    float diffuse = max(0.0, dot(normal, light_dir));
    float specular = pow(max(0.0, dot(normal, half_vector)), 48.0);
    float fresnel = pow(1.0 - max(0.0, dot(normal, view_dir)), 4.0);
    
    // Juicy Rim Highlight right at the meniscus edge
    float meniscus = smoothstep(0.0, 0.015, dist_to_surface) - smoothstep(0.015, 0.04, dist_to_surface);
    
    vec4 final_color = vec4(0.0);
    
    // ----------------------------------------------------
    // LIQUID TYPES WITH ADVANCED 3D MATERIALS
    // ----------------------------------------------------
    
    if (liquid_type == 0) {
        // WATER: Optical Refraction and Sharp Caustics
        float c_time = TIME * 1.5;
        vec2 p = world_pos * 1.2 + vec2(sin(c_time*0.5)*0.5, c_time*0.2);
        // Caustics by inverting voronoi
        float c = 1.0 - voronoi(p);
        c = pow(c, 3.0) * 2.0; // Sharpen
        
        // Calculate optical refraction using the 3D surface normal
        // normal.xy represents the slope of the wave.
        vec2 refracted_uv = SCREEN_UV + normal.xy * 0.05 * (1.0 - depth*0.5); // Refracts less deep down
        vec4 bg_refraction = texture(screen_texture, refracted_uv);
        
        // Tint the background slightly blue to simulate water absorption
        vec4 water_tint = vec4(0.1, 0.4, 0.7, 1.0);
        vec4 col = mix(bg_refraction, water_tint, 0.3 + depth * 0.4); // Gets bluer deeper down
        
        col += vec4(c * 0.5) * y_tilt; // Caustics strongest near surface
        
        final_color = col + vec4(1.0) * specular * 2.5 * y_tilt;
        final_color += vec4(0.8, 0.9, 1.0, 1.0) * fresnel * 0.8;
        final_color += vec4(1.0) * meniscus * 0.8;
    }
    else if (liquid_type == 1) {
        // LAVA: fBm displaced Voronoi (jagged tectonic plates)
        vec4 core_color = vec4(1.0, 0.9, 0.2, 1.0); // Intense yellow core
        vec4 mid_color = vec4(1.0, 0.2, 0.0, 1.0);  // Red heat
        vec4 crust_color = vec4(0.05, 0.0, 0.0, 1.0); // Dark basalt crust
        
        // Displace the coordinate using fBm for organic jagged cracks
        vec2 distorted_pos = world_pos * 0.6 + vec2(fbm(world_pos * 1.5 + TIME*0.2) * 0.5, TIME * -0.1);
        float v = voronoi(distorted_pos);
        
        // Map voronoi distance to cracks: 0.0 = center of cell, 1.0 = crack edge
        // Reverse it so 0.0 = crack, 1.0 = cell center
        float cracks = smoothstep(0.7, 0.95, v); 
        
        // Mix heat: center of crack is yellow, edges are red
        vec4 heat_color = mix(mid_color, core_color, smoothstep(0.85, 1.0, v));
        vec4 surf_color = mix(crust_color, heat_color, cracks);
        
        // Deep down, the lava is glowing molten red
        final_color = mix(surf_color, vec4(0.6, 0.0, 0.0, 1.0), depth * 0.4); 
        
        // Glowing hot rim on the surface bevel
        final_color += vec4(1.0, 0.4, 0.0, 1.0) * fresnel * 0.8;
        final_color += vec4(1.0, 0.8, 0.2, 1.0) * meniscus;
        // Specular highlight only hits the smooth basalt crust, not the glowing cracks
        final_color += vec4(1.0, 0.5, 0.2, 0.0) * specular * (1.0 - cracks) * 0.5;
    }
    else if (liquid_type == 2) {
        // SLIME: Thick jelly, slow fBM bubbles
        vec4 volume = mix(vec4(0.4, 0.8, 0.1, 0.98), vec4(0.1, 0.4, 0.0, 0.98), depth);
        
        // Inverted fbm for big thick clumps inside the slime
        float thick_noise = fbm(world_pos * 0.8 + vec2(0.0, TIME * -1.0));
        thick_noise = smoothstep(0.2, 0.8, thick_noise);
        
        // Add thick, distorted refraction
        vec2 refracted_uv = SCREEN_UV + normal.xy * 0.1 * (1.0 - depth*0.5); // Heavy bend
        refracted_uv += (thick_noise - 0.5) * 0.05; // Bubbles distort light
        vec4 bg_refraction = texture(screen_texture, refracted_uv);
        
        // Slime is mostly opaque but lets some light through near the surface
        volume = mix(bg_refraction * vec4(0.5, 1.0, 0.5, 1.0), volume, 0.6 + depth * 0.4);
        
        volume = mix(volume, vec4(0.6, 1.0, 0.3, 1.0), thick_noise * 0.6 * (1.0 - depth*0.5));
        
        final_color = volume + vec4(0.8, 1.0, 0.8, 0.0) * specular * y_tilt;
        final_color += vec4(0.5, 1.0, 0.5, 1.0) * fresnel * 0.7; // High subsurface glow
        final_color += vec4(0.8, 1.0, 0.2, 1.0) * meniscus * 0.6;
    }
    else if (liquid_type == 3) {
        // ACID: Toxic neon emissive glow, bubbling
        vec4 volume = mix(vec4(0.8, 1.0, 0.0, 1.0), vec4(0.1, 0.5, 0.0, 1.0), depth);
        
        // Add bubbling highlights
        float bubbles = fbm(world_pos * 3.0 + vec2(0.0, TIME * -4.0));
        
        // Refraction distorted violently by the boiling normal
        vec2 refracted_uv = SCREEN_UV + normal.xy * 0.08 * (1.0 - depth);
        vec4 bg_refraction = texture(screen_texture, refracted_uv);
        
        // Acid is partially transparent, heavily tinted yellow-green
        volume = mix(bg_refraction * vec4(1.0, 1.2, 0.2, 1.0), volume, 0.5 + depth * 0.5);
        
        if (bubbles > 0.4 && depth < 0.2) {
            volume = mix(volume, vec4(1.0, 1.0, 0.5, 1.0), (bubbles - 0.4) * 2.0);
        }
        
        final_color = volume + vec4(1.0, 1.0, 0.0, 0.0) * diffuse * y_tilt;
        // Specular is distorted wildly by the perturbed normal above!
        final_color += vec4(1.0, 1.0, 0.8, 0.0) * specular * 1.5 * y_tilt;
        final_color += vec4(1.0, 1.0, 0.5, 1.0) * fresnel * 0.7;
        final_color += vec4(1.0, 1.0, 1.0, 1.0) * meniscus * 0.8;
    }
    else if (liquid_type == 4) {
        // RAINBOW: Thin-film interference
        // Color depends on viewing angle (fresnel) and a swirling Simplex noise
        float swirl = snoise(world_pos * 0.5 + vec2(TIME * 0.2));
        float hue = fract(fresnel * 1.5 + swirl * 0.2 + TIME * 0.3);
        vec4 pearl = vec4(hue2rgb(hue), 0.95);
        
        final_color = pearl * (diffuse * 0.8 + 0.2);
        final_color += vec4(1.0) * specular * 1.5;
        final_color += vec4(1.0) * fresnel;
        final_color += vec4(1.0) * meniscus * 1.2;
    }
    else if (liquid_type == 5) {
        // GALAXY: Deep space void with parallax stars and fBM nebula
        vec4 deep_space = vec4(0.02, 0.0, 0.05, 1.0);
        
        // Nebula clouds
        float nebula1 = fbm(world_pos * 0.4 + vec2(TIME * 0.1, TIME * -0.2));
        float nebula2 = fbm(world_pos * 0.6 + vec2(TIME * -0.15, TIME * 0.1));
        
        vec4 cloud_color1 = vec4(0.6, 0.1, 0.8, 1.0); // Magenta
        vec4 cloud_color2 = vec4(0.1, 0.5, 0.9, 1.0); // Cyan
        
        deep_space = mix(deep_space, cloud_color1, smoothstep(0.2, 0.8, nebula1) * 0.7);
        deep_space = mix(deep_space, cloud_color2, smoothstep(0.3, 0.9, nebula2) * 0.6);
        
        // Parallax Stars! 3 distinct layers moving at different speeds
        float star1 = snoise(world_pos * 5.0 + vec2(0.0, TIME * -0.5));
        if (star1 > 0.8) deep_space += vec4(pow((star1 - 0.8) * 5.0, 2.0));
        
        float star2 = snoise(world_pos * 8.0 + vec2(TIME * 0.2, TIME * -0.2));
        if (star2 > 0.85) deep_space += vec4(pow((star2 - 0.85) * 6.6, 2.0)) * vec4(0.8, 0.9, 1.0, 1.0);
        
        float star3 = snoise(world_pos * 12.0 + vec2(TIME * -0.1, TIME * -0.8));
        if (star3 > 0.9) deep_space += vec4(pow((star3 - 0.9) * 10.0, 2.0)) * vec4(1.0, 0.8, 0.9, 1.0);
        
        final_color = deep_space;
        
        // Glowing magic rim
        final_color += vec4(0.8, 0.4, 1.0, 1.0) * fresnel * 0.8;
        final_color += vec4(1.0) * specular * 0.6 * y_tilt;
        final_color += vec4(1.0, 0.8, 1.0, 1.0) * meniscus;
    }
    else if (liquid_type == 6) {
        // GOLD: Simulated Environment Reflection
        vec4 gold_base = vec4(0.5, 0.3, 0.05, 1.0);
        vec4 gold_light = vec4(1.0, 0.85, 0.4, 1.0);
        
        // Simple matcap/environment reflection mapping
        float reflection = smoothstep(0.2, 0.9, normal.y + normal.x * 0.5);
        
        // Fake environmental reflection by sampling the screen above it!
        vec2 refl_uv = SCREEN_UV;
        refl_uv.y = clamp(1.0 - refl_uv.y, 0.0, 1.0); // Flip Y to fake a mirror reflection
        refl_uv += normal.xy * 0.1 * (1.0 - depth); // Distort with surface wave
        vec4 bg_refl = texture(screen_texture, refl_uv);
        
        // Blend the highly distorted reflection with the gold colors
        final_color = mix(gold_base, bg_refl * gold_light, reflection);
        
        // Depth makes the metal darker
        final_color = mix(final_color, gold_base * 0.3, depth);
        
        // Extremely sharp, bright specular highlight
        float metal_spec = pow(max(0.0, dot(normal, half_vector)), 128.0) * 4.0;
        final_color += vec4(1.0, 0.95, 0.7, 0.0) * metal_spec * y_tilt;
        final_color += vec4(1.0, 0.8, 0.2, 1.0) * fresnel * 1.5;
        final_color += vec4(1.0, 0.9, 0.5, 1.0) * meniscus * 2.0;
    }
    else if (liquid_type == 7) {
        // NEON PLASMA: Cyberpunk grid and scanlines
        vec4 magenta = vec4(1.0, 0.0, 0.8, 1.0);
        vec4 cyan = vec4(0.0, 1.0, 1.0, 1.0);
        vec4 dark = vec4(0.05, 0.0, 0.1, 1.0);
        
        // Fixed world grid
        float grid_x = step(0.1, fract(world_pos.x * 2.0));
        float grid_y = step(0.1, fract(world_pos.y * 2.0));
        vec4 volume = (grid_x * grid_y == 1.0) ? dark : magenta;
        
        // Scrolling scanlines
        float scanline = sin(world_pos.y * 10.0 - TIME * 20.0);
        if (scanline > 0.8) volume = cyan;
        
        // Glitch offset
        if (snoise(vec2(TIME * 5.0, 0.0)) > 0.7) {
            volume = mix(volume, cyan, 0.5);
        }
        
        final_color = mix(volume * (diffuse + 0.4), dark, depth);
        
        // Energy distortion (gravitational lensing)
        vec2 lens_uv = SCREEN_UV + normal.xy * 0.15 * (1.0 - depth);
        // Distort strongly on the grid lines
        if (grid_x * grid_y == 0.0) lens_uv += vec2(0.02, -0.02); 
        vec4 bg_distortion = texture(screen_texture, lens_uv);
        
        // Add the background distortion glowing heavily
        final_color = mix(final_color, bg_distortion * cyan, 0.4 * (1.0 - depth));

        final_color += cyan * diffuse * y_tilt * 2.0;
        final_color += vec4(1.0) * specular * y_tilt;
        final_color += cyan * fresnel;
        final_color += vec4(1.0) * meniscus * 1.2;
    }
    
    // Apply smooth anti-aliased edge
    final_color.a *= alpha;
    
    COLOR = clamp(final_color, 0.0, 1.0);
}
