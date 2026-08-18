extends Node

var player_status_path = "res://DATA/STATUS.json"
var player_inventory_path = "res://DATA/INVENTORY.json"
@export var autosave_enabled : bool
@export var daytime : bool

@export_category("All Inventory Items")
@export var permanent_items : Dictionary
@export var removable_items : Dictionary

@export_category("Inventory Menu")
@export var inventory_ui : Control
@export var inventory_back : Button
@export var item_list : VBoxContainer
var open_inventory : bool

@export_category("Pause Menu")
@export var menu_ui : Control
@export var save_game : Button
@export var inventory : Button
@export var options : Button
@export var exit_game : Button
@export var dither_slider : HSlider
@export var dither_pattern_slider : HSlider
var saving : bool
var pause_game : bool
var open_menu : bool 
var controller_used : bool 

func _ready():
	menu_ui.visible = false
	inventory_ui.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func _input(event: InputEvent) -> void:
	if(Input.is_action_just_pressed("pause")):
		pause_game = !pause_game
	if event is InputEventMouseMotion:
		controller_used = false

func _process(delta):
	if(pause_game && !menu_ui.visible && !open_menu):
		menu_ui.visible = true
		open_menu = true
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	if(!pause_game && menu_ui.visible || !pause_game && inventory_ui.visible):
		menu_ui.visible = false
		open_menu = false
		inventory_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if(save_game.button_pressed):
		saving = true
	if (exit_game.button_pressed):
		_quit_game()
	if(inventory.button_pressed):
		inventory_ui.visible = true
		menu_ui.visible = false
		_update_inventory()
	if(inventory_back.button_pressed):
		inventory_ui.visible = false
		menu_ui.visible = true
	#if(Input.is_action_just_pressed("cam_down") || Input.is_action_just_pressed("cam_up") || Input.is_action_just_pressed("cam_left") || Input.is_action_just_pressed("cam_right")):
		#controller_used = true

func _update_inventory():
	var inventory_data = _JSON_to_dictionary(player_inventory_path)
	for item in inventory_data.Removable.size():
		print(inventory_data.Removable[item])
		var item_add = Label.new()
		item_add.text = inventory_data.Removable[item]
		item_list.add_child(item_add)

func _JSON_to_dictionary(data_path:String): #returns true if JSON contains key
	var file = FileAccess.get_file_as_string(data_path)
	var dict = JSON.parse_string(file)
	return dict

func _save_JSON_file(data_path:String, game_data):
	var json = JSON.stringify(game_data, "\t")
	var file = FileAccess.open(data_path, FileAccess.WRITE)
	file.store_line(json)
	file.close()

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
