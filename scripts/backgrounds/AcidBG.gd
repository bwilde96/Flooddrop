extends TextureRect

func _ready() -> void:
    var img = Image.new()
    var err = img.load("res://assets/backgrounds/acid_bg.jpg")
    if err == OK:
        texture = ImageTexture.create_from_image(img)
        
    expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    set_anchors_preset(PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    
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
    particles.explosiveness = 0.8
    add_child(particles)
