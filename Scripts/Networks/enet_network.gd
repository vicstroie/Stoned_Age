extends Node
# ref this vid: https://youtu.be/V4a_J38XdHk?si=ClrCrIg6yETg3cAW
const SERVER_PORT = 8000
const SERVER_IP = "127.0.0.1"

var player_scene = preload("res://Scenes/Player/player.tscn")
var multiplayer_peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var _players_spawn_node 

func become_host():
	multiplayer_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)
	
	_add_player_to_game(1)

func join_as_client(lobby_id):
	multiplayer_peer.create_client(SERVER_IP,SERVER_PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	print("Player joining")

func _add_player_to_game(id : int):
	print("Player %s joined the game!" % id)
	var player_to_add = player_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add,true)
func _del_player(id : int):
	print("Player %s left the game!" % id)
