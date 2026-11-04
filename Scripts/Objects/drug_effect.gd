extends Resource

class_name DrugEffect

@export_category("Background")
@export var use_background : bool = true
@export var background_material_id : int

@export_category("Foreground")
@export var use_foreground : bool = false
@export var foreground_material_id : int

@export_category("Overlay")
@export var use_overlay : bool = false
@export var overlay_material_id : int

@export_category("Other Attributes")
@export var high_time : float = 20
