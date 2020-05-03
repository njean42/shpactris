extends Node2D


var peer
var clients = []

const SERVER_IP = '127.0.0.1'
const SERVER_PORT = 6000
const MAX_PLAYERS = 2


func _ready():
	get_tree().connect("network_peer_connected",self,'_on_network_peer_connected')
	get_tree().connect("network_peer_disconnected",self,'_on_network_peer_disconnected')
	get_tree().connect("server_disconnected",self,'_on_server_disconnected')


func _on_network_peer_connected(peer_id):
	clients.append(peer_id)
	
	if clients.size() == 2 and is_network_master():
		rpc('start_game')
		# TODO: server.set_refuse_new_network_connections(true)


func _on_network_peer_disconnected(peer_id):
	clients.erase(peer_id)


func _on_server_disconnected():
	pass
	# TODO: display error and abort game


remotesync func start_game():
	get_tree().change_scene("res://scenes/world.tscn")


