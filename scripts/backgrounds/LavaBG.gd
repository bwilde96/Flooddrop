extends TextureRect

func _ready() -> void:
    texture = load("res://assets/backgrounds/lava_bg.jpg")
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var particles = CPUParticles2D.new()
    particles.position = Vector2(360, 1350)
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(400, 1)
    particles.amount = 40
    particles.lifetime = 6.0
    particles.direction = Vector2(0, -1)
    particles.spread = 45.0
    particles.gravity = Vector2(0, -50)
    particles.initial_velocity_min = 50.0
    particles.initial_velocity_max = 100.0
    particles.scale_amount_min = 2.0
    particles.scale_amount_max = 5.0
    particles.color = Color(1.0, 0.4, 0.0, 1.0)
    add_child(particles)
