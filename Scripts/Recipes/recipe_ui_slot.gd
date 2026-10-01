extends Control

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var recipe_name : Label = %Name
@onready var resource_1_name : Label = %"Resource Needed"
@onready var resource_2_name : Label = %"Resource 2 Needed"
@onready var resource_3_name : Label = %"Resource 3 Needed"
@onready var amt_1_needed : Label = %AMT
@onready var amt_2_needed : Label = %"AMT 2"
@onready var amt_3_needed : Label = %"AMT 3"
@onready var crafting_button = %Craft
var crafting_ui
var crafting : bool 
var craft_button_buffer_max = .3
var craft_button_buffer

func _ready():
	craft_button_buffer = craft_button_buffer_max
	
func _process(delta):
	if(crafting_ui.inventory_ui.main_inventory): 	##TODO find better way to check this
		if(crafting_button.button_pressed && !crafting):
			crafting = true
			_check_craftable()
		##NOTE ensure you can't spam this button
		if(crafting && !crafting_button.button_pressed):
			craft_button_buffer -= delta
			if(craft_button_buffer <= 0):
				crafting = false
				craft_button_buffer = craft_button_buffer_max

func _check_craftable():
	if(crafting_ui.inventory.inventory_JSON_dictionary.has(resource_1_name.text)):
		print("Player has " +
		str(crafting_ui.inventory.inventory_JSON_dictionary[resource_1_name.text]["Amount"]) + 
		" " +
	 	resource_1_name.text)

func _craft_me():
	pass
