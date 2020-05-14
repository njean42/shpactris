extends Node2D


var clients = []
var clients_ready = []
var pacman = null
var ship = null

var joining = false
var SERVER_PORT = int(OS.get_environment('PORT'))
var TESTING = OS.get_environment('TESTING') == 'true'

const GAME_NAMES = {
	'6000': 'Ikaruga',
	'6001': 'Puckman',
	'6002': 'Korobeïniki',
}


func _ready():
	get_tree().connect("network_peer_connected",self,'_on_network_peer_connected')
	get_tree().connect("network_peer_disconnected",self,'_on_network_peer_disconnected')
	get_tree().connect("server_disconnected",self,'_on_server_disconnected')
	get_tree().connect("connected_to_server",self,'_on_connected_to_server')
	get_tree().connect("connection_failed",self,'_on_connection_failed')


func _on_network_peer_connected(peer_id):
	clients.append(peer_id)
	
	if get_tree().get_network_unique_id() == 1:
		prints('peer connected => ',clients)
		
		if clients.size() > 2:
			# already two players in the game, can't add more
			prints('already two players')
			rpc_id(peer_id,"could_not_join",SERVER_PORT)
			get_tree().network_peer.disconnect_peer(peer_id)
		else:
			rpc_id(peer_id,"you_joined",SERVER_PORT)


func _on_network_peer_disconnected(peer_id):
	clients.erase(peer_id)
	clients_ready.erase(peer_id)
	
	if get_tree().get_network_unique_id() == 1:
		prints('peer disconnected =>',clients)
		if clients.size() == 0:
			get_tree().quit()


func _on_server_disconnected():  # TODO: seems to never happen...
	prints('server disconnected, quitting')
	kicked()


func _on_connected_to_server():
	pass


func _on_connection_failed():
	prints('connection failed')
	get_tree().network_peer = null


func join(server_ip, port, fake_join=false):
	joining = not fake_join
	
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(server_ip, int(port))
	get_tree().set_network_peer(peer)
	
	if joining:
		$'/root/lobby-scene'.clear_game_buttons()
		$'/root/lobby-scene'.add_lobby_output("Joined game, click ready when you are")
		$'/root/lobby-scene'.find_node('bt-ready').visible = true
		prints('connected to',server_ip,'on port',port,'...')


func fake_join(server_ip, port):  # just check whether a game is full 
	join(server_ip,port,true)


puppet func kicked():
	prints(get_tree().get_network_unique_id(),'I was kicked')
	get_tree().network_peer = null
	get_tree().quit() # TODO: display error and game over (if playing)


puppet func could_not_join(port):
	get_tree().network_peer = null
	
	if joining:
		$'/root/lobby-scene'.clear_output()
		$'/root/lobby-scene'.add_lobby_output('Could not join game')
		$'/root/lobby-scene'.refresh_game_list()
	else:  # I was just checking if that game was full
		$'/root/lobby-scene'.set_btjoin(port,'BUSY')
		$'/root/lobby-scene'.check_games_avail()


puppet func you_joined(port):
	if not joining:  # was just a test, disconnect
		get_tree().network_peer = null
		$'/root/lobby-scene'.set_btjoin(port,'WAITING')
		$'/root/lobby-scene'.check_games_avail()
	else:
		rpc("player_has_joined")


remote func player_has_joined():
	$'/root/lobby-scene'.add_lobby_output("Another player joined!")


remote func player_ready(peer_id):
	if not (peer_id in clients):  # should not happen
		prints(peer_id,'not in',clients,'...')
		return
	
	if not(peer_id in clients_ready):
		prints(peer_id,'is now ready')
		clients_ready.append(peer_id)
	
	if clients_ready.size() == 2:
		rpc("set_clients",clients)
		set_clients(clients)
		rpc('start_game')


puppet func set_clients(actual_clients):
	clients = actual_clients
	pacman = clients[0]
	ship = clients[1]


remotesync func start_game():
	get_tree().change_scene("res://scenes/world.tscn")


# utility functions to determine who executes what code (who is master over which game elements)
func i_am_the_game():
	return get_tree().get_network_peer() == null or get_tree().get_network_unique_id() == 1
	
func i_am_pacman():
	return get_tree().get_network_peer() == null or $'/root/world/pacman'.is_network_master()

func i_am_the_ship():
	return get_tree().get_network_peer() == null or $'/root/world/ship'.is_network_master()
