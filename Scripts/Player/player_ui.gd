extends CanvasLayer

@onready var stats = %PlayerStats
@onready var inventory = %InventoryUI
@onready var crafting = %CraftingUI

enum ui_state{None, Inventory, Crafting, Pause}
var current_state : ui_state

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#current_state = ui_state.None
	#stats.visible = true
	#inventory.visible = false
	#crafting.visible = false
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
