extends Node2D


var peer
var clients = []
var pacman = null
var ship = null


func _ready():
	get_tree().connect("network_peer_connected",self,'_on_network_peer_connected')
	get_tree().connect("network_peer_disconnected",self,'_on_network_peer_disconnected')
	get_tree().connect("server_disconnected",self,'_on_server_disconnected')


func _on_network_peer_connected(peer_id):
	clients.append(peer_id)
	
	if clients.size() == 2 and is_network_master():
		rpc("set_clients",clients)
		set_clients(clients)
		rpc('start_game')
		# TODO: server.set_refuse_new_network_connections(true)


puppet func set_clients(actual_clients):
	clients = actual_clients
	pacman = clients[0]
	ship = clients[1]


func _on_network_peer_disconnected(peer_id):
	clients.erase(peer_id)


func _on_server_disconnected():
	pass
	# TODO: display error and abort game


remotesync func start_game():
	get_tree().change_scene("res://scenes/world.tscn")


# utility functions to determine who executes what code (who is master over which game elements)
func i_am_the_game():
	return get_tree().get_network_peer() == null or get_tree().get_network_unique_id() == 1
	
func i_am_pacman():
	return get_tree().get_network_peer() == null or $'/root/world/pacman'.is_network_master()

func i_am_the_ship():
	return get_tree().get_network_peer() == null or $'/root/world/ship'.is_network_master()
