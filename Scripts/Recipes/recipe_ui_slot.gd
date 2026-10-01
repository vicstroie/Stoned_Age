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
var crafting_behavior
