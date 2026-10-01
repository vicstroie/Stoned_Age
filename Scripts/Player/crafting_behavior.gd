extends Control

@export var all_recipes : Dictionary
@export var inventory_ui: Control
@onready var recipe_container = %"Recipe Container"
var recipe_slot = preload("res://Scenes/UI/recipe_slot.tscn")
var resource_slot = preload("res://Scenes/UI/resource_slot.tscn")
##COPYING THE ONE IN INVENTORY_UI
var inventory 
var is_open : bool 

##all active recipes
var unlocked_recipes : Dictionary
var current_crafting_slots
var all_slots : Array[Control]
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	if (inventory_ui.main_inventory): #to ensure we don't get a ref to another player's inventory
		if(inventory == null): #if we don't have a ref of inventory, use inventory_ui's ref
			inventory = inventory_ui.inventory
		if (Input.is_action_just_pressed("crafting")):
			if(is_open):
				close()
			else:
				open()
			##Updates known recipes in the list
			inventory._update_inventory_JSON()
			for recipe in all_recipes:
				_unlock_crafting_recipe()

func _add_to_crafting_slots(new_recipe):
	var new_slot = recipe_slot.instantiate()
	recipe_container.add_child(new_slot)
	new_slot.recipe_name.text = unlocked_recipes[new_recipe]["Recipe"].recipe_name
	
	##TODO dynamically add to this list rather than having a hard set 3
	for i in unlocked_recipes[new_recipe]["Recipe"].res_name.size():
		var new_resource = resource_slot.instantiate()
		new_slot.resource_container.add_child(new_resource)
		new_resource.get_child(0).text = unlocked_recipes[new_recipe]["Recipe"].res_name[i]
		new_resource.get_child(1).text = str(unlocked_recipes[new_recipe]["Recipe"].res_amt[i])
		new_slot.resource_name.append(new_resource.get_child(0).text)
		new_slot.resource_amt.append(new_resource.get_child(1).text)
	new_slot.crafting_ui = self
	
	#add slot to our list of all slots
	all_slots.append(new_slot)
	
##TODO recipe JSON to keep consistent what's already been unlocked
func _unlock_crafting_recipe():
	for recipe in all_recipes:
		if(all_recipes[recipe].Unlocked):
			if(!unlocked_recipes.has(recipe)):
				unlocked_recipes[recipe] = all_recipes[recipe]
				print("ADDING " + recipe + " TO RECIPE BOOK")
				_add_to_crafting_slots(recipe)

func open():
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func close():
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
