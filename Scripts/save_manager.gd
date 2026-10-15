# save_manager.gd - Add as Autoload in Project Settings
extends Node

#const SAVE_PATH = "user://savegame.json"
var room_name = "standin"
var lobby_ID = 1
signal game_saved
signal game_loaded

var database 

var save_JSON = "res://DATA/SAVE_DATA.json"
var save_data 

func _enter_tree():
	database = get_node("/root/Database")
	save_data = _JSON_to_dictionary(save_JSON)
	#TODO call save data BASED on what world the player is joining
	
func save_game() -> bool:
	_save_JSON_file(save_JSON,save_data)
	return true

func _JSON_to_dictionary(data_path:String): #returns true if JSON contains key
	var file = FileAccess.get_file_as_string(data_path)
	var dict = JSON.parse_string(file)
	return dict

func _save_JSON_file(data_path:String, game_data):
	var json = JSON.stringify(game_data, "\t")
	var file = FileAccess.open(data_path, FileAccess.WRITE)
	file.store_line(json)
	file.close()

func load_game() -> bool:
	return false
