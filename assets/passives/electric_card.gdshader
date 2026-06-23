shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.04, 0.05, 0.08, 0.95);
uniform vec4 line_color : source_color = vec4(0.15, 0.9, 1.0, 1.0);
uniform float corner_radius = 25.0;
uniform vec2 rect_size = vec2(300.0, 420.0);
uniform float time_speed = 2.0;

// 2D Random
float random (in vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// 2D Noise based on Morgan McGuire @morgan3d
float noise (in vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

// Smooth Interpolation
    vec2 u = f*f*(3.0-2.0*f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

// Fractal Brownian Motion for high-res, organic organic noise (fixes pixelation)
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    vec2 shift = vec2(100.0);
    // Rotate to reduce axial bias
    mat2 rot = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.50)));
    for (int i = 0; i < 3; i++) {
        value += amplitude * noise(st);
        st = rot * st * 2.0 + shift;
        amplitude *= 0.5;
    }
    return value;
}

// --- TRUE 3D SIMPLEX NOISE ---
// This mathematically prevents any squares, cubes, or grid lines from ever forming!
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 = v - i + dot(i, C.xxx) ;
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));
  float n_ = 1.0/7.0; 
  vec3  ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );
  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3) ) );
}

// 3D fBM using Simplex Noise
float fbm3(vec3 st) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; i++) {
        // snoise returns [-1, 1], so we map it to [0, 1] for our glow mask
        value += amplitude * (snoise(st) * 0.5 + 0.5);
        
        // Simplex noise has no grid, but we still rotate to prevent repeating patterns
        float nx = st.x * 0.8 - st.y * 0.6;
        float ny = st.x * 0.6 + st.y * 0.8;
        st = vec3(nx, ny, st.z + 0.5) * 2.0 + vec3(12.3, 45.6, 78.9);
        
        amplitude *= 0.5;
    }
    return value;
}

// SDF for rounded box
float rounded_box_sdf(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void fragment() {
    vec2 p = (UV - 0.5) * rect_size;
    vec2 b = rect_size * 0.5;
    
    float d = rounded_box_sdf(p, b, corner_radius);
    
    // Smooth anti-aliased clipping for the physical boundaries of the card
    float card_alpha = 1.0 - smoothstep(0.0, 2.5, d);
    
    vec4 col = bg_color;
    
    // Base glass highlight
    float highlight = smoothstep(0.8, 0.0, distance(UV, vec2(0.1, 0.1)));
    col.rgb += vec3(0.1, 0.3, 0.5) * highlight * 0.4;
    
    // Magical wandering energy inside the border
    // Fades perfectly to 0 before hitting the physical edge of the card, preventing any clipping!
    float border_mask = smoothstep(-120.0, -5.0, d) * (1.0 - smoothstep(-10.0, 0.0, d));
    
    // TRUE FLAWLESS SEAMLESS FIX: 
    // Instead of a rigid, fast orbit, we use chaotic wandering to make the movement completely random!
    
    // 1. A chaotic, localized drift that pushes the clouds in random directions (up, down, left, right)
    vec2 wander = vec2(
        sin(TIME * 0.25 + p.y * 0.01) * 50.0,
        cos(TIME * 0.18 + p.x * 0.01) * 50.0
    );
    
    // 2. A much slower, subtle overall orbit so the energy still cycles around the card organically
    float s = sin(TIME * 0.05);
    float c = cos(TIME * 0.05);
    vec2 rotated_p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
    
    // This maps the noise to a Cartesian grid, but heavily warps and pushes it randomly!
    // The Z-axis drifts over time to make the clouds continuously boil and morph.
    vec3 coords = vec3((rotated_p + wander) * 0.006, TIME * 0.1);
    
    // Evaluate 3D fbm. 
    float bolt_noise = fbm3(coords);
    
    // Widened to the absolute maximum mathematical softness
    float magic_aura = smoothstep(0.0, 1.0, bolt_noise);
    // Softened the bright core massively 
    float magic_core = smoothstep(0.2, 1.0, bolt_noise);
    
    // Add the glowing aura
    col.rgb += line_color.rgb * magic_aura * border_mask * 0.9; 

    
    // Restrict the bright white core strictly to the outer edge
    // Also fades perfectly to 0 before hitting the physical edge
    float core_mask = smoothstep(-25.0, -5.0, d) * (1.0 - smoothstep(-10.0, 0.0, d));
    col.rgb += vec3(1.0) * magic_core * core_mask * 0.3; 
    
    // --- CRISP POLISHED GLASS BEVEL ---
    // A mathematically precise 3.0-pixel inner line hugging the edge perfectly.
    float bevel_thickness = 3.0;
    float bevel_mask = smoothstep(-bevel_thickness - 2.0, -bevel_thickness, d) * (1.0 - smoothstep(-0.5, 0.0, d));
    
    // Sweeping diagonal shine for the premium gloss effect
    float shine_speed = 0.3;
    float shine_pos = fract(TIME * shine_speed) * 3.0 - 0.5; // Sweeps slowly across
    
    // Creates a sharp diagonal beam of light
    float diagonal = UV.x + UV.y;
    float sweeping_shine = smoothstep(0.2, 0.0, abs(diagonal - shine_pos));
    float shine_core = smoothstep(0.05, 0.0, abs(diagonal - shine_pos));
    
    // Base bevel color is a slightly darker version of the theme color
    vec3 bevel_color = line_color.rgb * 0.6;
    
    // Add the sweeping shine (intense white/bright theme color)
    bevel_color = mix(bevel_color, line_color.rgb * 2.0, sweeping_shine * 0.5);
    bevel_color = mix(bevel_color, vec3(1.0), shine_core * 0.9);
    
    // Add the polished glass edge to the final color
    col.rgb += bevel_color * bevel_mask;
    
    col.a *= card_alpha; // Apply the physical anti-aliased edge
    COLOR = col;
}
