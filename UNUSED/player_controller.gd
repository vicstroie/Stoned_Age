@icon("uid://b4e1f62upntch")
extends Node3D

@export_category("Movement")
@export var player_body : RigidBody3D
@export var lower_body_visual : MeshInstance3D
@export var ground_cast : RayCast3D
@export var climb_checker : RayCast3D
@export var max_stamina : float
@export var climb_speed = 3
var grounded
var stamina
var stamina_fully_recovered : bool
var stamina_fully_depleated : bool
var climbing : bool 
var sprinting : bool
##how much stamina is affected by climbing
var climb_effort = 3
##how much running affects stamina
var run_effort = 5
##how much stamina recovers by
var stamina_recovery = 10
##how much time before stamina starts recovering
var stamina_recovery_buffer_max = 1
var recovery_buffer

var speed
var input_dir 
var direction 
var climb_dir
#basic move variables
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 8
var sens = 0.0004
var default_sens =  0.0004
#fov variables
const DEFAULT_FOV = 75.0
const ZOOM_FOV = 50
const SPRINT_FOV = 100

@export_category("Collisions")
@export var body_collision : CollisionShape3D

@export_category("Camera")
@export var cam : Camera3D
var controller_vector 
var default_H_offset  = 1.5
var default_FOV = 84.1
var default_near = .05
var default_far = 4000
#center of teh camera view
@export var center_point : Marker3D
##how long it takes each axis to follow the player
@export var follow_buffer: Vector4
##how accurate the camera follow is
@export var cam_follow_weight : float
##origin point of the default camera
@export var cam_origin : Node3D
##how long it takes the lower body to match rotation
@export var rotation_buffer : float
var zoomed : bool

@export_category("States")
enum Move_State{Idle,Moving,Climbing, Null}
@export var move_state : Move_State = Move_State.Idle
enum Interact_State{Talk, Inspect, In_Menu, In_Minigame, Null}
@export var interact_state : Interact_State = Interact_State.Null
@export_category("Multiplayer")
@export var player_id : int
@export var multiplayer_name : Label3D

func _setup_local_player():
	player_id = get_multiplayer_authority()
	print("player id " + str(player_id))
	print("multiplayer id " + str(multiplayer.get_unique_id()))
	if(multiplayer.get_unique_id() == player_id):
		%Camera.make_current()
		%SubViewportContainer.visible = true
		%"Default Cam".visible = true
		print(cam)
		print(player_id)
	else:
		%Camera.visible = false

func _load_in():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)  
	recovery_buffer = stamina_recovery_buffer_max
	speed = WALK_SPEED
	stamina = max_stamina
	set_multiplayer_authority(name.to_int())

func _enter_tree():
	_load_in()

func _ready():
	_setup_local_player()


