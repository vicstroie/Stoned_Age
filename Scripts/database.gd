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
##used to cycle through JSONS based on what world/game the player is entering
var all_save_data
##used to sync the worlds when entering a game
var host_save_data
##current player active on this device
var active_player
##all players in the scene
var all_players
##stores the current amount of players compared to the amount of children in the player container
var player_count
##the node that is parent to all the players
var player_container

#TODO figure out a more efficient way to store all world data
##all interactable objects active in this world
var world_interactables
##all interactables to be removed in this world upon loading in
var remove_interactables : Array
##all interactables to be placed upon loading in
var place_interactables #TODO placement logic

func _ready():
	#disable menus
	menu_ui.visible = false
	
	#confine mouse
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	
	#assign save manager
	save_manager = get_node("/root/SaveManager")
	
	#store interactables

func _input(event: InputEvent) -> void:
	#Controller Check
	if event is InputEventMouseMotion:
		controller_used = false

func _store_world_data():
	world_interactables = get_tree().get_nodes_in_group("Interactable")
	_update_player_ref()
	for i in all_players.size():
		if all_players[i].is_host:
			print(str(all_players[i].multiplayer_name.text) + " is the host")
			host_save_data = all_players[i].game_save_data
			if !active_player.is_host:
				active_player.game_save_data.world = host_save_data.world
		else:
			all_save_data.append(all_players[i].game_save_data)
	_sync_worlds()

func _sync_worlds():
	#sync what objects have been removed from host world
	for o in host_save_data.world["Remove Object Global"]:
		if not o in remove_interactables:
			remove_interactables.append(o)
	
	#sync what objects have been removed from main world
	if (all_save_data != null):
		for player_save in all_save_data:
			for i in player_save.world["Remove Object Global"]:
				if not i in remove_interactables:
					remove_interactables.append(i)
	
	#set world removable to everything ALL players have removed
	active_player.game_save_data.world["Remove Object Global"] = remove_interactables 
	
	#REMOVE REMOVABLE
	for obj in world_interactables:
		for remove in remove_interactables:
			if (obj != null):
				if remove == obj.name:
					obj.pick_up()


##TODO figure out a way to update this any time a player JOINS or LEAVES
func _update_player_ref(): 
	player_container = get_tree().get_nodes_in_group("Player_Container")
	all_players = player_container[0].get_children() #needs to be array ref because get_tree().get_nodes_in_group() returns an array

func _process(delta):
	# if the world is active and JSONs haven't been assigned yet (which we can tell based on if there's an active player) 
	if(active_player != null && world_interactables == null): 
		_store_world_data() ##TODO switch this call into being a signal

#region UI Stuff
	if(save_game.button_pressed):
		saving = true
		save_manager.save_game()
	if (exit_game.button_pressed):
		_quit_game()
#endregion

	#if(Input.is_action_just_pressed("cam_down") || Input.is_action_just_pressed("cam_up") || Input.is_action_just_pressed("cam_left") || Input.is_action_just_pressed("cam_right")):
		#controller_used = true

func toggle_game_pause(toggle : bool):
	menu_ui.visible = toggle
	open_menu = toggle
	pause_game = toggle
	if toggle:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

#TODO check if this function can be removed
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
	save_manager.save_data.player = active_player._save_player_data()
	save_manager.save_game()
	get_tree().quit()

#func _on_save_pressed():
	#save_manager.save_data.player = active_player._save_player_data()
	#save_manager.save_game()
	#pass # Replace with function body.
