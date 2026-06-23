extends Node

var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 10
var sounds: Dictionary = {}

var sfx_volume: float = 1.0
var bgm_volume: float = 0.8
var haptics_enabled: bool = true

func _ready() -> void:
	_load_settings()
	
	for i in range(max_sfx_players):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	_generate_placeholder_sounds()

func _load_settings() -> void:
	var settings = SaveManager.get_value("settings", {})
	sfx_volume = settings.get("sfx_volume", 1.0)
	bgm_volume = settings.get("bgm_volume", 0.8)
	haptics_enabled = settings.get("haptics_enabled", true)
	_apply_volumes()

func update_settings(sfx: float, bgm: float, haptics: bool) -> void:
	sfx_volume = sfx
	bgm_volume = bgm
	haptics_enabled = haptics
	
	var settings = SaveManager.get_value("settings", {})
	settings["sfx_volume"] = sfx_volume
	settings["bgm_volume"] = bgm_volume
	settings["haptics_enabled"] = haptics_enabled
	SaveManager.set_value("settings", settings)
	
	_apply_volumes()

func _apply_volumes() -> void:
	# Convert linear 0.0 - 1.0 to dB
	var db = linear_to_db(sfx_volume) if sfx_volume > 0.01 else -80.0
	for p in sfx_players:
		p.volume_db = db

func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if sfx_volume < 0.01: return
	if not sounds.has(sfx_name): return
	
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[sfx_name]
			p.pitch_scale = pitch
			p.play()
			return
			
	# If all playing, override the oldest (index 0)
	sfx_players[0].stream = sounds[sfx_name]
	sfx_players[0].pitch_scale = pitch
	sfx_players[0].play()

func vibrate(type: String) -> void:
	if not haptics_enabled: return
	
	var ms = 0
	match type:
		"pop": ms = 10
		"miss": ms = 40
		"bomb", "rainbow": ms = 60
		"game_over": ms = 100
		
	if ms > 0:
		Input.vibrate_handheld(ms)

# --- Procedural Audio Generation for Ultra-Lightweight Placeholders ---
func _generate_placeholder_sounds() -> void:
	sounds["pop"] = _create_tone(800.0, 0.05, 0.5)
	sounds["miss"] = _create_tone(150.0, 0.15, 0.3)
	sounds["bomb"] = _create_noise(0.2)
	sounds["power_up"] = _create_tone(600.0, 0.1, 0.5)
	sounds["rainbow"] = _create_arpeggio([400, 500, 600, 800], 0.3)
	sounds["button"] = _create_tone(400.0, 0.05, 0.3)
	sounds["game_over"] = _create_tone(100.0, 0.5, 0.5)

func _create_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	var phase = 0.0
	var phase_inc = freq / sample_rate * TAU
	
	for i in range(total_samples):
		# Envelope (fast attack, linear decay)
		var env = 1.0 - (float(i) / total_samples)
		var val = sin(phase) * env * volume
		var sample = int(clamp(val * 32767.0, -32768, 32767))
		
		data.encode_s16(i * 2, sample)
		phase += phase_inc
		
	wav.data = data
	return wav

func _create_noise(duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var env = 1.0 - (float(i) / total_samples)
		var val = randf_range(-1.0, 1.0) * env * 0.4
		var sample = int(clamp(val * 32767.0, -32768, 32767))
		data.encode_s16(i * 2, sample)
		
	wav.data = data
	return wav

func _create_arpeggio(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	var phase = 0.0
	var steps = freqs.size()
	
	for i in range(total_samples):
		var step_idx = min(int((float(i) / total_samples) * steps), steps - 1)
		var freq = float(freqs[step_idx])
		var phase_inc = freq / sample_rate * TAU
		
		var env = 1.0 - (float(i) / total_samples)
		var val = sin(phase) * env * 0.4
		var sample = int(clamp(val * 32767.0, -32768, 32767))
		
		data.encode_s16(i * 2, sample)
		phase += phase_inc
		
	wav.data = data
	return wav
