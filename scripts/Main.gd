extends Node

func _ready() -> void:
	GameManager.root_scene = self
	GameManager.goto_main_menu()
