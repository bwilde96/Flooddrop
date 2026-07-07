extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel

func _ready() -> void:
	BackgroundManager.update_background("main_menu", "main_menu")
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

	# The Gauntlet (challenge mode) entry — badge shows waiting tickets.
	var ch_btn := Button.new()
	ch_btn.name = "ChallengeButton"
	ch_btn.text = "⚔  THE GAUNTLET  (🎟 %d)" % ChallengeManager.get_tickets()
	ch_btn.custom_minimum_size = Vector2(0, 64)
	ch_btn.add_theme_font_size_override("font_size", 26)
	ch_btn.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.change_scene("res://scenes/Challenge.tscn")
	)
	$VBoxContainer.add_child(ch_btn)
	$VBoxContainer.move_child(ch_btn, $VBoxContainer/ShopButton.get_index())

func _on_start_pressed() -> void:
	AudioManager.play_sfx("power_up")
	start_button.disabled = true
	
	var tw = create_tween()
	tw.tween_property($VBoxContainer, "position:y", -1000.0, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	tw.tween_callback(func():
		if not BackgroundManager.transition_halfway.is_connected(_on_transition_halfway):
			BackgroundManager.transition_halfway.connect(_on_transition_halfway, CONNECT_ONE_SHOT)
		var t = ThemeManager.get_theme("water")
		BackgroundManager._do_plunge_transition(Color.WHITE, t.drop_color, "water")
	)

func _on_transition_halfway() -> void:
	GameManager.start_game()
