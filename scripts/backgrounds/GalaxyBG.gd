extends TextureRect

var bg_tex = load("res://assets/backgrounds/galaxy_bg.jpg")

func _ready() -> void:
    texture = bg_tex
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var particles = CPUParticles2D.new()
    particles.position = Vector2(720, -100)
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = Vector2(200, 400)
    particles.amount = 5
    particles.lifetime = 1.5
    particles.direction = Vector2(-1, 1)
    particles.spread = 5.0
    particles.gravity = Vector2(0, 0)
    particles.initial_velocity_min = 600.0
    particles.initial_velocity_max = 1000.0
    particles.scale_amount_min = 2.0
    particles.scale_amount_max = 5.0
    particles.scale = Vector2(4.0, 1.0)
    particles.rotation = particles.direction.angle()
    particles.color = Color(1.0, 1.0, 1.0, 0.8)
    add_child(particles)
