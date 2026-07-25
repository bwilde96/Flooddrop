## ThemeFactory — builds the global Theme (docs/DESIGN_SYSTEM.md) applied to the
## root window so EVERY Control in EVERY scene inherits the premium look:
## Rajdhani as the default font, neon-glass buttons, ink panels, styled sliders.

const UIKit = preload("res://scripts/ui/UIKit.gd")

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = UIKit.font_ui()
	t.default_font_size = 19

	# ---- Labels (explicit class item — default_font alone doesn't reach every Label)
	t.set_font("font", "Label", UIKit.font_ui())
	t.set_color("font_color", "Label", UIKit.TEXT_HI)
	t.set_font("font", "CheckButton", UIKit.font_ui())
	t.set_font("font", "LineEdit", UIKit.font_ui())
	t.set_font("font", "RichTextLabel", UIKit.font_ui())

	# ---- Buttons (neon glass everywhere by default)
	var accent := UIKit.CYAN
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	normal.bg_color = UIKit.INK_1
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.16)
	normal.shadow_size = 5
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = UIKit.INK_2
	hover.shadow_size = 9

	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 1.0)
	pressed.border_color = Color.WHITE

	var disabled := StyleBoxFlat.new()
	disabled.set_corner_radius_all(14)
	disabled.set_border_width_all(1)
	disabled.bg_color = Color(UIKit.INK_1.r, UIKit.INK_1.g, UIKit.INK_1.b, 0.85)
	disabled.border_color = Color(0.28, 0.31, 0.37, 0.5)
	disabled.content_margin_left = 18
	disabled.content_margin_right = 18
	disabled.content_margin_top = 8
	disabled.content_margin_bottom = 8

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", UIKit.font_ui_semibold(2))
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Button", accent.lightened(0.45))
	t.set_color("font_hover_color", "Button", accent.lightened(0.6))
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", UIKit.TEXT_LOW)

	# ---- Panels (pause menu, debug, shop rows pick this up)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(UIKit.INK_1.r, UIKit.INK_1.g, UIKit.INK_1.b, 0.94)
	panel.set_corner_radius_all(16)
	panel.set_border_width_all(1)
	panel.border_color = Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, 0.18)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel.duplicate())

	# ---- Sliders (Settings)
	var track := StyleBoxFlat.new()
	track.bg_color = UIKit.INK_2
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, 0.85)
	filled.set_corner_radius_all(6)
	filled.content_margin_top = 5
	filled.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled.duplicate())
	var grabber := _dot_texture(26, Color.WHITE, UIKit.CYAN)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", grabber)
	t.set_icon("grabber_disabled", "HSlider", _dot_texture(26, Color(0.6, 0.6, 0.65), Color(0.3, 0.3, 0.35)))

	# ---- ProgressBar (generic)
	t.set_stylebox("background", "ProgressBar", track.duplicate())
	t.set_stylebox("fill", "ProgressBar", filled.duplicate())

	return t

static func _dot_texture(size: int, core: Color, glow: Color) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d < 1.0:
				var col := glow
				if d < 0.62:
					col = core.lerp(glow, d / 0.62 * 0.4)
				col.a = clampf((1.0 - d) * 6.0, 0.0, 1.0)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
