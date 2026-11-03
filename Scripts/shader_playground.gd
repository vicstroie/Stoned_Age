extends CanvasLayer

@export_category("Materials")
@export var materials : Array[ShaderMaterial]
var current_background = 0
var current_foreground = 0
@export var base_dither : ShaderMaterial
@export var distortion_flow : ShaderMaterial
@export var frequency_distortion : ShaderMaterial

@export_category("References")
@export var background_effect : SubViewportContainer
@export var foreground_effect : SubViewportContainer
@export var pixelation_effect : ColorRect
@export var blur_effect : ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func next_background():
	current_background = current_background + 1
	if current_background >= materials.size():
		current_background = 0
	change_background(materials[current_background])

func next_foreground():
	current_foreground = current_foreground + 1
	if current_foreground >= materials.size():
		current_foreground = 0
	change_foreground(materials[current_foreground])

func change_background(new_material:ShaderMaterial):
	background_effect.material = new_material

func change_foreground(new_material:ShaderMaterial):
	foreground_effect.material = new_material

func toggle_foreground():
	foreground_effect.visible = !foreground_effect.visible

func toggle_pixelation():
	pixelation_effect.visible = !pixelation_effect.visible

func toggle_blur():
	blur_effect.visible = !blur_effect.visible
