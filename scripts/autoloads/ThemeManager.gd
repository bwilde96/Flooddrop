extends Node

const THEMES = {
	"main_menu": {
		"name": "Main Menu", "price": 0,
		"drop_color": Color(1, 1, 1, 1), "flood_color": Color(0, 0, 0, 0), "bg_color": Color(0, 0, 0, 1),
	},
	"water": {
		"name": "Water", "price": 0,
		"drop_color": Color(0.35, 0.78, 0.98, 1.0), "flood_color": Color(0.19, 0.38, 0.84, 0.8), "bg_color": Color(0.10, 0.10, 0.15, 1.0),
		"shader_type": 0, "speed_mult": 1.0, "form_mult": 1.0, "damage_mult": 1.0, "size_mult": 1.0, "score_mult": 1.0
	},
	"lava": {
		"name": "Lava", "price": 250,
		"drop_color": Color(0.9, 0.4, 0.1, 1.0), "flood_color": Color(0.8, 0.2, 0.0, 0.8), "bg_color": Color(0.15, 0.05, 0.05, 1.0),
		"shader_type": 1, "speed_mult": 0.8, "form_mult": 1.5, "damage_mult": 2.0, "size_mult": 1.0, "score_mult": 1.0
	},
	"slime": {
		"name": "Slime", "price": 500,
		"drop_color": Color(0.4, 0.9, 0.2, 1.0), "flood_color": Color(0.2, 0.7, 0.1, 0.8), "bg_color": Color(0.05, 0.15, 0.05, 1.0),
		"shader_type": 2, "speed_mult": 1.5, "form_mult": 1.0, "damage_mult": 1.0, "size_mult": 1.0, "score_mult": 1.0, "spawn_interval_mult": 1.8
	},
	"acid": {
		"name": "Acid", "price": 750,
		"drop_color": Color(0.8, 1.0, 0.1, 1.0), "flood_color": Color(0.6, 0.9, 0.0, 0.8), "bg_color": Color(0.1, 0.15, 0.0, 1.0),
		"shader_type": 3, "speed_mult": 1.3, "form_mult": 0.5, "damage_mult": 0.5, "size_mult": 1.0, "score_mult": 1.0
	},
	"rainbow": {
		"name": "Rainbow", "price": 1200,
		"drop_color": Color(0.9, 0.8, 0.9, 1.0), "flood_color": Color(0.8, 0.4, 0.8, 0.8), "bg_color": Color(0.1, 0.0, 0.1, 1.0),
		"shader_type": 4, "speed_mult": 1.0, "form_mult": 1.0, "damage_mult": 1.0, "size_mult": 1.0, "score_mult": 1.0
	},
	"galaxy": {
		"name": "Galaxy", "price": 1800,
		"drop_color": Color(0.7, 0.3, 0.9, 1.0), "flood_color": Color(0.4, 0.1, 0.6, 0.8), "bg_color": Color(0.05, 0.05, 0.2, 1.0),
		"shader_type": 5, "speed_mult": 0.5, "form_mult": 1.0, "damage_mult": 3.0, "size_mult": 1.5, "score_mult": 1.0
	},
	"gold": {
		"name": "Gold", "price": 2500,
		"drop_color": Color(1.0, 0.9, 0.2, 1.0), "flood_color": Color(0.8, 0.7, 0.1, 0.8), "bg_color": Color(0.15, 0.13, 0.05, 1.0),
		"shader_type": 6, "speed_mult": 1.0, "form_mult": 1.0, "damage_mult": 1.0, "size_mult": 1.0, "score_mult": 2.0
	},
	"neon_plasma": {
		"name": "Neon Plasma", "price": 3500,
		"drop_color": Color(0.1, 1.0, 0.8, 1.0), "flood_color": Color(0.0, 0.8, 0.6, 0.8), "bg_color": Color(0.0, 0.15, 0.1, 1.0),
		"shader_type": 7, "speed_mult": 1.0, "form_mult": 1.0, "damage_mult": 0.5, "size_mult": 1.0, "score_mult": 1.0
	}
}

func get_theme(id: String) -> Dictionary:
	if THEMES.has(id):
		return THEMES[id]
	return THEMES["water"]

func get_equipped_theme_id() -> String:
	return SaveManager.get_value("equipped_theme", "water")
	
func get_equipped_theme() -> Dictionary:
	return get_theme(get_equipped_theme_id())

func get_droplets() -> int:
	var dr = SaveManager.get_value("droplets", 0.0)
	return int(dr)

func equip_theme(id: String) -> void:
	if not THEMES.has(id): return
	SaveManager.set_value("equipped_theme", id)
