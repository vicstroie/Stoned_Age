extends Control

#Reference player inventory
@onready var slot_container: GridContainer = $Background/GridContainer
@onready var slots: Array = $Background/GridContainer.get_children()
var inventory: Inventory

var is_open = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_open:
			close()
		else:
			open()
			update_slots()

#Called in "_ready()" in player.gd
func setup_inventory(size: int = 8):
	inventory = Inventory.new()
	inventory.update.connect(update_slots)
	for i in range(size):
		var new_slot = InvSlot.new()
		inventory.slots.append(new_slot)
	update_slots()

#Update the UI slots
func update_slots():
	for i in range(min(inventory.slots.size(), slots.size())):
		slots[i].update(inventory.slots[i])

#WILL BE Called in Player
func can_pick_up(item: InvItem) -> bool:
	return inventory.can_pick_up(item)

func insert_item(new_item: InvItem):
	if new_item != null:
		inventory.insert(new_item)
	else:
			print("INVALID ITEM ID")

func open():
	visible = true
	is_open = true

func close():
	visible = false
	is_open = false
