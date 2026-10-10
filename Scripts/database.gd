extends Node

@export var autosave_enabled : bool
@export var daytime : bool

@export_category("Multiplayer")
@export var players : Array[RigidBody3D]

@export_category("All Inventory Items")
@export var interactable_items : Dictionary

@export_category("Pause Menu")
@export var menu_ui : Control
@export var save_game : Button
@export var options : Button
@export var exit_game : Button
@export var dither_slider : HSlider
@export var dither_pattern_slider : HSlider
var saving : bool
var pause_game : bool
var open_menu : bool 
var controller_used : bool 

@export_category("Data")
var save_manager
var active_player
var world_interactables


func _ready():
	#disable menus
	menu_ui.visible = false
	
	#confine mouse
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	
	#assign save manager
	save_manager = get_node("/root/SaveManager")
	
	#store interactables

func _input(event: InputEvent) -> void:
	#Pausing
	if(Input.is_action_just_pressed("pause")):
		pause_game = !pause_game
	#Controller Check
	if event is InputEventMouseMotion:
		controller_used = false

func _process(delta):
#region UI Stuff
	if(pause_game && !menu_ui.visible && !open_menu):
		menu_ui.visible = true
		open_menu = true
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	if(!pause_game && menu_ui.visible):
		menu_ui.visible = false
		open_menu = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if(save_game.button_pressed):
		saving = true
		save_manager.save_game()
	if (exit_game.button_pressed):
		_quit_game()
#endregion

	#if(Input.is_action_just_pressed("cam_down") || Input.is_action_just_pressed("cam_up") || Input.is_action_just_pressed("cam_left") || Input.is_action_just_pressed("cam_right")):
		#controller_used = true

func _check_raycast(ray : RayCast3D, group : String):
	if(ray.collide_with_bodies):
		var collision = ray.get_collider()
		if(collision != null && collision.is_in_group(group)):
			return true
	if(ray.collide_with_areas):
		var collision = ray.get_collider()
		if(collision != null && collision.is_in_group(group)):
			return true

func _quit_game():
	get_tree().quit()

func _on_save_pressed():
	save_manager.save_data.player = active_player._save_player_data()
	save_manager.save_game()
	pass # Replace with function body.
