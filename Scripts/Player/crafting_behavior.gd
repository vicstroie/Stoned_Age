extends Control

@export var all_recipes : Dictionary
@export var inventory_ui: Control
@onready var recipe_container = %"Recipe Container"
var recipe_slot = preload("res://Scenes/UI/recipe_slot.tscn")
var resource_slot = preload("res://Scenes/UI/resource_slot.tscn")
##COPYING THE ONE IN INVENTORY_UI
var inventory 
var is_open : bool 
var database

##all active recipes
var unlocked_recipes : Dictionary
var current_crafting_slots
var all_slots : Array[Control]

##to be used to track WHAT crafting system is being used
var active_table

func _ready():
	database = get_node("/root/Database")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (inventory_ui.main_inventory): #to ensure we don't get a ref to another player's inventory
		if(inventory == null): #if we don't have a ref of inventory, use inventory_ui's ref
			inventory = inventory_ui.inventory

func toggle_crafting(toggle:bool):
	#Make sure wrong inventory isn't being accessed
	if(!inventory_ui.main_inventory):
		return
	if toggle:
		open()
		_unlock_crafting_recipe()
	else:
		close()


func _add_to_crafting_slots(new_recipe):
	var new_slot = recipe_slot.instantiate()
	recipe_container.add_child(new_slot)
	new_slot.recipe_name.text = unlocked_recipes[new_recipe]["Recipe"].recipe_name
	
	for i in unlocked_recipes[new_recipe]["Recipe"].res_name.size():
		var new_resource = resource_slot.instantiate()
		new_slot.resource_container.add_child(new_resource)
		new_resource.get_child(0).text = unlocked_recipes[new_recipe]["Recipe"].res_name[i]
		new_resource.get_child(1).text = str(unlocked_recipes[new_recipe]["Recipe"].res_amt[i])
		new_slot.resource_name.append(new_resource.get_child(0).text)
		new_slot.resource_amt.append(new_resource.get_child(1).text)
		
	new_slot.crafting_ui = self
	new_slot.active_recipe = unlocked_recipes[new_recipe]["Recipe"]
	new_slot.inventory = inventory
	new_slot.inventory_ui = inventory_ui

	#add slot to our list of all slots
	all_slots.append(new_slot)

func _check_recipe_valid(recipe):
	if (unlocked_recipes[recipe]["Recipe"].required_table != ""): #if the recipe has a required table
		if(active_table == unlocked_recipes[recipe]["Recipe"].required_table):
			print("ADDING " + recipe + " TO RECIPE BOOK")
			return true
		else:
			return false
	else:
		if(active_table == null):
			print("ADDING " + recipe + " TO RECIPE BOOK")
			return true
		else:
			return false

##TODO recipe JSON to keep consistent what's already been unlocked
##TODO unlock based on trips
##TODO toggle slots on/off based on crafting table
func _unlock_crafting_recipe():
	for recipe in all_recipes:
		if(all_recipes[recipe].Unlocked):
			if(!unlocked_recipes.has(recipe)):
				unlocked_recipes[recipe] = all_recipes[recipe]
				if(_check_recipe_valid(recipe)):
					_add_to_crafting_slots(recipe)
				else:
					#toggle recipe off
					pass

func open():
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func close():
	#clear slots
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
