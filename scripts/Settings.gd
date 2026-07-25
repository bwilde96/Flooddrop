extends Control

const UIKit = preload("res://scripts/ui/UIKit.gd")

@onready var sfx_slider: HSlider = $VBox/Margin/VBox/SFXHBox/SFXSlider
@onready var bgm_slider: HSlider = $VBox/Margin/VBox/BGMHBox/BGMSlider
@onready var haptics_btn: CheckButton = $VBox/Margin/VBox/HapticsHBox/HapticsButton
@onready var back_button: Button = $VBox/Header/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)

	# Design-system styling: display title + tracked caps back button.
	var title := get_node_or_null("VBox/Header/TitleLabel")
	if title == null:
		for c in get_node("VBox/Header").get_children():
			if c is Label: title = c; break
	if title:
		title.add_theme_font_override("font", UIKit.font_display(2))
		title.add_theme_font_size_override("font_size", 30)
		title.add_theme_color_override("font_color", UIKit.CYAN.lightened(0.25))
	back_button.text = "‹  BACK"

	# Each setting sits in its own liquid vessel.
	var vbox_s: VBoxContainer = $VBox/Margin/VBox
	for row_name in ["SFXHBox", "BGMHBox", "HapticsHBox"]:
		var row := vbox_s.get_node_or_null(row_name)
		if row == null: continue
		var idx := row.get_index()
		vbox_s.remove_child(row)
		var lp := UIKit.LiquidPanel.new(Color(0.35, 0.75, 1.0), 0.07, 22.0, 16)
		lp.content.add_child(row)
		vbox_s.add_child(lp)
		vbox_s.move_child(lp, idx)
	vbox_s.add_theme_constant_override("separation", 14)
	UIKit.animate_in(vbox_s.get_children(), 0.06)
	
	sfx_slider.value = AudioManager.sfx_volume * 100.0
	bgm_slider.value = AudioManager.bgm_volume * 100.0
	haptics_btn.button_pressed = AudioManager.haptics_enabled
	
	sfx_slider.value_changed.connect(_on_settings_changed)
	bgm_slider.value_changed.connect(_on_settings_changed)
	haptics_btn.toggled.connect(_on_settings_changed.bind())
	
	get_tree().set_quit_on_go_back(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()

func _on_settings_changed(_val: float = 0.0) -> void:
	var sfx = sfx_slider.value / 100.0
	var bgm = bgm_slider.value / 100.0
	var haptics = haptics_btn.button_pressed
	
	AudioManager.update_settings(sfx, bgm, haptics)
	
	# Only play test sound for SFX slider drag
	if not sfx_slider.is_drag_successful():
		AudioManager.play_sfx("button")

func _on_back() -> void:
	AudioManager.play_sfx("button")
	GameManager.goto_main_menu()
