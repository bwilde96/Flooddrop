extends Control

var shader = preload("res://assets/galaxy_bg.gdshader")

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg_rect.material = mat
	add_child(bg_rect)
	
	# Shooting stars / Comets
	var particles = CPUParticles2D.new()
	particles.position = Vector2(720, -100) # Top right
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(200, 400)
	particles.amount = 5
	particles.lifetime = 1.5
	particles.direction = Vector2(-1, 1) # Diagonal down-left
	particles.spread = 5.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 600.0
	particles.initial_velocity_max = 1000.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	
	# Make them look like comets (long)
	# CPUParticles doesn't easily do trail without texture, but we can fake it by stretching
	particles.scale = Vector2(4.0, 1.0)
	particles.rotation = particles.direction.angle()
	
	particles.color = Color(1.0, 1.0, 1.0, 0.8)
	add_child(particles)
