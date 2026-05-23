extends Control

var bg_tex : ImageTexture

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(PRESET_FULL_RECT)
    
    var img = Image.new()
    var err = img.load("res://assets/backgrounds/acid_bg.png")
    if err == OK:
        bg_tex = ImageTexture.create_from_image(img)
    
    var bg_rect = TextureRect.new()
    if bg_tex:
        bg_rect.texture = bg_tex
    bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg_rect.set_anchors_preset(PRESET_FULL_RECT)
    bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg_rect)
    
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
