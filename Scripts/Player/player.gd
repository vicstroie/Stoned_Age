@icon("uid://b4e1f62upntch")
extends RigidBody3D
##quick link to top of script
func _back_to_vars():
	pass

@export_category("Movement")
var speed
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 10
const SENSITIVITY = 0.004

#Terrain
@export var water_cast : RayCast3D

#fov variables
const BASE_FOV = 75.0
const SPRINT_F_CHANGE = 2
const WALK_F_CHANGE = 1.5
var fov_change := 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 9.8
var grounded : bool
@export var ground_cast : RayCast3D
@export var use_fov_change : bool
@export var use_headbob : bool
#bob variables
var t_bob = 0.0
@export_range(0,3,.1) var bob_freq
@export_range(0,.5,.01) var bob_amp

@onready var head = %Head
@onready var camera = %Camera3D
@onready var p_cam = %PhantomCamera3D
@onready var camera_cast = %CameraCast

#UI Elements
@onready var interaction_text = %InteractionText
@onready var inventory_ui = %InventoryUI

@export_category("Player Data Info")
@export var health : float
@export var inventory_size : int = 8 #DO NOT CHANGE
var status_dictionary
var inventory_dictionary 
var database
var time_to_autosave_max = 600
var autosave_timer

@export_category("Multiplayer")
@export var player_id : int
@export var multiplayer_name : Label3D
@export var body_mesh : MeshInstance3D
@export var vc_output : AudioStreamPlayer3D
##this is the player that this instance is controlling
var main_player := true

func _load_in():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  
	speed = WALK_SPEED
	set_multiplayer_authority(name.to_int())

func _enter_tree():
	_load_in()

func _setup_local_player():
	player_id = get_multiplayer_authority()
	print("player id " + str(player_id))
	print("multiplayer id " + str(multiplayer.get_unique_id()))
	if(multiplayer.get_unique_id() == player_id):
		%Camera3D.make_current()
		%SubViewportContainer.visible = true
		%PhantomCamera3D.visible = true
		multiplayer_name.text = Steam.getPersonaName()
		#cull these from main camera
		body_mesh.set_layer_mask_value(20,true)
		body_mesh.set_layer_mask_value(1,false)
		multiplayer_name.set_layer_mask_value(20,true)
		multiplayer_name.set_layer_mask_value(1,false)
	else:
		%Camera3D.visible = false
		%PhantomCamera3D.visible = false
		main_player = false
		inventory_ui.visible = false
		# We get the index of the "Record" bus.
	
	#JSON stuff
	for game_obj in get_tree().get_nodes_in_group("Database"): #assign database
		database = game_obj
	status_dictionary = database._JSON_to_dictionary(database.player_status_path)
	inventory_dictionary = database._JSON_to_dictionary(database.player_inventory_path)
		
	#spawn location
	position = Vector3(status_dictionary.Position[0],status_dictionary.Position[1],status_dictionary.Position[2])

func _ready():
	_setup_local_player()
	
	#Setup UI and Inventory
	inventory_ui.setup_inventory()
	interaction_text.text = ""

func _process(delta):
	%SubViewportContainer.material.set("shader_parameter/quantize_size", database.dither_slider.value)
	%SubViewportContainer.material.set("shader_parameter/dither_pattern", database.dither_pattern_slider.value)

	_handle_saving()
	_handle_picking_up()
	

func _physics_process(delta):
	if(main_player):
		if(!database.pause_game):
			#movement
			grounded = ground_cast.is_colliding()
			_handle_movement(delta)
		_handle_water_check(delta)

func _input(event):
	#region Mouse Head Rotation
	if event is InputEventMouseMotion && main_player && !database.pause_game:
			head.rotate_y(-event.relative.x * SENSITIVITY)
			p_cam.rotate_x(-event.relative.y * SENSITIVITY)
			p_cam.rotation.x = clamp(p_cam.rotation.x, deg_to_rad(-40), deg_to_rad(60))
	#endregion

#region Inventory
func _handle_picking_up():
	#Found object to grab
	if camera_cast.is_colliding():
		var collider = camera_cast.get_collider()
		interaction_text.text = "press 'e' to pick up."
		
		#Pick objects up with "E"
		if Input.is_action_just_pressed("interact"):
			_handle_adding_inventory(collider)
			interaction_text.text = ""
	#Did not find an object
	else:
		if interaction_text.text != "":
			interaction_text.text = ""
#endregion

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp
	pos.x = cos(time * bob_freq / 2) * bob_amp
	return pos

func _handle_movement(delta):
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	body_mesh.rotation.y = head.rotation.y
		# Add the gravity.
	if !grounded:
		linear_velocity.y -= gravity * delta
		linear_velocity.x = lerp(linear_velocity.x, direction.x * speed, delta * 3.0)
		linear_velocity.z = lerp(linear_velocity.z, direction.z * speed, delta * 3.0)
	else:
		#jump
		if(Input.is_action_just_pressed("jump")):
			linear_velocity.y = JUMP_VELOCITY
		#TODO sprint
		if(Input.is_action_pressed("sprint")):
			speed = SPRINT_SPEED
			fov_change = SPRINT_F_CHANGE
		else:
			speed = WALK_SPEED
			fov_change = WALK_F_CHANGE
		#move
		if direction:
			linear_velocity.x = direction.x * speed
			linear_velocity.z = direction.z * speed
		else:
			linear_velocity.x = lerp(linear_velocity.x, direction.x * speed, delta * 7.0)
			linear_velocity.z = lerp(linear_velocity.z, direction.z * speed, delta * 7.0)
	
	if(use_headbob):
		# Head bob
		t_bob += delta * abs(sqrt((linear_velocity.x ** 2 )+ (linear_velocity.z) ** 2)) * float(grounded)
		p_cam.transform.origin = _headbob(t_bob)
	if(use_fov_change):
		# FOV
		var velocity_clamped = clamp(abs(sqrt((linear_velocity.x ** 2 )+ (linear_velocity.z) ** 2)), 0.5, SPRINT_SPEED * 2)
		var target_fov = BASE_FOV + fov_change * velocity_clamped
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func _handle_water_check(delta):
	pass

func _handle_adding_inventory(target_item): ##handles adding an item to your inventory
	if(!target_item.permanent):
		#inventory_dictionary.Removable.append(target_item.ID)
		inventory_ui.insert_item(target_item.pick_up())
	else:
		#this is called when the player grabs a permanent item
		pass

func _handle_saving():
	if (database.saving):
		_update_JSON_data()
		print("SAVING...")
		autosave_timer = time_to_autosave_max
		database.saving = false
	if (database.autosave_enabled):
		_handle_autosave()

func _handle_autosave():
	if(autosave_timer >= 0):
		autosave_timer -= get_process_delta_time()
	else:
		_update_JSON_data()
		print("AUTOSAVING...")
		autosave_timer = time_to_autosave_max

func _update_JSON_data():
	status_dictionary.Health = health
	
	status_dictionary.Position[0] = global_position.x
	status_dictionary.Position[1] = global_position.y
	status_dictionary.Position[2] = global_position.z
	
	database._save_JSON_file(database.player_status_path, status_dictionary)
	database._save_JSON_file(database.player_inventory_path, inventory_dictionary)
