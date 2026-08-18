extends Area3D
@export var wave_size_tall := 3
@export var wave_size_short := 0
@export var frequency := .5
@export var wave_pos_y : float
var buffer := .5
var get_big := true
# Called when the node enters the scene tree for the first time.
func _ready():
	wave_pos_y = global_position.y
	wave_size_tall += wave_pos_y
	wave_size_short += wave_pos_y
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if(get_big):
		wave_pos_y = lerpf(wave_pos_y,wave_size_tall,delta * frequency)
		if(wave_pos_y >= wave_size_tall - buffer):
			get_big = false
	else:
		wave_pos_y = lerpf(wave_pos_y,wave_size_short,delta * frequency)
		if(wave_pos_y <= wave_size_short + buffer):
			get_big = true
