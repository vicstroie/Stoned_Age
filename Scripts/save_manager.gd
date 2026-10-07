# save_manager.gd - Add as Autoload in Project Settings
extends Node

const SAVE_PATH = "user://savegame.json"
const ROOM = 1

signal game_saved
signal game_loaded

var game_data = {
	"room": ROOM, ##what room/world the player is in (steam lobby ID?)
	"player": {}, ## player status save
	##TODO add inventory
	"world": {}, ## world save
	"settings": {} ##player settings save
}

func save_game() -> bool:
	game_saved.emit()  # Every subscriber writes its section into game_data now

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	
	if not file:
		push_error("Could not open save file: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(JSON.stringify(game_data, "\t"))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return false

	if not is_valid_save(json.data):
		push_warning("Save has an unsupported version or invalid fields.")
		return false

	game_data = json.data
	game_loaded.emit()  # Every subscriber reads its section back
	return true

func is_valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("room", ROOM) != ROOM:
		return false  # Add migrations before accepting another version.
	for section in ["player", "world", "settings"]:
		if not data.get(section, {}) is Dictionary:
			return false
	var player: Dictionary = data.get("player", {})
	
	var pos: Variant = player.get("position", {})
	
	if not pos is Dictionary:
		return false
	for axis in ["x", "y"]:
		if not is_number(pos.get(axis, 0.0)):
			return false
	return is_number(player.get("health", 100)) and player.get("inventory", []) is Array

func is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
