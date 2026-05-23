extends Node

var current_scene: Node = null
var root_scene: Node = null

var score: int = 0
var survival_time: float = 0.0
var is_new_high_score: bool = false

func _ready() -> void:
	pass

func change_scene(scene_path: String) -> void:
	if root_scene == null:
		push_error("GameManager.root_scene is not set!")
		return
		
	if current_scene != null:
		current_scene.queue_free()
		
	var new_scene_resource := load(scene_path)
	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()
		root_scene.add_child(current_scene)
	else:
		push_error("Failed to load scene: " + scene_path)

func start_game() -> void:
	score = 0
	survival_time = 0.0
	is_new_high_score = false
	change_scene("res://scenes/Gameplay.tscn")
	
var last_droplets_earned: int = 0

func trigger_game_over() -> void:
	var high_score: float = SaveManager.get_value("high_score", 0.0)
	is_new_high_score = float(score) > high_score
	if is_new_high_score:
		SaveManager.set_value("high_score", float(score))
		
	# Phase 6: Calculate Droplets
	var score_mult = ThemeManager.get_equipped_theme().get("score_mult", 1.0)
	last_droplets_earned = floori((score * 0.5 + survival_time * 2.0) * score_mult)
	if is_new_high_score:
		last_droplets_earned += int(100 * score_mult)
		
	var current_droplets: float = SaveManager.get_value("droplets", 0.0)
	SaveManager.set_value("droplets", current_droplets + float(last_droplets_earned))
	
	EventBus.game_over.emit()
	change_scene("res://scenes/GameOver.tscn")

func goto_main_menu() -> void:
	change_scene("res://scenes/MainMenu.tscn")
