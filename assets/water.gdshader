shader_type canvas_item;

uniform float wave_speed = 1.5;
uniform float wave_freq = 5.0;
uniform float wave_amp = 0.03;
uniform vec4 top_color: source_color = vec4(0.35, 0.78, 0.98, 0.9);
uniform vec4 bottom_color: source_color = vec4(0.19, 0.38, 0.84, 0.95);

void fragment() {
    // Basic sine wave offset at the top of the rect
    float wave = sin(UV.x * wave_freq + TIME * wave_speed) * wave_amp;
    
    // UV.y goes from 0.0 (top) to 1.0 (bottom)
    // If we are above the wavy line (UV.y < wave_amp + wave), discard
    float edge = wave_amp + wave;
    if (UV.y < edge) {
        COLOR.a = 0.0;
    } else {
        // Gradient from top_color to bottom_color
        // Normalize the Y coordinate so the gradient starts at the wave edge
        float t = (UV.y - edge) / (1.0 - edge);
        COLOR = mix(top_color, bottom_color, t);
        
        // Inherit alpha from modulate if applied externally
        COLOR.a *= COLOR.a; 
    }
}
