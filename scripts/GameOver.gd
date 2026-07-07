extends Control

const UIKit = preload("res://scripts/ui/UIKit.gd")

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

	# Verdict titles are display moments (Audiowide).
	var title: Label = $VBoxContainer/TitleLabel
	title.add_theme_font_override("font", UIKit.font_display(2))

	# Challenge results take a different shape entirely.
	if not GameManager.last_challenge_result.is_empty():
		_setup_challenge_result(GameManager.last_challenge_result)
		return

	# Make RETRY the obvious default action.
	restart_button.text = "▶  RETRY"
	restart_button.add_theme_font_size_override("font_size", 40)
	UIKit.style_button(restart_button, Color(0.55, 0.9, 1.0), true)
	UIKit.style_button(menu_button, Color(0.5, 0.65, 0.85), false)

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
		_near_miss_label.text = "NEW BEST!"
		_near_miss_label.add_theme_font_override("font", UIKit.font_display(2))
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

func _setup_challenge_result(res: Dictionary) -> void:
	var title: Label = $VBoxContainer/TitleLabel
	var def: Dictionary = res.get("def", {})
	new_hs_label.visible = false
	score_label.text = "Score: %d" % GameManager.score
	survival_label.text = str(def.get("name", "Challenge"))
	menu_button.text = "THE GAUNTLET"

	if res.get("won", false):
		title.text = "CHALLENGE\nCOMPLETE!"
		title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		droplets_earned_label.text = ""
		total_droplets_label.text = "" if res.get("first_clear", false) else "practice — reduced rewards"
		restart_button.text = "NEXT"
		UIKit.style_button(restart_button, Color(0.35, 1.0, 0.55), true)
		var lbl := _make_info_label(Color(0.4, 1.0, 0.6))
		lbl.text = "FIRST CLEAR!" if res.get("first_clear", false) else "Cleared again — nice."
		$VBoxContainer.add_child(lbl)
		$VBoxContainer.move_child(lbl, survival_label.get_index() + 1)
		# Reward chips (shader icons, no emoji)
		var chips := HBoxContainer.new()
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		chips.add_theme_constant_override("separation", 12)
		if res.get("droplets", 0) > 0:
			chips.add_child(UIKit.chip(UIKit.ICON_DROPLET, "+%d" % res.droplets, 28, 24))
		if res.get("cores", 0) > 0:
			chips.add_child(UIKit.chip(UIKit.ICON_CORE, "+%d" % res.cores, 28, 24))
		if res.get("prisms", 0) > 0:
			chips.add_child(UIKit.chip(UIKit.ICON_PRISM, "+%d" % res.prisms, 28, 24))
		$VBoxContainer.add_child(chips)
		$VBoxContainer.move_child(chips, droplets_earned_label.get_index())
	else:
		title.text = "CHALLENGE\nFAILED"
		title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		var pct := int(res.get("progress", 0.0) * 100.0)
		droplets_earned_label.text = "+%d droplets consolation" % GameManager.last_droplets_earned
		total_droplets_label.text = "You reached %d%% — so close!" % pct if pct >= 50 else "You reached %d%%" % pct
		if res.get("second_wind", false):
			restart_button.text = "SECOND WIND — FREE RETRY"
			UIKit.style_button(restart_button, Color(1.0, 0.8, 0.3), true)
			var lbl := _make_info_label(Color(1.0, 0.85, 0.3))
			lbl.text = "Second Wind: that was close enough to go again, free."
			$VBoxContainer.add_child(lbl)
			$VBoxContainer.move_child(lbl, survival_label.get_index() + 1)
		elif res.get("refunded", false):
			restart_button.text = "RETRY"
			UIKit.style_button(restart_button, Color(0.55, 0.9, 1.0), true)
			var lbl := _make_info_label(Color(0.6, 0.85, 1.0))
			lbl.text = "Ticket refunded — that ended too fast to count."
			$VBoxContainer.add_child(lbl)
			$VBoxContainer.move_child(lbl, survival_label.get_index() + 1)
		else:
			var cost := ChallengeManager.get_attempt_cost(res.get("stage", 0), def)
			restart_button.text = "RETRY  (1 TICKET)" if cost > 0 else "RETRY — FREE"
			UIKit.style_button(restart_button, Color(0.55, 0.9, 1.0), true)
	UIKit.style_button(menu_button, Color(0.5, 0.65, 0.85), false)

	# Rewire the buttons for challenge flow.
	restart_button.pressed.disconnect(_on_restart_pressed)
	restart_button.pressed.connect(func(): _retry_challenge(res))
	menu_button.pressed.disconnect(_on_menu_pressed)
	menu_button.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.change_scene("res://scenes/Challenge.tscn")
	)

func _retry_challenge(res: Dictionary) -> void:
	AudioManager.play_sfx("button")
	var stage: int = res.get("stage", 0)
	var def: Dictionary = res.get("def", {})
	if res.get("won", false):
		GameManager.change_scene("res://scenes/Challenge.tscn") # "NEXT" -> pick the next one
		return
	var cid: String = def.get("id", "")
	if res.get("second_wind", false):
		ChallengeManager.use_second_wind(cid)
		GameManager.challenge_ticket_spent = false
	else:
		var cost := ChallengeManager.get_attempt_cost(stage, def)
		if cost > 0 and not ChallengeManager.spend_ticket():
			AudioManager.play_sfx("miss")
			GameManager.change_scene("res://scenes/Challenge.tscn")
			return
		GameManager.challenge_ticket_spent = cost > 0
	GameManager.start_challenge(stage, def)

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
