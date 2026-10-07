extends Control

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var recipe_name : Label = %Name
@onready var resource_container := %"Resource Container"
@export var crafting_button : Button

var crafting_ui
var crafting : bool
var craftable : bool  
var craft_button_buffer_max = .3
var craft_button_buffer
var active_recipe : Recipe
var inventory : Inventory
var inventory_ui : Control

var resource_name : Array[String]
var resource_amt : Array[String]


func _ready():
	craft_button_buffer = craft_button_buffer_max


func _process(delta):
	if(inventory_ui.main_inventory): 	##TODO find better way to check this
		if(crafting_button.button_pressed && !crafting):
			_check_craftable() #TODO move to anytime book is open
			crafting = true
			if(craftable):
				_craft_me()
			else:
				print("NOT CRAFTABLE NEED MORE MATERIALS")
		##NOTE ensure you can't spam this button
		if(crafting && !crafting_button.button_pressed):
			craft_button_buffer -= delta
			if(craft_button_buffer <= 0):
				crafting = false
				craft_button_buffer = craft_button_buffer_max

func _check_craftable():
	var has_enough : Array[int]
	for r in resource_name.size():
			for i in inventory_ui.slots.size():
				if(inventory_ui.slots[i].current_item != null):
					if resource_name[r] == inventory_ui.slots[i].current_item.name:
						if(int(resource_amt[r]) <= inventory_ui.slots[i].current_slot.amount):
							has_enough.append(1)
						else:
							has_enough.append(0)
	if (has_enough.size() <= 0):
		craftable = false
		return
	if (not 0 in has_enough):
		craftable = true
	else:
		craftable = false

func _craft_me():
	print("Crafted " + recipe_name.text)
	_remove_cost_from_inventory()
	inventory_ui.insert_item(active_recipe.resulting_item)
	
func _remove_cost_from_inventory():
	for r in resource_name.size():
		for i in inventory_ui.slots.size():
			if(inventory_ui.slots[i].current_item != null):
				if resource_name[r] == inventory_ui.slots[i].current_item.name:
					inventory_ui.slots[i].current_slot.amount -= int(resource_amt[r])
					if (inventory_ui.slots[i].current_slot.amount <= 0):
						inventory_ui.slots[i].reset_current_slot()
					else:
						#update inventory slots
						print("SUBTRACT")
						inventory_ui.slots[i].update(inventory_ui.slots[i].current_slot)
					#update is craftable
					_check_craftable()
