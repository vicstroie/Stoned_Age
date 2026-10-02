extends Control

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var recipe_name : Label = %Name
@onready var resource_container := %"Resource Container"
@export var crafting_button :Button

var crafting_ui
var crafting : bool
var craftable : bool  
var craft_button_buffer_max = .3
var craft_button_buffer

var resource_name : Array[String]
var resource_amt : Array[String]

func _ready():
	craft_button_buffer = craft_button_buffer_max
	
func _process(delta):
	_check_craftable()
	if(crafting_ui.inventory_ui.main_inventory): 	##TODO find better way to check this
		if(crafting_button.button_pressed && !crafting):
			crafting = true
			if(craftable):
				_craft_me()
		##NOTE ensure you can't spam this button
		if(crafting && !crafting_button.button_pressed):
			craft_button_buffer -= delta
			if(craft_button_buffer <= 0):
				crafting = false
				craft_button_buffer = craft_button_buffer_max

func _check_craftable():
	var has_enough : Array[bool]
	for i in resource_name.size():
		if(crafting_ui.inventory.inventory_JSON_dictionary.has(resource_name[i])):
			if(int(resource_amt[i]) <= crafting_ui.inventory.inventory_JSON_dictionary[resource_name[i]]["Amount"]):
				has_enough.append(true)
			else: 
				has_enough.append(false)
	if (not false in has_enough):
		craftable = true

func _craft_me():
	#TODO crafting
	print("Crafted " + recipe_name.text)
