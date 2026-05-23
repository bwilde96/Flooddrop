extends Control

var shader = preload("res://assets/rainbow_bg.gdshader")

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg_rect.material = mat
	add_child(bg_rect)
	
	# Floating geometric shards (simulated with large particles)
	var particles = CPUParticles2D.new()
	particles.position = Vector2(360, 1350)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(400, 700)
	particles.amount = 15
	particles.lifetime = 20.0
	particles.direction = Vector2(0, -1)
	particles.spread = 15.0
	particles.gravity = Vector2(0, -5)
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.angular_velocity_min = -30.0
	particles.angular_velocity_max = 30.0
	particles.scale_amount_min = 10.0
	particles.scale_amount_max = 30.0
	particles.color = Color(1.0, 1.0, 1.0, 0.4)
	add_child(particles)
