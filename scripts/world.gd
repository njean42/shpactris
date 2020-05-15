extends Node2D

var level = 0
var game_time = 0
var gold = 0

# lives are common to pacman and the ship
var lives = conf.current.SHIP_LIVES

const SCENE_LIFE_DOWN = preload('res://scenes/HUD/life-down.tscn')
const SCENE_ENEMY_HIT = preload('res://scenes/HUD/enemy-hit.tscn')


func _ready():
	get_tree().connect("network_peer_disconnected",self,'_on_network_peer_disconnected')
	get_tree().connect("server_disconnected",self,'_on_server_disconnected')
	
	for i in range(conf.current.START_LEVEL):
		level_up()
	
	if lobby.i_am_the_game():
		walls.rpc("new_walls")
		walls.new_walls()
	
	# attribute network master status to both players
	if get_tree().get_network_peer() != null:
		
		# TODO: pause everyone and wait for clients to be ready too (see the doc)
		
		var players = ['ship','pacman']
		for i in range(players.size()):
			get_node(players[i]).set_network_master(lobby.clients[i])


func _on_network_peer_disconnected(peer_id):
	lobby.clients.erase(peer_id)
	lobby.clients_ready.erase(peer_id)
	
	if lobby.i_am_the_game() and lobby.clients.size() < 2:
		prints('peer disconnected during the game, quitting - ',peer_id)
		get_tree().quit()


func _on_server_disconnected():
	global.end_game('A player disconnected')


func _process(delta):
	game_time += delta


remote func earn_life(who):
	global.play_sound('heart_collected',false)
	lives += 1
	find_node('HUD').update()
	
	var lifeup = SCENE_LIFE_DOWN.instance()
	lifeup.position = get_node(who).position
	lifeup.find_node('cross').visible = false
	$'/root/world/HUD'.add_child(lifeup)


func lose_life(who):
	global.play_sound('player_hit')
	
	lives -= 1
	find_node('HUD').update()
	if lives < 0:
		$'HUD/game-over-spot'.position = who.position
		if who.is_in_group('pacman'):
			$'HUD/game-over-spot'.position += Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2)
		$'HUD/game-over-spot'.visible = true
		global.end_game()
		return
	
	var lifedown = SCENE_LIFE_DOWN.instance()
	lifedown.position = who.position
	$'/root/world/HUD'.add_child(lifedown)


func earn_gold(who,inc=100):
	gold += inc
	get_node('HUD').update()
	
	for i in range(floor(inc/100)):
		var hit = SCENE_ENEMY_HIT.instance()
		hit.position = who.position + Vector2(i * global.GRID_SIZE / 5,i * global.GRID_SIZE / 5)
		$'HUD'.add_child(hit)


puppet func level_up():
	level += 1
	conf.level_up(level)
	
	find_node('spawner').nb_enemies_left = conf.current.TRIS_SHAPE_NB_ENEMIES
	
	if level == 1:
		return
	
	# add a heart randomly on the map
	if lobby.i_am_the_game():
		new_item('heart')


var item_i = 0
var items = {
	'heart': global.HEART,
	'bubble': global.BUBBLE,
	'slow-mo': global.SLOW_MO
}
func new_item(item_name=''):
	if not item_name:
		item_name = items.keys()[floor(rand_range(0,3))]
	var pos = global.get_random_maze_pos()
	rpc("sync_new_item",item_name,pos,item_i)
	sync_new_item(item_name,pos,item_i)
	item_i += 1

remote func sync_new_item(item_name,pos,i):
	var item = items[item_name].instance()
	item.name = 'item-' + str(i)
	item.position = pos
	$'/root/world/items'.add_child(item)
