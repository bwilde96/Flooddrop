@tool
extends SceneTree
func _init():
    var shader = load("res://assets/crashing_wave.gdshader")
    if shader:
        print("Shader loaded successfully!")
    else:
        print("Failed to load shader!")
    quit()
