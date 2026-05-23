extends Control

@onready var sfx_slider: HSlider = $VBox/Margin/VBox/SFXHBox/SFXSlider
@onready var bgm_slider: HSlider = $VBox/Margin/VBox/BGMHBox/BGMSlider
@onready var haptics_btn: CheckButton = $VBox/Margin/VBox/HapticsHBox/HapticsButton
@onready var back_button: Button = $VBox/Header/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	
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
