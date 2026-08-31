extends Resource

class_name InvItem

@export_category("General Attributes")
@export var name : String = ""
@export var texture : Texture2D

@export_category("Food Attributes")
@export var is_consumable : bool
@export var health_points : float
@export var hunger_points : float
