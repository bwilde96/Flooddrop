extends Control

const UIKit = preload("res://scripts/ui/UIKit.gd")

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

	# Premium styling across the menu (docs/DESIGN_SYSTEM.md).
	var title: Label = $VBoxContainer/TitleLabel
	title.add_theme_font_override("font", UIKit.font_display(3))
	title.add_theme_color_override("font_color", UIKit.CYAN.lightened(0.25))
	title.add_theme_color_override("font_shadow_color", Color(UIKit.CYAN.r, UIKit.CYAN.g, UIKit.CYAN.b, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 12)
	high_score_label.add_theme_font_override("font", UIKit.font_ui_semibold(2))
	high_score_label.add_theme_color_override("font_color", UIKit.TEXT_MID)

	UIKit.style_button(start_button, Color(0.35, 0.95, 1.0), true)
	start_button.add_theme_font_size_override("font_size", 34)
	start_button.custom_minimum_size = Vector2(0, 76)
	UIKit.style_button($VBoxContainer/ShopButton, Color(0.55, 0.8, 1.0), false)
	UIKit.style_button($VBoxContainer/SettingsButton, Color(0.5, 0.65, 0.85), false)

	# The Gauntlet (challenge mode) entry — shows waiting tickets.
	var ch_btn := UIKit.neon_button("THE GAUNTLET   ·   %d TICKETS" % ChallengeManager.get_tickets(),
		UIKit.COL_TICKET, Vector2(0, 64), 25, false)
	ch_btn.name = "ChallengeButton"
	ch_btn.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.change_scene("res://scenes/Challenge.tscn")
	)
	$VBoxContainer.add_child(ch_btn)
	$VBoxContainer.move_child(ch_btn, $VBoxContainer/ShopButton.get_index())

	# Waiting tickets glow with quiet invitation.
	if ChallengeManager.get_tickets() > 0:
		var pulse := ch_btn.create_tween().set_loops()
		pulse.tween_property(ch_btn, "modulate", Color(1.14, 1.12, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(ch_btn, "modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)

	# Staggered entrance for the whole stack.
	UIKit.animate_in($VBoxContainer.get_children(), 0.06)

	# Signature moment: a droplet periodically beads off the logo and falls.
	var drip_timer := Timer.new()
	drip_timer.one_shot = false
	drip_timer.wait_time = 3.4
	drip_timer.timeout.connect(_spawn_logo_drip.bind(drip_timer))
	add_child(drip_timer)
	drip_timer.start()

func _spawn_logo_drip(timer: Timer) -> void:
	timer.wait_time = randf_range(2.8, 5.2)
	var title: Label = $VBoxContainer/TitleLabel
	var dr := UIKit.icon(UIKit.ICON_DROPLET, 26, Color(0.55, 0.85, 1.0, 0.95))
	add_child(dr)
	var start := title.global_position + Vector2(title.size.x * randf_range(0.25, 0.75), title.size.y - 8.0)
	dr.global_position = start
	dr.pivot_offset = Vector2(13, 13)
	dr.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(dr, "scale", Vector2(1, 1), 0.7).set_ease(Tween.EASE_OUT) # beads up
	tw.tween_property(dr, "global_position:y", start.y + 130.0, 0.55).set_ease(Tween.EASE_IN) # lets go
	tw.parallel().tween_property(dr, "modulate:a", 0.0, 0.55).set_delay(0.25)
	tw.tween_callback(dr.queue_free)

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
