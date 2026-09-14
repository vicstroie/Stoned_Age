extends Area3D
@export var ID : String
@export var permanent := false
@export var item_id: InvItem
@export var collision_shape : CollisionShape3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

@rpc("any_peer","reliable","call_local")
func remove_from_world():
	self.set_process(false)
	print("Disabled " + str(name))
	visible = false

func pick_up() -> InvItem:
	rpc("remove_from_world")
	return item_id
