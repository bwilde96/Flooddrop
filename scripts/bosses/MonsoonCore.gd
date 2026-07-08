extends Node2D
## The Monsoon Core — boss archetype #3 (fully procedural).
## A hovering orb that fires radial VOLLEYS of drops from behind a rotating
## shield ring. It only opens in telegraphed windows — burn it down then, or
## survive another barrage. It fires faster as it loses health.

signal defeated

const MAX_HP := 12
const CLOSED_TIME := 6.0
const OPEN_TIME := 3.4
const ORB_R := 54.0

var accent := Color(1.0, 0.5, 0.2)
var gameplay: Node = null
var volley_type := 0 # DropType fired in volleys (per-stage flavour)

var hp := MAX_HP
var _state := "closed" # closed | telegraph | open | dying
var _state_t := 0.0
var _volley_t := 1.4
var _t := 0.0
var _flash := 0.0
var _base := Vector2(360, 255)

func _ready() -> void:
	z_index = 100 # shines through blackout events (it IS the light)
	position = _base
	var area := Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ORB_R * 1.7
	cs.shape = shape
	area.add_child(cs)
	area.input_pickable = true
	area.input_event.connect(_on_input)
	add_child(area)

func _process(delta: float) -> void:
	if _state == "dying": return
	_t += delta
	_state_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	position = _base + Vector2(sin(_t * 0.7) * 44.0, sin(_t * 1.35) * 16.0)

	match _state:
		"closed":
			_volley_t -= delta
			if _volley_t <= 0.0:
				_fire_volley()
				_volley_t = lerpf(2.4, 1.2, 1.0 - float(hp) / MAX_HP) # enrages
			if _state_t >= CLOSED_TIME:
				_state = "telegraph"
				_state_t = 0.0
				AudioManager.play_sfx("power_up")
		"telegraph":
			if _state_t >= 0.7:
				_state = "open"
				_state_t = 0.0
		"open":
			if _state_t >= OPEN_TIME:
				_state = "closed"
				_state_t = 0.0
				_volley_t = 0.8
				AudioManager.play_sfx("miss", 0.8)
	queue_redraw()

func _fire_volley() -> void:
	if gameplay == null: return
	AudioManager.play_sfx("bomb", 1.4)
	gameplay.shake_intensity = maxf(gameplay.shake_intensity, 6.0)
	var n := 5
	for i in range(n):
		var spread := lerpf(-1.0, 1.0, float(i) / float(n - 1))
		var vx := spread * 340.0 + randf_range(-30.0, 30.0)
		var vy := randf_range(-520.0, -300.0) # launched up, arcs out, falls back
		gameplay.spawn_specific_drop(global_position + Vector2(spread * 30.0, 20.0), volley_type, 1.0, vy, vx)
	if gameplay.has_method("_spawn_ripple"):
		gameplay._spawn_ripple(global_position, accent, 1.5)

func get_progress() -> float:
	return float(MAX_HP - hp) / float(MAX_HP)

func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton): return
	if not event.is_pressed(): return
	_tap()

func _tap() -> void:
	if _state == "dying": return
	if _state != "open":
		_flash = 1.0 # shield clank
		AudioManager.play_sfx("button", 0.5)
		return
	hp -= 1
	_flash = 1.0
	AudioManager.play_sfx("pop", 1.1)
	AudioManager.vibrate("pop")
	GameManager.score += 15
	if gameplay:
		gameplay._spawn_particle(global_position, accent)
		gameplay._spawn_floating_text("+15", position + Vector2(0, -70), accent.lightened(0.3))
		gameplay.update_hud()
	if hp <= 0:
		_die()

func _die() -> void:
	_state = "dying"
	AudioManager.play_sfx("bomb")
	AudioManager.vibrate("bomb")
	if gameplay:
		gameplay.shake_intensity = 30.0
		gameplay.trigger_hit_pause(0.08)
		gameplay._spawn_particle(global_position, accent, true)
		gameplay._spawn_ripple(global_position, accent, 2.6)
	defeated.emit()
	queue_free()

func _draw() -> void:
	var tms := Time.get_ticks_msec() / 1000.0
	var open := _state == "open"
	# Aura + orb body (drop lighting language)
	var pulse := 0.5 + 0.5 * sin(tms * (9.0 if open else 3.0))
	draw_circle(Vector2.ZERO, ORB_R * 1.6, Color(accent.r, accent.g, accent.b, 0.10 + 0.06 * pulse))
	draw_circle(Vector2.ZERO, ORB_R, accent.darkened(0.4))
	draw_circle(Vector2.ZERO, ORB_R * 0.8, accent)
	draw_circle(Vector2(-ORB_R * 0.28, -ORB_R * 0.32), ORB_R * 0.24, Color(1, 1, 1, 0.85))
	if open:
		# White-hot exposed heart — HIT IT
		draw_circle(Vector2.ZERO, ORB_R * (0.42 + 0.08 * pulse), Color(1, 1, 1, 0.85))
		draw_arc(Vector2.ZERO, ORB_R * 1.25, 0, TAU, 32, Color(1, 1, 1, 0.35 + 0.35 * pulse), 4.0)
	else:
		# Rotating shield ring in 6 arc plates
		var flick := 1.0 if _state != "telegraph" else (0.4 + 0.6 * absf(sin(_state_t * 25.0)))
		for i in range(6):
			var a0 := tms * 1.6 + TAU * float(i) / 6.0
			draw_arc(Vector2.ZERO, ORB_R * 1.32, a0, a0 + 0.72, 10,
				Color(0.6, 0.9, 1.0, 0.85 * flick), 5.0)
		draw_arc(Vector2.ZERO, ORB_R * 1.32, 0, TAU, 40, Color(0.6, 0.9, 1.0, 0.16 * flick), 12.0)
	# HP pips
	for i in range(MAX_HP):
		var pa := -PI / 2.0 + TAU * float(i) / MAX_HP
		var pc := Color(1, 1, 1, 0.8) if i < hp else Color(1, 1, 1, 0.15)
		draw_circle(Vector2(cos(pa), sin(pa)) * ORB_R * 1.55, 3.5, pc)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, ORB_R * 1.1, Color(1, 1, 1, _flash * 0.5))
