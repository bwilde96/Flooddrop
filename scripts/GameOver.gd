extends Control

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var survival_label: Label = $VBoxContainer/SurvivalLabel
@onready var new_hs_label: Label = $VBoxContainer/NewHighScoreLabel
@onready var droplets_earned_label: Label = $VBoxContainer/DropletsEarnedLabel
@onready var total_droplets_label: Label = $VBoxContainer/TotalDropletsLabel

@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	score_label.text = "Score: %d" % GameManager.score
	survival_label.text = "Survived: %.1fs" % GameManager.survival_time
	
	var earned = GameManager.last_droplets_earned
	var bonus_text = " (High Score Bonus!)" if GameManager.is_new_high_score else ""
	droplets_earned_label.text = "+%d Droplets%s" % [earned, bonus_text]
	
	total_droplets_label.text = "Total Droplets: %d" % int(SaveManager.get_value("droplets", 0.0))
	
	if GameManager.is_new_high_score:
		new_hs_label.visible = true
		var tween = create_tween().set_loops()
		tween.tween_property(new_hs_label, "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(new_hs_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu_pressed()

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("button")
	GameManager.start_game()

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("button")
	GameManager.goto_main_menu()
