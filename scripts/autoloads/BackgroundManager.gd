extends CanvasLayer

@onready var bg_rect: ColorRect = $BackgroundRect
@onready var wipe_rect: ColorRect = $WipeRect

func _ready() -> void:
	layer = -100 # Put it way behind everything
	
	# The BackgroundRect holds the current animated shader/texture
	# The WipeRect covers it temporarily during transitions

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

func update_background(theme_id: String) -> void:
	var t = ThemeManager.get_theme(theme_id)
	_do_wipe_transition(t.get("drop_color", Color.WHITE), theme_id)

func _do_wipe_transition(wipe_color: Color, theme_id: String) -> void:
	wipe_rect.color = wipe_color
	wipe_rect.visible = true
	wipe_rect.position.y = get_viewport().get_visible_rect().size.y
	
	var tween = create_tween()
	# Wipe Up
	tween.tween_property(wipe_rect, "position:y", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
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
	# Fade out
	tween.tween_property(wipe_rect, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tween.tween_callback(func():
		wipe_rect.visible = false
		wipe_rect.modulate.a = 1.0
	)
