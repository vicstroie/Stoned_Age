extends Control

#Self Reference player inventory
@onready var horz_container: HBoxContainer = $HBoxContainer
@export var quick_slots : Array[TextureRect]
@export var max_slots : int
@export var player_owner : RigidBody3D
@export var main_inventory : Control

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(Input.is_action_just_pressed("interact")):
		_update_quick_inv()

func _update_quick_inv():
	for i in range(max_slots):
			if (main_inventory.inventory.slots[i].item != null):
				#print("INVENTORY ADDED " + str(main_inventory.inventory.slots[i].item.name))
				quick_slots[i].item_icon.texture = main_inventory.inventory.slots[i].item.texture
