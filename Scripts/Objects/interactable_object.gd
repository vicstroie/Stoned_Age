extends Area3D
@export var ID : String
@export var permanent := false
@export var picked_up := false
@export var item_id: InvItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (picked_up):
		queue_free()

func pick_up() -> InvItem:
	picked_up = true
	return item_id
