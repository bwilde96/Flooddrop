extends CanvasLayer

@onready var bg_rect: ColorRect = $BackgroundRect
@onready var wipe_rect: ColorRect = $WipeRect

signal transition_halfway
signal transition_complete

func _ready() -> void:
	layer = -100 # Put it way behind everything
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://assets/speed_lines.gdshader")
	mat.set_shader_parameter("speed", 0.0)
	mat.set_shader_parameter("darkness", 0.0)
	mat.set_shader_parameter("aberration", 0.0)
	wipe_rect.material = mat
	wipe_rect.color = Color.WHITE # Shader handles alpha
	wipe_rect.visible = true 
	wipe_rect.anchor_right = 1.0
	wipe_rect.anchor_bottom = 1.0
	wipe_rect.position = Vector2.ZERO

var bg_scripts = {
	"main_menu": "res://scripts/backgrounds/MainMenuBG.gd",
	"water": "res://scripts/backgrounds/WaterBG.gd",
	"slime": "res://scripts/backgrounds/SlimeBG.gd",
	"lava": "res://scripts/backgrounds/LavaBG.gd",
	"acid": "res://scripts/backgrounds/AcidBG.gd",
	"gold": "res://scripts/backgrounds/GoldBG.gd",
	"rainbow": "res://scripts/backgrounds/RainbowBG.gd",
	"neon_plasma": "res://scripts/backgrounds/NeonPlasmaBG.gd",
	"galaxy": "res://scripts/backgrounds/GalaxyBG.gd"
}

func update_background(from_theme_id: String, to_theme_id: String) -> void:
	var t_from = ThemeManager.get_theme(from_theme_id)
	var t_to = ThemeManager.get_theme(to_theme_id)
	_do_plunge_transition(t_from.get("drop_color", Color.WHITE), t_to.get("drop_color", Color.WHITE), to_theme_id)

var bg_tween: Tween = null

func _do_plunge_transition(from_color: Color, to_color: Color, theme_id: String) -> void:
	if bg_tween and bg_tween.is_valid():
		bg_tween.kill()
		
	wipe_rect.material.set_shader_parameter("line_color", from_color)
	wipe_rect.material.set_shader_parameter("reveal_progress", 0.0)
	
	bg_tween = create_tween()
	
	# Phase 1: The Descent (Accelerate to smooth speed and darkness)
	bg_tween.tween_method(func(v): wipe_rect.material.set_shader_parameter("speed", v), 0.0, 5.0, 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	bg_tween.parallel().tween_method(func(v): wipe_rect.material.set_shader_parameter("darkness", v), 0.0, 1.0, 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	bg_tween.parallel().tween_method(func(c): wipe_rect.material.set_shader_parameter("line_color", c), from_color, to_color, 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Phase 2: The Swap (At pitch black)
	bg_tween.tween_callback(func():
		transition_halfway.emit()
		
		# Swap the actual background visual
		for child in bg_rect.get_children():
			child.queue_free()
			
		if bg_scripts.has(theme_id):
			var script = load(bg_scripts[theme_id])
			if script:
				var new_bg = script.new()
				bg_rect.add_child(new_bg)
				new_bg.anchor_right = 1.0
				new_bg.anchor_bottom = 1.0
				new_bg.offset_left = 0
				new_bg.offset_top = 0
				new_bg.offset_right = 0
				new_bg.offset_bottom = 0
	)
	
	# Phase 3: The Arrival (Decelerate gracefully and reveal from center)
	bg_tween.tween_method(func(v): wipe_rect.material.set_shader_parameter("speed", v), 5.0, 0.0, 2.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	bg_tween.parallel().tween_method(func(v): wipe_rect.material.set_shader_parameter("reveal_progress", v), 0.0, 1.0, 2.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	
	bg_tween.tween_callback(func():
		transition_complete.emit()
	)
