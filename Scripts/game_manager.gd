extends Node
@onready var multiplayer_hud = %"Multiplayer HUD"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func attempt_host():
	print("Host pressed")
	#MultiplayerManager._become_host()
	%"Network Manager".become_host()
	multiplayer_hud.hide()
	%"Steam HUD".hide()

func attempt_join_as_client():
	print("Join Pressed")
	join_lobby()

func use_steam():
	%"Steam HUD".show()
	%"Multiplayer HUD".hide()
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	SteamManager.init_steam()
	%"Network Manager".active_network_type = %"Network Manager".NETWORK_TYPE.STEAM
	
func list_steam_lobbies():
	print("LISTING LOBBIES...")
	%"Network Manager".list_lobbies()
	
func join_lobby(lobby_id := 0):
	print("Joining Lobby...")
	%"Network Manager".join_as_client(lobby_id)
	multiplayer_hud.hide()
	%"Steam HUD".hide()
	
func join_from_button(lobby_id : int):
	print(lobby_id)
	print("Joining Lobby...")
	%"Network Manager".join_as_client(lobby_id)
	multiplayer_hud.hide()
	%"Steam HUD".hide()

func _on_lobby_match_list(lobbies : Array):
	for lobby_child in %"Available Lobbies".get_children():
		lobby_child.queue_free()
		
	for lobby in lobbies:
		var lobby_name:String = Steam.getLobbyData(lobby,"name")
		if(lobby_name != ""):
			var lobby_button = preload("res://Scenes/Multiplayer/lobby_option.tscn").instantiate()
			lobby_button.set_text(lobby_name)
			lobby_button.set_name("lobby_%s" % lobby)
			lobby_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lobby_button.lobby_option_id = lobby
			lobby_button.connect("pressed", Callable(self, "join_from_button").bind(lobby_button.lobby_option_id))
			%"Available Lobbies".add_child(lobby_button)
