extends Node

enum ForceDropType {
	NONE = -1,
	NORMAL = 0,
	DRAIN = 1,
	FREEZE = 2,
	BOMB = 3,
	SHIELD = 4,
	RAINBOW = 5
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

var current_power_up_chance: float = 0.0
var freeze_timer: float = 0.0
var shield_charges: int = 0

var active_ability: String = "time_warp"
var ability_cooldown: float = 0.0
var ability_cooldown_max: float = 30.0
var ability_progress: TextureProgressBar

var is_midas_active: bool = false
var midas_timer: float = 0.0
var midas_overlay: ColorRect

var is_turret_active: bool = false
var turret_timer: float = 0.0
var laser_line: Line2D
var laser_timer: float = 0.0

var evaporation_particles: CPUParticles2D

var is_tidal_wave_active: bool = false
var tidal_wave_y: float = 1280.0
var tidal_wave_rect: ColorRect

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
@onready var danger_label: Label = $HUD/GameUI/CenterContainer/DangerLabel
@onready var level_up_label: Label = $HUD/GameUI/CenterContainer/LevelUpLabel
@onready var debug_panel: PanelContainer = $HUD/DebugPanel
@onready var debug_label: Label = $HUD/DebugPanel/Margin/DebugLabel
@onready var camera: Camera2D = $Camera2D

@onready var pause_menu: Control = $HUD/PauseMenu
@onready var game_ui: Control = $HUD/GameUI
@onready var pause_btn: Button = $HUD/GameUI/PauseButtonContainer/PauseButton

@onready var freeze_overlay: ColorRect = $HUD/GameUI/FreezeOverlay
@onready var shield_icon: ColorRect = $HUD/GameUI/ShieldsContainer/ShieldIcon
@onready var shield_count_label: Label = $HUD/GameUI/ShieldsContainer/ShieldCountLabel

var shake_intensity: float = 0.0

func _ready() -> void:
	current_spawn_interval = base_spawn_interval
	current_drop_speed = base_drop_speed
	GameManager.score = 0
	GameManager.survival_time = 0.0
	BackgroundManager.update_background(levels[current_level_index].theme)
	
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
	
	if OS.has_feature("editor"):
		debug_panel.visible = true
	
	laser_line = Line2D.new()
	laser_line.default_color = Color(1.0, 0.2, 0.2, 0.8)
	laser_line.width = 8.0
	laser_line.visible = false
	add_child(laser_line)
	
	evaporation_particles = CPUParticles2D.new()
	evaporation_particles.emitting = false
	evaporation_particles.one_shot = true
	evaporation_particles.amount = 100
	evaporation_particles.lifetime = 1.5
	evaporation_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	evaporation_particles.emission_rect_extents = Vector2(360, 20)
	evaporation_particles.position = Vector2(360, 1280) # Bottom of screen
	evaporation_particles.direction = Vector2(0, -1)
	evaporation_particles.spread = 15.0
	evaporation_particles.gravity = Vector2(0, -100)
	evaporation_particles.initial_velocity_min = 200.0
	evaporation_particles.initial_velocity_max = 400.0
	evaporation_particles.scale_amount_min = 10.0
	evaporation_particles.scale_amount_max = 30.0
	evaporation_particles.color = Color(0.9, 0.9, 1.0, 0.6)
	add_child(evaporation_particles)
	
	tidal_wave_rect = ColorRect.new()
	tidal_wave_rect.color = Color(0.2, 0.6, 1.0, 0.7)
	tidal_wave_rect.size = Vector2(720, 200)
	tidal_wave_rect.position = Vector2(0, 1280)
	tidal_wave_rect.visible = false
	tidal_wave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tidal_wave_rect)
	
	midas_overlay = ColorRect.new()
	midas_overlay.color = Color(1.0, 0.8, 0.2, 0.2)
	midas_overlay.size = Vector2(720, 1280)
	midas_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	midas_overlay.visible = false
	add_child(midas_overlay)
	
	current_level_index = 0
	ThemeManager.equip_theme(levels[0].theme)

