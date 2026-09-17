# POLYBLOCKS | CAMERA CONTROLLER
# bukkbeek.github.io

extends Camera3D

# --- Exported Settings ---
@export var move_speed: float = 5.0
@export var speed_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.005
@export var max_pitch: float = 1.5
@export var min_pitch: float = -1.5

# Position clamping bounds
@export var min_x: float = -10.0
@export var max_x: float = 60.0
@export var min_y: float = 1.0
@export var max_y: float = 15.0
@export var min_z: float = -15.0
@export var max_z: float = 20.0

# Start in fullscreen? (ESC toggles fullscreen/windowed and mouse capture)
@export var start_fullscreen: bool = true

# --- Internal State ---
var rotation_h: float = 0.0
var rotation_v: float = 0.0
var is_mouse_captured: bool = true

func _ready():
	# Set initial fullscreen mode
	if start_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Always capture mouse at start
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Toggle mouse capture and fullscreen/windowed with Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_mouse_capture()
		return

	if not is_mouse_captured:
		return

	if event is InputEventMouseMotion:
		rotation_h -= event.relative.x * mouse_sensitivity
		rotation_v -= event.relative.y * mouse_sensitivity
		rotation_v = clamp(rotation_v, min_pitch, max_pitch)

		transform.basis = Basis()
		rotate_object_local(Vector3.UP, rotation_h)
		rotate_object_local(Vector3.RIGHT, rotation_v)

func _process(delta):
	if not is_mouse_captured:
		return

	var input_dir = get_input_direction()
	if input_dir.length() == 0:
		return

	var current_speed = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= speed_multiplier

	var movement = transform.basis * input_dir.normalized() * current_speed * delta
	var new_position = transform.origin + movement

	# Apply clamping using exported bounds
	new_position.x = clamp(new_position.x, min_x, max_x)
	new_position.y = clamp(new_position.y, min_y, max_y)
	new_position.z = clamp(new_position.z, min_z, max_z)

	transform.origin = new_position

func toggle_mouse_capture():
	is_mouse_captured = not is_mouse_captured

	if is_mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func get_input_direction() -> Vector3:
	var input_dir = Vector3.ZERO

	# WASD and Arrow keys for movement
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1

	# Q / E for vertical movement
	if Input.is_key_pressed(KEY_Q):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_E):
		input_dir.y -= 1

	return input_dir
