extends Panel

@onready var item_visual: Sprite2D = %ItemDisplay
@onready var amount_text: Label = %ItemCount

#TEMP SOLUTION TO SPRITE SCALING
var visual_width : float = 170

func update(slot: InvSlot):
	if !slot.item:
		item_visual.visible = false
		amount_text.visible = false
	else:
		item_visual.visible = true
		item_visual.texture = slot.item.texture
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
