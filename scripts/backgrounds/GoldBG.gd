extends TextureRect

func _ready() -> void:
    texture = load("res://assets/backgrounds/gold_bg.jpg")
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var particles = CPUParticles2D.new()
    particles.position = Vector2(360, 640)
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(400, 700)
    particles.amount = 50
    particles.lifetime = 8.0
    particles.direction = Vector2(0, -1)
    particles.spread = 180.0
    particles.gravity = Vector2(0, -5)
    particles.initial_velocity_min = 5.0
    particles.initial_velocity_max = 20.0
    particles.scale_amount_min = 3.0
    particles.scale_amount_max = 12.0
    particles.color = Color(1.0, 0.9, 0.4, 0.4)
    add_child(particles)
