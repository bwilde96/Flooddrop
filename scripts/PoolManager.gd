class_name PoolManager
extends Node

var drop_scene: PackedScene
var floating_text_scene: PackedScene
var container: Node2D

var _available_drops: Array[Node] = []
var _active_drops: Array[Node] = []

var _available_texts: Array[Node] = []
var _active_texts: Array[Node] = []

var drop_prewarm: int = 20
var text_prewarm: int = 15

var particle_scene: PackedScene
var _available_particles: Array[Node] = []
var _active_particles: Array[Node] = []
var particle_prewarm: int = 15

func init(d_scene: PackedScene, t_scene: PackedScene, p_scene: PackedScene, cont: Node2D) -> void:
	drop_scene = d_scene
	floating_text_scene = t_scene
	particle_scene = p_scene
	container = cont
	
	for i in range(drop_prewarm):
		var d = drop_scene.instantiate()
		container.add_child(d)
		_deactivate_drop(d)
		_available_drops.append(d)
		
	for i in range(text_prewarm):
		var t = floating_text_scene.instantiate()
		container.add_child(t)
		_deactivate_text(t)
		_available_texts.append(t)
		
	for i in range(particle_prewarm):
		var p = particle_scene.instantiate()
		container.add_child(p)
		_deactivate_particle(p)
		_available_particles.append(p)

func get_drop() -> Node:
	var d: Node
	if _available_drops.size() > 0:
		d = _available_drops.pop_back()
	else:
		d = drop_scene.instantiate()
		container.add_child(d)
	
	_active_drops.append(d)
	_activate_drop(d)
	return d

func return_drop(d: Node) -> void:
	if d in _active_drops:
		_active_drops.erase(d)
	_deactivate_drop(d)
	_available_drops.append(d)

func get_floating_text() -> Node:
	var t: Node
	if _available_texts.size() > 0:
		t = _available_texts.pop_back()
	else:
		t = floating_text_scene.instantiate()
		container.add_child(t)
	
	_active_texts.append(t)
	_activate_text(t)
	return t

func return_floating_text(t: Node) -> void:
	if t in _active_texts:
		_active_texts.erase(t)
	_deactivate_text(t)
	_available_texts.append(t)

func get_particle() -> Node:
	var p: Node
	if _available_particles.size() > 0:
		p = _available_particles.pop_back()
	else:
		p = particle_scene.instantiate()
		container.add_child(p)
	
	_active_particles.append(p)
	_activate_particle(p)
	return p

func return_particle(p: Node) -> void:
	if p in _active_particles:
		_active_particles.erase(p)
	_deactivate_particle(p)
	_available_particles.append(p)

func _activate_drop(d: Node) -> void:
	if d.has_method("on_pool_activate"):
		d.on_pool_activate(self)

func _deactivate_drop(d: Node) -> void:
	if d.has_method("on_pool_deactivate"):
		d.on_pool_deactivate()

func _activate_text(t: Node) -> void:
	if t.has_method("on_pool_activate"):
		t.on_pool_activate(self)

func _deactivate_text(t: Node) -> void:
	if t.has_method("on_pool_deactivate"):
		t.on_pool_deactivate()

func _activate_particle(p: Node) -> void:
	p.pool_ref = self
	p.visible = true

func _deactivate_particle(p: Node) -> void:
	p.visible = false
	p.emitting = false

func get_debug_info() -> Dictionary:
	return {
		"active_drops": _active_drops.size(),
		"pooled_drops": _available_drops.size(),
		"active_texts": _active_texts.size(),
		"pooled_texts": _available_texts.size(),
		"active_particles": _active_particles.size(),
		"pooled_particles": _available_particles.size()
	}
