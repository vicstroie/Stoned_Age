extends Node


var player_scene = preload("res://Scenes/Player/player.tscn")
var multiplayer_peer : SteamMultiplayerPeer = SteamMultiplayerPeer.new()
var _players_spawn_node 
var _hosted_lobby_id = 0

func  _ready():
	Steam.connect("lobby_created", _on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

func become_host():
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, SteamManager.lobby_max_members)
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)
	if not OS.has_feature("dedicated_server"):
		_add_player_to_game(1)

func join_as_client(lobby_id : int):
	print("Joining lobby %s" % lobby_id)
	Steam.joinLobby(lobby_id)

func _on_lobby_created(connect_status: int, lobby_id):
	print("On lobby created")
	if connect_status == Steam.RESULT_OK:
		print("Created lobby: %s" % lobby_id)
		var LOBBY_NAME = Steam.getPersonaName()
		_hosted_lobby_id = lobby_id

		multiplayer_peer.host_with_lobby(lobby_id)
		multiplayer.multiplayer_peer = multiplayer_peer
		
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int) -> void:
	print("Lobby joined %s" % lobby_id)
	if Steam.getLobbyOwner(lobby_id) == Steam.getSteamID():
		print("Lobby host already in lobby, bypassing...")
		return
	multiplayer_peer.connect_to_lobby(lobby_id)
	multiplayer.multiplayer_peer = multiplayer_peer

func _add_player_to_game(id : int):
	print("Player %s joined the game!" % id)
	var player_to_add = player_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	#player_to_add.multiplayer_name.text = Steam.getPersonaName()

	_players_spawn_node.add_child(player_to_add,true)

func _del_player(id : int):
	print("Player %s left the game!" % id)

func list_lobbies():
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()
