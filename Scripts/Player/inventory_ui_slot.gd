extends Button

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var amount_text: Label = %ItemCount
@onready var item_name: Label = %ItemName
@onready var action_button: Button = %ActionButton
@onready var drop_button: Button = %DropButton

var current_item: InvItem
var current_slot: InvSlot

#TEMP SOLUTION TO SPRITE SCALING
var visual_width : float = 170
var is_mouse_over
var inventory_ui

func _ready() -> void:
	toggle_action_buttons(false)

func _process(delta: float) -> void:
	if is_mouse_over:
		var is_x_range = get_global_mouse_position().x > global_position.x and get_global_mouse_position().x < global_position.x + 200
		var is_y_range = get_global_mouse_position().y > global_position.y and get_global_mouse_position().y < global_position.y + 200
		if !is_x_range or !is_y_range:
			is_mouse_over = false
			toggle_action_buttons(false)

func update(slot: InvSlot):
	current_slot = slot
	if !slot.item:
		current_item = null
		
		item_visual.visible = false
		amount_text.visible = false
		item_name.text = ""
		item_name.visible = false
	else:
		current_item = slot.item
		if current_item.is_edible:
			action_button.text = "EAT"
		
		item_visual.visible = true
		item_visual.texture = slot.item.texture
		item_name.text = slot.item.name
		item_name.visible = true
		rescale_sprite(slot.item.texture)
		if slot.amount > 1:
			amount_text.visible = true
			amount_text.text = str(slot.amount)

#TEMP SOLUTION TO SPRITE SCALING
func rescale_sprite(new_texture : Texture2D):
	var width = new_texture.get_width()
	var height = new_texture.get_height()
	item_visual.scale.x = 170.0/width
	item_visual.scale.y = 170.0/height

func _on_mouse_entered() -> void:
	if current_item != null:
		is_mouse_over = true
		toggle_action_buttons(true)

func toggle_action_buttons(toggle: bool) -> void:
	if toggle:
		action_button.mouse_filter = Control.MOUSE_FILTER_STOP
		action_button.visible = true
		drop_button.mouse_filter = Control.MOUSE_FILTER_STOP
		drop_button.visible = true
	else:
		action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_button.visible = false
		drop_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop_button.visible = false

func _on_action_button_pressed() -> void:
	#Temporary Eating Logic
	if current_item.is_edible:
		current_slot.amount = current_slot.amount - 1
		inventory_ui.player.update_hunger(current_item.hunger_points)
		if current_slot.amount <= 0:
			reset_current_slot()
	#Update slot to account for action
	update(current_slot)

func _on_drop_button_pressed() -> void:
	#Temporary Drop Logic
	reset_current_slot()

func reset_current_slot():
	current_slot.item = null
	current_slot.amount = 0
	update(current_slot)
	toggle_action_buttons(false)
