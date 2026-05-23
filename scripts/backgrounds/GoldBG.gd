extends Control

var bg_tex : ImageTexture

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(PRESET_FULL_RECT)
    
    var img = Image.new()
    var err = img.load("res://assets/backgrounds/gold_bg.png")
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
