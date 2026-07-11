extends Node2D
## The Rainfather — the water stage's own boss (fully procedural).
## A storm cloud that cannot be touched. It beads a giant glowing RAINHEART
## from its belly; burst it with 3 taps before it lands, six times, to kill
## the storm at its source. Wounded, it answers with telegraphed lightning.

signal defeated
signal flood_damage(amount: float)

const MAX_HEARTS := 6
const BEAD_HP := 3
const CLOUD_Y := 150.0

var accent := Color(0.35, 0.78, 0.98)
var gameplay: Node = null

var hearts_burst := 0
var _state := "gather" # gather | charge | fall | dying
var _state_t := 0.0
var _t := 0.0
var _cloud_x := 360.0
var _flash := 0.0
var _rain_t := 3.0
var _lightning_t := 7.0
var _lightning_x := -1.0
var _lightning_warn := 0.0

var _bead: Area2D
var _bead_r := 0.0
var _bead_hp := BEAD_HP
var _bead_pos := Vector2.ZERO
var _puffs: Array = [] # cloud lobes: [offset: Vector2, radius: float]

func _ready() -> void:
	z_index = 90
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(7):
		var fx := lerpf(-215.0, 215.0, float(i) / 6.0)
		_puffs.append([Vector2(fx, rng.randf_range(-14.0, 18.0)), rng.randf_range(58.0, 92.0)])

	_bead = Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 62.0
	cs.shape = shape
	_bead.add_child(cs)
	_bead.input_pickable = true
	_bead.input_event.connect(_on_bead_input)
	_bead.get_child(0).set_deferred("disabled", true)
	add_child(_bead)

func _process(delta: float) -> void:
	if _state == "dying": return
	_t += delta
	_state_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_cloud_x = 360.0 + sin(_t * 0.45) * 130.0

	# Ambient rain pressure, denser as it weakens
	_rain_t -= delta
	if _rain_t <= 0.0:
		_rain_t = lerpf(5.0, 3.2, float(hearts_burst) / MAX_HEARTS)
		_rain_burst()

	# Lightning once wounded
	if hearts_burst >= 2:
		_lightning_t -= delta
		if _lightning_t <= 0.0 and _lightning_x < 0.0:
			_lightning_x = randf_range(90.0, 630.0)
			_lightning_warn = 0.75
			AudioManager.play_sfx("miss", 0.6)
		if _lightning_x >= 0.0:
			_lightning_warn -= delta
			if _lightning_warn <= 0.0:
				_strike_lightning()

	match _state:
		"gather":
			if _state_t >= 2.2:
				_state = "charge"
				_state_t = 0.0
				_bead_r = 10.0
				AudioManager.play_sfx("power_up", 0.7)
		"charge":
			_bead_r = lerpf(10.0, 46.0, minf(1.0, _state_t / 2.2))
			_bead_pos = Vector2(_cloud_x, CLOUD_Y + 74.0 + _bead_r * 0.5)
			if _state_t >= 2.2:
				_state = "fall"
				_state_t = 0.0
				_bead_hp = BEAD_HP
				_bead.get_child(0).set_deferred("disabled", false)
				AudioManager.play_sfx("pop", 0.6)
		"fall":
			_bead_pos.y += (105.0 + 22.0 * float(hearts_burst)) * delta
			_bead_pos.x += sin(_t * 2.2) * 30.0 * delta
			if _bead_pos.y >= 1080.0:
				_bead_lands()
	_bead.position = _bead_pos
	queue_redraw()

func _rain_burst() -> void:
	if gameplay == null: return
	for i in range(3):
		var x: float = clampf(_cloud_x + randf_range(-190.0, 190.0), 70.0, 650.0)
		gameplay.spawn_specific_drop(Vector2(x, CLOUD_Y + 90.0), 0, 1.0, randf_range(140.0, 240.0))

func _strike_lightning() -> void:
	_lightning_t = randf_range(6.0, 9.0)
	var x := _lightning_x
	_lightning_x = -1.0
	AudioManager.play_sfx("bomb", 1.5)
	if gameplay:
		gameplay.shake_intensity = maxf(gameplay.shake_intensity, 10.0)
		for i in range(2):
			gameplay.spawn_specific_drop(Vector2(x + randf_range(-24.0, 24.0), 240.0 + i * 130.0), 0, 1.0, randf_range(320.0, 430.0))
	# Bolt flash: jagged line that fades fast
	var bolt := Line2D.new()
	bolt.default_color = Color(0.9, 0.97, 1.0, 0.95)
	bolt.width = 7.0
	var y := 210.0
	bolt.add_point(Vector2(x, y))
	while y < 1150.0:
		y += randf_range(90.0, 150.0)
		bolt.add_point(Vector2(x + randf_range(-34.0, 34.0), y))
	add_child(bolt)
	var tw := create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.28)
	tw.tween_callback(bolt.queue_free)

func _bead_lands() -> void:
	_bead.get_child(0).set_deferred("disabled", true)
	flood_damage.emit(16.0)
	if gameplay:
		gameplay._spawn_flood_splash(_bead_pos.x, accent)
		gameplay.shake_intensity = maxf(gameplay.shake_intensity, 16.0)
	AudioManager.play_sfx("bomb")
	AudioManager.vibrate("bomb")
	_state = "gather"
	_state_t = 0.0
	_bead_r = 0.0

func get_progress() -> float:
	var bead_part: float = float(BEAD_HP - _bead_hp) / float(BEAD_HP * MAX_HEARTS)
	return float(hearts_burst) / MAX_HEARTS + maxf(0.0, bead_part)

