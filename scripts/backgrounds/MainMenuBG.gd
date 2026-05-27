extends TextureRect

func _ready() -> void:
	texture = load("res://assets/backgrounds/main_menu_bg.jpg")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
