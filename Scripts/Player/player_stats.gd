extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var player = $"../.."

var health : float
var max_health : float = 100
var hunger : float
var max_hunger : float = 100

var is_sprinting : bool
var main_player : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	is_sprinting = player.speed == player.SPRINT_SPEED
	if is_sprinting:
		update_hunger_bar(-delta * 1.5)

func update_hunger_bar(hunger_change):
	hunger_bar.value = hunger_bar.value + hunger_change

func update_health_bar(health_change):
	health_bar.value = health_bar.value + health_change

func setup(player, max_health, max_hunger):
	self.player = player
	self.max_health = max_health
	self.max_hunger = max_hunger
	set_bar_values()

func set_bar_values():
	health_bar.max_value = max_health
	health_bar.value = max_health
	hunger_bar.max_value = max_hunger
	hunger_bar.value = max_hunger
