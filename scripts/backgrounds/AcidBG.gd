extends Control

var shader = preload("res://assets/acid_bg.gdshader")

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	bg_rect.material = mat
	add_child(bg_rect)
	
	# Electrical sparks
	var particles = CPUParticles2D.new()
	particles.position = Vector2(360, 200)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(400, 400)
	particles.amount = 20
	particles.lifetime = 0.5
	particles.direction = Vector2(0, 1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 1.0, 0.2, 1.0)
	
	# Sparks burst randomly rather than constantly emitting perfectly
	particles.explosiveness = 0.8
	add_child(particles)
