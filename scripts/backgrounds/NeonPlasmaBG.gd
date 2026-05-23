extends Control

var shader = preload("res://assets/neon_plasma_bg.gdshader")

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg_rect.material = mat
	add_child(bg_rect)
	
	# Falling digital data particles
	var particles = CPUParticles2D.new()
	particles.position = Vector2(360, -50)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(400, 1)
	particles.amount = 40
	particles.lifetime = 3.0
	particles.direction = Vector2(0, 1)
	particles.spread = 0.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 500.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.0, 1.0, 1.0, 0.6)
	add_child(particles)