func _setup_ability_ui() -> void:
	var container = Control.new()
	container.custom_minimum_size = Vector2(100, 100)
	game_ui.add_child(container)
	container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	container.position = Vector2(game_ui.size.x - 140, game_ui.size.y - 140)
	
	ability_progress = TextureProgressBar.new()
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.2, 0.2, 0.8))
	var tex_bg = ImageTexture.create_from_image(img)
	
	var img_fill = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img_fill.fill(Color(0.8, 0.8, 0.2, 0.8))
	var tex_fill = ImageTexture.create_from_image(img_fill)
	
	ability_progress.texture_under = tex_bg
	ability_progress.texture_progress = tex_fill
	ability_progress.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ability_progress.step = 0.1
	ability_progress.max_value = ability_cooldown_max
	ability_progress.value = ability_cooldown_max
	
	var icon_path = "res://assets/icons/icon_%s.jpg" % active_ability
	var icon_img = Image.new()
	var err = icon_img.load(icon_path)
	var icon_tex = null
	if err == OK:
		icon_tex = ImageTexture.create_from_image(icon_img)
	
	if icon_tex != null:
		var tex_rect = TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(80, 80)
		tex_rect.position = Vector2(10, 10)
		container.add_child(tex_rect)
		
		# Make progress fill a dark transparent overlay
		var img_overlay = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		img_overlay.fill(Color(0, 0, 0, 0.7))
		ability_progress.texture_progress = ImageTexture.create_from_image(img_overlay)
		ability_progress.texture_under = null
		# We want it to be fully dark when cooling down, and empty when ready
		ability_progress.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	
	var btn = Button.new()
	btn.text = "USE"
	btn.custom_minimum_size = Vector2(100, 100)
	btn.modulate.a = 0.0 # Make it invisible, just clickable
	
	container.add_child(ability_progress)
	container.add_child(btn)
	
	btn.pressed.connect(_use_ability)
	var t = ThemeManager.get_equipped_theme()
	flood_rect.material.set_shader_parameter("top_color", t.drop_color)
	flood_rect.material.set_shader_parameter("bottom_color", t.flood_color)
	flood_rect.material.set_shader_parameter("liquid_type", t.get("shader_type", 0))
	
	level_up_label.modulate.a = 0.0
	level_up_label.scale = Vector2(1.5, 1.5)
	
	update_hud()
	_update_powerup_hud()
	_update_flood_visual_instant()
	
	await get_tree().create_timer(grace_period).timeout
	is_playing = true

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
	if get_tree().paused: return
	
	if is_playing and not get_tree().paused:
		GameManager.survival_time += delta
		
		# Check level up
		if current_level_index < levels.size() - 1:
			if GameManager.survival_time >= levels[current_level_index + 1].time:
				current_level_index += 1
				_trigger_level_up()
				
		var freeze_mult = get_freeze_multiplier()

		if freeze_timer > 0:
			freeze_timer -= delta
			if freeze_timer <= 0:
				freeze_overlay.visible = false
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
		current_power_up_chance = min(power_up_spawn_chance_max, current_power_up_chance + (power_up_spawn_ramp * delta * ramp_mult))
		
		if current_flood > 0:
			current_flood = max(0.0, current_flood - (flood_drain_rate * delta))
			_update_flood_visual_smooth(delta)
		
		var spawn_mult = freeze_mult if freeze_affects_spawning else 1.0
		
		# Time Warp Logic
		if is_midas_active:
			midas_overlay.visible = true
			midas_timer -= delta
			if midas_timer <= 0:
				is_midas_active = false
				midas_overlay.visible = false
		
		if is_tidal_wave_active:
			tidal_wave_y -= delta * 1500.0
			tidal_wave_rect.position.y = tidal_wave_y
			
			for d in drop_container.get_children():
				if d.has_method("pop") and "state" in d and "DropState" in d:
					if d.state == d.DropState.FALLING and d.position.y > tidal_wave_y:
						d.pop()
						
			if tidal_wave_y < -200:
				is_tidal_wave_active = false
				tidal_wave_rect.visible = false
		
		if is_turret_active:
			turret_timer -= delta
			if turret_timer <= 0:
				is_turret_active = false
			else:
				# Auto pop drops low on screen
				for d in drop_container.get_children():
					if d.has_method("pop") and "state" in d and "DropState" in d:
						if d.position.y > 1280.0 - 150.0 and d.state == d.DropState.FALLING:
							laser_line.clear_points()
							laser_line.add_point(Vector2(360, 1280))
							laser_line.add_point(d.position)
							laser_line.visible = true
							laser_timer = 0.1
							AudioManager.play_sfx("button") # temporary laser sound
							d.pop()
							break # Pop one per frame maximum for turret
							
		if laser_timer > 0:
			laser_timer -= delta
			if laser_timer <= 0:
				laser_line.visible = false
		
		if ability_cooldown < ability_cooldown_max:
			ability_cooldown += delta
			ability_progress.value = ability_cooldown_max - ability_cooldown
			if ability_cooldown >= ability_cooldown_max:
				AudioManager.play_sfx("power_up") # Ready sound
				ability_progress.modulate = Color(1,1,1,1)
			else:
				ability_progress.modulate = Color(0.8,0.8,0.8,1.0)
				
		spawn_timer -= (delta * spawn_mult)
		if spawn_timer <= 0:
			spawn_drop()
			
			var t = ThemeManager.get_equipped_theme()
			var theme_spawn_mult = t.get("spawn_interval_mult", 1.0)
			spawn_timer = current_spawn_interval * theme_spawn_mult
			
	if debug_panel.visible:
		update_debug_ui()

