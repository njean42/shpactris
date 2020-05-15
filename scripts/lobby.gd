extends Node2D


var clients = []
var clients_ready = []
var pacman = null
var ship = null

var SERVER_PORT = int(OS.get_environment('PORT'))
var TESTING = OS.get_environment('TESTING') == 'true'

const GAME_NAMES = {
	'6000': 'Ikaruga',
	'6001': 'Puckman',
	'6002': 'Korobeïniki',
}


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
