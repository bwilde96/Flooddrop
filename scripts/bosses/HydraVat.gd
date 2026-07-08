extends Node2D
## The Hydra — boss archetype #4 (fully procedural).
## Three liquid heads hang from the ceiling on swaying tendrils. Only ONE is
## real — it carries a beating white heart. Strike it and the heads submerge
## and reshuffle. Strike a decoy and it SPITS drops at your flood. Faster and
## meaner with every wound.

signal defeated

const MAX_HP := 6
const HEAD_R := 40.0
const ANCHORS_X := [170.0, 360.0, 550.0]

var accent := Color(0.7, 1.0, 0.2)
var gameplay: Node = null

var hp := MAX_HP
var real_idx := 0
var _heads: Array = []
var _t := 0.0
var _state := "active" # active | shuffle | dying
var _state_t := 0.0
var _flash := [0.0, 0.0, 0.0]
var _spit_t := 5.0

func _ready() -> void:
	z_index = 90
	real_idx = randi() % 3
	for i in range(3):
		var head := Area2D.new()
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = HEAD_R * 1.7
		cs.shape = shape
		head.add_child(cs)
		head.input_pickable = true
		head.input_event.connect(_on_head_input.bind(i))
		head.position = Vector2(ANCHORS_X[i], 320.0)
		add_child(head)
		_heads.append(head)

func _bob_speed() -> float:
	return 1.0 + float(MAX_HP - hp) * 0.22 # meaner with every wound

func _process(delta: float) -> void:
	if _state == "dying": return
	_t += delta * _bob_speed()
	_state_t += delta
	for i in range(3):
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)

	match _state:
		"active":
			for i in range(3):
				var h: Area2D = _heads[i]
				var target_y := 320.0 + sin(_t * 1.4 + float(i) * 2.1) * 42.0
				var target_x: float = ANCHORS_X[i] + sin(_t * 0.8 + float(i) * 1.3) * 34.0
				h.position = h.position.lerp(Vector2(target_x, target_y), 1.0 - pow(0.001, delta))
			_spit_t -= delta
			if _spit_t <= 0.0: # ambient pressure: a random head spits one drop
				_spit_t = lerpf(6.0, 3.0, 1.0 - float(hp) / MAX_HP)
				_spit(randi() % 3, 1)
		"shuffle":
			for i in range(3):
				var h: Area2D = _heads[i]
				h.position = h.position.lerp(Vector2(ANCHORS_X[i], 60.0), 1.0 - pow(0.0005, delta))
			if _state_t >= 0.7:
				real_idx = randi() % 3
				_state = "active"
				AudioManager.play_sfx("power_up", 0.8)
	queue_redraw()

func _spit(idx: int, count: int) -> void:
	if gameplay == null: return
	for c in range(count):
		gameplay.spawn_specific_drop(_heads[idx].global_position + Vector2(randf_range(-20, 20), 30),
			0, 1.0, randf_range(120.0, 260.0), randf_range(-120.0, 120.0))
	AudioManager.play_sfx("miss", 1.3)

func get_progress() -> float:
	return float(MAX_HP - hp) / float(MAX_HP)

func _on_head_input(_viewport: Node, event: InputEvent, _shape_idx: int, idx: int) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton): return
	if not event.is_pressed(): return
	_tap_head(idx)

func _tap_head(idx: int) -> void:
	if _state != "active": return
	_flash[idx] = 1.0
	if idx == real_idx:
		hp -= 1
		AudioManager.play_sfx("pop", 1.15)
		AudioManager.vibrate("pop")
		GameManager.score += 30
		if gameplay:
			gameplay._spawn_particle(_heads[idx].global_position, accent)
			gameplay._spawn_ripple(_heads[idx].global_position, accent, 1.4)
			gameplay._spawn_floating_text("+30", _heads[idx].position + Vector2(0, -60), accent.lightened(0.3))
			gameplay.trigger_hit_pause(0.04)
			gameplay.update_hud()
		if hp <= 0:
			_die()
		else:
			_state = "shuffle"
			_state_t = 0.0
	else:
		# Decoy: it laughs and spits two drops at you
		AudioManager.play_sfx("button", 0.45)
		AudioManager.vibrate("miss")
		_spit(idx, 2)
		if gameplay:
			gameplay._spawn_floating_text("DECOY!", _heads[idx].position + Vector2(0, -60), Color(1.0, 0.5, 0.4))

func _die() -> void:
	_state = "dying"
	AudioManager.play_sfx("bomb")
	AudioManager.vibrate("bomb")
	if gameplay:
		gameplay.shake_intensity = 30.0
		gameplay.trigger_hit_pause(0.08)
		for i in range(3):
			gameplay._spawn_particle(_heads[i].global_position, accent, true)
		gameplay._spawn_ripple(_heads[real_idx].global_position, accent, 2.6)
	defeated.emit()
	queue_free()

func _draw() -> void:
	var tms := Time.get_ticks_msec() / 1000.0
	for i in range(3):
		var p: Vector2 = _heads[i].position
		# Tendril: a swaying curve from the ceiling anchor to the head
		var a := Vector2(ANCHORS_X[i], -8.0)
		var pts := PackedVector2Array()
		for s in range(9):
			var f := float(s) / 8.0
			var mid := a.lerp(p, f)
			mid.x += sin(tms * 2.0 + f * 5.0 + float(i)) * 14.0 * f * (1.0 - f) * 4.0
			pts.append(mid)
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.20), 16.0)
		draw_polyline(pts, Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 0.6), 8.0)

	for i in range(3):
		var p: Vector2 = _heads[i].position
		draw_circle(p, HEAD_R * 1.45, Color(accent.r, accent.g, accent.b, 0.10))
		draw_circle(p, HEAD_R, accent.darkened(0.38))
		draw_circle(p, HEAD_R * 0.8, accent)
		draw_circle(p + Vector2(-HEAD_R * 0.28, -HEAD_R * 0.34), HEAD_R * 0.24, Color(1, 1, 1, 0.85))
		draw_circle(p + Vector2(-12, -4), 5.5, Color(0.05, 0.07, 0.12))
		draw_circle(p + Vector2(12, -4), 5.5, Color(0.05, 0.07, 0.12))
		if i == real_idx and _state == "active":
			# The tell: a beating white heart deep in the real head
			var beat := 0.35 + 0.3 * maxf(0.0, sin(tms * 5.0))
			draw_circle(p + Vector2(0, 10), HEAD_R * 0.22, Color(1, 1, 1, beat))
		if _flash[i] > 0.0:
			draw_circle(p, HEAD_R * 1.1, Color(1, 1, 1, _flash[i] * 0.5))
