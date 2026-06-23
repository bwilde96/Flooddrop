shader_type canvas_item;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// Pure black removal. DALL-E might have slight compression artifacts,
	// so we allow a tiny tolerance on brightness.
	float brightness = max(max(col.r, col.g), col.b);
	
	if (brightness < 0.05) {
		col.a = 0.0;
	} else if (brightness < 0.15) {
		// Smooth transition for anti-aliased dark edges to act like a natural drop shadow
		col.a = smoothstep(0.05, 0.15, brightness);
	}
	
	COLOR = col;
}
