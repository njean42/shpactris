extends Node2D


var clients = []
var clients_ready = []
var pacman = null
var ship = null

var SERVER_PORT = int(OS.get_environment('PORT'))
var TESTING = OS.get_environment('TESTING') == 'true'

var game_statuses = ['UNCERTAIN','FREE','BUSY','WAITING']
var min_port = INF

const GAME_NAMES = [
	'Ikaruga',
	'Puckman',
	'Korobeïniki',
]


func get_game_name(port):
	port = int(port)
	var game_name = GAME_NAMES[port % GAME_NAMES.size()]
	var nb = (port - min_port) / GAME_NAMES.size() + 1
	if nb > 1:
		game_name += ' #%s' % nb
	return game_name


puppet func set_clients(actual_clients):
	clients = actual_clients
	pacman = clients[0]
	ship = clients[1]


# utility functions to determine who executes what code (who is master over which game elements)
func i_am_the_game():
	return get_tree().get_network_peer() == null or get_tree().get_network_unique_id() == 1
	
func i_am_pacman():
	return get_tree().get_network_peer() == null or $'/root/world/pacman'.is_network_master()

func i_am_the_ship():
	return get_tree().get_network_peer() == null or $'/root/world/ship'.is_network_master()
