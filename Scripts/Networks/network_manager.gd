extends Node

enum NETWORK_TYPE{ENET,STEAM}
var active_network_type : NETWORK_TYPE = NETWORK_TYPE.ENET
var enet_net_scene := preload("res://Scenes/Multiplayer/Networks/Enet_Network.tscn")
var steam_net_scene := preload("res://Scenes/Multiplayer/Networks/Steam_Network.tscn")

var active_network
@export var _players_spawn_node : Node3D

func _build_network():
	if (!active_network):
		print("Setting active network...")
		match(active_network_type):
			NETWORK_TYPE.ENET:
				print("Setting ENET Network Type")
				_set_active_network(enet_net_scene)
			NETWORK_TYPE.STEAM:
				print("Setting STEAM Network Type")
				_set_active_network(steam_net_scene)
			_:
				print("No Matching Network Type")

func _set_active_network(active_network_scene):
	var network_scene_initialized = active_network_scene.instantiate()
	active_network = network_scene_initialized
	active_network._players_spawn_node = _players_spawn_node
	add_child(active_network)

func become_host():
	_build_network()
	active_network.become_host()

func join_as_client(lobby_id : int = 0):
	_build_network()
	active_network.join_as_client(lobby_id)
	
func list_lobbies():
	_build_network()
	active_network.list_lobbies()
