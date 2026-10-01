extends Resource

class_name InvItem

@export_category("Identity Attributes")
@export var texture : Texture2D
@export var name : String = ""
##if picking up this item changes it's name (i.e. ephedra bush -> ephedra berry)
@export var inventory_item_name : String
@export var is_permanent : bool 

@export_category("Food Attributes")
@export var is_consumable : bool
@export var health_points : float
@export var hunger_points : float
