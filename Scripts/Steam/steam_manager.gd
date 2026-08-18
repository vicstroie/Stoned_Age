extends Node
#ref https://youtu.be/MoRl9kQb6L0?si=MLgdQpoNMABUXGf2
var is_owned : bool = false
var steam_app_id: int = 4489380 #test ID replace later
var steam_id : int = 0
var steam_username : String = ""

var lobby_id = 0
var lobby_max_members = 4

func _init():
	print("INIT STEAM...")
	OS.set_environment("SteamAppId", str(steam_app_id)) #make sure steam knows what app ID to use
	OS.set_environment("SteamGameId", str(steam_app_id)) #make sure steam knows what app ID to use

func _process(delta):
	Steam.run_callbacks() #makes sure everything recieved from steam API is run and executed on the project
	
func init_steam():
	var init_response : Dictionary = Steam.steamInitEx()
	print("Did Steam Initialize?: %s" % init_response)
	
	if(init_response['status'] > 0):
		print("Failed to init Steam. Shutting down. %s" % init_response)
		get_tree().quit()
	
	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	print("user is " + str(steam_username))
	
	if (!is_owned):
		print("User does not own game.")
		get_tree().quit()
