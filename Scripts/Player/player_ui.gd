extends CanvasLayer

@onready var stats = %PlayerStats
@onready var inventory = %InventoryUI
@onready var crafting = %CraftingUI
var database

enum ui_state{None, Inventory, Crafting, Pause}
var current_state : ui_state

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Setup References
	database = get_node("/root/Database")
	
	#Setup UI States
	current_state = ui_state.None
	stats.visible = true
	inventory.toggle_inventory(false)
	crafting.toggle_crafting(false)
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		_handle_inventory()
	if Input.is_action_just_pressed("crafting"):
		_handle_crafting()
	if Input.is_action_just_pressed("pause"):
		_handle_pause()


func _handle_inventory():
	match(current_state):
			ui_state.None:
				stats.visible = false
				inventory.toggle_inventory(true)
				current_state = ui_state.Inventory
			ui_state.Inventory:
				stats.visible = true
				inventory.toggle_inventory(false)
				current_state = ui_state.None
			ui_state.Crafting:
				crafting.toggle_crafting(false)
				inventory.toggle_inventory(true)
				current_state = ui_state.Inventory
			ui_state.Pause:
				database.toggle_game_pause(false)
				inventory.toggle_inventory(true)
				current_state = ui_state.Inventory

func _handle_crafting():
	match(current_state):
			ui_state.None:
				stats.visible = false
				crafting.toggle_crafting(true)
				current_state = ui_state.Crafting
			ui_state.Inventory:
				inventory.toggle_inventory(false)
				crafting.toggle_crafting(true)
				current_state = ui_state.Crafting
			ui_state.Crafting:
				stats.visible = true
				crafting.toggle_crafting(false)
				current_state = ui_state.None
			ui_state.Pause:
				database.toggle_game_pause(false)
				crafting.toggle_crafting(true)
				current_state = ui_state.Crafting

func _handle_pause():
	match(current_state):
			ui_state.None:
				stats.visible = false
				database.toggle_game_pause(true)
				current_state = ui_state.Pause
			ui_state.Inventory:
				inventory.toggle_inventory(false)
				database.toggle_game_pause(true)
				current_state = ui_state.Pause
			ui_state.Crafting:
				crafting.toggle_crafting(false)
				database.toggle_game_pause(true)
				current_state = ui_state.Pause
			ui_state.Pause:
				stats.visible = false
				database.toggle_game_pause(false)
				current_state = ui_state.None
