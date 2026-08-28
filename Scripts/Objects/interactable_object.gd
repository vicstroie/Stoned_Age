extends Area3D
@export var ID : String
@export var permanent := false
@export var picked_up := false
@export var item_id: InvItem
@export var collision_shape : CollisionShape3D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
@rpc("any_peer","call_local","reliable")
func _process(delta: float) -> void:
	if (picked_up):
		visible = false
	if(!visible):
		self.set_process(false)
		print("Disabled " + str(name))

func pick_up() -> InvItem:
	picked_up = true
	return item_id
