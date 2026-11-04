extends Control

@export_category("Attributes")
@export var subviewport_material_array : Array[ShaderMaterial]
@export var overlay_material_array : Array[ShaderMaterial]

#References
var background_view : SubViewportContainer
var foreground_view : SubViewportContainer
var overlay_effects : ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	background_view = %BackgroundView
	foreground_view = %ForegroundView
	overlay_effects = %OverlayEffects


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#region Material Assignments
func set_background_material(num:int):
	if num >= subviewport_material_array.size():
		print("INVALID SUBVIEWPORT MATERIAL ASSIGNMENT")
		return
	background_view.material = subviewport_material_array[num]

func set_foreground_material(num:int):
	if num >= subviewport_material_array.size():
		print("INVALID SUBVIEWPORT MATERIAL ASSIGNMENT")
		return
	foreground_view.material = subviewport_material_array[num]

func set_overlay_material(num:int):
	if num >= overlay_material_array.size():
		print("INVALID OVERLAY MATERIAL ASSIGNMENT")
		return
	overlay_effects.material = overlay_material_array[num]
#endregion

func reset_camera_effects():
	toggle_overlay(false)
	toggle_foreground(false)

func set_base_attributes(dither_size:float, dither_pattern:int):
	subviewport_material_array[1].set("shader_parameter/quantize_size", dither_size)
	subviewport_material_array[1].set("shader_parameter/dither_pattern", dither_pattern)

#region Toggle Effects
func toggle_overlay(toggle:bool):
	overlay_effects.visible = toggle

func toggle_foreground(toggle:bool):
	foreground_view.visible = toggle

func toggle_background(toggle:bool):
	background_view.visible = toggle
#endregion
