extends Node2D


var SCREEN_SIZE
var GRID_SIZE = 40
var HUD

var UP = Vector2(0,-1)
var DOWN = Vector2(0,1)
var LEFT = Vector2(-1,0)
var RIGHT = Vector2(1,0)
var DIRECTIONS = [UP,DOWN,LEFT,RIGHT]
var DIRECTIONS_TEXT = ['up','down','left','right']

var DEBUG = false

var PLAYERS = {
	'ship': null,
	'pacman': null,
	'mode_1p': true,
	'mouse': null
}

var SERVER_COMPATIBILITY = 'v1.2'

# preload scenes to be added in-game
const GHOST = preload('res://scenes/ghost.tscn')
const HEART = preload('res://scenes/items/heart.tscn')
const BUBBLE = preload('res://scenes/items/bubble.tscn')
const SLOW_MO = preload('res://scenes/items/slow-mo.tscn')
const SCENE_MILESTONE = preload('res://scenes/debug/milestone.tscn')
const SCENE_BASE = preload('res://scenes/debug/base.tscn')
const SHAPES = [
	preload('res://scenes/shapes/regular/tris-shape-bar.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-L.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-L2.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-S.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-S2.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-square.tscn'),
	preload('res://scenes/shapes/regular/tris-shape-t.tscn'),
]
const SHAPE_SPECIAL_CROSS = preload('res://scenes/shapes/special/tris-shape-cross.tscn')
const SHAPE_SPECIAL_STAIRS = preload('res://scenes/shapes/special/tris-shape-stairs.tscn')
const SHAPE_SPECIAL_U = preload('res://scenes/shapes/special/tris-shape-u.tscn')
var SHAPES_SPECIAL = {
	2: SHAPE_SPECIAL_CROSS,
	4: SHAPE_SPECIAL_STAIRS,
	6: SHAPE_SPECIAL_U,
}

const GHOSTS = {
	'BLINKY': Color(231.0/255, 76.0/255, 60.0/255),  # red
	'CLYDE': Color(241.0/255, 196.0/255, 15.0/255),  # orange
	'INKY': Color(46.0/255, 204.0/255, 113.0/255),   # green
	'PINKY': Color(155.0/255, 89.0/255, 182.0/255),  # purple
}

enum {
	LAYER_SHIP, # 0
	LAYER_PACMAN, # 1
	LAYER_TETRIS_SHAPE_ENEMIES, # 2
	LAYER_TETRIS_SHAPE_FROZEN, # 3
	LAYER_TETRIS_SHAPE_FRIENDS, # 4
	LAYER_WALLS, # 5
	LAYER_BULLETS, # 6
	LAYER_TETRIS_BULLET, # 7
	LAYER_ITEMS, # 8
	LAYER_TETRIS_BLOCKS, # 9
	LAYER_GHOSTS,  # 10
	LAYER_PACMAN_WALLS,  # 11
	LAYER_PACMAN_KILL,  # 12
	LAYER_TETRIS_BULLET_BAD,  # 13
}


var enemy_bullet_i = 0


func _ready():
	randomize()
	SCREEN_SIZE = {
		'x': GRID_SIZE * 11,
		'y': get_viewport_rect().size.y
	}

func get_layer(layers):
	var res = 0
	for l in layers:
		res += pow(2,l)
	return res

func get_random_maze_pos():
	return global.grid_to_pos(Vector2(
		floor(rand_range(walls.maze_x_min,walls.maze_x_max)),
		floor(rand_range(walls.maze_y_min,walls.maze_y_max))
	))

func remove_from_game(node):
	node.set_physics_process(false)
	node.global_position.x = -SCREEN_SIZE.x
	node.global_position.y = -SCREEN_SIZE.y
	node.set_collision_layer(0)
	node.set_collision_mask(0)
	node.queue_free()

func disable_collision(node):
	enable_collision(node,0)

func enable_collision(node,value=1):
	node.collision_layer = get_layer(node.collisions.layer) if value else 0
	node.collision_mask = get_layer(node.collisions.mask) if value else 0

func reparent(node,new_parent,new_position=null):
	if new_parent == get_parent():
		return
	
	var globpos = node.global_position
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	
	if new_position == null:
		node.set_global_position(globpos)
	else:
		node.set_position(new_position)

func pos_to_grid(pos):
	for i in ['x','y']:
		pos[i] = round( (pos[i] - GRID_SIZE/2) / GRID_SIZE )
	return pos

