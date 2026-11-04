extends Control

@export_category("Attributes")
@export var base_camera_material : ShaderMaterial

#References
var background_view : SubViewportContainer
var foreground_view : SubViewportContainer
var overlay_effects : ColorRect

var is_high : bool
var high_timer : float

func _ready() -> void:
	background_view = %BackgroundView
	foreground_view = %ForegroundView
	overlay_effects = %OverlayEffects

func _process(delta: float) -> void:
	#Process "High"
	if is_high:
		high_timer = high_timer - delta
		if high_timer < 0:
			high_timer = 0
			is_high = false
			reset_camera_effects() #Reset to Default

#Apply Effects, called in player.gd -> consume_item()
func use_drug(current_drug:DrugEffect):
	if toggle_background(current_drug.use_background):
		set_background_material(current_drug.background_material)
	if toggle_foreground(current_drug.use_foreground):
		set_foreground_material(current_drug.foreground_material)
	if toggle_overlay(current_drug.use_overlay):
		set_overlay_material(current_drug.overlay_material)
	
	is_high = true
	high_timer = current_drug.high_time

#Assign Materials to each Node
#region Material Assignments
func set_background_material(new_material:ShaderMaterial):
	if new_material == null:
		print("INVALID SUBVIEWPORT MATERIAL ASSIGNMENT")
		return
	background_view.material = new_material

func set_foreground_material(new_material:ShaderMaterial):
	if new_material == null:
		print("INVALID SUBVIEWPORT MATERIAL ASSIGNMENT")
		return
	foreground_view.material = new_material

func set_overlay_material(new_material:ShaderMaterial):
	if new_material == null:
		print("INVALID OVERLAY MATERIAL ASSIGNMENT")
		return
	overlay_effects.material = new_material
#endregion

#Default Camera Functions
#region Default Camera Effects
#Reset to Base Camera Material
func reset_camera_effects():
	toggle_overlay(false)
	toggle_foreground(false)
#Set Base Material Attributes
func set_base_attributes(dither_size:float, dither_pattern:int):
	base_camera_material.set("shader_parameter/quantize_size", dither_size)
	base_camera_material.set("shader_parameter/dither_pattern", dither_pattern)
#endregion

#Toggle Each Effect Node
#region Toggle Effects
func toggle_overlay(toggle:bool)->bool:
	overlay_effects.visible = toggle
	return toggle

func toggle_foreground(toggle:bool)->bool:
	foreground_view.visible = toggle
	return toggle

func toggle_background(toggle:bool)->bool:
	background_view.visible = toggle
	return toggle
#endregion
