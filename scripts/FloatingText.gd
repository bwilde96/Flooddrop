extends Node2D

@onready var label: Label = $Label

@export var duration: float = 0.8
@export var float_distance: float = 60.0

var _pool: Node = null
var _tween: Tween = null

func _ready() -> void:
	z_index = 200
	if not _pool:
		start_animation()

func on_pool_activate(pool: Node) -> void:
	_pool = pool
	visible = true
	modulate.a = 1.0
	if _tween and _tween.is_valid():
		_tween.kill()

func on_pool_deactivate() -> void:
	visible = false
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

func start_animation() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - float_distance, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	_tween.chain().tween_callback(func():
		if _pool: _pool.return_floating_text(self)
		else: queue_free()
	)
