extends Node

const PACMAN_WALL = preload('res://scenes/pacman-wall.tscn')

var top_wall_row_y = 2
var nb_rows = 15
var maze_x_min = 0
var maze_x_max = 9
var maze_y_min = top_wall_row_y
var maze_y_max = top_wall_row_y + nb_rows

var allowed_dirs


func is_in_maze(gridpos):
	return gridpos.x >= maze_x_min and gridpos.x <= maze_x_max and gridpos.y >= maze_y_min and gridpos.y < maze_y_max

puppet func new_walls():
	
	$'/root/world/funky-imp'.time_since_last_wall_move = -2
	
	# remove current walls (and fake walls!)
	for wall in get_tree().get_nodes_in_group('pacman-walls'):
		wall.queue_free()
	for wall in get_tree().get_nodes_in_group('pacman-walls-fake'):
		wall.queue_free()
	
	allowed_dirs = range(maze_x_max + 2)
	for x in allowed_dirs.size():
		allowed_dirs[x] = range(maze_y_max + 2)
		for y in range(maze_y_max + 2):
			allowed_dirs[x][y] = {
				'up': 0,
				'down': 0,
				'left': 0,
				'right': 0,
			}
	
	if not lobby.i_am_the_game():
		return
	
	# draw a square around pacman's and ghosts' playground
	for x in range(maze_x_min, maze_x_max + 1):
		# top row
		new_wall(x, top_wall_row_y)
		# bottom row
		new_wall(x, top_wall_row_y + nb_rows)
	for y in range(maze_y_min, maze_y_max):
		# left column
		new_wall(0,y,90)
		# right column
		new_wall(10,y,90)

	# random walls
	for y in range(maze_y_min, maze_y_max):
		for x in range(maze_x_min,maze_x_max):
			var rot = 0 if randf() >= 0.33 else 90
			if randf() >= 0.25:
				if wall_ok(x,y,rot):
					new_wall(x,y,rot)
			
			# [debug mode] add random fake walls
			elif global.DEBUG and randf() >= 0.1:
				if wall_ok(x,y,rot):
					new_wall(x,y,rot,true,'GHOST_WALL')

func wall_ok(x,y,rot):
	return (
		not x in [maze_x_min, floor((maze_x_min+maze_x_max)/2), maze_x_max]
		) if rot == 0 else (
		not y in [maze_y_min, floor((maze_y_min+maze_y_max)/2), maze_y_max-1]
	)

var wall_i = 0
func new_wall(x,y,rot=0,new_walls=true,type='NORMAL'):
	if not lobby.i_am_the_game():
		return
	
	var wall_name = 'pacman-wall-' + str(wall_i)
	wall_i += 1
	rpc('synced_new_wall',x,y,rot,new_walls,type,wall_name)
	synced_new_wall(x,y,rot,new_walls,type,wall_name)

puppet func synced_new_wall(x,y,rot,new_walls,type,wall_name):
	var wall = PACMAN_WALL.instance()
	if type == 'GHOST_WALL':
		# don't block pacman, not a real wall (also leave group)
		wall.set_collision_layer_bit(global.LAYER_PACMAN_WALLS,0)
		wall.remove_from_group('pacman-walls')
		wall.add_to_group('pacman-walls-fake')  # will disappear after some time
		
		# [debug mode] ghost walls are only visible in debug mode
		if global.DEBUG:
			wall.modulate.a = 0.25
			wall.get_node('line').width = 1
		else:
			wall.visible = false
	
	
	wall.name = wall_name
	$'/root/world/pacman-walls'.add_child(wall)
	
	wall.position = global.grid_to_pos(Vector2(x,y))
	wall.rotation_degrees = rot
	
	# [debug mode] moved walls take a diferent color
	if global.DEBUG and not new_walls:
		wall.get_node('line').modulate = Color(0,1,0)
	
	update_allowed_dirs(x,y,rot,1)


func new_fake_wall(x,y,rot):
	new_wall(x,y,rot,false,'GHOST_WALL')


func remove_wall(wall):
	if lobby.i_am_the_game():
		var gridpos = global.pos_to_grid(wall.position)
		rpc("update_allowed_dirs",gridpos.x,gridpos.y,wall.rotation_degrees,-1)
		update_allowed_dirs(gridpos.x,gridpos.y,wall.rotation_degrees,-1)
		wall.rpc("be_removed")
		wall.be_removed()


puppet func update_allowed_dirs(x,y,rot,value):
	if rot == 0:
		allowed_dirs[x][y].up += value
		if y > top_wall_row_y:
			allowed_dirs[x][y-1].down += value
	elif rot == 90:
		allowed_dirs[x][y].left += value
		if x-1 >= 0:
			allowed_dirs[x-1][y].right += value

func wall_move():
	var walls = get_tree().get_nodes_in_group('pacman-walls')
	walls.shuffle()
	var wall = false
	while not wall:
		wall = walls.pop_front()
		if !wall_is_movable(wall):
			wall = false
	
	if not wall:
		return
	
	# move it
	remove_wall(wall)
	var rot = wall.rotation_degrees
	
	var pos = false
	while not pos:
		pos = Vector2(
			floor(
				rand_range(maze_x_min+1,maze_x_max)   # horizontal wall x
				if rot == 0 else
				rand_range(maze_x_min,maze_x_max) # vertical wall x
			),
			floor(
				rand_range(maze_y_min,maze_y_max) # horizontal wall y 
				if rot == 0 else
				rand_range(maze_y_min,maze_y_max)   # vertical wall y
			)
		)
		
		if not wall_ok(pos.x,pos.y,rot):
			pos = false
			continue
		
		# avoid stacking walls on the same spot
		if rot == 0 and allowed_dirs[pos.x][pos.y].up > 0 or rot == 90 and allowed_dirs[pos.x][pos.y].left > 0:
			pos = false
	
	new_wall(pos.x,pos.y,rot,false)

func wall_is_movable(wall):
	if not wall:
		prints('[BUG] wall disappeared')
		return false
	
	var gridpos = global.pos_to_grid(wall.position)
	
	# don't move the top and bottom full horizontal lines
	if gridpos.y in [maze_y_min,maze_y_max] and wall.rotation_degrees == 0:
		return false
	# don't move the left and right full vertical lines
	if gridpos.x in [maze_x_min,maze_x_max+1] and wall.rotation_degrees == 90:
		return false
		
	return true
