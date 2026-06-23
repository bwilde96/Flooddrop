extends Node

enum ForceDropType {
	NONE = -1,
	NORMAL = 0,
	DRAIN = 1,
	FREEZE = 2,
	BOMB = 3,
	SHIELD = 4,
	RAINBOW = 5,
	GOLD = 6,
	METEOR = 7,
	ACID = 8,
	NEUTRALIZER = 9
}

@export_group("Debug Tools")
@export var force_drop_type: ForceDropType = ForceDropType.NONE

@export_group("Difficulty Tuning: Spawning")
@export var grace_period: float = 1.5          
@export var base_spawn_interval: float = 1.0   
@export var min_spawn_interval: float = 0.25   
@export var spawn_ramp_speed: float = 0.01     

@export_group("Difficulty Tuning: Drop Speed")
@export var base_drop_speed: float = 300.0     
@export var max_drop_speed: float = 900.0      
@export var speed_ramp_speed: float = 8.0      

@export_group("Difficulty Tuning: Mechanics")
@export var flood_damage_per_miss: float = 18.0 
@export var flood_drain_rate: float = 3.0      
@export var max_flood: float = 100.0           
@export var flood_danger_threshold: float = 0.75 
@export var min_drop_distance_x: float = 140.0 

@export_group("Feel Tuning")
@export var screen_shake_strength: float = 15.0
@export var floating_text_duration: float = 0.8

@export_group("Power-ups: Spawn Rules")
@export var min_time_before_powerups: float = 5.0
@export var max_active_powerups: int = 2
@export var power_up_spawn_chance_start: float = 0.05
@export var power_up_spawn_chance_max: float = 0.15
@export var power_up_spawn_ramp: float = 0.001

@export_group("Power-ups: Weights")
@export var weight_drain: float = 10.0
@export var weight_freeze: float = 8.0
@export var weight_bomb: float = 8.0
@export var weight_shield: float = 5.0
@export var weight_rainbow: float = 2.0

@export_group("Power-ups: Stats")
@export var drain_amount: float = 30.0
@export var freeze_duration: float = 5.0
@export var freeze_slow_multiplier: float = 0.4
@export var freeze_affects_spawning: bool = true
@export var freeze_affects_difficulty_ramp: bool = true
@export var post_freeze_spawn_grace: float = 0.5
@export var bomb_radius: float = 2000.0
@export var shield_charges_per_pickup: int = 3
@export var rainbow_bonus_score: int = 50
@export var rainbow_flood_reduction: float = 15.0

var current_spawn_interval: float
var current_drop_speed: float
var current_flood: float = 0.0
var spawn_timer: float = 0.0
var last_spawn_x: float = -1000.0
var next_available_fall_time: float = 0.0

var current_streak: float = 0.0
var current_multiplier: int = 1
var multiplier_label: Label
var multiplier_bar: ColorRect
var multiplier_container: Control

var multiplier_color_map = {
	1: Color(1.0, 1.0, 1.0),
	2: Color(0.3, 0.8, 1.0),
	3: Color(0.8, 0.3, 1.0),
	4: Color(1.0, 0.8, 0.2),
	5: Color(1.0, 0.3, 0.3)
}

var current_power_up_chance: float = 0.0
var freeze_timer: float = 0.0
var shield_charges: int = 0

var active_ability: String = "time_warp"
var ability_cooldown: float = 0.0
var ability_cooldown_max: float = 30.0
var ability_progress: TextureProgressBar
var ability_container: Control
var ability_icon_rect: TextureRect
var is_ability_ready: bool = true
var is_midas_active: bool = false
var midas_timer: float = 0.0
var midas_overlay: ColorRect
var midas_particles: CPUParticles2D

var is_turret_active: bool = false
var turret_timer: float = 0.0
var laser_line: Line2D
var laser_timer: float = 0.0

var evaporation_particles: CPUParticles2D

var is_tidal_wave_active: bool = false
var tidal_wave_y: float = 1280.0

var owned_passives: Array = []

func get_screen_top() -> float:
	return (get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO).y

func get_screen_bottom() -> float:
	return (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect().size).y
var tidal_wave_rect: ColorRect
var tidal_wave_particles: CPUParticles2D

var active_event: String = ""
var event_timer: float = 0.0
var event_overlay: ColorRect = null
var event_label: Label = null
var event_tween: Tween = null
var blackout_rect: ColorRect = null
var eruption_particles: CPUParticles2D = null
var event_triggered_for_level: bool = false
var next_chaos_event: float = 0.0

var current_level_index: int = 0
var levels = [
	{"time": 0.0, "theme": "water"},
	{"time": 30.0, "theme": "slime"},
	{"time": 60.0, "theme": "lava"},
	{"time": 90.0, "theme": "acid"},
	{"time": 120.0, "theme": "gold"},
	{"time": 150.0, "theme": "rainbow"},
	{"time": 180.0, "theme": "neon_plasma"},
	{"time": 210.0, "theme": "galaxy"}
]

var is_playing: bool = false
var drop_scene: PackedScene = preload("res://scenes/Drop.tscn")
var floating_text_scene: PackedScene = preload("res://scenes/FloatingText.tscn")
var particle_scene: PackedScene = preload("res://scenes/PopParticles.tscn")
var pool_manager: PoolManager

@onready var drop_container: Node2D = $DropContainer
@onready var flood_rect: ColorRect = $FloodRect
@onready var score_label: Label = $HUD/GameUI/MarginContainer/HBox/ScoreLabel
@onready var high_score_label: Label = $HUD/GameUI/MarginContainer/HBox/HighScoreLabel
@onready var danger_label: Label = $HUD/GameUI/CenterContainer/VBoxContainer/DangerLabel
@onready var level_up_label: Label = $HUD/GameUI/CenterContainer/VBoxContainer/LevelUpLabel
@onready var debug_panel: PanelContainer = $HUD/DebugPanel
@onready var debug_label: Label = $HUD/DebugPanel/Margin/DebugLabel
@onready var camera: Camera2D = $Camera2D

@onready var pause_menu: Control = $HUD/PauseMenu
@onready var game_ui: Control = $HUD/GameUI
@onready var pause_btn: Button = $HUD/GameUI/PauseButtonContainer/PauseButton

@onready var freeze_overlay: ColorRect = $HUD/GameUI/FreezeOverlay
@onready var shield_icon: ColorRect = $HUD/GameUI/ShieldsContainer/ShieldIcon
@onready var shield_count_label: Label = $HUD/GameUI/ShieldsContainer/ShieldCountLabel

var freeze_particles: CPUParticles2D
var shake_intensity: float = 0.0

