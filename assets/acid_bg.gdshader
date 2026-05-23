shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.1, 0.15, 0.0, 1.0);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    vec4 col = bg_color;
    
    // Vertical metal grates/pipes
    float pipes = abs(sin(uv.x * 30.0));
    pipes = smoothstep(0.8, 0.9, pipes);
    
    col.rgb -= pipes * 0.1;
    
    // Bubbling acid behind grates
    float bubbles = sin(uv.y * 20.0 - TIME * 5.0) * sin(uv.x * 50.0);
    bubbles = smoothstep(0.8, 1.0, bubbles);
    
    col.rgb += vec3(0.6, 1.0, 0.0) * bubbles * (1.0 - pipes) * 0.5;
    
    // Flickering fluorescent light
    float flicker = random(vec2(floor(TIME * 15.0), 0.0));
    if (flicker > 0.9) {
        col.rgb += vec3(0.2, 0.3, 0.0);
    }
    
    COLOR = col;
}
