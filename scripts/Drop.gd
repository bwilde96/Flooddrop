extends Area2D

enum DropType {
	NORMAL,
	DRAIN,
	FREEZE,
	BOMB,
	SHIELD,
	RAINBOW,
	GOLD,
	METEOR,
	ACID,
	NEUTRALIZER
}

signal popped(drop_node: Area2D)
signal missed(flood_value: float)

@export var fall_speed: float = 300.0
@export var score_value: int = 10
var flood_damage: float = 15.0 

var type: DropType = DropType.NORMAL :
	set(value):
		type = value
		
		# Rainbow drops pop out in front of darkness events
		if type == DropType.RAINBOW:
			z_index = 100
		else:
			z_index = 0
			
		if is_inside_tree() and fluid_rect:
			fluid_rect.material.set_shader_parameter("water_color", get_current_color())
			_update_shader_liquid_type()
		queue_redraw()

func apply_stats() -> void:
	var theme_mult = theme_cache.get("size_mult", 1.0) if theme_cache else 1.0
	if type == DropType.METEOR:
		if custom_scale_mult >= 1.0:
			tap_health = 5
			meteor_generation = 0
			custom_scale_mult = 2.5 # Force scale to 2.5x
			drop_radius = 40.0 * theme_mult * custom_scale_mult
		elif custom_scale_mult > 0.5:
			tap_health = 2
			meteor_generation = 1
			custom_scale_mult = 1.2 # Medium splits
			drop_radius = 40.0 * theme_mult * custom_scale_mult
		else:
			tap_health = 1
			meteor_generation = 2
			custom_scale_mult = 0.6 # Tiny splits
			drop_radius = 40.0 * theme_mult * custom_scale_mult
	elif type == DropType.NEUTRALIZER:
		tap_health = 10
		drop_radius = 40.0 * theme_mult * custom_scale_mult * 1.5
	elif type == DropType.GOLD:
		tap_health = 1
		custom_scale_mult = 1.5
		drop_radius = 40.0 * theme_mult * custom_scale_mult
	else:
		tap_health = 1
		drop_radius = 40.0 * theme_mult * custom_scale_mult

	if type == DropType.ACID:
		icon_label.text = "☠"
		icon_label.add_theme_color_override("font_color", Color(0.2, 0.0, 0.0))
		icon_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.0))
		icon_label.add_theme_constant_override("outline_size", 8)
		icon_label.add_theme_color_override("font_shadow_color", Color(0,0,0, 0.8))
		icon_label.add_theme_constant_override("shadow_outline_size", 12)
		icon_label.show()
	elif type == DropType.NEUTRALIZER:
		icon_label.text = "✚"
		icon_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		icon_label.add_theme_color_override("font_outline_color", Color(0.0, 0.5, 1.0))
		icon_label.add_theme_constant_override("outline_size", 8)
		icon_label.add_theme_color_override("font_shadow_color", Color(0,0,0, 0.8))
		icon_label.add_theme_constant_override("shadow_outline_size", 12)
		icon_label.show()
	elif type == DropType.GOLD:
		icon_label.hide()
	else:
		icon_label.hide()
		
	# Position is synced with shader in the forming tween, but we set its horizontal center here
	icon_label.position.x = -60
		
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = drop_radius * 2.5
	visuals.scale = Vector2.ONE * custom_scale_mult
var gameplay_ref: Node = null
var tap_health: int = 1

@export_group("Visuals & Feel")
@export var drop_radius: float = 40.0
@export var pop_duration: float = 0.15

@export_group("Formation Anim")
@export var spawn_formation_duration: float = 0.8
@export var drip_stretch_amount: float = 1.3

var screen_bottom: float:
	get:
		if not is_inside_tree(): return 1350.0
		return (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect().size).y + 70.0
enum DropState {
	INACTIVE,
	FORMING,
	FALLING,
	POPPING
}

var state: DropState = DropState.INACTIVE
var _pool: Node = null
var _tween: Tween = null

var theme_cache: Dictionary = {}
var bounce_count: int = 0
var fall_velocity: float = 0.0

var tex_drop_base = null
var tex_drop_high = null
var tex_blob_base = null
var tex_blob_high = null

var custom_scale_mult: float = 1.0
var is_eruption: bool = false
var is_pinata: bool = false
var bounce_velocity_x: float = 0.0
var is_glitching: bool = false
var glitch_timer: float = 0.0
var next_glitch_target: float = 0.5
var meteor_generation: int = 0
var icon_label: Label = null
var is_targeted_by_turret: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals
@onready var fluid_rect: ColorRect = $Visuals/FluidRect
var coin_rect: ColorRect = null

