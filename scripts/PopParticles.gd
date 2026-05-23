extends CPUParticles2D

var _timer: float = 0.0
var _active: bool = false
var pool_ref = null

func _process(delta: float) -> void:
	if not _active: return
	
	_timer -= delta
	if _timer <= 0:
		_active = false
		if pool_ref:
			pool_ref.return_particle(self)
		else:
			queue_free()

func play_effect(col: Color, is_bomb: bool = false, is_rainbow: bool = false) -> void:
	self.color = col
	if is_bomb:
		self.amount = 30
		self.initial_velocity_min = 300.0
		self.initial_velocity_max = 600.0
		self.scale_amount_min = 8.0
		self.scale_amount_max = 16.0
	elif is_rainbow:
		self.amount = 40
		self.initial_velocity_min = 200.0
		self.initial_velocity_max = 400.0
		self.scale_amount_min = 6.0
		self.scale_amount_max = 12.0
		# Rainbow will just rely on the color passed in or we can randomize it in process if we want
	else:
		self.amount = 12
		self.initial_velocity_min = 100.0
		self.initial_velocity_max = 200.0
		self.scale_amount_min = 4.0
		self.scale_amount_max = 8.0
		
	self.emitting = true
	_active = true
	_timer = self.lifetime + 0.1
