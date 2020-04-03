extends Node2D

var level = 0
var game_time = 0
var gold = 0

# lives are common to pacman and the ship
var lives = conf.current.SHIP_LIVES

const SCENE_LIFE_DOWN = preload('res://scenes/HUD/life-down.tscn')
const SCENE_ENEMY_HIT = preload('res://scenes/HUD/enemy-hit.tscn')

func _ready():
	for i in range(conf.current.START_LEVEL):
		level_up()

func _process(delta):
	game_time += delta

func earn_life(who):
	global.play_sound('heart_collected')
	lives += 1
	find_node('HUD').update()
	
	var lifeup = SCENE_LIFE_DOWN.instance()
	lifeup.position = who.position
	lifeup.find_node('cross').visible = false
	$'/root/world/HUD'.add_child(lifeup)

func lose_life(who):
	global.play_sound('player_hit')
	
	lives -= 1
	find_node('HUD').update()
	if lives < 0:
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

func level_up():
	level += 1
	
	walls.new_walls()
	conf.level_up(level)
	
	find_node('spawner').nb_enemies_left = conf.current.TRIS_SHAPE_NB_ENEMIES
	
	if level == 1:
		return
	
	# add a heart randomly on the map
	get_node('items').add_child(global.HEART.instance())