func _ready() -> void:
	icon_label = Label.new()
	icon_label.add_theme_font_size_override("font_size", 32) # Reduced from 48 to fit inside drops
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.position.x = -60 # Match FluidRect bounds
	icon_label.size.x = 120     # Match FluidRect bounds
	icon_label.hide()
	visuals.add_child(icon_label)
	
	coin_rect = ColorRect.new()
	coin_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_rect.position = Vector2(-60, -60)
	coin_rect.size = Vector2(120, 120)
	var c_mat = ShaderMaterial.new()
	c_mat.shader = preload("res://assets/spinning_coin.gdshader")
	coin_rect.material = c_mat
	coin_rect.hide()
	visuals.add_child(coin_rect)
	
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = drop_radius * 2.5
	fluid_rect.material = fluid_rect.material.duplicate()

func on_pool_activate(pool: Node) -> void:
	_pool = pool
	state = DropState.FORMING
	visible = true
	modulate.a = 1.0
	collision_shape.set_deferred("disabled", true)
	_disconnect_all(popped)
	_disconnect_all(missed)
	type = DropType.NORMAL
	
	theme_cache = ThemeManager.get_equipped_theme()
	bounce_count = 0
	fall_velocity = fall_speed
	custom_scale_mult = 1.0
	is_eruption = false
	is_pinata = false
	bounce_velocity_x = 0.0
	is_glitching = false
	glitch_timer = 0.0
	next_glitch_target = randf_range(0.3, 0.8)
	meteor_generation = 0
	is_targeted_by_turret = false
	
	var current_color = get_current_color()
	fluid_rect.material.set_shader_parameter("water_color", current_color)
	_update_shader_liquid_type()
	
	var size_m = theme_cache.get("size_mult", 1.0)
	drop_radius = 40.0 * size_m
	if collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = drop_radius * 2.5
		
	visuals.scale = Vector2.ONE
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	var actual_duration = spawn_formation_duration * theme_cache.get("form_mult", 1.0)
	
	# Start as a tiny blob on the ceiling
	fluid_rect.material.set_shader_parameter("drop_y", 25.0)
	fluid_rect.material.set_shader_parameter("drop_radius", 5.0)
	fluid_rect.material.set_shader_parameter("anchor_multiplier", 1.0)
	
	var s_type = theme_cache.get("shader_type", 0)
	var final_radius = 32.0 * size_m
	var final_y = 50.0
	
	if s_type == 1 or s_type == 2 or s_type == 6: # Thick (Lava, Slime, Gold)
		final_radius = 45.0 * size_m
		final_y = 35.0
	elif s_type == 0 or s_type == 3: # Thin (Water, Acid)
		final_radius = 28.0 * size_m
		final_y = 70.0
		
	_tween = create_tween()
	_tween.set_parallel(true)
	# Phase 1: Build mass
	_tween.tween_method(func(val): fluid_rect.material.set_shader_parameter("drop_radius", val), 5.0, final_radius, actual_duration * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	_tween.chain().set_parallel(true)
	# Phase 2: Weight pulls it down.
	if s_type == 6:
		_tween.tween_property(coin_rect, "position:y", -60.0, actual_duration * 0.5).from(-110.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		_tween.tween_method(func(val):
			if icon_label and icon_label.visible:
				icon_label.position.y = val - 28
		, 25.0, final_y, actual_duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		_tween.tween_method(func(val): 
			fluid_rect.material.set_shader_parameter("drop_y", val)
			if icon_label and icon_label.visible:
				icon_label.position.y = val - 28
		, 25.0, final_y, actual_duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
		# Fade out the anchor during the final moments of Phase 2 so it detaches naturally
		_tween.tween_method(func(val): fluid_rect.material.set_shader_parameter("anchor_multiplier", val), 1.0, 0.0, actual_duration * 0.1).set_delay(actual_duration * 0.4)
	
	_tween.chain().tween_callback(func():
		if state == DropState.FORMING:
			state = DropState.FALLING
			collision_shape.set_deferred("disabled", false)
	)

func force_fall() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	state = DropState.FALLING
	collision_shape.set_deferred("disabled", false)
	
	# Instantly snap visuals to their fully formed state
	var size_m = theme_cache.get("size_mult", 1.0)
	var final_radius = 32.0 * size_m
	var final_y = 50.0
	var s_type = theme_cache.get("shader_type", 0)
	
	if s_type == 1 or s_type == 2 or s_type == 6:
		final_radius = 45.0 * size_m
		final_y = 35.0
	elif s_type == 0 or s_type == 3:
		final_radius = 28.0 * size_m
		final_y = 70.0
		
	fluid_rect.material.set_shader_parameter("drop_y", final_y)
	fluid_rect.material.set_shader_parameter("drop_radius", final_radius)
	fluid_rect.material.set_shader_parameter("anchor_multiplier", 0.0)
	coin_rect.position.y = -60.0
	if icon_label and icon_label.visible:
		icon_label.position.y = final_y - 28

func on_pool_deactivate() -> void:
	state = DropState.INACTIVE
	visible = false
	collision_shape.set_deferred("disabled", true)
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

func _disconnect_all(sig: Signal) -> void:
	var conns = sig.get_connections()
	for c in conns:
		sig.disconnect(c.callable)

func _process(delta: float) -> void:
	var current_color = get_current_color()
	if fluid_rect and fluid_rect.visible:
		fluid_rect.material.set_shader_parameter("water_color", current_color)
	if coin_rect and coin_rect.visible:
		coin_rect.material.set_shader_parameter("coin_color", current_color)
		
	if type != DropType.NORMAL and type != DropType.GOLD:
		queue_redraw()
	if state != DropState.FALLING: return
	
	var multiplier = 1.0
	if gameplay_ref and gameplay_ref.has_method("get_freeze_multiplier"):
		multiplier = gameplay_ref.get_freeze_multiplier()
		
	if coin_rect and coin_rect.visible and icon_label and icon_label.visible:
		var spin_speed = coin_rect.material.get_shader_parameter("spin_speed")
		var spin_time = Time.get_ticks_msec() / 1000.0 * spin_speed
		icon_label.scale.x = max(abs(cos(spin_time)), 0.05)
	elif icon_label:
		icon_label.scale.x = 1.0
		
	var s_type = theme_cache.get("shader_type", 0)
	var current_speed = fall_speed * theme_cache.get("speed_mult", 1.0)
	
	if is_eruption or fall_velocity < current_speed:
		fall_velocity = move_toward(fall_velocity, current_speed, 1500.0 * multiplier * delta)
		current_speed = fall_velocity
	elif s_type == 6: # Gold accelerates
		fall_velocity += 150.0 * multiplier * delta
		current_speed = fall_velocity
	elif s_type == 4: # Rainbow sways and changes speed
		position.x += sin(Time.get_ticks_msec() / 200.0) * 150.0 * delta
		current_speed += sin(Time.get_ticks_msec() / 300.0) * 100.0
	elif s_type == 7: # Neon Plasma stutters
		if sin(Time.get_ticks_msec() / 50.0) > 0.0:
			current_speed *= 2.5
		else:
			current_speed *= 0.1
			
	position.y += current_speed * multiplier * delta
	
	if bounce_velocity_x != 0.0:
		position.x += bounce_velocity_x * multiplier * delta
		if position.x < 60.0:
			position.x = 60.0
			bounce_velocity_x = abs(bounce_velocity_x)
		elif position.x > 660.0:
			position.x = 660.0
			bounce_velocity_x = -abs(bounce_velocity_x)
			
	if is_glitching:
		glitch_timer += delta * multiplier
		if glitch_timer > next_glitch_target:
			glitch_timer = 0.0
			next_glitch_target = randf_range(0.3, 0.8)
			position.y += randf_range(50.0, 150.0)
			position.x += randf_range(-50.0, 50.0)
			if position.x < 60: position.x = 60
			if position.x > 660: position.x = 660
			if gameplay_ref and gameplay_ref.has_method("_spawn_particle"):
				gameplay_ref._spawn_particle(position, Color(0.1, 1.0, 0.8))
				
	if is_pinata:
		if randf() > 0.7:
			if gameplay_ref and gameplay_ref.has_method("_spawn_particle"):
				gameplay_ref._spawn_particle(position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)), Color(1.0, 1.0, 0.5))
				
	# Add watery wobble as it falls
	var wobble_amp = 0.04
	if s_type == 2: wobble_amp = 0.12 # Slime wobbles a lot
	elif s_type == 1: wobble_amp = 0.01 # Lava wobbles very little
	
	var time_sec = Time.get_ticks_msec() / 1000.0
	var wobble_x = sin(time_sec * 15.0 + get_instance_id()) * wobble_amp
	var wobble_y = cos(time_sec * 15.0 + get_instance_id()) * wobble_amp
	visuals.scale = Vector2(1.0 + wobble_x, 1.0 + wobble_y) * custom_scale_mult
	
	if position.y > screen_bottom and current_speed > 0.0:
		if s_type == 2 and bounce_count < 3:
			bounce_count += 1
			position.y = screen_bottom - 10.0
			
			var bounce_height = 0.0
			if bounce_count == 1: bounce_height = 800.0
			elif bounce_count == 2: bounce_height = 500.0
			elif bounce_count == 3: bounce_height = 200.0
			
			var bounce_tween = create_tween()
			bounce_tween.tween_property(self, "position:y", screen_bottom - bounce_height, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			bounce_tween.tween_property(self, "position:y", screen_bottom + 50.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			missed.emit(flood_damage * 0.1) # Small penalty for bouncing
		else:
			if is_pinata:
				if gameplay_ref:
					gameplay_ref.current_flood = 0.0
					gameplay_ref._spawn_floating_text("JACKPOT!", position, Color(1.0, 0.9, 0.2))
					gameplay_ref._update_flood_visual_smooth(0.0)
					AudioManager.play_sfx("rainbow")
			elif type != DropType.ACID:
				var final_damage = flood_damage * theme_cache.get("damage_mult", 1.0)
				if type == DropType.METEOR:
					if meteor_generation == 0:
						final_damage *= 2.5 # Giant hurts a lot
					elif meteor_generation == 1:
						final_damage *= 0.5 # Medium hurts normally
					else:
						final_damage *= 0.1 # Tiny barely hurts (1.5 per drop)
				missed.emit(final_damage)
				
			if _pool:
				_pool.return_drop(self)
			else:
				queue_free()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if state != DropState.FALLING: return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			pop()

func _update_shader_liquid_type() -> void:
	var s_type = theme_cache.get("shader_type", 0) if theme_cache else 0
	var is_midas_level = (s_type == 6)
	
	if type == DropType.GOLD:
		s_type = 6
	elif type == DropType.BOMB:
		s_type = 8
	elif type == DropType.FREEZE:
		s_type = 9
	elif type == DropType.SHIELD:
		s_type = 10
	elif type == DropType.DRAIN:
		s_type = 11
	elif type == DropType.METEOR:
		s_type = 2 # Slime thick
	elif type == DropType.ACID or type == DropType.NEUTRALIZER:
		s_type = 3 # Acid thin
	elif type == DropType.RAINBOW:
		s_type = 4 # Pearlescent
		
	if s_type == 6 or is_midas_level:
		fluid_rect.hide()
		coin_rect.show()
		coin_rect.material.set_shader_parameter("coin_color", get_current_color())
		if is_pinata:
			coin_rect.material.set_shader_parameter("spin_speed", 12.0)
		else:
			coin_rect.material.set_shader_parameter("spin_speed", 5.0)
	elif type == DropType.RAINBOW:
		fluid_rect.hide()
		coin_rect.hide()
	else:
		coin_rect.hide()
		fluid_rect.show()
		fluid_rect.material.set_shader_parameter("liquid_type", s_type)

func pop() -> void:
	if state == DropState.POPPING or state == DropState.INACTIVE: return
	
	if is_pinata:
		bounce_velocity_x *= 1.15
		fall_velocity = -400.0 # Pop back up!
		if gameplay_ref and gameplay_ref.has_method("_on_drop_popped"):
			gameplay_ref._on_drop_popped(self) # Give points but stay alive!
		var tween = create_tween()
		tween.tween_property(visuals, "scale", visuals.scale * 0.8, 0.1)
		tween.tween_property(visuals, "scale", Vector2.ONE, 0.1)
		return
	
	if type == DropType.METEOR:
		tap_health -= 1
		var tween = create_tween()
		tween.tween_property(visuals, "scale", visuals.scale * 0.9, 0.1)
		if gameplay_ref and gameplay_ref.has_method("_spawn_particle"):
			gameplay_ref._spawn_particle(position, get_current_color())
		AudioManager.play_sfx("pop")
		AudioManager.vibrate("pop")
		if tap_health > 0:
			return
			
		# Split
		if gameplay_ref and gameplay_ref.has_method("spawn_specific_drop"):
			var child_count = 0
			var next_scale = 1.0
			var jump_vel = 1000.0
			if meteor_generation == 0:
				child_count = 2 # Reduced from 3
				next_scale = 0.6
				jump_vel = 1800.0 # Jump significantly higher
			elif meteor_generation == 1:
				child_count = 3 # Reduced from 4
				next_scale = 0.3
				jump_vel = 1100.0
				
			for i in range(child_count):
				var fraction = float(i) / max(1.0, float(child_count - 1))
				var angle = lerpf(PI + 0.5, 2 * PI - 0.5, fraction) # Safe upward arc avoiding pure horizontal
				var split_vel_x = cos(angle) * randf_range(300.0, 600.0)
				var split_vel_y = sin(angle) * jump_vel * randf_range(0.8, 1.2)
				gameplay_ref.spawn_specific_drop(position, DropType.METEOR, next_scale, split_vel_y, split_vel_x)
			
	state = DropState.POPPING
	collision_shape.set_deferred("disabled", true)
	popped.emit(self)
	
	_play_pop_animation()

func pop_by_bomb() -> void:
	if state == DropState.POPPING or state == DropState.INACTIVE: return
	state = DropState.POPPING
	collision_shape.set_deferred("disabled", true)
	_play_pop_animation()

func _play_pop_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(visuals, "scale", Vector2(1.5, 1.5), pop_duration).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, pop_duration).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func():
		if _pool: _pool.return_drop(self)
		else: queue_free()
	)

func get_current_color() -> Color:
	match type:
		DropType.NORMAL: 
			var t = ThemeManager.get_equipped_theme()
			return t.get("drop_color", Color(0.35, 0.78, 0.98, 1.0))
		DropType.DRAIN:  return Color(0.2, 0.8, 0.2, 1.0)
		DropType.FREEZE: return Color(0.8, 0.95, 1.0, 1.0)
		DropType.BOMB:   return Color(0.9, 0.2, 0.1, 1.0)
		DropType.SHIELD: return Color(0.7, 0.2, 0.9, 1.0)
		DropType.RAINBOW:
			return Color.from_hsv(fmod(Time.get_ticks_msec() / 1000.0, 1.0), 1.0, 1.0)
		DropType.GOLD:
			# Make the Piñata exceptionally bright and glowing compared to normal gold
			var t = Time.get_ticks_msec() / 200.0
			return Color(1.0, 0.9, 0.1, 1.0).lerp(Color(1.0, 1.0, 0.8, 1.0), (sin(t) + 1.0) / 2.0)
		DropType.METEOR:
			return Color(0.2, 1.0, 0.2, 1.0)
		DropType.ACID:
			var t = Time.get_ticks_msec() / 200.0
			return Color(0.5, 0.0, 0.7, 1.0).lerp(Color(0.8, 0.2, 1.0, 1.0), (sin(t) + 1.0) / 2.0) # Toxic Purple Pulse
		DropType.NEUTRALIZER:
			var t = Time.get_ticks_msec() / 150.0
			return Color(0.1, 1.0, 0.8, 1.0).lerp(Color(1.0, 1.0, 1.0, 1.0), (sin(t) + 1.0) / 2.0)
			
	var theme = theme_cache
	if theme:
		return theme.drop_color
	return Color(0.2, 0.6, 1.0, 1.0)

func _draw() -> void:
	if type == DropType.NORMAL or type == DropType.GOLD: return
	
	# Do not draw the symbol until the drop detaches from the ceiling!
	if state == DropState.FORMING: return
	
	var current_scale = visuals.scale.x
	var size = drop_radius * 0.45 * current_scale
	
	var y_val = fluid_rect.material.get_shader_parameter("drop_y")
	var visual_offset_y = 0.0
	if y_val != null:
		visual_offset_y = float(y_val) + visuals.position.y
		
	var spin_scale_x = 1.0
	if coin_rect and coin_rect.visible:
		var spin_speed = coin_rect.material.get_shader_parameter("spin_speed")
		var spin_time = Time.get_ticks_msec() / 1000.0 * spin_speed
		spin_scale_x = max(abs(cos(spin_time)), 0.05)
		
	draw_set_transform(Vector2(0, visual_offset_y), 0.0, Vector2(spin_scale_x, 1.0))
	
	var base_col = Color(1.0, 1.0, 1.0, 1.0)
	match type:
		DropType.DRAIN: base_col = Color(0.2, 1.0, 0.2, 1.0)
		DropType.FREEZE: base_col = Color(0.5, 0.9, 1.0, 1.0)
		DropType.BOMB: base_col = Color(1.0, 0.4, 0.1, 1.0)
		DropType.SHIELD: base_col = Color(0.9, 0.4, 1.0, 1.0)
		DropType.ACID: base_col = Color(0.8, 1.0, 0.1, 1.0)
		DropType.METEOR: base_col = Color(0.1, 0.8, 0.1, 1.0)
		
	var glow_col = base_col
	
	# Draw beautiful soft radial glow behind the symbol
	var glow_radius = size * 2.5
	for i in range(12, 0, -1):
		var r = (i / 12.0) * glow_radius
		var a = pow(1.0 - (i / 12.0), 2.5) * 0.2
		draw_circle(Vector2.ZERO, r, Color(glow_col.r, glow_col.g, glow_col.b, a))
	
	match type:
		DropType.DRAIN:
			base_col = Color(0.2, 1.0, 0.2, 1.0)
			for w in [8.0, 4.0]:
				var c = Color(0.1, 0.8, 0.1, 0.4) if w == 8.0 else base_col
				draw_line(Vector2(0, -size), Vector2(0, size), c, w * current_scale)
				draw_line(Vector2(-size*0.7, size*0.3), Vector2(0, size), c, w * current_scale)
				draw_line(Vector2(size*0.7, size*0.3), Vector2(0, size), c, w * current_scale)
		DropType.FREEZE:
			base_col = Color(0.5, 0.9, 1.0, 1.0)
			for w in [7.0, 3.0]:
				var c = Color(0.2, 0.6, 1.0, 0.4) if w == 7.0 else base_col
				draw_line(Vector2(0, -size), Vector2(0, size), c, w * current_scale)
				draw_line(Vector2(-size*0.86, -size*0.5), Vector2(size*0.86, size*0.5), c, w * current_scale)
				draw_line(Vector2(-size*0.86, size*0.5), Vector2(size*0.86, -size*0.5), c, w * current_scale)
		DropType.BOMB:
			base_col = Color(1.0, 0.4, 0.1, 1.0)
			draw_circle(Vector2.ZERO, size * 0.5, base_col)
			draw_line(Vector2(0, -size*0.5), Vector2(size*0.8, -size*1.2), Color(0.1, 0.1, 0.1, 1.0), 4.0 * current_scale)
			draw_circle(Vector2(size*0.8, -size*1.2), size*0.3, Color(1.0, 0.8, 0.2, 1.0)) # Spark
		DropType.SHIELD:
			base_col = Color(0.9, 0.4, 1.0, 1.0)
			var points = PackedVector2Array([
				Vector2(-size, -size*0.8), Vector2(size, -size*0.8),
				Vector2(size, size*0.2), Vector2(0, size*0.9), Vector2(-size, size*0.2)
			])
			draw_polygon(points, [base_col, base_col, base_col, base_col, base_col])
		DropType.RAINBOW:
			var time_sec = Time.get_ticks_msec() / 1000.0
			base_col = Color.from_hsv(fmod(time_sec, 1.0), 1.0, 1.0)
			for w in [8.0, 4.0]:
				var alpha = 0.3 if w == 8.0 else 1.0
				draw_arc(Vector2(0, size*0.3), size, 0, PI*2, 24, Color.from_hsv(fmod(time_sec, 1.0), 1.0, 1.0, alpha), w * current_scale)
				draw_arc(Vector2(0, size*0.3), size*0.7, 0, PI*2, 24, Color.from_hsv(fmod(time_sec + 0.33, 1.0), 1.0, 1.0, alpha), w * current_scale)
				draw_arc(Vector2(0, size*0.3), size*0.4, 0, PI*2, 24, Color.from_hsv(fmod(time_sec + 0.66, 1.0), 1.0, 1.0, alpha), w * current_scale)
		DropType.ACID:
			base_col = Color(0.8, 1.0, 0.1, 1.0)
			# Draw a skull or toxic symbol. For simplicity, an X
			for w in [6.0, 3.0]:
				var c = Color(0.5, 0.8, 0.0, 0.4) if w == 6.0 else base_col
				draw_line(Vector2(-size*0.6, -size*0.6), Vector2(size*0.6, size*0.6), c, w * current_scale)
				draw_line(Vector2(size*0.6, -size*0.6), Vector2(-size*0.6, size*0.6), c, w * current_scale)
		DropType.METEOR:
			base_col = Color(0.2, 0.9, 0.2, 1.0)
			# Draw a rock-like texture/lines
			draw_arc(Vector2.ZERO, size*0.8, 0, PI*2, 12, base_col, 3.0 * current_scale)