func _process(delta):
	
	#ground check
	grounded = ground_cast.is_colliding()
	
	#clamp_cam
	cam_origin.rotation.x = clampf(cam_origin.rotation.x, deg_to_rad(-70), deg_to_rad(70))

	#stamina
	_handle_stamina()
	
	#handle move check
	input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (player_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	climb_dir = (player_body.transform.basis * Vector3(input_dir.x, input_dir.y, 0)).normalized()
		
	#camera
	_handle_follow_cam(delta)
	_handle_zoom(delta)
	#set up moving
	if(direction && move_state != Move_State.Moving && !climbing && grounded):
		_set_move_state(Move_State.Moving)

func _physics_process(delta):
	#rotation
	_body_rotation()
	# jump
	if(Input.is_action_just_pressed("jump") && grounded && !climbing && move_state != Move_State.Null):
		player_body.linear_velocity.y += JUMP_VELOCITY * 45 * delta
	else:
		player_body.gravity_scale = 2
	#visual 
	lower_body_visual.global_position = player_body.global_position #only when the rotation has reached a certain edge
	
	#movement state machine
	match(move_state):
		Move_State.Moving:
			_handle_movement()
			pass
		Move_State.Climbing:
			_handle_climbing()
			pass

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cam_origin.rotation.x -= event.relative.y * sens
		cam_origin.rotation.y += -event.relative.x * sens

func _handle_controller_cam(delta):
	controller_vector = Input.get_vector("cam_right","cam_left","cam_up","cam_down")
	if (controller_vector.length() >= .2):
		cam_origin.rotation.x -= controller_vector.y  * delta
		cam_origin.rotation.y += controller_vector.x  * delta

func _handle_stamina():
		#stamina
	if (!stamina_fully_depleated):
		if (grounded && !climbing && !sprinting && stamina < max_stamina):
			if(recovery_buffer >= 0):
				recovery_buffer -= get_process_delta_time()
			else:
				stamina += stamina_recovery * get_process_delta_time()
				if(stamina >= max_stamina):
					stamina = max_stamina
		else:
			recovery_buffer = stamina_recovery_buffer_max
	else:
		if(player_body.linear_velocity == Vector3.ZERO):
			if(recovery_buffer >= 0):
				recovery_buffer -= get_process_delta_time()
			else:
				stamina += stamina_recovery * get_process_delta_time()
				if(stamina >= max_stamina):
					stamina = max_stamina
	stamina_fully_recovered = stamina >= max_stamina
	if (stamina <= 0):
		stamina_fully_depleated = true
	if (stamina_fully_recovered):
		stamina_fully_depleated = false

func _handle_movement():
		# Handle Sprint.
	if(!zoomed):
		if (Input.is_action_pressed("sprint") && stamina > 0 && !stamina_fully_depleated):
			speed = SPRINT_SPEED
			stamina -= run_effort * get_process_delta_time()
			sprinting = true
		else:
			sprinting = false
			speed = WALK_SPEED
	# Get the input direction and handle the movement/deceleration.
	if direction:
		player_body.linear_velocity.x = direction.x *  speed
		player_body.linear_velocity.z = direction.z * speed
	else:
		player_body.linear_velocity.x = lerp(player_body.linear_velocity.x, direction.x * speed, get_process_delta_time()   * 7.0)
		player_body.linear_velocity.z = lerp(player_body.linear_velocity.z, direction.z * speed, get_process_delta_time()   * 7.0)
	player_body.position.normalized()
	#exit move
	if(player_body.linear_velocity.x <= 0 && player_body.linear_velocity.y <= 0):
		_set_move_state(Move_State.Idle)

func _body_rotation():
	if(move_state != Move_State.Idle):
		#top rotation
		#player_body.rotation.y = cam_origin.rotation.y
		player_body.rotation.y = lerp_angle(player_body.rotation.y,cam_origin.rotation.y, 15 * get_process_delta_time())
		#lower rotation
		if (!climbing):
			lower_body_visual.rotation.y = lerp_angle(lower_body_visual.rotation.y,player_body.rotation.y, rotation_buffer * get_process_delta_time())

func _handle_climbing():
	# Get the input direction and handle the movement/deceleration.
	if (Input.is_action_pressed("sprint") && stamina > 0):
		#will likely need to change later
		climbing = true
		player_body.gravity_scale = 0
		if climb_dir:
			stamina -= climb_effort * get_process_delta_time()
			player_body.linear_velocity.y = -climb_dir.y * climb_speed 
			#messy way of doing relative movement bc the normal way wasn't working
			if(absf(climb_dir.x) > .95):
				player_body.linear_velocity.x = direction.x *  climb_speed
			if(absf(climb_dir.z) > .95):
				player_body.linear_velocity.z = direction.z * climb_speed
		else:
			player_body.linear_velocity.y = 0
			player_body.linear_velocity.x = 0
			player_body.linear_velocity.z = 0
			stamina -= climb_effort/2 * get_process_delta_time() 
		#pull self to top of structure if at the top
	if(!Input.is_action_pressed("sprint") || stamina <= 0 || !climb_checker.is_colliding()):
		#jump AWAY from wall when jump is released
		_set_move_state(Move_State.Idle)

func _handle_zoom(delta):
	if(Input.is_action_pressed("zoom")):
		cam.fov = lerpf(cam.fov, ZOOM_FOV, delta * 2)
		if(!zoomed):
			zoomed = true
	else:
		cam.fov = lerpf(cam.fov, DEFAULT_FOV, delta * 2)
		if(zoomed):
			zoomed = false

func _handle_follow_cam(delta): #needs some tweaking later, maybe figure out some ease?
	##x
	if (absf(player_body.global_position.x - cam_origin.global_position.x) > follow_buffer.x):
		cam_origin.global_position.x = lerpf(cam_origin.global_position.x, player_body.global_position.x, cam_follow_weight/2 * delta)
	##y
	cam_origin.global_position.y = lerpf(cam_origin.global_position.y, center_point.global_position.y, cam_follow_weight * delta)
	##z
	cam_origin.global_position.z = lerpf(cam_origin.global_position.z, center_point.global_position.z, cam_follow_weight * delta)
	cam_origin.position.normalized()

func _set_move_state(next_move_state:int):
	var prev_move_state := move_state
	move_state = next_move_state
		
	#check last state
	match(prev_move_state):
		Move_State.Climbing:
			climbing = false
			player_body.gravity_scale = 2

	#check upcoming state
	match(next_move_state):
		Move_State.Moving:
			pass

func _set_interact_state(next_interact_state:int):
	var prev_interact_state := interact_state
	interact_state = next_interact_state
		
	#check last state
	match(prev_interact_state):
		pass
	#check upcoming state
	match(next_interact_state):
		pass
