extends Resource

class_name Inventory

signal update
var player_inventory_path = "res://DATA/INVENTORY.json"
@export var slots: Array[InvSlot]

#Create Inventory
func setup_inventory(size: int = 8):
	for i in range(size):
		var new_slot = InvSlot.new()
		slots.append(new_slot)

func can_pick_up(item: InvItem) -> bool:
	#Can it add to another slot?
	var itemslots = slots.filter(func(slot): return slot.item == item)
	if !itemslots.is_empty():
		return true
	#Is there an empty slot open?
	for i in range(slots.size()):
		if slots[i].item == null:
			return true
	#No where for it to go
	return false

func _update_inventory_JSON():
	var inventory_JSON_dictionary = _JSON_to_dictionary(player_inventory_path)
	print(inventory_JSON_dictionary)
	for i in slots.size():
		if (slots[i].item != null):
			inventory_JSON_dictionary[slots[i].item.name] = {
				"Amount" : slots[i].amount,
				"Permanent" : slots[i].item.is_permanent,
				##TODO discrete IDS
				#"Discrete_ID" : 0000
				}
	_save_JSON_file(player_inventory_path, inventory_JSON_dictionary)


func insert(item: InvItem):
	var itemslots = slots.filter(func(slot): return slot.item == item)
	#Is this item already in a slot?
	if !itemslots.is_empty():
			itemslots[0].amount += 1
	#Is this item being placed in an empty slot?
	else:
		var emptyslots = slots.filter(func(slot): return slot.item == null)
		if !emptyslots.is_empty():
			emptyslots[0].item = item
			emptyslots[0].amount = 1
	update.emit()

##ALERT this is a repeat function from database, find a way to consolidate 
func _JSON_to_dictionary(data_path:String): #returns true if JSON contains key
	var file = FileAccess.get_file_as_string(data_path)
	var dict = JSON.parse_string(file)
	return dict

##ALERT this is a repeat function from database, find a way to consolidate 
func _save_JSON_file(data_path:String, game_data):
	var json = JSON.stringify(game_data, "\t")
	var file = FileAccess.open(data_path, FileAccess.WRITE)
	file.store_line(json)
	file.close()
