extends Control

@export_category("Attributes")
@export var base_camera_material : ShaderMaterial
@export var blink_speed : float = 60

#References
var background_view : SubViewportContainer
var foreground_view : SubViewportContainer
var overlay_effects : ColorRect

#Managers
var player_ui : CanvasLayer

#Blink
var top_eyelid : ProgressBar
var bottom_eyelid : ProgressBar

var is_high : bool
var high_timer : float

var close_eyes : bool
var open_eyes : bool

var current_drug : DrugEffect

func _ready() -> void:
	background_view = %BackgroundView
	foreground_view = %ForegroundView
	overlay_effects = %OverlayEffects
	
	player_ui = %"Player UI"
	
	top_eyelid = %TopEyelid
	bottom_eyelid = %BottomEyelid

func _process(delta: float) -> void:
	#Process "High"
	if is_high:
		high_timer = high_timer - delta
		if high_timer < 0:
			#Reset High Timer
			high_timer = 0
			is_high = false
			
			#Reset drug effects
			current_drug = null
			close_eyes = true
	#Player "Blink" to hide transition
	if close_eyes:
		top_eyelid.value = move_toward(top_eyelid.value, 100, delta * blink_speed)
		bottom_eyelid.value = move_toward(bottom_eyelid.value, 100, delta * blink_speed)
		
		if top_eyelid.value == 100 and bottom_eyelid.value == 100:
			if current_drug != null:
				use_current_drug()
			else:
				reset_camera_effects()
			player_ui.exit_current_menu()
			close_eyes = false
			open_eyes = true
	if open_eyes:
		top_eyelid.value = move_toward(top_eyelid.value, 0, delta * blink_speed)
		bottom_eyelid.value = move_toward(bottom_eyelid.value, 0, delta * blink_speed)
		
		if top_eyelid.value == 0 and bottom_eyelid.value == 0:
			open_eyes = false
	

#Set current_drug, called in player.gd -> consume_item()
func set_current_drug(current_drug:DrugEffect):
	self.current_drug = current_drug
	close_eyes = true
#Apply Effects
func use_current_drug():
	use_drug(current_drug)
#Apply Effects
func use_drug(drug_effect:DrugEffect):
	if toggle_background(drug_effect.use_background):
		set_background_material(drug_effect.background_material)
	if toggle_foreground(drug_effect.use_foreground):
		set_foreground_material(drug_effect.foreground_material)
	if toggle_overlay(drug_effect.use_overlay):
		set_overlay_material(drug_effect.overlay_material)
	
	is_high = true
	high_timer = drug_effect.high_time

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
	toggle_background(true)
	set_background_material(base_camera_material)
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
