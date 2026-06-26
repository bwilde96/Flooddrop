extends Control

@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var survival_label: Label = $VBoxContainer/SurvivalLabel
@onready var new_hs_label: Label = $VBoxContainer/NewHighScoreLabel
@onready var droplets_earned_label: Label = $VBoxContainer/DropletsEarnedLabel
@onready var total_droplets_label: Label = $VBoxContainer/TotalDropletsLabel

@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var menu_button: Button = $VBoxContainer/MenuButton

# The cheapest -> dearest ability unlock ladder (matches Shop.gd ABILITIES).
const UNLOCK_LADDER = [
	["evaporation", 1000, "Evaporation"],
	["tidal_wave", 2000, "Tidal Wave"],
	["midas_touch", 3000, "Midas Touch"],
	["auto_turret", 4000, "Auto-Turret"],
]

var _near_miss_label: Label
var _next_unlock_label: Label

func _ready() -> void:
	get_tree().set_quit_on_go_back(false)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	# Make RETRY the obvious default action.
	restart_button.text = "▶  RETRY"
	restart_button.add_theme_font_size_override("font_size", 40)

	score_label.text = "Score: %d" % GameManager.score
	survival_label.text = "Survived: %.1fs" % GameManager.survival_time

	var earned = GameManager.last_droplets_earned
	var total = int(SaveManager.get_value("droplets", 0.0))

	# Count both reward numbers up for a satisfying payoff.
	_count_up(droplets_earned_label, "+", earned, " Droplets", 0.7)
	_count_up(total_droplets_label, "Total: ", total, "", 0.9)

	# Near-miss framing (or celebration) — the core "one more run" hook.
	_near_miss_label = _make_info_label(Color(1.0, 0.85, 0.3))
	$VBoxContainer.add_child(_near_miss_label)
	$VBoxContainer.move_child(_near_miss_label, survival_label.get_index() + 1)

	var hs := int(SaveManager.get_value("high_score", 0.0))
	if GameManager.is_new_high_score:
		new_hs_label.visible = true
		_near_miss_label.text = "🏆  NEW BEST!"
		_near_miss_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		var tween = create_tween().set_loops()
		tween.tween_property(new_hs_label, "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(new_hs_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	else:
		var gap := hs - GameManager.score
		if gap <= 0:
			_near_miss_label.text = "So close to your best!"
		elif gap < 300:
			_near_miss_label.text = "Just %d from your best — go again!" % gap
		else:
			_near_miss_label.text = "Best: %d   (%d to beat it)" % [hs, gap]

	# Progress toward the next ability unlock — always give a goal to chase.
	_next_unlock_label = _make_info_label(Color(0.6, 0.85, 1.0))
	$VBoxContainer.add_child(_next_unlock_label)
	$VBoxContainer.move_child(_next_unlock_label, total_droplets_label.get_index() + 1)

	var unlocked = SaveManager.get_value("unlocked_abilities", ["time_warp"])
	var shown := false
	for item in UNLOCK_LADDER:
		if not (item[0] in unlocked):
			var have: int = min(total, int(item[1]))
			_next_unlock_label.text = "Next: %s  %d / %d" % [item[2], have, item[1]]
			shown = true
			break
	if not shown:
		_next_unlock_label.text = "All abilities unlocked! ⚡"

func _make_info_label(color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _count_up(label: Label, prefix: String, target: int, suffix: String, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): label.text = prefix + str(int(v)) + suffix, 0.0, float(target), dur).set_ease(Tween.EASE_OUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_menu_pressed()

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("button")
	GameManager.start_game()

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("button")
	GameManager.goto_main_menu()
