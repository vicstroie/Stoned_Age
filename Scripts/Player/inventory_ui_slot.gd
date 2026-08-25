extends Button

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var amount_text: Label = %ItemCount
@onready var item_name: Label = %ItemName
@onready var action_button: Button = %ActionButton
@onready var drop_button: Button = %DropButton

#TEMP SOLUTION TO SPRITE SCALING
var visual_width : float = 170

func _ready() -> void:
	toggle_action_buttons(false)

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
		item_name.text = ""
		item_name.visible = false
	else:
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
	print("mouse enter")

func _on_mouse_exited() -> void:
	toggle_action_buttons(false)

func _on_pressed() -> void:
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
	print("action button pressed")

func _on_drop_button_pressed() -> void:
	print("drop button pressed")