func _increment_streak(amount: float = 1.0) -> void:
	if "streak_accelerator" in owned_passives:
		amount *= 1.25
		
	current_streak += amount
	var old_mult = current_multiplier
	var target_progress = 0.0
	
	if current_streak >= 100:
		current_multiplier = 5
		target_progress = 1.0
	elif current_streak >= 50:
		current_multiplier = 4
		target_progress = float(current_streak - 50) / 50.0
	elif current_streak >= 25:
		current_multiplier = 3
		target_progress = float(current_streak - 25) / 25.0
	elif current_streak >= 10:
		current_multiplier = 2
		target_progress = float(current_streak - 10) / 15.0
	else:
		current_multiplier = 1
		target_progress = float(current_streak) / 10.0
		
	if multiplier_bar and multiplier_bar.material:
		var mat = multiplier_bar.material as ShaderMaterial
		var tw = create_tween()
		tw.tween_method(func(v): mat.set_shader_parameter("progress", v), mat.get_shader_parameter("progress"), target_progress, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		
	if current_multiplier > old_mult:
		_trigger_multiplier_level_up()
	else:
		_pulse_multiplier_ui()

func _reset_streak() -> void:
	if current_streak == 0.0: return
	current_streak = 0.0
	current_multiplier = 1
	
	if multiplier_label:
		multiplier_label.text = "1x"
		multiplier_label.add_theme_color_override("font_color", multiplier_color_map[1])
	if multiplier_bar and multiplier_bar.material:
		var mat = multiplier_bar.material as ShaderMaterial
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("fg_color", multiplier_color_map[1])
		_pulse_multiplier_ui()

func _trigger_multiplier_level_up() -> void:
	AudioManager.play_sfx("power_up")
	var m_color = multiplier_color_map[current_multiplier]
	multiplier_label.text = "%dx" % current_multiplier
	multiplier_label.add_theme_color_override("font_color", m_color)
	
	var mat = multiplier_bar.material as ShaderMaterial
	mat.set_shader_parameter("fg_color", m_color)
	
	multiplier_container.scale = Vector2(1.5, 1.5)
	var tw = create_tween()
	tw.tween_property(multiplier_container, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_spawn_particle(multiplier_container.global_position + Vector2(100, 50), m_color, false, true)

func _pulse_multiplier_ui() -> void:
	if not multiplier_container: return
	multiplier_container.scale = Vector2(1.1, 1.1)
	var tw = create_tween()
	tw.tween_property(multiplier_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	current_spawn_interval = base_spawn_interval
	current_drop_speed = base_drop_speed
	GameManager.score = 0
	GameManager.survival_time = 0.0
	_setup_glow()
	BackgroundManager.update_background(levels[current_level_index].theme, levels[current_level_index].theme)

	freeze_timer = 0.0
	shield_charges = 0
	current_power_up_chance = power_up_spawn_chance_start
	
	pool_manager = PoolManager.new()
	add_child(pool_manager)
	pool_manager.init(drop_scene, floating_text_scene, particle_scene, drop_container)
	
	get_tree().set_quit_on_go_back(false)
	
	pause_btn.pressed.connect(func():
		AudioManager.play_sfx("button")
		_toggle_pause()
	)
	$HUD/PauseMenu/VBox/ResumeButton.pressed.connect(func():
		AudioManager.play_sfx("button")
		_toggle_pause()
	)
	$HUD/PauseMenu/VBox/RestartButton.pressed.connect(func(): 
		AudioManager.play_sfx("button")
		get_tree().paused = false
		GameManager.start_game()
	)
	
	active_ability = SaveManager.get_value("equipped_ability", "time_warp")
	_setup_ability_ui()
	
	owned_passives = SaveManager.get_value("owned_passives", [])
	if "mini_turret" in owned_passives or active_ability == "auto_turret":
		_setup_turret()
		if not ("mini_turret" in owned_passives):
			turret_base.visible = false
		
	var ups = SaveManager.get_value("upgrades", {})
	shield_charges = ups.get("shield_capacity", 1) - 1 # Level 1 = 0 extra charges
	_update_powerup_hud()
	
	update_debug_ui()
	
	is_playing = true
	_trigger_level_up() # Start Level 1
	
	$HUD/PauseMenu/VBox/MenuButton.pressed.connect(func(): 
		AudioManager.play_sfx("button")
		get_tree().paused = false
		GameManager.goto_main_menu()
	)
	
	# Setup Multiplier UI dynamically
	var score_margin = game_ui.get_node("MarginContainer")
	var hbox = score_margin.get_node("HBox")
	
	var ui_vbox = VBoxContainer.new()
	ui_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_vbox.add_theme_constant_override("separation", 10)
	
	score_margin.remove_child(hbox)
	score_margin.add_child(ui_vbox)
	ui_vbox.add_child(hbox)
	
	multiplier_container = Control.new()
	multiplier_container.custom_minimum_size = Vector2(198, 108)
	multiplier_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	multiplier_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_vbox.add_child(multiplier_container)
	
	var dev_panel = get_node_or_null("HUD/DebugPanel")
	if dev_panel:
		dev_panel.position.y += 120
	
	var arc_shader = Shader.new()
	arc_shader.code = """
	shader_type canvas_item;
	uniform float progress : hint_range(0.0, 1.0) = 0.5;
	uniform vec4 bg_color : source_color = vec4(0.1, 0.1, 0.1, 0.5);
	uniform vec4 fg_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
	uniform float thickness = 0.22;

	void fragment() {
		vec2 pos = vec2(UV.x * 2.2 - 1.1, UV.y * 1.2 - 1.1);
		float r = 1.0 - thickness * 0.5;
		float d = length(pos);
		float a = atan(pos.y, pos.x);
		
		float dist_to_arc = abs(d - r);
		vec2 left_cap = vec2(-r, 0.0);
		vec2 right_cap = vec2(r, 0.0);
		
		float final_dist = 0.0;
		if (pos.y > 0.0) {
			final_dist = min(length(pos - left_cap), length(pos - right_cap));
		} else {
			final_dist = dist_to_arc;
		}
		
		float alpha = 1.0 - smoothstep(thickness * 0.5 - 0.02, thickness * 0.5 + 0.01, final_dist);
		float target_angle = mix(-3.14159265, 0.0, progress);
		vec2 prog_point = vec2(r * cos(target_angle), r * sin(target_angle));
		
		float fill_alpha = 0.0;
		float prog_dist = length(pos - prog_point);
		
		if (pos.y > 0.0) {
			if (pos.x < 0.0) { fill_alpha = smoothstep(0.0, 0.01, progress); }
			else { fill_alpha = smoothstep(0.99, 1.0, progress); }
		} else {
			if (a <= target_angle) { fill_alpha = 1.0; }
			else { fill_alpha = 1.0 - smoothstep(thickness * 0.5 - 0.02, thickness * 0.5 + 0.01, prog_dist); }
		}
		
		float juicy = 1.0 - (final_dist / (thickness * 0.5));
		juicy = smoothstep(0.1, 1.0, juicy);
		
		vec4 base_c = mix(bg_color, fg_color, fill_alpha);
		vec4 final_color = base_c + (fg_color * juicy * fill_alpha * 0.9);
		
		float tip_glow = 1.0 - smoothstep(0.0, thickness * 1.5, prog_dist);
		final_color += fg_color * tip_glow * 1.2 * fill_alpha;
		
		COLOR = vec4(final_color.rgb, final_color.a * alpha);
	}
	"""
	var arc_mat = ShaderMaterial.new()
	arc_mat.shader = arc_shader
	arc_mat.set_shader_parameter("progress", 0.0)
	arc_mat.set_shader_parameter("fg_color", multiplier_color_map[1])
	
	multiplier_bar = ColorRect.new()
	multiplier_bar.material = arc_mat
	multiplier_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	multiplier_container.add_child(multiplier_bar)
	
	multiplier_label = Label.new()
	multiplier_label.text = "1x"
	multiplier_label.add_theme_font_size_override("font_size", 40)
	multiplier_label.add_theme_color_override("font_color", multiplier_color_map[1])
	multiplier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiplier_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	multiplier_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	multiplier_label.offset_bottom = -10
	multiplier_container.add_child(multiplier_label)
	
	debug_panel.visible = OS.has_feature("editor")


	
	evaporation_particles = CPUParticles2D.new()
	evaporation_particles.emitting = false
	evaporation_particles.one_shot = true
	evaporation_particles.amount = 400
	evaporation_particles.lifetime = 1.0
	evaporation_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	evaporation_particles.emission_rect_extents = Vector2(360, 50)
	evaporation_particles.position = Vector2(360, get_screen_bottom()) # Bottom of screen
	evaporation_particles.direction = Vector2(0, -1)
	evaporation_particles.spread = 10.0
	evaporation_particles.gravity = Vector2(0, -500)
	evaporation_particles.initial_velocity_min = 800.0
	evaporation_particles.initial_velocity_max = 1200.0
	evaporation_particles.scale_amount_min = 0.2
	evaporation_particles.scale_amount_max = 0.8
	evaporation_particles.color = Color(1.0, 1.0, 1.0, 0.8)
	add_child(evaporation_particles)
	
	tidal_wave_rect = ColorRect.new()
	tidal_wave_rect.color = Color(0.2, 0.6, 1.0, 0.7)
	tidal_wave_rect.size = Vector2(720, 1500) # Ensure it covers the whole screen bottom
	tidal_wave_rect.position = Vector2(0, get_screen_bottom())
	tidal_wave_rect.visible = false
	tidal_wave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tidal_wave_rect)
	
	tidal_wave_particles = CPUParticles2D.new()
	tidal_wave_particles.emitting = false
	tidal_wave_particles.amount = 300
	tidal_wave_particles.lifetime = 0.5
	tidal_wave_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	tidal_wave_particles.emission_rect_extents = Vector2(360, 10)
	tidal_wave_particles.position = Vector2(360, 0)
	tidal_wave_particles.direction = Vector2(0, -1)
	tidal_wave_particles.spread = 45.0
	tidal_wave_particles.initial_velocity_min = 200.0
	tidal_wave_particles.initial_velocity_max = 500.0
	tidal_wave_particles.scale_amount_min = 0.2
	tidal_wave_particles.scale_amount_max = 0.5
	tidal_wave_particles.color = Color(0.8, 0.9, 1.0, 0.8)
	tidal_wave_rect.add_child(tidal_wave_particles)
	
	midas_overlay = ColorRect.new()
	midas_overlay.color = Color(1.0, 0.8, 0.2, 0.0)
	midas_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	midas_overlay.visible = false
	game_ui.add_child(midas_overlay)
	midas_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	midas_particles = CPUParticles2D.new()
	midas_particles.emitting = false
	midas_particles.one_shot = true
	midas_particles.amount = 150
	midas_particles.lifetime = 2.0
	midas_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	midas_particles.emission_rect_extents = Vector2(360, 600)
	midas_particles.position = Vector2(360, 600)
	midas_particles.direction = Vector2(0, 1)
	midas_particles.spread = 180.0
	midas_particles.gravity = Vector2(0, 150)
	midas_particles.initial_velocity_min = 50.0
	midas_particles.initial_velocity_max = 200.0
	midas_particles.scale_amount_min = 0.1
	midas_particles.scale_amount_max = 0.3
	midas_particles.color = Color(1.0, 0.9, 0.2, 0.8)
	add_child(midas_particles)
	
	freeze_particles = CPUParticles2D.new()
	freeze_particles.emitting = false
	freeze_particles.amount = 150
	freeze_particles.lifetime = 5.0
	freeze_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	freeze_particles.emission_rect_extents = Vector2(360, 600)
	freeze_particles.position = Vector2(360, 600)
	freeze_particles.direction = Vector2(0, 0)
	freeze_particles.spread = 180.0
	freeze_particles.gravity = Vector2(0, -10)
	freeze_particles.initial_velocity_min = 10.0
	freeze_particles.initial_velocity_max = 30.0
	freeze_particles.scale_amount_min = 0.1
	freeze_particles.scale_amount_max = 0.25
	freeze_particles.color = Color(0.6, 0.8, 1.0, 0.6)
	add_child(freeze_particles)
	
	event_overlay = ColorRect.new()
	event_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_overlay.modulate.a = 0.0
	game_ui.add_child(event_overlay)
	event_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var soft_tex = _create_soft_particle_texture()
	evaporation_particles.texture = soft_tex
	tidal_wave_particles.texture = soft_tex
	midas_particles.texture = soft_tex
	freeze_particles.texture = soft_tex
	event_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.move_child(event_overlay, 0)
	
	var blackout_rect_bg = ColorRect.new()
	blackout_rect_bg.color = Color(0.0, 0.0, 0.0, 0.98)
	blackout_rect_bg.size = Vector2(2500, 2500) # Huge size to cover aspect ratio expansion
	blackout_rect_bg.position = Vector2(-800, -600) # Centered over the camera
	blackout_rect_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout_rect_bg.modulate.a = 0.0
	blackout_rect_bg.z_index = 50 # Render OVER normal drops but UNDER rainbow drops!
	add_child(blackout_rect_bg)
	move_child(blackout_rect_bg, drop_container.get_index()) # Put behind drops, but over flood
	blackout_rect = blackout_rect_bg
	
	eruption_particles = CPUParticles2D.new()
	eruption_particles.emitting = false
	eruption_particles.amount = 80
	eruption_particles.lifetime = 2.5
	eruption_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	eruption_particles.emission_rect_extents = Vector2(360, 20)
	eruption_particles.position = Vector2(360, get_screen_bottom() + 20.0) # Bottom of screen
	eruption_particles.direction = Vector2(0, -1)
	eruption_particles.spread = 15.0
	eruption_particles.initial_velocity_min = 800.0
	eruption_particles.initial_velocity_max = 1400.0
	eruption_particles.scale_amount_min = 5.0
	eruption_particles.scale_amount_max = 20.0
	eruption_particles.color = Color(1.0, 0.4, 0.0, 0.8)
	add_child(eruption_particles)
	move_child(eruption_particles, drop_container.get_index())
	
	var event_center = CenterContainer.new()
	event_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(event_center)
	event_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	event_label = Label.new()
	event_label.text = ""
	event_label.add_theme_font_size_override("font_size", 54)
	event_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	event_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	event_label.add_theme_constant_override("outline_size", 12)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.custom_minimum_size = Vector2(720, 300)
	event_label.pivot_offset = Vector2(360, 150) # Scale perfectly from true center of the screen
	event_label.modulate.a = 0.0
	event_center.add_child(event_label)
	
	current_level_index = 0
	ThemeManager.equip_theme(levels[0].theme)

func _setup_glow() -> void:
	# Bloom on the bright neon/liquid highlights — the single biggest quality lift.
	# Shaders clamp to 1.0, so a sub-1.0 HDR threshold blooms the brightest areas.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.75
	env.glow_hdr_scale = 2.0
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _create_soft_particle_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 1))
	grad.add_point(1.0, Color(1, 1, 1, 0))
	tex.gradient = grad
	return tex