func attach_pos_to_grid(pos):
	return grid_to_pos(pos_to_grid(pos))

func grid_to_pos(gridpos):
	gridpos *= GRID_SIZE
	gridpos.x += GRID_SIZE/2
	gridpos.y += GRID_SIZE/2
	return gridpos

func get_shapes(statuses=null):
	if not (statuses is Array):
		statuses = [statuses]
	
	var shapes = []
	for s in get_tree().get_nodes_in_group('tris-shape'):
		if not statuses or s.status in statuses:
			shapes.append(s)
	
	return shapes


func path_find(from, to, colour=Color.white):
	var paths = [[from]]
	var known_cells = []
	
	if DEBUG:
		remove_milestones(false,colour)
	
	var step = 0
	while true:
		step += 1
		if step >= 100:
			prints('[BUG] path_find: too many steps, giving up',step)  # DEBUG
			break
		
		# try to extend current paths in all 4 directions
		var new_paths = []
		for p in paths:
			var curr_cell = p[-1]
			
			for d in range(DIRECTIONS.size()):
				var dir_text = DIRECTIONS_TEXT[d]
				var dir_ok = walls.allowed_dirs[curr_cell.x][curr_cell.y][dir_text] == 0
				
				# don't try to go through walls
				if not dir_ok:
					continue
				
				var next_cell = curr_cell + DIRECTIONS[d]
				# if another path already lands on next_cell, this path is useless
				if next_cell in known_cells:
					continue
				known_cells.append(next_cell)
				
				# don't add cells that are already on the path (don't go back)
				if next_cell in p:
					continue
				
				# add this next_cell to the current path
				new_paths.append(p.duplicate())
				new_paths[-1].append(next_cell)
				
				# found destination!
				if next_cell == to:
					p.append(next_cell)
					p.pop_front()  # remove ghost starting position (reached already)
					if DEBUG:
						for cell in p:
							milestone(cell.x, cell.y, Vector2(), colour)
					return p
		
		# no new paths, finished exploring
		if new_paths.size() == 0:
			break
		
		paths = new_paths
	
	return []


func enemy_hit(who):
	# earn gold
	$'/root/world'.earn_gold(who)
	
func end_game(error_msg=''):
	# if there's a game playing, pause it so we can see the score and everything
	$'/root/world/HUD/game-over-menu'.find_node('error-msg').text = error_msg
	$'/root/world/HUD/game-over-menu'.visible = true
	$'/root/world/HUD/game-over-menu/timer'.start()
	$'/root/world/HUD/pause-menu'.pause(true)  # game over

func milestone(x,y,dir,color=Color(0.05,0.05,0.05)):
	var milestone = SCENE_MILESTONE.instance()
	milestone.modulate = color
	milestone.global_position = global.grid_to_pos(Vector2(x,y)) + dir * 10
	$'/root/world'.add_child(milestone)

func remove_milestones(gridpos = false, color = null):
	var milestones = get_tree().get_nodes_in_group('milestones')
	for m in milestones:
		if color != null && m.modulate != color:
			continue
		if not gridpos or attach_pos_to_grid(m.position) == gridpos:
			m.queue_free()

func show_base(x,y,dir,color=Color(0.05,0.05,0.05)):
	var base = SCENE_BASE.instance()
	base.modulate = color
	base.global_position = global.grid_to_pos(Vector2(x,y)) + dir * 10
	$'/root/world'.add_child(base)

func remove_base(gridpos = false, color = null):
	var base = get_tree().get_nodes_in_group('bases')
	for m in base:
		if color != null && m.modulate != color:
			continue
		if not gridpos or attach_pos_to_grid(m.position) == gridpos:
			m.queue_free()

func play_sound(sound,play_remote=true):
	if play_remote:
		rpc("synced_play_sound",sound)
	synced_play_sound(sound)

remote func synced_play_sound(sound):
	$'/root/world/sounds'.play_sound(sound)


func save_user_data(new_data):
	var data = get_user_data()
	
	for k in new_data:
		data[k] = new_data[k]
	
	var file = File.new()
	file.open("user://user.json", File.WRITE)
	file.store_string(JSON.print(data))
	file.close()

func get_user_data(key=null):
	var file = File.new()
	file.open("user://user.json", File.READ)
	
	var data = file.get_as_text()
	data = JSON.parse(data)
	data = data.result if data.error == OK else {}
	
	file.close()
	if key == null:  # return whole data
		return data
	
	return data[key] if key in data else null
