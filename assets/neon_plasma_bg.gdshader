shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.05, 0.0, 0.1, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    vec4 col = bg_color;
    
    // Wireframe Grid (floor perspective)
    if (uv.y > 0.5) {
        float floor_y = (uv.y - 0.5) / 0.5; // 0 to 1
        float perspective_x = (uv.x - 0.5) / (floor_y + 0.1) + 0.5;
        
        float grid_x = fract(perspective_x * 15.0);
        float grid_y = fract(pow(floor_y, 0.5) * 15.0 - TIME * 3.0);
        
        float line_w_x = 0.05 / max(0.1, floor_y);
        float line_w_y = 0.05;
        
        if (grid_x < line_w_x || grid_y < line_w_y) {
            col.rgb = grid_color.rgb * smoothstep(1.0, 0.0, floor_y);
        }
    } else {
        // Distant city silhouette
        float city = random(vec2(floor(uv.x * 20.0), 0.0));
        if (uv.y > 0.5 - city * 0.3) {
            col.rgb += vec3(0.0, 1.0, 1.0) * 0.2; // Cyan glow
            
            // City windows
            if (fract(uv.x * 100.0) < 0.2 && fract(uv.y * 50.0) < 0.2) {
                if (random(floor(uv * vec2(100.0, 50.0))) > 0.5) {
                    col.rgb = vec3(1.0, 1.0, 0.0);
                }
            }
        }
    }
    
    // Digital rain overlay (matrix style)
    float rain = random(floor(uv * vec2(50.0, 20.0) + vec2(0.0, TIME * 5.0)));
    if (rain > 0.95) {
        col.rgb += vec3(0.0, 1.0, 0.8) * 0.3 * smoothstep(1.0, 0.5, uv.y);
    }
    
    // Scanlines
    col.rgb *= 0.9 + 0.1 * sin(uv.y * 500.0);
    
    COLOR = col;
}
