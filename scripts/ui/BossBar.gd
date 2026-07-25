extends Control
## Boss HP bar — a liquid-glass vessel: the boss's own liquid drains as it dies.

const UIKit = preload("res://scripts/ui/UIKit.gd")

var _mat: ShaderMaterial
var _name_label: Label
var _frac := 1.0
var _shown_frac := 1.0

func setup(boss_name: String, accent: Color) -> void:
	# Compact single row (name inside the glass) tucked under the score row,
	# clear of the multiplier arc and the pause button.
	var bar_size := Vector2(380, 30)
	custom_minimum_size = bar_size
	size = bar_size
	position = Vector2((720.0 - bar_size.x) / 2.0, 82.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ColorRect.new()
	bar.size = bar_size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/ui/liquid_glass.gdshader")
	_mat.set_shader_parameter("accent", accent)
	_mat.set_shader_parameter("rect_size", bar_size)
	_mat.set_shader_parameter("corner_radius", 15.0)
	_mat.set_shader_parameter("fill_level", 1.0)
	_mat.set_shader_parameter("wave_amp", 1.2)
	bar.material = _mat
	add_child(bar)

	_name_label = Label.new()
	_name_label.text = boss_name.to_upper()
	_name_label.add_theme_font_override("font", UIKit.font_display(2))
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_name_label.add_theme_constant_override("shadow_outline_size", 5)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_name_label)

	# Entrance: drop in from above
	modulate.a = 0.0
	position.y = 58.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(self, "position:y", 82.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func set_frac(f: float) -> void:
	_frac = clampf(f, 0.0, 1.0)

func _process(delta: float) -> void:
	# Smooth drain toward the real value (liquid doesn't teleport)
	if _mat and absf(_shown_frac - _frac) > 0.001:
		_shown_frac = lerpf(_shown_frac, _frac, 1.0 - pow(0.002, delta))
		_mat.set_shader_parameter("fill_level", _shown_frac)

func shatter() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(self, "position:y", 58.0, 0.45)
	tw.tween_callback(queue_free)
