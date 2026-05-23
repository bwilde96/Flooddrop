extends Node

const SAVE_PATH := "user://save_data.json"
const SAVE_BAK_PATH := "user://save_data.json.bak"
const CURRENT_VERSION := 1

var save_data: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Save file not found. Creating default.")
		reset_to_default()
		save_data_to_disk()
		return
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(content)
	
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message())
		recover_save()
		return
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		print("Save data is not a dictionary.")
		recover_save()
		return
		
	if not validate_save(data):
		print("Save validation failed.")
		recover_save()
		return
		
	save_data = data
	print("Save loaded successfully.")

func recover_save() -> void:
	print("Attempting recovery from backup...")
	if FileAccess.file_exists(SAVE_BAK_PATH):
		var dir := DirAccess.open("user://")
		dir.copy(SAVE_BAK_PATH, SAVE_PATH)
		
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and typeof(json.get_data()) == TYPE_DICTIONARY and validate_save(json.get_data()):
			save_data = json.get_data()
			print("Recovery successful.")
			return
	
	print("Recovery failed. Resetting to defaults.")
	reset_to_default()
	save_data_to_disk()

func validate_save(data: Dictionary) -> bool:
	if not data.has("version") or typeof(data["version"]) != TYPE_FLOAT:
		return false
		
	if not data.has("high_score") or typeof(data["high_score"]) != TYPE_FLOAT:
		data["high_score"] = 0.0
		
	if not data.has("droplets") or typeof(data["droplets"]) != TYPE_FLOAT:
		data["droplets"] = 0.0
		
	if not data.has("upgrades") or typeof(data["upgrades"]) != TYPE_DICTIONARY:
		data["upgrades"] = {
			"freeze_duration": 1,
			"bomb_radius": 1,
			"drain_amount": 1,
			"shield_capacity": 1
		}
		
	if not data.has("unlocked_abilities") or typeof(data["unlocked_abilities"]) != TYPE_ARRAY:
		data["unlocked_abilities"] = ["time_warp"]
		
	if not data.has("equipped_ability") or typeof(data["equipped_ability"]) != TYPE_STRING:
		data["equipped_ability"] = "time_warp"
		
	var valid_abilities = ["time_warp", "evaporation", "tidal_wave", "midas_touch", "auto_turret"]
	if not (data["equipped_ability"] in valid_abilities):
		data["equipped_ability"] = "time_warp"
		
	var clean_abilities = []
	for a in data["unlocked_abilities"]:
		if typeof(a) == TYPE_STRING and (a in valid_abilities) and not (a in clean_abilities):
			clean_abilities.append(a)
	if "time_warp" not in clean_abilities:
		clean_abilities.append("time_warp")
	data["unlocked_abilities"] = clean_abilities
		
	if not data.has("settings") or typeof(data["settings"]) != TYPE_DICTIONARY:
		data["settings"] = {
			"sfx_volume": 1.0,
			"bgm_volume": 0.8,
			"haptics_enabled": true
		}
	else:
		var settings = data["settings"]
		if not settings.has("sfx_volume") or typeof(settings["sfx_volume"]) != TYPE_FLOAT:
			settings["sfx_volume"] = 1.0
		if not settings.has("bgm_volume") or typeof(settings["bgm_volume"]) != TYPE_FLOAT:
			settings["bgm_volume"] = 0.8
		if not settings.has("haptics_enabled") or typeof(settings["haptics_enabled"]) != TYPE_BOOL:
			settings["haptics_enabled"] = true
			
	return true

func reset_to_default() -> void:
	save_data = {
		"version": float(CURRENT_VERSION),
		"high_score": 0.0,
		"droplets": 0.0,
		"upgrades": {
			"freeze_duration": 1,
			"bomb_radius": 1,
			"drain_amount": 1,
			"shield_capacity": 1
		},
		"unlocked_abilities": ["time_warp"],
		"equipped_ability": "time_warp",
		"settings": {
			"sfx_volume": 1.0,
			"bgm_volume": 0.8,
			"haptics_enabled": true
		}
	}

func save_data_to_disk() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		dir.copy(SAVE_PATH, SAVE_BAK_PATH)
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

func get_value(key: String, default_val = null):
	return save_data.get(key, default_val)

func set_value(key: String, value) -> void:
	save_data[key] = value
	save_data_to_disk()
