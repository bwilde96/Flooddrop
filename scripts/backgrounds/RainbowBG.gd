extends TextureRect

var bg_tex = load("res://assets/backgrounds/rainbow_bg.jpg")

func _ready() -> void:
    texture = bg_tex
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
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
