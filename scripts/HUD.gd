extends Node2D

var hearts_bits

func _ready():
	hearts_bits = [
		find_node('heart').find_node('empty'),
		#find_node('heart').find_node('half'),
		find_node('heart').find_node('full'),
		find_node('heart2').find_node('empty'),
		#find_node('heart2').find_node('half'),
		find_node('heart2').find_node('full'),
		find_node('heart3').find_node('empty'),
		#find_node('heart3').find_node('half'),
		find_node('heart3').find_node('full'),
	]

var update_interval = 1
var updated_last = update_interval  # update once when the game starts

func _process(delta):
	updated_last += delta
	if updated_last < update_interval:
		return
	updated_last = 0
	
	update()

func update():
	var world = $'/root/world'
	
	# time spent in game
	var time = int(world.game_time)
	var time_str = ''
	if time >= 60*60:
		time_str += str(floor(time / 60/60)) + 'h'
		time %= 60*60
	if time >= 60:
		time_str += ' ' + str(floor(time / 60)) + 'm'
		time %= 60
	time_str += ' ' + str(floor(time)) + 's'
	find_node('game_time').text = time_str
	
	# update level and ship lives display
	find_node('level').text = 'Level ' + str(world.level)
	var lives = world.lives
	for i in range(6):
		hearts_bits[i].visible = i <= lives
	
	find_node('lives-count').text = str(lives+1)
	find_node('lives-count').visible = lives >= 6
	
	
	# update enemy count display
	var nb_enemies = global.get_shapes(['ENEMY']).size()
	var nb_enemies_left = world.find_node('spawner').nb_enemies_left
	find_node('nb_enemies_left').text = str(nb_enemies) + '/' + str(floor(conf.current.TRIS_SHAPE_MAX_ENEMIES_SIMULT)) + ' (' + str(nb_enemies_left) + ')'
	
	# update ghost count display
	var nb_ghosts = get_tree().get_nodes_in_group('ghosts').size()
	find_node('nb_ghosts').text = str(nb_ghosts) + '/' + str(floor(conf.current.GHOSTS_MAX_NB_SIMULT))
	
	# gold
	find_node('goldcount').text = str(world.gold)

