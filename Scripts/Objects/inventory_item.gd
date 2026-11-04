extends Resource

class_name InvItem

@export_category("Identity Attributes")
@export var texture : Texture2D
@export var name : String = ""
@export var is_permanent : bool 

@export_category("Food Attributes")
@export var is_consumable : bool
@export var health_points : float
@export var hunger_points : float

@export_category("Drug Attributes")
@export var is_drug : bool
@export var drug_effect : DrugEffect
