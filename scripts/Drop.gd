extends Area2D

enum DropType {
	NORMAL,
	DRAIN,
	FREEZE,
	BOMB,
	SHIELD,
	RAINBOW,
	GOLD
}

signal popped(drop_node: Area2D)
signal missed(flood_value: float)

@export var fall_speed: float = 300.0
@export var score_value: int = 10
var flood_damage: float = 15.0 

var type: DropType = DropType.NORMAL :
	set(value):
		type = value
		if is_inside_tree() and fluid_rect:
			fluid_rect.material.set_shader_parameter("water_color", get_current_color())
			_update_shader_liquid_type()
		queue_redraw()
var gameplay_ref: Node = null

@export_group("Visuals & Feel")
@export var drop_radius: float = 40.0
@export var pop_duration: float = 0.15

@export_group("Formation Anim")
@export var spawn_formation_duration: float = 0.8
@export var drip_stretch_amount: float = 1.3

var screen_bottom: float = 1350.0
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

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visuals: Node2D = $Visuals
@onready var fluid_rect: ColorRect = $Visuals/FluidRect

func _ready() -> void:
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
	_tween.tween_method(func(val): fluid_rect.material.set_shader_parameter("drop_y", val), 25.0, final_y, actual_duration * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	# Fade out the anchor during the final moments of Phase 2 so it detaches naturally
	_tween.tween_method(func(val): fluid_rect.material.set_shader_parameter("anchor_multiplier", val), 1.0, 0.0, actual_duration * 0.1).set_delay(actual_duration * 0.4)
	
	_tween.chain().tween_callback(func():
		if state == DropState.FORMING:
			state = DropState.FALLING
			collision_shape.set_deferred("disabled", false)
	)

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
	if type != DropType.NORMAL and type != DropType.GOLD:
		queue_redraw()
	if state != DropState.FALLING: return
	
	var multiplier = 1.0
	if gameplay_ref and gameplay_ref.has_method("get_freeze_multiplier"):
		multiplier = gameplay_ref.get_freeze_multiplier()
		
	var s_type = theme_cache.get("shader_type", 0)
	var current_speed = fall_speed * theme_cache.get("speed_mult", 1.0)
	
	if s_type == 6: # Gold accelerates
		fall_velocity += 150.0 * delta
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
	
	# Add watery wobble as it falls
	var wobble_amp = 0.04
	if s_type == 2: wobble_amp = 0.12 # Slime wobbles a lot
	elif s_type == 1: wobble_amp = 0.01 # Lava wobbles very little
	
	var time_sec = Time.get_ticks_msec() / 1000.0
	var wobble_x = sin(time_sec * 15.0 + get_instance_id()) * wobble_amp
	var wobble_y = cos(time_sec * 15.0 + get_instance_id()) * wobble_amp
	visuals.scale = Vector2(1.0 + wobble_x, 1.0 + wobble_y)
	
	if position.y > screen_bottom:
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
			var final_damage = flood_damage * theme_cache.get("damage_mult", 1.0)
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
	if type == DropType.GOLD:
		fluid_rect.material.set_shader_parameter("liquid_type", 6)
	elif type == DropType.BOMB:
		fluid_rect.material.set_shader_parameter("liquid_type", 8)
	elif type == DropType.FREEZE:
		fluid_rect.material.set_shader_parameter("liquid_type", 9)
	elif type == DropType.SHIELD:
		fluid_rect.material.set_shader_parameter("liquid_type", 10)
	elif type == DropType.DRAIN:
		fluid_rect.material.set_shader_parameter("liquid_type", 11)
	else:
		if theme_cache == null:
			theme_cache = ThemeManager.get_equipped_theme()
		fluid_rect.material.set_shader_parameter("liquid_type", theme_cache.get("shader_type", 0))

func pop() -> void:
	if state == DropState.POPPING or state == DropState.INACTIVE: return
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
	var col = Color(0.35, 0.78, 0.98, 1.0)
	match type:
		DropType.NORMAL: 
			var t = ThemeManager.get_equipped_theme()
			col = t.get("drop_color", Color(0.35, 0.78, 0.98, 1.0))
		DropType.DRAIN:  col = Color(0.2, 0.8, 0.2, 1.0)
		DropType.FREEZE: col = Color(0.8, 0.95, 1.0, 1.0)
		DropType.BOMB:   col = Color(0.9, 0.2, 0.1, 1.0)
		DropType.SHIELD: col = Color(0.7, 0.2, 0.9, 1.0)
		DropType.RAINBOW:col = Color(0.9, 0.8, 0.1, 1.0)
		DropType.GOLD:   col = Color(1.0, 0.9, 0.2, 1.0)
	return col

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
		
	draw_set_transform(Vector2(0, visual_offset_y), 0.0, Vector2.ONE)
	
	var base_col = Color(1.0, 1.0, 1.0, 1.0)
	match type:
		DropType.DRAIN: base_col = Color(0.2, 1.0, 0.2, 1.0)
		DropType.FREEZE: base_col = Color(0.5, 0.9, 1.0, 1.0)
		DropType.BOMB: base_col = Color(1.0, 0.4, 0.1, 1.0)
		DropType.SHIELD: base_col = Color(0.9, 0.4, 1.0, 1.0)
		
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
			base_col = Color(1.0, 1.0, 1.0, 1.0)
			for w in [8.0, 4.0]:
				var alpha = 0.3 if w == 8.0 else 1.0
				draw_arc(Vector2(0, size*0.3), size, PI, PI*2, 24, Color(1,0.2,0.2, alpha), w * current_scale)
				draw_arc(Vector2(0, size*0.3), size*0.7, PI, PI*2, 24, Color(0.2,1,0.2, alpha), w * current_scale)
				draw_arc(Vector2(0, size*0.3), size*0.4, PI, PI*2, 24, Color(0.2,0.2,1, alpha), w * current_scale)
