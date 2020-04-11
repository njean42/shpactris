extends Node


var current

# level up default values for increasing game difficulty
var default_increase = 1.05
var default_decrease = 0.95

var default = {
	'START_LEVEL': 1,
	
	'SHIP_SPEED': {'init': 400, 'levelup': default_increase},
	'SHIP_LIVES': 5,
	'SHIP_BULLET_RATE': 0.2,  # every X seconds
	'SHIP_FROST_BEAM_RATE': 1,  # every X seconds
	'SHIP_MAX_SPEED_AFTER': 0.2,  # ship 'unlocks' full speed after X seconds (speed/2 until then)
	'SHIP_BULLET_SPEED': {'init': 500, 'levelup': default_increase},
	
	'PACMAN_SPEED': {'init': 200, 'levelup': default_increase},
	'PACMAN_SHADOW_INTERVAL': 0.5,
	
	'PACMAN_WALLS_MOVE_INTERVAL': {'init': 1, 'levelup': default_decrease},
	
	'GHOSTS_SPEED': {'init': 60, 'levelup': default_increase},
	'GHOSTS_MAX_NB': 4,
	'GHOSTS_MAX_NB_SIMULT': 1,
	'GHOSTS_SPAWN_INTERVAL': {'init': 3, 'levelup': default_decrease},
	'GHOSTS_SPAWN_DURATION': {'init': 2.5, 'levelup': default_decrease},
	
	'TRIS_SHAPE_NB_ENEMIES': 5,
	'TRIS_SHAPE_MAX_ENEMIES_SIMULT': 2,
	'TRIS_SHAPE_SPAWN_INTERVAL': {'init': 5, 'levelup': default_decrease},  # one new shape every X seconds
	'TRIS_SHAPE_SPEED': {'init': 80, 'levelup': default_increase},
	'TRIS_SHAPE_BULLET_INTERVAL': {'init': 6, 'levelup': default_decrease},
	'TRIS_SHAPE_BULLET_SPEED': {'init': 100, 'levelup': default_increase},
	'TRIS_SHAPE_BULLET_FOLLOW': {'init': 10, 'levelup': default_increase}, # update direction to follow ship: at most X degrees per second
	'TRIS_SHAPE_MAX_FRIENDS': 1,
	'TRIS_SHAPE_DOWN_INTERVAL': {'init': 2, 'levelup': default_decrease},  # one square down every X seconds
}


func _init():
	init_conf()


func init_conf():
	current = default.duplicate(true)
	for k in current:
		if current[k] is Dictionary and 'init' in current[k]:
			current[k] = current[k]['init']


func level_up(level):
	
	if level == 1:
		init_conf()
		debug_speed()
		return
	
	# increase nb enemies to spawn
	current.TRIS_SHAPE_NB_ENEMIES += 1
	
	# more simultaneous tetris shapes, more ghosts
	current.TRIS_SHAPE_MAX_ENEMIES_SIMULT += 0.5
	current.GHOSTS_MAX_NB_SIMULT = min(4,current.GHOSTS_MAX_NB_SIMULT+0.5)
	
	# make the game more difficult: increase or decrease conf parameters
	for k in current:
		if default[k] is Dictionary and 'levelup' in default[k]:
			current[k] *= default[k]['levelup']
	
	debug_speed()


func debug_speed():
	if not global.DEBUG:
		return
	
	if $'/root/world'.level != 5:
		return
	
	prints(' ')
	prints('##### Level ', $'/root/world'.level, '#####')
	for s in current:
		var speed = '·'
		if default[s] is Dictionary and 'levelup' in default[s]:
			speed = '↗' if default[s]['levelup'] > 1 else '↘'
		prints(s+':', current[s], speed)
