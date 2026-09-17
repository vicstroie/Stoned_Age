# POLYBLOCKS | NATUREBLOCKS | DEMO
# bukkbeek.github.io

extends Node3D

const ENVIRONMENTS: Array[PackedScene] = [
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_default.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_alien.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_atmospheric.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_cartoon.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_cemetery.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_dune.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_night.tscn"),
	preload("res://PolyBlocks/NatureBlocks/assets/environments/nb_env_sunset.tscn"),
]

var _current_env_instance: Node = null


func _ready() -> void:
	switch_environment(0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	match event.keycode:
		KEY_1, KEY_KP_1:
			switch_environment(0)
		KEY_2, KEY_KP_2:
			switch_environment(1)
		KEY_3, KEY_KP_3:
			switch_environment(2)
		KEY_4, KEY_KP_4:
			switch_environment(3)
		KEY_5, KEY_KP_5:
			switch_environment(4)
		KEY_6, KEY_KP_6:
			switch_environment(5)
		KEY_7, KEY_KP_7:
			switch_environment(6)
		KEY_8, KEY_KP_8:
			switch_environment(7)


func switch_environment(index: int) -> void:
	if index < 0 or index >= ENVIRONMENTS.size():
		return

	if is_instance_valid(_current_env_instance):
		_current_env_instance.queue_free()
		_current_env_instance = null

	var env_scene: PackedScene = ENVIRONMENTS[index]
	if env_scene != null:
		_current_env_instance = env_scene.instantiate()
		add_child(_current_env_instance)
