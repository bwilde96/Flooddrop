extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel

func _ready() -> void:
	BackgroundManager.update_background("main_menu")
	get_tree().set_quit_on_go_back(true)
	start_button.pressed.connect(_on_start_pressed)
	var shop_btn = $VBoxContainer/ShopButton
	if shop_btn: shop_btn.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.change_scene("res://scenes/Shop.tscn")
	)
	var set_btn = $VBoxContainer/SettingsButton
	if set_btn: set_btn.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.change_scene("res://scenes/Settings.tscn")
	)
	
	var hs: float = SaveManager.get_value("high_score", 0.0)
	high_score_label.text = "High Score: %d" % int(hs)

func _on_start_pressed() -> void:
	AudioManager.play_sfx("button")
	GameManager.start_game()
