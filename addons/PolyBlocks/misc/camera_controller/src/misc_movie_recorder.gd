# POLYBLOCKS | CAMERA ANIMATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

enum ActionMode {
	SMOOTH,
	POINT
}

enum RepeatMode {
	LOOP,
	EXIT,
	STAY
}

const CAM_SPEED: float = 8.0
const CAM_SPRINT_MULTIPLIER: float = 3.0
const CAM_ROTATION_SPEED: float = 60.0

@onready var active_camera: Camera3D = $Camera3D


@export_group("Playback")

@export var play_animation: bool = false

@export var action_mode: ActionMode = ActionMode.SMOOTH

@export var repeat_mode: RepeatMode = RepeatMode.STAY

@export var return_duration: float = 1.0

@export var exit_wait: float = 0.0


@export_group("Setup")

@export_tool_button("Set Camera Start")
var set_start_button: Callable = _set_start_from_camera

@export_tool_button("Set Camera End")
var set_end_button: Callable = _set_end_from_camera

@export_tool_button("Move Camera to Start")
var camera_to_start_button: Callable = _camera_to_start

@export_tool_button("Move Camera to End")
var camera_to_end_button: Callable = _camera_to_end


@export var start_pos: Vector3 = Vector3.ZERO
@export var start_rot: Vector3 = Vector3.ZERO

@export var end_pos: Vector3 = Vector3.ZERO
@export var end_rot: Vector3 = Vector3.ZERO


@export_group("Smooth Mode")

@export var move_duration: float = 24.0


@export_group("Point Mode")

@export var points: int = 8
@export var point_duration: float = 1.0
@export var transition_duration: float = 0.8


var _tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not play_animation:
		return

	active_camera.current = true

	active_camera.global_position = start_pos
	active_camera.global_rotation_degrees = start_rot

	play_movement()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_camera_movement(delta)


func _editor_camera_movement(delta: float) -> void:
	var move_direction := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W):
		move_direction.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move_direction.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		move_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		move_direction.y += 1.0

	if move_direction.length_squared() > 0.0:
		move_direction = move_direction.normalized()
		var camera_basis := active_camera.global_transform.basis
		var speed := CAM_SPEED

		if Input.is_physical_key_pressed(KEY_SHIFT):
			speed *= CAM_SPRINT_MULTIPLIER

		var motion := (
			camera_basis.x * move_direction.x
			+ camera_basis.y * move_direction.y
			+ camera_basis.z * move_direction.z
		)

		active_camera.global_position += motion * speed * delta

	var camera_rotation := active_camera.global_rotation_degrees

	if Input.is_physical_key_pressed(KEY_LEFT):
		camera_rotation.y += CAM_ROTATION_SPEED * delta
	if Input.is_physical_key_pressed(KEY_RIGHT):
		camera_rotation.y -= CAM_ROTATION_SPEED * delta
	if Input.is_physical_key_pressed(KEY_UP):
		camera_rotation.x -= CAM_ROTATION_SPEED * delta
	if Input.is_physical_key_pressed(KEY_DOWN):
		camera_rotation.x += CAM_ROTATION_SPEED * delta

	camera_rotation.x = clampf(camera_rotation.x, -89.0, 89.0)
	active_camera.global_rotation_degrees = camera_rotation


func play_movement() -> void:
	if Engine.is_editor_hint():
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()

	match action_mode:

		ActionMode.SMOOTH:
			_tween.set_trans(Tween.TRANS_LINEAR)
			_tween.set_ease(Tween.EASE_IN_OUT)

			_tween.tween_property(
				active_camera,
				"global_position",
				end_pos,
				maxf(move_duration, 0.0)
			)

			_tween.parallel().tween_property(
				active_camera,
				"global_rotation_degrees",
				end_rot,
				maxf(move_duration, 0.0)
			)

		ActionMode.POINT:
			_tween.set_trans(Tween.TRANS_QUART)
			_tween.set_ease(Tween.EASE_IN_OUT)

			var point_count: int = maxi(points, 2)

			_tween.tween_property(
				active_camera,
				"global_position",
				start_pos,
				0.0
			)

			_tween.parallel().tween_property(
				active_camera,
				"global_rotation_degrees",
				start_rot,
				0.0
			)

			_tween.tween_interval(maxf(point_duration, 0.0))

			for i in range(1, point_count):
				var t: float = float(i) / float(point_count - 1)

				var target_pos: Vector3 = start_pos.lerp(end_pos, t)
				var target_rot: Vector3 = start_rot.lerp(end_rot, t)

				_tween.tween_property(
					active_camera,
					"global_position",
					target_pos,
					maxf(transition_duration, 0.0)
				)

				_tween.parallel().tween_property(
					active_camera,
					"global_rotation_degrees",
					target_rot,
					maxf(transition_duration, 0.0)
				)

				if i < point_count - 1:
					_tween.tween_interval(maxf(point_duration, 0.0))


	match repeat_mode:

		RepeatMode.LOOP:
			_tween.tween_property(
				active_camera,
				"global_position",
				start_pos,
				maxf(return_duration, 0.0)
			)

			_tween.parallel().tween_property(
				active_camera,
				"global_rotation_degrees",
				start_rot,
				maxf(return_duration, 0.0)
			)

			_tween.tween_callback(play_movement)

		RepeatMode.EXIT:
			if exit_wait > 0.0:
				_tween.tween_interval(exit_wait)

			_tween.tween_callback(_exit_scene)

		RepeatMode.STAY:
			pass


func _exit_scene() -> void:
	if is_inside_tree():
		get_tree().quit()


func _set_start_from_camera() -> void:
	start_pos = active_camera.global_position
	start_rot = active_camera.global_rotation_degrees


func _set_end_from_camera() -> void:
	end_pos = active_camera.global_position
	end_rot = active_camera.global_rotation_degrees


func _camera_to_start() -> void:
	active_camera.global_position = start_pos
	active_camera.global_rotation_degrees = start_rot


func _camera_to_end() -> void:
	active_camera.global_position = end_pos
	active_camera.global_rotation_degrees = end_rot
