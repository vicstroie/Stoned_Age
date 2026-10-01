extends Control

@export var all_recipes : Dictionary
@export var inventory_ui: Control
@onready var recipe_container = %"Recipe Container"
var recipe_slot = preload("res://Scenes/UI/recipe_slot.tscn")
var inventory : Inventory
var is_open : bool 

##all active recipes
var unlocked_recipes : Dictionary
var current_crafting_slots

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(inventory == null):
		inventory = inventory_ui.inventory
	if (Input.is_action_just_pressed("crafting") && inventory_ui.main_inventory):
		inventory._update_inventory_JSON()
		if(is_open):
			close()
		else:
			open()
		for recipe in all_recipes:
			_unlock_crafting_recipe()

func _add_to_crafting_slots(new_recipe):
	var new_slot = recipe_slot.instantiate()
	recipe_container.add_child(new_slot)
	new_slot.recipe_name.text = unlocked_recipes[new_recipe]["Recipe"].recipe_name
	
	var new_slot_resources = [new_slot.resource_1_name, new_slot.resource_2_name, new_slot.resource_3_name]
	var new_slot_amt = [new_slot.amt_1_needed, new_slot.amt_2_needed, new_slot.amt_3_needed]

	##TODO dynamically add to this list rather than having a hard set 3
	for i in unlocked_recipes[new_recipe]["Recipe"].res_name.size():
		if(unlocked_recipes[new_recipe]["Recipe"].res_name[i] != null):
			new_slot_resources[i].text = unlocked_recipes[new_recipe]["Recipe"].res_name[i]
			##TODO player stock/amount needed
			new_slot_amt[i].text = str(unlocked_recipes[new_recipe]["Recipe"].res_amt[i])
	for i in new_slot_resources.size():
		if (new_slot_resources[i].text == null):
			new_slot_resources[i].queue_free()
			new_slot_amt[i].queue_free()
	
##TODO recipe JSON to keep consistent what's already been unlocked
func _unlock_crafting_recipe():
	for recipe in all_recipes:
		if(all_recipes[recipe].Unlocked):
			if(!unlocked_recipes.has(recipe)):
				unlocked_recipes[recipe] = all_recipes[recipe]
				_add_to_crafting_slots(recipe)
func open():
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func close():
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
