extends Area3D
##ALERT this is a repeat in inventory item script find a way to consolidate
@export var permanent := false
@export var item_type: InvItem
@export var item_name : String
var picked_up : bool 
@export var collision_shape : CollisionShape3D

@rpc("any_peer","reliable","call_local")
func remove_from_world():
	self.set_process(false)
	print("Disabled " + str(name))
	visible = false
	queue_free()

func pick_up() -> InvItem:
	rpc("remove_from_world")
	picked_up = true
	return item_type
