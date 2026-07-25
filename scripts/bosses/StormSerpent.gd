extends Node2D
## The Storm Serpent — challenge-boss archetype #2 (fully procedural).
## A chain of luminous liquid segments that weaves across the sky and
## dive-bombs the flood. Rules the player discovers fast:
##   - only the TAIL segment (pulsing white) is vulnerable — sever it tail-first
##   - wrong segments flash a shield and shrug the tap off
##   - every severed segment makes it FASTER
##   - dives are telegraphed (red tremble); two rapid taps on the head interrupt
##   - when no segments remain, the head opens (3 taps)

signal defeated
signal flood_damage(amount: float)

const SEG_COUNT := 8
const SEG_SPACING := 46.0
const SEG_RADIUS := 30.0
const HEAD_RADIUS := 42.0

var accent := Color(0.4, 1.0, 0.5)
var gameplay: Node = null

var _parts: Array = []   # Area2D per part; index 0 = head
var _alive: Array = []
var _flash: Array = []   # wrong-tap shield flash per part
var _trail: Array = []   # head position history, newest first
var _t := 0.0
var _state := "weave"    # weave | telegraph | dive | recover | dying
var _state_t := 0.0
var _next_dive := 6.0
var _speed := 1.0
var head_hp := 3
var _dive_taps := 0

func _ready() -> void:
	z_index = 90
	for i in range(SEG_COUNT + 1):
		var part := Area2D.new()
		var cs := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = (HEAD_RADIUS if i == 0 else SEG_RADIUS) * 1.7
		cs.shape = shape
		part.add_child(cs)
		part.input_pickable = true
		part.input_event.connect(_on_part_input.bind(i))
		add_child(part)
		_parts.append(part)
		_alive.append(true)
		_flash.append(0.0)
	var start := _head_target(0.0)
	for i in range(500):
		_trail.append(start)
	_place_parts()

func _head_target(t: float) -> Vector2:
	var x := 360.0 + sin(t * 0.9) * 250.0 + sin(t * 0.37) * 60.0
	var y := 220.0 + sin(t * 1.7) * 70.0
	return Vector2(x, y)

func _process(delta: float) -> void:
	if _state == "dying": return
	_t += delta * _speed
	_state_t += delta
	for i in range(_flash.size()):
		_flash[i] = maxf(0.0, _flash[i] - delta * 3.0)

	var head_pos: Vector2 = _trail[0]
	match _state:
		"weave":
			head_pos = head_pos.lerp(_head_target(_t), 1.0 - pow(0.002, delta))
			_next_dive -= delta
			if _next_dive <= 0.0:
				_state = "telegraph"
				_state_t = 0.0
				AudioManager.play_sfx("miss", 0.7)
		"telegraph":
			head_pos += Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)) # trembles with intent
			if _state_t >= 0.8:
				_state = "dive"
				_state_t = 0.0
				_dive_taps = 0
		"dive":
			head_pos.y += 1250.0 * delta
			if head_pos.y >= 1110.0:
				flood_damage.emit(14.0)
				if gameplay:
					gameplay._spawn_flood_splash(head_pos.x, accent)
					gameplay.shake_intensity = maxf(gameplay.shake_intensity, 18.0)
				AudioManager.play_sfx("bomb")
				AudioManager.vibrate("bomb")
				_state = "recover"
				_state_t = 0.0
		"recover":
			head_pos = head_pos.lerp(_head_target(_t), 1.0 - pow(0.03, delta))
			if _state_t >= 1.1:
				_state = "weave"
				_next_dive = randf_range(5.5, 8.5)

	if head_pos.distance_to(_trail[0]) > 2.0:
		_trail.push_front(head_pos)
		if _trail.size() > 600:
			_trail.resize(600)

	_place_parts()
	queue_redraw()

func _place_parts() -> void:
	var ti := 0
	var acc := 0.0
	for i in range(_parts.size()):
		var want := float(i) * SEG_SPACING
		while ti < _trail.size() - 1 and acc < want:
			acc += _trail[ti].distance_to(_trail[ti + 1])
			ti += 1
		_parts[i].position = _trail[mini(ti, _trail.size() - 1)]

func _segments_remaining() -> int:
	var n := 0
	for i in range(1, _alive.size()):
		if _alive[i]: n += 1
	return n

func _vulnerable_index() -> int:
	for i in range(_parts.size() - 1, 0, -1):
		if _alive[i]: return i
	return -1

func get_progress() -> float:
	var killed := SEG_COUNT - _segments_remaining()
	return (float(killed) + float(3 - head_hp)) / float(SEG_COUNT + 3)

func _on_part_input(_viewport: Node, event: InputEvent, _shape_idx: int, idx: int) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton): return
	if not event.is_pressed(): return
	_tap_part(idx)

func _tap_part(idx: int) -> void:
	if _state == "dying": return
	if idx == 0:
		_tap_head()
		return
	if not _alive[idx]: return
	if idx == _vulnerable_index():
		_sever_segment(idx)
	else:
		_flash[idx] = 1.0 # shielded — shrugs it off
		AudioManager.play_sfx("button", 0.5)

