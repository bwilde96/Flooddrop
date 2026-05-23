extends TextureRect

func _ready() -> void:
    texture = load("res://assets/backgrounds/water_zen_garden_bg.jpg")
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var particles = CPUParticles2D.new()
    particles.position = Vector2(360, -50)
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(400, 1)
    particles.amount = 15
    particles.lifetime = 10.0
    particles.direction = Vector2(0, 1)
    particles.spread = 20.0
    particles.gravity = Vector2(0, 30)
    particles.initial_velocity_min = 20.0
    particles.initial_velocity_max = 50.0
    particles.angular_velocity_min = -45.0
    particles.angular_velocity_max = 45.0
    particles.scale_amount_min = 4.0
    particles.scale_amount_max = 8.0
    particles.color = Color(0.2, 0.8, 0.4, 0.8)
    add_child(particles)