func _create_ring_texture(base_radius: int, base_thickness: int, color: Color, is_glow: bool = false) -> ImageTexture:
	var scale_factor = 2
	var r = base_radius * scale_factor
	var t = base_thickness * scale_factor
	var img = Image.create_empty(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	var center = Vector2(r, r)
	var r_outer = float(r)
	var r_inner = float(r - t)
	
	for y in range(r * 2):
		for x in range(r * 2):
			var dist = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha_mult = 0.0
			
			if is_glow:
				var center_radius = (r_outer + r_inner) / 2.0
				var tube_width = float(t) / 2.0
				var dist_from_center = abs(dist - center_radius)
				if dist_from_center < tube_width:
					var normalized_dist = dist_from_center / tube_width
					alpha_mult = pow(1.0 - normalized_dist, 1.2)
			else:
				if dist <= r_outer and dist >= r_inner:
					alpha_mult = 1.0
				elif dist > r_outer and dist < r_outer + 2.0:
					alpha_mult = max(0.0, 1.0 - (dist - r_outer) / 2.0)
				elif dist < r_inner and dist > r_inner - 2.0:
					alpha_mult = max(0.0, 1.0 - (r_inner - dist) / 2.0)
				
			if alpha_mult > 0.0:
				var c = color
				c.a *= alpha_mult
				if is_glow and alpha_mult > 0.7:
					c = c.lerp(Color.WHITE, min(1.0, (alpha_mult - 0.7) * 3.3))
				img.set_pixel(x, y, c)
				
	return ImageTexture.create_from_image(img)

func _setup_ability_ui() -> void:
	if active_ability == "none": return
	
	ability_container = Control.new()
	ability_container.custom_minimum_size = Vector2(120, 120)
	ability_container.size = Vector2(120, 120)
	game_ui.add_child(ability_container)
	ability_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ability_container.position = Vector2(game_ui.size.x - 150, game_ui.size.y - 150)
	ability_container.pivot_offset = Vector2(60, 60)
	
	var icon_path = "res://assets/icons/icon_%s.jpg" % active_ability
	var icon_tex = null
	
	if ResourceLoader.exists(icon_path):
		icon_tex = load(icon_path)
		
	if icon_tex == null:
		var img = Image.new()
		if img.load(icon_path) == OK:
			icon_tex = ImageTexture.create_from_image(img)
			
	ability_icon_rect = TextureRect.new()
	if icon_tex != null:
		ability_icon_rect.texture = icon_tex
		
	ability_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ability_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ability_icon_rect.custom_minimum_size = Vector2(120, 120)
	ability_icon_rect.size = Vector2(120, 120)
	ability_icon_rect.position = Vector2(0, 0)
	ability_icon_rect.pivot_offset = Vector2(60, 60)
	
	if active_ability == "evaporation":
		ability_icon_rect.position = Vector2(-2, 4) # Adjust slight off-center visual from image
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ability_icon_rect.material = mat
	
	ability_container.add_child(ability_icon_rect)
	
	ability_progress = TextureProgressBar.new()
	ability_progress.texture_under = _create_ring_texture(60, 12, Color(0.0, 0.0, 0.0, 0.8), false)
	ability_progress.texture_progress = _create_ring_texture(60, 12, Color(0.0, 1.0, 0.9, 1.0), true)
	ability_progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ability_progress.step = 0.01
	ability_progress.max_value = ability_cooldown_max
	ability_progress.value = ability_cooldown_max
	ability_progress.position = Vector2(0, 0)
	ability_progress.scale = Vector2(0.5, 0.5)
	ability_container.add_child(ability_progress)
	
	var btn = Button.new()
	btn.text = "USE"
	btn.custom_minimum_size = Vector2(120, 120)
	btn.size = Vector2(120, 120)
	btn.modulate.a = 0.0
	ability_container.add_child(btn)
	btn.pressed.connect(_use_ability)
	
	var t = ThemeManager.get_equipped_theme()
	flood_rect.material.set_shader_parameter("top_color", t.drop_color)
	flood_rect.material.set_shader_parameter("bottom_color", t.flood_color)
	flood_rect.material.set_shader_parameter("liquid_type", t.get("shader_type", 0))

func _trigger_ability_ready_animation() -> void:
	is_ability_ready = true
	AudioManager.play_sfx("power_up")
	if not ability_icon_rect or not ability_container: return
	ability_icon_rect.modulate = Color(2.0, 2.0, 2.0, 1.0) # Flash bright white
	var tw = create_tween()
	tw.tween_property(ability_icon_rect, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	
	ability_container.scale = Vector2(1.5, 1.5)
	var tw2 = create_tween()
	tw2.tween_property(ability_container, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	_spawn_particle(ability_container.global_position + Vector2(60, 60), Color(0.2, 1.0, 0.8), false, true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			var target_level = event.keycode - KEY_1
			if target_level < levels.size():
				GameManager.survival_time = levels[target_level].time
				current_level_index = target_level
				_trigger_level_up()

func _toggle_pause() -> void:
	if not is_playing: return
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused
	game_ui.visible = !is_paused

func get_freeze_multiplier() -> float:
	return freeze_slow_multiplier if freeze_timer > 0 else 1.0

func _process(delta: float) -> void:
	if turret_base and turret_base.visible:
		_process_turret(delta)
		
	if get_tree().paused: return
	
	if is_turret_active:
		turret_timer -= delta
		if turret_timer <= 0:
			is_turret_active = false
			if not ("mini_turret" in owned_passives) and turret_base:
				turret_base.visible = false
	
	if is_playing and not get_tree().paused:
		GameManager.survival_time += delta
		
		# Check level up
		if current_level_index < levels.size() - 1:
			if GameManager.survival_time >= levels[current_level_index + 1].time:
				current_level_index += 1
				_trigger_level_up()
				
		if not event_triggered_for_level and GameManager.survival_time >= levels[current_level_index].time + 15.0:
			_trigger_event_for_current_level()
			event_triggered_for_level = true
			
		if event_timer > 0:
			event_timer -= delta
			if active_event == "chaos":
				next_chaos_event -= delta
				if next_chaos_event <= 0:
					_trigger_chaos_event()
					var chaos_interval = max(5.0, 15.0 - ((GameManager.survival_time - 210.0) / 10.0))
					next_chaos_event = chaos_interval
			if event_timer <= 0 and active_event != "chaos":
				if current_level_index >= 7:
					active_event = "chaos"
					event_timer = 9999.0 # Restore endless loop
				else:
					active_event = ""
				event_overlay.modulate.a = 0.0
				blackout_rect.modulate.a = 0.0
				if eruption_particles: eruption_particles.emitting = false
				
		if active_event == "eruption" or active_event == "toxic" or active_event == "overdrive" or active_event == "prismatic":
			var pulse = (sin(Time.get_ticks_msec() / 150.0) * 0.5 + 0.5) * 0.3
			event_overlay.modulate.a = pulse
			if active_event == "prismatic" or active_event == "chaos_prismatic":
				var hue = fmod(Time.get_ticks_msec() / 2000.0, 1.0)
				event_overlay.color = Color.from_hsv(hue, 1.0, 1.0)
		elif event_timer <= 0:
			event_overlay.modulate.a = lerpf(event_overlay.modulate.a, 0.0, delta * 5.0)
			
		if not _illuminate_tween or not _illuminate_tween.is_valid():
			if active_event == "prismatic" or active_event == "chaos_prismatic":
				blackout_rect.modulate.a = lerpf(blackout_rect.modulate.a, 1.0, delta * 5.0)
			else:
				blackout_rect.modulate.a = lerpf(blackout_rect.modulate.a, 0.0, delta * 5.0)
			
		if active_event == "toxic":
			current_flood += 5.0 * delta # Survivable passive drain
			if current_flood >= max_flood:
				_on_drop_missed(0.0) # Trigger game over check
			_update_flood_visual_smooth(delta)
			
		var freeze_mult = get_freeze_multiplier()

		if freeze_timer > 0:
			freeze_timer -= delta
			freeze_overlay.modulate.a = 0.4 + sin(Time.get_ticks_msec() / 200.0) * 0.1 # Pulse
			if freeze_timer <= 0:
				freeze_overlay.visible = false
				freeze_particles.emitting = false
				spawn_timer = max(spawn_timer, post_freeze_spawn_grace)
	
		if shake_intensity > 0:
			camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
			shake_intensity = lerpf(shake_intensity, 0.0, 10.0 * delta)
			if shake_intensity < 0.1: 
				shake_intensity = 0.0
				camera.offset = Vector2.ZERO
		
		var ramp_mult = freeze_mult if freeze_affects_difficulty_ramp else 1.0
		current_spawn_interval = max(min_spawn_interval, current_spawn_interval - (spawn_ramp_speed * delta * ramp_mult))
		current_drop_speed = min(max_drop_speed, current_drop_speed + (speed_ramp_speed * delta * ramp_mult))
		
		# Infinite scaling for Cosmic Chaos (Level 8+)
		if current_level_index >= 7:
			var endless_time = max(0.0, GameManager.survival_time - 210.0)
			current_spawn_interval -= (0.05 * (endless_time / 180.0)) * delta * ramp_mult
			current_spawn_interval = max(0.05, current_spawn_interval) # Hard floor to prevent crashes
			current_drop_speed += (30.0 * (endless_time / 180.0)) * delta * ramp_mult
			
		current_power_up_chance = min(power_up_spawn_chance_max, current_power_up_chance + (power_up_spawn_ramp * delta * ramp_mult))
		
		if current_flood > 0:
			current_flood = max(0.0, current_flood - (flood_drain_rate * delta))
			_update_flood_visual_smooth(delta)
		
		var spawn_mult = freeze_mult if freeze_affects_spawning else 1.0
		
		# Time Warp Logic
		if is_midas_active:
			midas_overlay.visible = true
			midas_overlay.color.a = 0.15 + sin(Time.get_ticks_msec() / 150.0) * 0.05
			midas_timer -= delta
			if midas_timer <= 0:
				is_midas_active = false
				midas_overlay.visible = false
		
		if is_tidal_wave_active:
			tidal_wave_y -= delta * 1500.0
			tidal_wave_rect.position.y = tidal_wave_y
			shake_intensity = 15.0 # Continuous shake while wave is moving
			
			for d in drop_container.get_children():
				if d.has_method("pop") and "state" in d and "DropState" in d:
					if d.state == d.DropState.FALLING and d.position.y > tidal_wave_y:
						d.pop()
						
			if tidal_wave_y < -200:
				is_tidal_wave_active = false
				tidal_wave_rect.visible = false
				tidal_wave_particles.emitting = false
		
		# Turret timer logic moved to top of process
		
		if ability_cooldown < ability_cooldown_max:
			is_ability_ready = false
			ability_cooldown += delta
			if ability_progress: ability_progress.value = ability_cooldown
			if ability_icon_rect: ability_icon_rect.modulate = Color(0.8, 0.8, 0.8, 0.9)
			if ability_container: ability_container.scale = Vector2(1.0, 1.0)
			if ability_cooldown >= ability_cooldown_max:
				ability_cooldown = ability_cooldown_max
				if ability_progress: ability_progress.value = ability_cooldown_max
				_trigger_ability_ready_animation()
		else:
			if is_ability_ready and ability_container:
				var pulse = 1.0 + (sin(Time.get_ticks_msec() / 300.0) * 0.05)
				ability_container.scale = Vector2(pulse, pulse)
		
		spawn_timer -= (delta * spawn_mult)
		if spawn_timer <= 0:
			spawn_drop()
			
			var t = ThemeManager.get_equipped_theme()
			var theme_spawn_mult = t.get("spawn_interval_mult", 1.0)
			var ev = active_event
			if ev.begins_with("chaos_"): ev = ev.replace("chaos_", "")
			
			if ev == "overdrive":
				theme_spawn_mult *= 0.33 # 3x faster spawns
				
			spawn_timer = current_spawn_interval * theme_spawn_mult
			
	if debug_panel.visible:
		update_debug_ui()



func _use_ability() -> void:
	if not is_playing or get_tree().paused: return
	if ability_cooldown < ability_cooldown_max: return
	
	ability_cooldown = 0.0
	is_ability_ready = false
	if ability_progress: ability_progress.value = 0.0
	if ability_icon_rect: ability_icon_rect.modulate = Color(0.8, 0.8, 0.8, 0.9)
	if ability_container: ability_container.scale = Vector2(1.0, 1.0)
	
	AudioManager.play_sfx("power_up")
	
	if active_ability == "time_warp":
		freeze_timer = max(freeze_timer, 5.0) # Using existing freeze logic
		freeze_overlay.visible = true
		freeze_overlay.modulate = Color(0.3, 0.2, 1.0, 0.6) # Deep Indigo
		freeze_particles.emitting = true
		shake_intensity = 20.0 # Brief impact
		
		event_overlay.color = Color(0.8, 0.9, 1.0)
		event_overlay.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_property(event_overlay, "modulate:a", 0.0, 0.5)
	elif active_ability == "evaporation":
		evaporation_particles.position.y = get_screen_bottom() - current_flood * 5.0 # Emit exactly from top of flood
		var target_flood = max(0.0, current_flood - 30.0)
		var tw = create_tween()
		tw.tween_property(self, "current_flood", target_flood, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_method(_update_flood_visual_smooth_raw, current_flood, target_flood, 0.5)
		
		event_overlay.color = Color(1.0, 1.0, 1.0)
		event_overlay.modulate.a = 0.4
		var tw2 = create_tween()
		tw2.tween_property(event_overlay, "modulate:a", 0.0, 0.4)
		
		shake_intensity = 20.0
		evaporation_particles.emitting = true
		AudioManager.play_sfx("pop")
	elif active_ability == "tidal_wave":
		is_tidal_wave_active = true
		tidal_wave_y = get_screen_bottom()
		tidal_wave_rect.visible = true
		tidal_wave_particles.emitting = true
		shake_intensity = 40.0 # Huge initial impact
		event_overlay.color = Color(0.0, 0.4, 1.0)
		event_overlay.modulate.a = 0.8
		var tw = create_tween()
		tw.tween_property(event_overlay, "modulate:a", 0.0, 1.0)
	elif active_ability == "midas_touch":
		is_midas_active = true
		midas_timer = 8.0
		midas_particles.emitting = true
		for d in drop_container.get_children():
			if d.has_method("pop") and d.state == d.DropState.FALLING:
				d.type = d.DropType.GOLD
				_spawn_particle(d.position, Color(1.0, 0.9, 0.2))
	elif active_ability == "auto_turret":
		is_turret_active = true
		turret_timer = 4.0
		if turret_base:
			turret_base.visible = true

func _update_flood_visual_smooth_raw(val: float) -> void:
	if not flood_rect: return
	var p = val / max_flood
	var target_h = p * (get_screen_bottom() - get_screen_top() + 150)
	flood_rect.size.y = target_h
	flood_rect.position.y = get_screen_bottom() - target_h
	flood_rect.material.set_shader_parameter("water_height", target_h)

func _trigger_level_up() -> void:
	var new_level = levels[current_level_index]
	ThemeManager.equip_theme(new_level.theme)
	var t = ThemeManager.get_theme(new_level.theme)

	event_triggered_for_level = false
	if active_event != "chaos":
		active_event = ""
		event_timer = 0.0

	var is_first = (current_level_index == 0)

	# --- Bold "new environment" reveal ---
	level_up_label.text = "LEVEL %d\n%s" % [current_level_index + 1, t.name.to_upper()]
	level_up_label.add_theme_font_size_override("font_size", 60)
	level_up_label.add_theme_color_override("font_color", t.drop_color.lightened(0.3))
	level_up_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	level_up_label.add_theme_constant_override("outline_size", 14)
	level_up_label.pivot_offset = level_up_label.size / 2.0
	level_up_label.scale = Vector2(0.4, 0.4)
	level_up_label.modulate = Color(2.0, 2.0, 2.0, 0.0) # Bright + invisible to start

	var tween = create_tween()
	tween.tween_property(level_up_label, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.25)
	tween.parallel().tween_property(level_up_label, "scale", Vector2(1.15, 1.15), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(level_up_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_interval(1.4)
	tween.tween_property(level_up_label, "modulate:a", 0.0, 0.6)

	var old_theme = levels[max(0, current_level_index - 1)].theme
	BackgroundManager.update_background(old_theme, levels[current_level_index].theme)
	var pool_tween = create_tween()
	pool_tween.tween_property(flood_rect.material, "shader_parameter/top_color", t.drop_color, 2.0)
	pool_tween.tween_property(flood_rect.material, "shader_parameter/bottom_color", t.flood_color, 2.0)
	flood_rect.material.set_shader_parameter("liquid_type", t.get("shader_type", 0))

	if is_first:
		AudioManager.play_sfx("power_up")
		return

	# --- Celebration: reaching a new depth should feel like an event ---
	AudioManager.play_sfx("rainbow")
	AudioManager.vibrate("rainbow")
	shake_intensity = screen_shake_strength * 1.5
	trigger_hit_pause(0.06)

	# Theme-coloured screen flash
	event_overlay.color = t.drop_color
	event_overlay.modulate.a = 0.55
	var flash = create_tween()
	flash.tween_property(event_overlay, "modulate:a", 0.0, 0.6)

	# Burst of light at the centre + a tangible "you went deeper" reward
	var cx = get_viewport().get_visible_rect().size.x / 2.0
	var center = Vector2(cx, (get_screen_top() + get_screen_bottom()) / 2.0)
	_spawn_particle(center, t.drop_color, false, true)
	var depth_bonus = current_level_index * 250
	GameManager.score += depth_bonus
	_spawn_floating_text("NEW DEPTH!  +%d" % depth_bonus, center + Vector2(0, 90), t.drop_color.lightened(0.4))
	update_hud()

func _start_event(title: String, duration: float, internal_name: String, color: Color = Color.WHITE) -> void:
	active_event = internal_name
	event_timer = duration
	shake_intensity = screen_shake_strength * 2.0 # Big shake on start
	
	if active_event == "eruption": event_overlay.color = Color(1.0, 0.2, 0.0)
	elif active_event == "toxic": event_overlay.color = Color(0.5, 1.0, 0.0)
	elif active_event == "overdrive": event_overlay.color = Color(0.1, 1.0, 0.8)
	elif active_event == "prismatic": event_overlay.color = Color(1.0, 1.0, 1.0)
	
	event_label.text = title
	event_label.add_theme_color_override("font_color", color)
	
	var current_screen_width = get_viewport().get_visible_rect().size.x
	event_label.custom_minimum_size = Vector2(current_screen_width, 300)
	event_label.pivot_offset = Vector2(current_screen_width / 2.0, 150)
	
	if event_tween and event_tween.is_valid():
		event_tween.kill()
	
	event_tween = create_tween()
	event_tween.tween_property(event_label, "modulate:a", 1.0, 0.2)
	event_tween.tween_property(event_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	event_tween.tween_property(event_label, "scale", Vector2(1.0, 1.0), 0.2)
	event_tween.tween_property(event_label, "modulate:a", 0.0, 0.5).set_delay(2.0)
	
	AudioManager.play_sfx("power_up") # Could be a new siren sound later

func _trigger_event_for_current_level() -> void:
	var level = current_level_index
	if level == 1:
		_start_event("SLIME METEOR!", 1.0, "meteor", Color(0.2, 1.0, 0.2))
		var old_force = force_drop_type
		force_drop_type = ForceDropType.METEOR
		spawn_drop()
		force_drop_type = old_force
	elif level == 2:
		_start_event("VOLCANIC ERUPTION!", 7.0, "eruption", Color(1.0, 0.4, 0.1))
		if eruption_particles: eruption_particles.emitting = true
	elif level == 3:
		_start_event("CORROSIVE CORE!", 15.0, "toxic", Color(0.8, 1.0, 0.1))
		var old_force = force_drop_type
		force_drop_type = ForceDropType.NEUTRALIZER
		spawn_drop() # Spawn Neutralizer immediately
		force_drop_type = old_force
	elif level == 4:
		_start_event("GOLDEN PINATA!", 15.0, "midas", Color(1.0, 0.9, 0.2))
		var old_force = force_drop_type
		force_drop_type = ForceDropType.GOLD
		spawn_drop() # Spawn Piñata
		force_drop_type = old_force
	elif level == 5:
		_start_event("BLACKOUT!", 10.0, "prismatic", Color(0.3, 0.3, 0.3))
		var old_force = force_drop_type
		force_drop_type = ForceDropType.RAINBOW
		spawn_drop() # Spawn a Rainbow drop immediately so the player isn't stuck in the dark
		force_drop_type = old_force
	elif level == 6:
		_start_event("CYBER GLITCH!", 12.0, "overdrive", Color(0.1, 1.0, 0.8))
	elif level == 7:
		_start_event("COSMIC CHAOS!", 9999.0, "chaos", Color(0.8, 0.4, 1.0))
		next_chaos_event = 5.0

func _trigger_chaos_event() -> void:
	var events = ["meteor", "eruption", "toxic", "midas", "prismatic", "overdrive"]
	var e = events[randi() % events.size()]
	match e:
		"meteor":
			_start_event("SLIME METEOR!", 1.0, "chaos", Color(0.2, 1.0, 0.2))
			var old_force = force_drop_type
			force_drop_type = ForceDropType.METEOR
			spawn_drop()
			force_drop_type = old_force
		"eruption": _start_event("ERUPTION!", 7.0, "chaos_eruption", Color(1.0, 0.4, 0.1))
		"toxic": _start_event("TOXIC SURGE!", 10.0, "chaos_toxic", Color(0.8, 1.0, 0.1))
		"midas": _start_event("MIDAS RUSH!", 7.0, "chaos_midas", Color(1.0, 0.9, 0.2))
		"prismatic": 
			_start_event("PRISMATIC STORM!", 5.0, "chaos_prismatic", Color(1.0, 0.5, 1.0))
			var old_force = force_drop_type
			force_drop_type = ForceDropType.RAINBOW
			spawn_drop() # Provide an immediate light source in chaos
			force_drop_type = old_force
		"overdrive": _start_event("NEON OVERDRIVE!", 8.0, "chaos_overdrive", Color(0.1, 1.0, 0.8))

func _count_active_powerups() -> int:
	var count = 0
	for d in drop_container.get_children():
		if d.has_method("pop") and d.state != d.DropState.INACTIVE and d.state != d.DropState.POPPING and d.type != d.DropType.NORMAL:
			count += 1
	return count

var rainbow_spawn_counter: int = 0
func spawn_drop(is_cluster_child: bool = false) -> void:
	if pool_manager == null: return
	
	var ev = active_event.replace("chaos_", "")
	var is_eruption = (ev == "eruption")
	
	# Eruption cluster spawning
	if is_eruption and not is_cluster_child:
		if randf() > 0.5: # 50% chance to spawn an extra drop instead of guaranteed 1-2 extras
			spawn_drop(true)
			
	var safe_left = 60.0
	var safe_right = 660.0
	var drop = pool_manager.get_drop()
	
	var act_speed = current_drop_speed
	if ev == "eruption": act_speed = min(current_drop_speed * 1.5, 950.0)
	elif ev == "overdrive": act_speed = current_drop_speed * 0.6
	
	drop.gameplay_ref = self
	drop.fall_speed = act_speed
	drop.flood_damage = flood_damage_per_miss
	
	# Determine drop type
	var chosen_type = drop.DropType.NORMAL
	
	if is_midas_active:
		chosen_type = drop.DropType.GOLD
	elif force_drop_type != ForceDropType.NONE:
		chosen_type = force_drop_type as int
	elif ev == "toxic":
		var roll = randf()
		if roll < 0.25:
			chosen_type = drop.DropType.NEUTRALIZER
		elif roll < 0.55:
			chosen_type = drop.DropType.ACID
	elif ev == "prismatic":
		rainbow_spawn_counter += 1
		if randf() < 0.35 or rainbow_spawn_counter > 2:
			chosen_type = drop.DropType.RAINBOW # Rainbow drops light up the way
			rainbow_spawn_counter = 0
		else:
			chosen_type = drop.DropType.NORMAL # Normal drops are hidden in the dark!
	elif ev == "toxic":
		chosen_type = drop.DropType.NORMAL # Don't spawn powerups during Corrosive, just normal drops
	else:
		if GameManager.survival_time >= min_time_before_powerups:
			if _count_active_powerups() < max_active_powerups:
				if randf() < current_power_up_chance:
					chosen_type = _pick_random_powerup()
					
	drop.type = chosen_type
	if drop.has_method("apply_stats"):
		drop.apply_stats()
	drop.queue_redraw()
	
	var x_pos = randf_range(safe_left, safe_right)
	
	if abs(x_pos - last_spawn_x) < min_drop_distance_x:
		x_pos += min_drop_distance_x
		if x_pos > safe_right:
			x_pos -= (min_drop_distance_x * 2.0)
			
	x_pos = clamp(x_pos, safe_left, safe_right)
	last_spawn_x = x_pos
	
	var spawn_y = get_screen_bottom() + 150.0 if is_eruption else get_screen_top() + 50.0
	
	# Spawn lower so formation animation is visible
	drop.position = Vector2(x_pos, spawn_y)
	
	if is_eruption:
		drop.fall_velocity = -1100.0 # Shoot up!
		drop.is_eruption = true
	else:
		drop.fall_velocity = act_speed
		drop.is_eruption = false
		
	if ev == "overdrive":
		drop.is_glitching = true
	else:
		drop.is_glitching = false
		
	if ev == "midas" and chosen_type == drop.DropType.GOLD:
		drop.is_pinata = true
		drop.bounce_velocity_x = randf_range(300.0, 500.0) * (1.0 if randf() > 0.5 else -1.0)
	else:
		drop.is_pinata = false
		
	var current_time = Time.get_ticks_msec() / 1000.0
	# Tighter, snappier formation: drops drip and fall quickly instead of hanging at the
	# ceiling for up to 3.5s (which read as sticky/unresponsive on the water level).
	var requested_formation = randf_range(0.45, 1.1)
	var proposed_fall_time = current_time + requested_formation
	
	if proposed_fall_time < next_available_fall_time:
		proposed_fall_time = next_available_fall_time
		requested_formation = proposed_fall_time - current_time
		
	next_available_fall_time = proposed_fall_time + 0.2 # Small gap between drops falling (was 0.35, felt over-metered)
	
	# Pass the exact formation duration to the drop
	drop.spawn_formation_duration = requested_formation
	
	if is_eruption:
		drop.spawn_formation_duration = 0.1 # Shoot up instantly!
		var travel_dist = (spawn_y - get_screen_top()) * randf_range(0.75, 0.95)
		drop.fall_velocity = -sqrt(2.0 * 1500.0 * travel_dist) # Dynamically calculate velocity to reach near the top!
	elif ev == "overdrive": 
		drop.spawn_formation_duration *= 0.5 # Form faster during overdrive
	
	drop.popped.connect(_on_drop_popped)
	drop.missed.connect(_on_drop_missed)

func spawn_specific_drop(pos: Vector2, t: int, scale_mult: float, initial_velocity_y: float = 0.0, custom_vel_x: float = 0.0) -> void:
	if pool_manager == null: return
	var drop = pool_manager.get_drop()
	drop.gameplay_ref = self
	
	if initial_velocity_y != 0.0:
		drop.fall_velocity = initial_velocity_y
		if drop.has_method("force_fall"):
			drop.force_fall()
	else:
		drop.fall_velocity = current_drop_speed
		
	drop.bounce_velocity_x = custom_vel_x
	drop.flood_damage = flood_damage_per_miss
	drop.type = t
	drop.custom_scale_mult = scale_mult # Apply scale before generating stats!
	
	if drop.has_method("apply_stats"):
		drop.apply_stats()
		
	drop.queue_redraw()
	drop.position = pos
	drop.spawn_formation_duration = 0.2
	
	drop.popped.connect(_on_drop_popped)
	drop.missed.connect(_on_drop_missed)

func _pick_random_powerup() -> int:
	var total_weight = weight_drain + weight_freeze + weight_bomb + weight_shield
	var roll = randf_range(0.0, total_weight)
	
	if roll < weight_drain: return 1 # DRAIN
	roll -= weight_drain
	if roll < weight_freeze: return 2 # FREEZE
	roll -= weight_freeze
	if roll < weight_bomb: return 3 # BOMB
	return 4 # SHIELD

func trigger_hit_pause(duration: float = 0.05) -> void:
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

func _on_drop_popped(drop_node: Area2D) -> void:
	var t = drop_node.type
	var pos = drop_node.position
	var base_score = int(drop_node.score_value * ThemeManager.get_equipped_theme().get("score_mult", 1.0))
	
	if "score_boost" in owned_passives:
		base_score += 2
		
	var is_juicy = false
	if "juicy_drops" in owned_passives and t == drop_node.DropType.NORMAL and randf() < 0.1:
		is_juicy = true
		base_score *= 2
	
	var has_toxic_immunity = "toxic_immunity" in owned_passives
	
	if t != drop_node.DropType.ACID or has_toxic_immunity:
		_increment_streak(2.0 if is_juicy else 1.0)
		
	if "chain_lightning" in owned_passives and randf() < 0.05:
		call_deferred("_trigger_chain_lightning", pos, 3)
		
	var mult = current_multiplier
	var mult_text = ""
	var m_color = multiplier_color_map.get(mult, Color(1,1,1))
	if mult > 1:
		mult_text = " x%d" % mult
		
	var final_score = base_score * mult
	var pitch = 1.0 + min(0.5, current_streak * 0.005)
	
	match t:
		drop_node.DropType.NORMAL:
			GameManager.score += final_score
			_spawn_floating_text("+%d%s" % [final_score, mult_text], pos, m_color)
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("pop", pitch)
			AudioManager.vibrate("pop")
		drop_node.DropType.GOLD:
			var gold_score = final_score * 5
			GameManager.score += gold_score
			_spawn_floating_text("+%d GOLD!%s" % [gold_score, mult_text], pos, m_color)
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("pop", pitch)
			AudioManager.vibrate("pop")
			shake_intensity = screen_shake_strength * 0.8
			trigger_hit_pause(0.04)
		drop_node.DropType.DRAIN:
			current_flood = max(0.0, current_flood - drain_amount)
			GameManager.score += final_score
			_spawn_floating_text("DRAIN!%s" % mult_text, pos, m_color)
			_update_flood_visual_smooth(0.0)
			_spawn_particle(pos, Color(0.2, 0.8, 0.2, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
			AudioManager.vibrate("pop")
		drop_node.DropType.FREEZE:
			freeze_timer = freeze_duration
			freeze_overlay.visible = true
			GameManager.score += final_score
			_spawn_floating_text("FREEZE!%s" % mult_text, pos, m_color)
			_spawn_particle(pos, Color(0.8, 0.95, 1.0, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
		drop_node.DropType.BOMB:
			_trigger_bomb(pos)
			GameManager.score += final_score
			_spawn_floating_text("BOOM!%s" % mult_text, pos, m_color)
			_spawn_particle(pos, Color(0.9, 0.2, 0.1, 1.0), true)
			AudioManager.play_sfx("bomb")
			AudioManager.vibrate("bomb")
			shake_intensity = screen_shake_strength * 2.5
			trigger_hit_pause(0.08)
		drop_node.DropType.SHIELD:
			shield_charges += shield_charges_per_pickup
			GameManager.score += final_score
			_spawn_floating_text("SHIELD x%d%s" % [shield_charges_per_pickup, mult_text], pos, m_color)
			_update_powerup_hud()
			_spawn_particle(pos, Color(0.4, 0.4, 0.9, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
		drop_node.DropType.RAINBOW:
			var rb_score = rainbow_bonus_score * mult
			GameManager.score += rb_score
			current_flood = max(0.0, current_flood - rainbow_flood_reduction)
			_spawn_floating_text("RAINBOW +%d%s" % [rb_score, mult_text], pos, m_color)
			_update_flood_visual_smooth(0.0)
			_spawn_particle(pos, Color.WHITE, false, true)
			AudioManager.play_sfx("rainbow")
			AudioManager.vibrate("rainbow")
			if active_event == "prismatic" or active_event == "chaos_prismatic":
				illuminate_blackout()
		drop_node.DropType.METEOR:
			var m_score = final_score * 5
			GameManager.score += m_score
			_spawn_floating_text("+%d MASSIVE!%s" % [m_score, mult_text], pos, m_color)
			_spawn_particle(pos, drop_node.get_current_color(), true)
			AudioManager.play_sfx("bomb")
			AudioManager.vibrate("bomb")
			shake_intensity = screen_shake_strength * 3.0
			trigger_hit_pause(0.06)
		drop_node.DropType.NEUTRALIZER:
			current_flood = max(0.0, current_flood - 35.0)
			_spawn_floating_text("NEUTRALIZED!%s" % mult_text, pos, m_color)
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("power_up")
			_update_flood_visual_smooth(0.0)
		drop_node.DropType.ACID:
			var toxic_score = final_score * 5
			GameManager.score += toxic_score
			_spawn_floating_text("+%d TOXIC!%s" % [toxic_score, mult_text], pos, Color(0.8, 1.0, 0.1))
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("miss")
			_on_drop_missed(drop_node.flood_damage * 1.5, not has_toxic_immunity)
			
	update_hud()

func _trigger_bomb(center: Vector2) -> void:
	for child in drop_container.get_children():
		if child.has_method("pop_by_bomb") and child.state != child.DropState.INACTIVE and child.state != child.DropState.POPPING:
			if child.type == child.DropType.NORMAL:
				if child.position.distance_to(center) <= bomb_radius:
					child.pop_by_bomb()
					GameManager.score += child.score_value
					_spawn_floating_text("+%d" % child.score_value, child.position)

func _on_drop_missed(flood_value: float, break_streak: bool = true) -> void:
	if shield_charges > 0:
		shield_charges -= 1
		_update_powerup_hud()
		AudioManager.play_sfx("pop")
		AudioManager.vibrate("pop")
		return
		
	if break_streak:
		_reset_streak()
		
	current_flood += flood_value
	shake_intensity = screen_shake_strength
	trigger_hit_pause(0.05)
	
	AudioManager.play_sfx("miss")
	AudioManager.vibrate("miss")
	
	_update_flood_visual_smooth(0.0)
	update_hud()
	
	if current_flood >= max_flood:
		is_playing = false
		AudioManager.play_sfx("game_over")
		AudioManager.vibrate("game_over")
		GameManager.trigger_game_over()

func _spawn_floating_text(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var ft = pool_manager.get_floating_text()
	ft.duration = floating_text_duration
	ft.position = pos
	var lbl = ft.get_node("Label")
	lbl.text = text
	lbl.modulate = color
	ft.start_animation()

func _spawn_particle(pos: Vector2, col: Color, is_bomb: bool = false, is_rainbow: bool = false) -> void:
	var p = pool_manager.get_particle()
	p.position = pos
	p.play_effect(col, is_bomb, is_rainbow)

func update_hud() -> void:
	score_label.text = "Score: %d" % GameManager.score
	var hs = SaveManager.get_value("high_score", 0.0)
	high_score_label.text = "Best: %d" % int(hs)
	
	if current_flood > max_flood * flood_danger_threshold:
		danger_label.text = "DANGER!"
		if shake_intensity < screen_shake_strength * 0.3:
			shake_intensity = screen_shake_strength * 0.3
	else:
		danger_label.text = ""

func _update_powerup_hud() -> void:
	if shield_charges > 0:
		shield_icon.visible = true
		shield_count_label.visible = true
		shield_count_label.text = "Shields: %d" % shield_charges
	else:
		shield_icon.visible = false
		shield_count_label.visible = false

func update_debug_ui() -> void:
	var p_info = pool_manager.get_debug_info()
	debug_label.text = "DEBUG INFO\n" + \
		"Time: %.1fs\n" % GameManager.survival_time + \
		"Interval: %.2fs\n" % current_spawn_interval + \
		"Speed: %d px/s\n" % int(current_drop_speed) + \
		"Flood: %d%%\n\n" % int((current_flood / max_flood) * 100.0) + \
		"[Pool] Drops: %d act | %d av\n" % [p_info.active_drops, p_info.pooled_drops] + \
		"[Pool] Texts: %d act | %d av\n\n" % [p_info.active_texts, p_info.pooled_texts] + \
		"[Power] Chance: %.1f%%\n" % (current_power_up_chance * 100.0) + \
		"[Power] Freeze: %.1fs\n" % freeze_timer + \
		"[Power] Shields: %d\n" % shield_charges + \
		"Speed Mult: %.2fx\n" % get_freeze_multiplier() + \
		"Spawn Timer: %.2fs\n" % max(0.0, spawn_timer) + \
		"Active Drops: %d" % p_info.active_drops

func _update_flood_visual_instant() -> void:
	var screen_height = get_screen_bottom() - get_screen_top()
	var flood_ratio = current_flood / max_flood
	var target_height = flood_ratio * screen_height
	flood_rect.offset_top = -target_height
	flood_rect.offset_bottom = 0
	_update_flood_color(flood_ratio)

func _update_flood_visual_smooth(delta: float) -> void:
	var screen_height = get_screen_bottom() - get_screen_top()
	var flood_ratio = current_flood / max_flood
	var target_height = flood_ratio * screen_height
	
	if delta > 0:
		var curr_h = -flood_rect.offset_top
		curr_h = lerpf(curr_h, target_height, 5.0 * delta)
		flood_rect.offset_top = -curr_h
	else:
		flood_rect.offset_top = -target_height
		
	flood_rect.offset_bottom = 0
	_update_flood_color(flood_ratio)

func _update_flood_color(ratio: float) -> void:
	var t = ThemeManager.get_equipped_theme()
	var normal_color = t.get("flood_color", Color(0.19, 0.38, 0.84, 0.8))
	var danger_color = Color(0.8, 0.2, 0.2, 0.8)
	var final_color = normal_color
	if ratio >= flood_danger_threshold:
		var danger_ratio = (ratio - flood_danger_threshold) / (1.0 - flood_danger_threshold)
		final_color = normal_color.lerp(danger_color, danger_ratio)
	
	if flood_rect.material is ShaderMaterial:
		var top_c = final_color.lightened(0.2)
		top_c.a = 0.9
		var bot_c = final_color.darkened(0.2)
		bot_c.a = 0.95
		flood_rect.material.set_shader_parameter("top_color", top_c)
		flood_rect.material.set_shader_parameter("bottom_color", bot_c)
		flood_rect.material.set_shader_parameter("flood_height", flood_rect.size.y)
	else:
		flood_rect.color = final_color

var _illuminate_tween: Tween = null
func illuminate_blackout() -> void:
	if not blackout_rect: return
	if _illuminate_tween and _illuminate_tween.is_valid():
		_illuminate_tween.kill()
		
	# Hold at fully bright for 2 seconds, then slowly fade back to pitch black over 2 seconds
	blackout_rect.modulate.a = 0.0
	_illuminate_tween = create_tween()
	_illuminate_tween.tween_property(blackout_rect, "modulate:a", 1.0, 2.0).set_delay(2.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func _trigger_chain_lightning(start_pos: Vector2, remaining_jumps: int) -> void:
	if remaining_jumps <= 0: return
	
	var best_dist = 400.0
	var best_drop = null
	
	for child in drop_container.get_children():
		if child.has_method("pop_by_bomb") and child.state != child.DropState.INACTIVE and child.state != child.DropState.POPPING:
			var d = child.global_position.distance_to(start_pos)
			if d > 10.0 and d < best_dist:
				best_dist = d
				best_drop = child
				
	if best_drop:
		_draw_lightning(start_pos, best_drop.global_position)
		best_drop.pop_by_bomb()
		GameManager.score += best_drop.score_value
		_spawn_floating_text("+%d CHAIN!" % best_drop.score_value, best_drop.position, Color(0.2, 0.8, 1.0))
		AudioManager.play_sfx("pop", 1.5)
		
		get_tree().create_timer(0.15).timeout.connect(func():
			_trigger_chain_lightning(best_drop.global_position, remaining_jumps - 1)
		)

func _draw_lightning(from: Vector2, to: Vector2) -> void:
	var line = Line2D.new()
	line.default_color = Color(0.2, 0.8, 1.0, 0.8)
	line.width = 8.0
	line.add_point(from)
	
	var steps = 5
	var dist = from.distance_to(to)
	var dir = (to - from).normalized()
	for i in range(1, steps):
		var p = from + dir * (dist * float(i)/steps)
		p += Vector2(randf_range(-30, 30), randf_range(-30, 30))
		line.add_point(p)
		
	line.add_point(to)
	add_child(line)
	var tw = create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.3)
	tw.tween_callback(line.queue_free)

var turret_base: Node2D
var turret_barrel: Node2D
var laser_core: Line2D
var muzzle_flash: Sprite2D
var laser_impact_sprite: Sprite2D
var time_since_last_shot: float = 0.0

func _additive_material() -> CanvasItemMaterial:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _setup_turret() -> void:
	# Procedural neon turret. The generated turret art is opaque JPEG (no alpha) and
	# unusable as a sprite, so the body is drawn from primitives and the beam is procedural.
	var accent := Color(0.2, 0.9, 1.0) # neon cyan rim

	turret_base = Node2D.new()
	turret_base.position = Vector2(360, get_screen_bottom() - 150)
	turret_base.scale = Vector2(1.3, 1.3)
	turret_base.z_index = 8 # Render above the rising flood
	add_child(turret_base)

	# Base housing (trapezoid) + glowing rim.
	var base_body = Polygon2D.new()
	base_body.polygon = PackedVector2Array([Vector2(-46, 34), Vector2(46, 34), Vector2(34, -12), Vector2(-34, -12)])
	base_body.color = Color(0.10, 0.12, 0.16)
	turret_base.add_child(base_body)

	var rim = Line2D.new()
	rim.points = PackedVector2Array([Vector2(-46, 34), Vector2(-34, -12), Vector2(34, -12), Vector2(46, 34)])
	rim.width = 4.0
	rim.default_color = accent
	rim.material = _additive_material()
	turret_base.add_child(rim)

	# Rotating hub dome.
	var hub = Polygon2D.new()
	var hub_pts = PackedVector2Array()
	for i in range(18):
		var a = TAU * i / 18.0
		hub_pts.append(Vector2(cos(a), sin(a)) * 17.0 + Vector2(0, -12))
	hub.polygon = hub_pts
	hub.color = Color(0.16, 0.18, 0.22)
	turret_base.add_child(hub)

	# Barrel (rotates to aim). Points up (-Y) at rotation 0.
	turret_barrel = Node2D.new()
	turret_barrel.position = Vector2(0, -12)
	turret_base.add_child(turret_barrel)

	var barrel_body = Polygon2D.new()
	barrel_body.polygon = PackedVector2Array([Vector2(-10, 6), Vector2(10, 6), Vector2(8, -64), Vector2(-8, -64)])
	barrel_body.color = Color(0.14, 0.16, 0.20)
	turret_barrel.add_child(barrel_body)

	var barrel_glow = Line2D.new()
	barrel_glow.points = PackedVector2Array([Vector2(0, 2), Vector2(0, -62)])
	barrel_glow.width = 3.0
	barrel_glow.default_color = Color(1.0, 0.4, 0.3)
	barrel_glow.material = _additive_material()
	turret_barrel.add_child(barrel_glow)

	var muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(0, -64) # Barrel tip
	turret_barrel.add_child(muzzle)

	# Procedural glowing beam: wide soft-red glow + a warm bright core, both additive.
	laser_line = Line2D.new()
	laser_line.default_color = Color(1.0, 0.12, 0.06, 0.7)
	laser_line.width = 30.0
	laser_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.material = _additive_material()
	laser_line.visible = false
	add_child(laser_line)

	laser_core = Line2D.new()
	laser_core.default_color = Color(1.0, 0.55, 0.4, 1.0)
	laser_core.width = 8.0
	laser_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	laser_core.material = _additive_material()
	laser_core.visible = false
	add_child(laser_core)

	var soft = _create_soft_particle_texture()

	muzzle_flash = Sprite2D.new()
	muzzle_flash.texture = soft
	muzzle_flash.visible = false
	muzzle_flash.material = _additive_material()
	add_child(muzzle_flash)

	laser_impact_sprite = Sprite2D.new()
	laser_impact_sprite.texture = soft
	laser_impact_sprite.visible = false
	laser_impact_sprite.material = _additive_material()
	add_child(laser_impact_sprite)

func _process_turret(delta: float) -> void:
	if not turret_barrel or not is_playing: return

	time_since_last_shot += delta

	if laser_timer > 0:
		laser_timer -= delta
		if laser_timer <= 0:
			if laser_line: laser_line.visible = false
			if laser_core: laser_core.visible = false

	var target = null
	var best_d = 800.0

	for child in drop_container.get_children():
		if child.has_method("pop_by_bomb") and child.state == child.DropState.FALLING and not child.get("is_targeted_by_turret"):
			var d = child.global_position.distance_to(turret_base.global_position)
			if d < best_d and child.position.y < turret_base.global_position.y:
				best_d = d
				target = child

	if target:
		var dir = (target.global_position - turret_barrel.global_position).normalized()
		turret_barrel.rotation = dir.angle() + PI / 2.0

		var muzzle_pos = turret_barrel.get_node("Muzzle").global_position

		if is_turret_active:
			if time_since_last_shot > 0.05: # Rapid laser
				time_since_last_shot = 0.0
				target.set("is_targeted_by_turret", true)
				_fire_laser(muzzle_pos, target.global_position)
				laser_timer = 0.08
				AudioManager.play_sfx("button")
				target.pop_by_bomb()
				GameManager.score += target.score_value
				_spawn_floating_text("+%d LASER!" % target.score_value, target.position, Color(1.0, 0.3, 0.2))
		else:
			var fire_rate = 3.0
			if time_since_last_shot > fire_rate:
				time_since_last_shot = 0.0
				_fire_turret_bullet(dir, target, muzzle_pos)

func _fire_laser(from: Vector2, to: Vector2) -> void:
	for ln in [laser_line, laser_core]:
		if ln:
			ln.clear_points()
			ln.add_point(from)
			ln.add_point(to)
			ln.visible = true
	if laser_line:
		laser_line.width = randf_range(26.0, 34.0) # Energetic flicker

	if muzzle_flash:
		muzzle_flash.global_position = from
		muzzle_flash.visible = true
		muzzle_flash.modulate = Color(1.0, 0.5, 0.35, 1.0)
		muzzle_flash.scale = Vector2(1.5, 1.5)
		var t1 = create_tween()
		t1.tween_property(muzzle_flash, "scale", Vector2(0.7, 0.7), 0.1)
		t1.parallel().tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
		t1.tween_callback(_hide_muzzle_flash)

	if laser_impact_sprite:
		laser_impact_sprite.global_position = to
		laser_impact_sprite.visible = true
		laser_impact_sprite.modulate = Color(1.0, 0.55, 0.45, 1.0)
		laser_impact_sprite.scale = Vector2(1.0, 1.0)
		var t2 = create_tween()
		t2.tween_property(laser_impact_sprite, "scale", Vector2(2.8, 2.8), 0.14).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(laser_impact_sprite, "modulate:a", 0.0, 0.18)
		t2.tween_callback(_hide_laser_impact)

func _hide_muzzle_flash() -> void:
	if muzzle_flash: muzzle_flash.visible = false

func _hide_laser_impact() -> void:
	if laser_impact_sprite: laser_impact_sprite.visible = false

func _fire_turret_bullet(dir: Vector2, target: Area2D, muzzle_pos: Vector2) -> void:
	target.set("is_targeted_by_turret", true)
	var bullet = ColorRect.new()
	bullet.size = Vector2(10, 26)
	bullet.color = Color(1.0, 0.85, 0.3)
	bullet.pivot_offset = Vector2(5, 13)
	bullet.position = muzzle_pos - Vector2(5, 13) + dir * 10.0
	bullet.rotation = dir.angle() + PI / 2.0
	bullet.material = _additive_material()
	add_child(bullet)

	AudioManager.play_sfx("button")

	var tw = create_tween()
	var travel_time = bullet.position.distance_to(target.global_position) / 1000.0
	tw.tween_property(bullet, "position", target.global_position, travel_time)
	tw.tween_callback(func():
		bullet.queue_free()
		if target and is_instance_valid(target) and target.state != target.DropState.POPPING and target.state != target.DropState.INACTIVE:
			if target.has_method("pop_by_bomb"):
				target.pop_by_bomb()
				GameManager.score += target.score_value
				_spawn_floating_text("+%d TURRET!" % target.score_value, target.position, Color(1.0, 0.8, 0.2))
				AudioManager.play_sfx("pop")
	)