func _tap_head() -> void:
	# During a dive run-up, two rapid taps interrupt the attack.
	if _state == "telegraph" or _state == "dive":
		_dive_taps += 1
		_flash[0] = 1.0
		AudioManager.play_sfx("pop", 0.7)
		if _dive_taps >= 2:
			_state = "recover"
			_state_t = 0.0
			GameManager.score += 50
			if gameplay:
				gameplay._spawn_floating_text("INTERRUPTED! +50", _parts[0].position, Color(1.0, 0.9, 0.4))
				gameplay._spawn_ripple(_parts[0].position, Color(1.0, 0.9, 0.4), 1.6)
				gameplay.trigger_hit_pause(0.05)
				gameplay.update_hud()
		return
	if _segments_remaining() > 0:
		_flash[0] = 1.0 # head is armoured while it has a body
		AudioManager.play_sfx("button", 0.5)
		return
	head_hp -= 1
	_flash[0] = 1.0
	AudioManager.play_sfx("pop", 0.85)
	AudioManager.vibrate("pop")
	if gameplay:
		gameplay._spawn_particle(_parts[0].global_position, accent)
		gameplay.shake_intensity = maxf(gameplay.shake_intensity, 10.0)
	if head_hp <= 0:
		_die()

func _sever_segment(idx: int) -> void:
	_alive[idx] = false
	_parts[idx].get_child(0).set_deferred("disabled", true)
	_speed += 0.13 # it gets angrier
	AudioManager.play_sfx("pop", 1.25)
	AudioManager.vibrate("pop")
	GameManager.score += 25
	if gameplay:
		gameplay._spawn_particle(_parts[idx].global_position, accent)
		gameplay._spawn_ripple(_parts[idx].global_position, accent, 1.2)
		gameplay._spawn_floating_text("+25", _parts[idx].position, accent.lightened(0.3))
		gameplay.update_hud()
	if _segments_remaining() == 0 and gameplay:
		gameplay._spawn_floating_text("THE HEAD IS OPEN!", Vector2(360, 430), Color(1.0, 0.9, 0.4))
		AudioManager.play_sfx("power_up")

func _die() -> void:
	_state = "dying"
	AudioManager.play_sfx("bomb")
	AudioManager.vibrate("bomb")
	if gameplay:
		gameplay.shake_intensity = 30.0
		gameplay.trigger_hit_pause(0.08)
		gameplay._spawn_particle(_parts[0].global_position, accent, true)
		gameplay._spawn_ripple(_parts[0].global_position, accent, 2.4)
	defeated.emit()
	queue_free()

func _draw() -> void:
	# Connective liquid body through the alive parts
	var pts := PackedVector2Array()
	for i in range(_parts.size()):
		if _alive[i]:
			pts.append(_parts[i].position)
	if pts.size() >= 2:
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.16), SEG_RADIUS * 1.7)
		draw_polyline(pts, Color(accent.r * 0.6, accent.g * 0.6, accent.b * 0.6, 0.55), SEG_RADIUS * 0.95)

	var vul := _vulnerable_index()
	var tms := Time.get_ticks_msec() / 1000.0
	for i in range(_parts.size() - 1, -1, -1):
		if not _alive[i]: continue
		var p: Vector2 = _parts[i].position
		var r := HEAD_RADIUS if i == 0 else SEG_RADIUS
		# soft aura -> body -> core -> specular (same lighting language as the drops)
		draw_circle(p, r * 1.45, Color(accent.r, accent.g, accent.b, 0.10))
		draw_circle(p, r, accent.darkened(0.38))
		draw_circle(p, r * 0.8, accent)
		draw_circle(p + Vector2(-r * 0.28, -r * 0.34), r * 0.26, Color(1, 1, 1, 0.85))
		if i == vul:
			var pulse := 0.5 + 0.5 * sin(tms * 8.0)
			draw_arc(p, r * 1.35, 0, TAU, 24, Color(1, 1, 1, 0.45 + 0.4 * pulse), 3.5)
		if _flash[i] > 0.0:
			draw_circle(p, r * 1.12, Color(1, 1, 1, _flash[i] * 0.55))
		if i == 0:
			draw_circle(p + Vector2(-13, -7), 6.0, Color(0.03, 0.05, 0.1))
			draw_circle(p + Vector2(13, -7), 6.0, Color(0.03, 0.05, 0.1))
			if _state == "telegraph":
				draw_circle(p, HEAD_RADIUS * 1.8, Color(1.0, 0.25, 0.15, 0.22 + 0.15 * sin(_state_t * 30.0)))
			elif _segments_remaining() == 0:
				var hp_pulse := 0.5 + 0.5 * sin(tms * 6.0)
				draw_arc(p, HEAD_RADIUS * 1.5, 0, TAU, 28, Color(1, 1, 1, 0.4 + 0.4 * hp_pulse), 4.0)