func _on_bead_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton): return
	if not event.is_pressed(): return
	_tap_bead()

func _tap_bead() -> void:
	if _state != "fall": return
	_bead_hp -= 1
	AudioManager.play_sfx("pop", 1.1 + 0.15 * float(BEAD_HP - _bead_hp))
	AudioManager.vibrate("pop")
	if gameplay:
		gameplay._spawn_particle(_bead.global_position, accent)
	if _bead_hp > 0:
		_bead_r *= 0.88 # it visibly shrinks with each hit
		return
	# Heart burst: the storm is wounded
	hearts_burst += 1
	_flash = 1.0
	_bead.get_child(0).set_deferred("disabled", true)
	AudioManager.play_sfx("bomb", 1.2)
	AudioManager.vibrate("bomb")
	GameManager.score += 40
	if gameplay:
		gameplay._spawn_ripple(_bead.global_position, accent, 1.8)
		gameplay._spawn_particle(_bead.global_position, accent, true)
		gameplay._spawn_floating_text("+40  %d/%d" % [hearts_burst, MAX_HEARTS], _bead.position, accent.lightened(0.3))
		gameplay.shake_intensity = maxf(gameplay.shake_intensity, 14.0)
		gameplay.trigger_hit_pause(0.04)
		gameplay.update_hud()
	_state = "gather"
	_state_t = 0.0
	_bead_r = 0.0
	if hearts_burst >= MAX_HEARTS:
		_die()

func _die() -> void:
	_state = "dying"
	AudioManager.play_sfx("bomb")
	AudioManager.vibrate("bomb")
	if gameplay:
		gameplay.shake_intensity = 30.0
		gameplay.trigger_hit_pause(0.08)
		for p in _puffs:
			gameplay._spawn_particle(Vector2(_cloud_x, CLOUD_Y) + p[0], accent, true)
		gameplay._spawn_ripple(Vector2(_cloud_x, CLOUD_Y), accent, 2.8)
	defeated.emit()
	queue_free()

func _draw() -> void:
	var c := Vector2(_cloud_x, CLOUD_Y)
	var wound := float(hearts_burst) / MAX_HEARTS

	# Storm cloud: layered lobes, darkening as it weakens, pale rim on top
	for p in _puffs:
		var pp: Vector2 = c + p[0] + Vector2(0, sin(_t * 1.3 + p[0].x * 0.02) * 5.0)
		var r: float = p[1]
		draw_circle(pp, r * 1.25, Color(accent.r, accent.g, accent.b, 0.06))
		draw_circle(pp, r, Color(0.10, 0.14, 0.22, 0.97).lerp(Color(0.16, 0.10, 0.14, 0.97), wound))
		draw_circle(pp + Vector2(-r * 0.2, -r * 0.3), r * 0.66, Color(0.22, 0.30, 0.44, 0.9))
		draw_circle(pp + Vector2(-r * 0.3, -r * 0.42), r * 0.3, Color(0.55, 0.68, 0.85, 0.5))
	# Glowering eyes
	draw_circle(c + Vector2(-46, 6), 9.0, Color(0.6, 0.9, 1.0, 0.95))
	draw_circle(c + Vector2(46, 6), 9.0, Color(0.6, 0.9, 1.0, 0.95))
	if _flash > 0.0:
		for p in _puffs:
			draw_circle(c + p[0], p[1], Color(1, 1, 1, _flash * 0.35))

	# The rainheart
	if _state == "charge" or _state == "fall":
		var bp := _bead_pos if _state == "fall" else Vector2(_cloud_x, CLOUD_Y + 74.0 + _bead_r * 0.5)
		var pulse := 0.5 + 0.5 * sin(_t * 7.0)
		draw_circle(bp, _bead_r * 1.5, Color(accent.r, accent.g, accent.b, 0.14 + 0.08 * pulse))
		draw_circle(bp, _bead_r, accent.darkened(0.3))
		draw_circle(bp, _bead_r * 0.78, accent.lightened(0.1))
		draw_circle(bp + Vector2(-_bead_r * 0.28, -_bead_r * 0.32), _bead_r * 0.24, Color(1, 1, 1, 0.9))
		if _state == "charge":
			# Umbilical drip from the belly while it swells
			draw_line(Vector2(_cloud_x, CLOUD_Y + 55.0), bp + Vector2(0, -_bead_r * 0.7),
				Color(accent.r, accent.g, accent.b, 0.5), 7.0)
		else:
			# Falling: white target ring — BURST IT
			draw_arc(bp, _bead_r * 1.3, 0, TAU, 26, Color(1, 1, 1, 0.4 + 0.35 * pulse), 3.5)

	# Lightning warning column
	if _lightning_x >= 0.0 and _lightning_warn > 0.0:
		var blink := 0.5 + 0.5 * sin(_t * 22.0)
		draw_rect(Rect2(_lightning_x - 26.0, 210.0, 52.0, 940.0), Color(1.0, 0.95, 0.6, 0.10 + 0.10 * blink))
		draw_line(Vector2(_lightning_x - 26.0, 210.0), Vector2(_lightning_x - 26.0, 1150.0), Color(1.0, 0.95, 0.6, 0.35 * blink), 2.0)
		draw_line(Vector2(_lightning_x + 26.0, 210.0), Vector2(_lightning_x + 26.0, 1150.0), Color(1.0, 0.95, 0.6, 0.35 * blink), 2.0)
