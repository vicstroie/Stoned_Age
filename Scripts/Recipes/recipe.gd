extends Resource
class_name Recipe

@export var recipe_name : String
##what resource(s) needed
@export var res_name : Array[String]
##how much of of the corresponding resource
@export var res_amt : Array[int]
##what is crafted
@export var resulting_item : InvItem
##what this recipe is unlocked by, if NULL then it will default unlocked
@export var unlocked_by : String
##what crafting table/tool needs to be used for this recipe, if NULL default to crafting book/ui
@export var required_table : String
