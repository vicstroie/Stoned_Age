extends TextureRect


@export var item_visual : TextureRect
var item_scale : float = 65.0

func set_sprite(new_texture: Texture2D):
	item_visual.texture = new_texture
	rescale_sprite(new_texture)

#TEMP SOLUTION TO SPRITE SCALING
func rescale_sprite(new_texture : Texture2D):
	print("rescaled")
	var width = new_texture.get_width()
	var height = new_texture.get_height()
	print(item_visual.scale.x)
	item_visual.scale.x = item_scale/width
	item_visual.scale.y = item_scale/height
	print(item_visual.scale.x)