func _use_ability() -> void:
	if not is_playing or get_tree().paused: return
	if ability_cooldown < ability_cooldown_max: return
	
	ability_cooldown = 0.0
	ability_progress.value = ability_cooldown_max
	ability_progress.modulate = Color(0.8,0.8,0.8,1.0)
	
	AudioManager.play_sfx("power_up")
	
	# Execute ability
	if active_ability == "time_warp":
		freeze_timer = max(freeze_timer, 5.0) # Using existing freeze logic
		freeze_overlay.visible = true
		freeze_overlay.modulate = Color(0.5, 0.5, 1.0, 0.5)
	elif active_ability == "evaporation":
		current_flood = max(0.0, current_flood - 30.0)
		_update_flood_visual_smooth(0.0)
		evaporation_particles.emitting = true
	elif active_ability == "tidal_wave":
		is_tidal_wave_active = true
		tidal_wave_y = 1280.0
		tidal_wave_rect.visible = true
	elif active_ability == "midas_touch":
		is_midas_active = true
		midas_timer = 8.0
	elif active_ability == "auto_turret":
		is_turret_active = true
		turret_timer = 4.0

func _trigger_level_up() -> void:
	var new_level = levels[current_level_index]
	ThemeManager.equip_theme(new_level.theme) # Actually, ThemeManager will return equipped theme
	var t = ThemeManager.get_theme(new_level.theme)
	ThemeManager.equip_theme(new_level.theme) # Make sure it's globally equipped
	
	level_up_label.text = "LEVEL %d - %s" % [current_level_index + 1, t.name.to_upper()]
	
	var tween = create_tween()
	tween.tween_property(level_up_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(level_up_label, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(level_up_label, "modulate:a", 0.0, 0.5).set_delay(2.0)
	
	BackgroundManager.update_background(levels[current_level_index].theme)
	var pool_tween = create_tween()
	pool_tween.tween_property(flood_rect.material, "shader_parameter/top_color", t.drop_color, 2.0)
	pool_tween.tween_property(flood_rect.material, "shader_parameter/bottom_color", t.flood_color, 2.0)
	flood_rect.material.set_shader_parameter("liquid_type", t.get("shader_type", 0))
	
	AudioManager.play_sfx("power_up")

func _count_active_powerups() -> int:
	var count = 0
	for d in drop_container.get_children():
		if d.has_method("pop") and d.state != d.DropState.INACTIVE and d.state != d.DropState.POPPING and d.type != d.DropType.NORMAL:
			count += 1
	return count

func spawn_drop() -> void:
	var drop = pool_manager.get_drop()
	
	drop.gameplay_ref = self
	drop.fall_speed = current_drop_speed
	drop.flood_damage = flood_damage_per_miss
	
	# Determine drop type
	var chosen_type = drop.DropType.NORMAL
	
	if OS.has_feature("editor") and force_drop_type != ForceDropType.NONE:
		chosen_type = force_drop_type as int
	elif is_midas_active:
		chosen_type = drop.DropType.GOLD
	else:
		if GameManager.survival_time >= min_time_before_powerups:
			if _count_active_powerups() < max_active_powerups:
				if randf() < current_power_up_chance:
					chosen_type = _pick_random_powerup()
					
	drop.type = chosen_type
	drop.queue_redraw()
	
	var safe_left = 60.0
	var safe_right = 660.0
	var x_pos = randf_range(safe_left, safe_right)
	
	if abs(x_pos - last_spawn_x) < min_drop_distance_x:
		x_pos += min_drop_distance_x
		if x_pos > safe_right:
			x_pos -= (min_drop_distance_x * 2.0)
			
	x_pos = clamp(x_pos, safe_left, safe_right)
	last_spawn_x = x_pos
	
	# Spawn lower so formation animation is visible
	drop.position = Vector2(x_pos, 50.0)
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var requested_formation = randf_range(0.8, 3.5)
	var proposed_fall_time = current_time + requested_formation
	
	if proposed_fall_time < next_available_fall_time:
		proposed_fall_time = next_available_fall_time
		requested_formation = proposed_fall_time - current_time
		
	next_available_fall_time = proposed_fall_time + 0.35 # Enforce at least 0.35s gap between drops falling
	
	# Pass the exact formation duration to the drop
	drop.spawn_formation_duration = requested_formation
	
	drop.popped.connect(_on_drop_popped)
	drop.missed.connect(_on_drop_missed)

func _pick_random_powerup() -> int:
	var total_weight = weight_drain + weight_freeze + weight_bomb + weight_shield + weight_rainbow
	var roll = randf_range(0.0, total_weight)
	
	if roll < weight_drain: return 1 # DRAIN
	roll -= weight_drain
	if roll < weight_freeze: return 2 # FREEZE
	roll -= weight_freeze
	if roll < weight_bomb: return 3 # BOMB
	roll -= weight_bomb
	if roll < weight_shield: return 4 # SHIELD
	return 5 # RAINBOW

func _on_drop_popped(drop_node: Area2D) -> void:
	var t = drop_node.type
	var pos = drop_node.position
	var base_score = int(drop_node.score_value * ThemeManager.get_equipped_theme().get("score_mult", 1.0))
	
	match t:
		drop_node.DropType.NORMAL:
			GameManager.score += base_score
			_spawn_floating_text("+%d" % base_score, pos, Color(1, 1, 1))
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("pop")
			AudioManager.vibrate("pop")
		drop_node.DropType.GOLD:
			var gold_score = base_score * 5
			GameManager.score += gold_score
			_spawn_floating_text("+%d GOLD!" % gold_score, pos, Color(1.0, 0.9, 0.2))
			_spawn_particle(pos, drop_node.get_current_color())
			AudioManager.play_sfx("pop")
			AudioManager.vibrate("pop")
		drop_node.DropType.DRAIN:
			current_flood = max(0.0, current_flood - drain_amount)
			GameManager.score += base_score
			_spawn_floating_text("DRAIN!", pos)
			_update_flood_visual_smooth(0.0)
			_spawn_particle(pos, Color(0.2, 0.8, 0.2, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
			AudioManager.vibrate("pop")
		drop_node.DropType.FREEZE:
			freeze_timer = freeze_duration
			freeze_overlay.visible = true
			GameManager.score += base_score
			_spawn_floating_text("FREEZE!", pos)
			_spawn_particle(pos, Color(0.8, 0.95, 1.0, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
		drop_node.DropType.BOMB:
			_trigger_bomb(pos)
			GameManager.score += base_score
			_spawn_floating_text("BOOM!", pos)
			_spawn_particle(pos, Color(0.9, 0.2, 0.1, 1.0), true)
			AudioManager.play_sfx("bomb")
			AudioManager.vibrate("bomb")
		drop_node.DropType.SHIELD:
			shield_charges += shield_charges_per_pickup
			GameManager.score += base_score
			_spawn_floating_text("SHIELD x%d" % shield_charges_per_pickup, pos)
			_update_powerup_hud()
			_spawn_particle(pos, Color(0.4, 0.4, 0.9, 1.0))
			AudioManager.play_sfx("power_up")
			AudioManager.vibrate("pop")
		drop_node.DropType.RAINBOW:
			GameManager.score += rainbow_bonus_score
			current_flood = max(0.0, current_flood - rainbow_flood_reduction)
			_spawn_floating_text("RAINBOW +%d" % rainbow_bonus_score, pos)
			_update_flood_visual_smooth(0.0)
			_spawn_particle(pos, Color.WHITE, false, true)
			AudioManager.play_sfx("rainbow")
			AudioManager.vibrate("rainbow")
			
	update_hud()

func _trigger_bomb(center: Vector2) -> void:
	for child in drop_container.get_children():
		if child.has_method("pop_by_bomb") and child.state != child.DropState.INACTIVE and child.state != child.DropState.POPPING:
			if child.type == child.DropType.NORMAL:
				if child.position.distance_to(center) <= bomb_radius:
					child.pop_by_bomb()
					GameManager.score += child.score_value
					_spawn_floating_text("+%d" % child.score_value, child.position)

func _on_drop_missed(flood_value: float) -> void:
	if shield_charges > 0:
		shield_charges -= 1
		_update_powerup_hud()
		AudioManager.play_sfx("pop")
		AudioManager.vibrate("pop")
		return
		
	current_flood += flood_value
	shake_intensity = screen_shake_strength
	
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
	var screen_height = 1280.0
	var flood_ratio = current_flood / max_flood
	var target_height = flood_ratio * screen_height
	flood_rect.offset_top = -target_height
	flood_rect.offset_bottom = 0
	_update_flood_color(flood_ratio)

func _update_flood_visual_smooth(delta: float) -> void:
	var screen_height = 1280.0
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
	else:
		flood_rect.color = final_color
