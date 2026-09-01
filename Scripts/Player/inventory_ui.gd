extends Control

#Reference objects outside of prefab
@export var hand_slot: Button

#Reference player inventory
@onready var slot_container: GridContainer = $Background/GridContainer
@onready var slots: Array = $Background/GridContainer.get_children()
var inventory: Inventory

var is_open = false
var main_inventory : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Add the handheld to the front of the array
	#slots[0] will always be the handheld object
	slots.push_front(hand_slot)
	close()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory") && main_inventory:
		if is_open:
			close()
		else:
			open()
			update_slots()
	if Input.is_action_just_pressed("use") && main_inventory && !is_open && slots[0].current_item:
		slots[0]._on_action_button_pressed()
		update_slots()

#Called in "_ready()" in player.gd
func setup_inventory(player, size: int = 9):
	if(main_inventory):
		setup_slots(player)
		inventory = Inventory.new()
		inventory.update.connect(update_slots)
		for i in range(size):
			var new_slot = InvSlot.new()
			inventory.slots.append(new_slot)
		update_slots()

func setup_slots(player):
	for i in range(0, slots.size()):
		slots[i].player = player
		slots[i].inventory_ui = self

#Update the UI slots
func update_slots():
	if(main_inventory):
		slots[0].update(inventory.slots[0])
		for i in range(0, min(inventory.slots.size(), slots.size())):
			slots[i].update(inventory.slots[i])

#Called in inventory_ui_slot
func equip_item(old_ui_slot):
	var swap_slot = old_ui_slot.current_slot
	var old_index = slots.find(old_ui_slot)
	inventory.slots[old_index] = inventory.slots[0]
	inventory.slots[0] = swap_slot
	update_slots()

#WILL BE Called in Player
func can_pick_up(item: InvItem) -> bool:
	return inventory.can_pick_up(item)

func insert_item(new_item: InvItem):
	if(main_inventory):
		if new_item != null:
			inventory.insert(new_item)
		else:
			print("INVALID ITEM ID")

func open():
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func close():
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
