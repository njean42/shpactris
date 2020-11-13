extends KinematicBody2D

var ghost_name = null

var speed = conf.current.GHOSTS_SPEED
var direction = null
var path2pacman = null
var current_base = null

var pinky_change_strat_cooldown = 0  # a number of cells to travel before switching strategy
var pinky_cells_ahead = 3
var inky_normal_behaviour = true  # normal = chase pacman (as opposed to going back to base)

var collisions = {
	'layer': [global.LAYER_GHOSTS],
	'mask': [
		global.LAYER_BULLETS,
		global.LAYER_TETRIS_SHAPE_FRIENDS,
		global.LAYER_PACMAN_KILL
	]
}

var base_list = [
	Vector2(walls.get_maze_min_size()[0], walls.get_maze_min_size()[1]),
	Vector2(walls.get_maze_max_size()[0], walls.get_maze_min_size()[1]),
	Vector2(walls.get_maze_max_size()[0], walls.get_maze_max_size()[1]),
	Vector2(walls.get_maze_min_size()[0], walls.get_maze_max_size()[1]),
]

func _ready():
	# appear
	find_node('anim').get_animation('appear').set_length(conf.current.GHOSTS_SPAWN_DURATION)
	global.disable_collision(self)
	
	# only the server compute ghosts collisions
	if not lobby.i_am_the_game() and not lobby.i_am_pacman():
		$'collision-shape'.disabled = true


func _physics_process(delta):
	if direction == null:
		return
	
	speed = conf.current.GHOSTS_SPEED  # will be affected by slow-mo
	
	# we have reached the first cell on path, remove it (move to next cell)
	if path2pacman.size() > 0 and global.pos_to_grid(position) == path2pacman[0]:
		path2pacman.pop_front()
		if global.DEBUG:
			global.remove_milestones(global.attach_pos_to_grid(position), global.GHOSTS[ghost_name])
	
	var gridpos = global.attach_pos_to_grid(position)
	
	# stick on a maze row or column (may be displaced after collision)
	if abs(direction.x) > abs(direction.y):  # going left or right
		if position.y != gridpos.y:
			position.y = gridpos.y # stick to current row
			rpc("set_pos",position,path2pacman)
			set_pos(position,path2pacman)
	else:  # going up or down
		if position.x != gridpos.x:
			position.x = gridpos.x # stick to current column
			rpc("set_pos",position,path2pacman)
			set_pos(position,path2pacman)
	
	# at crossroads (on grid positions), try new directions
	var dist2gridpos = (position - gridpos).length()
	if dist2gridpos < delta*float(speed)/2: # am I on grid? (= in the middle of a cell)
		update_direction()
	
	var c = move_and_collide(direction.normalized()*speed*delta)
	if c:
		collide(c)


func path_to_pacman():
	
	# start at the ghosts (grid) position
	var gridpos = global.pos_to_grid(position)
	var paths = [ [gridpos] ]
	
	var pacman = $'/root/world/pacman'
	var pacman_grid_pos = find_destination()
	
	var known_cells = []
	
	var step = 0
	while true:
		step += 1
		if step >= 100:
			prints('[BUG] path2pacman: too many steps, giving up',step)  # DEBUG
			break
		
		# try to extend current paths in all 4 directions
		var new_paths = []
		for p in paths:
			var curr_cell = p[-1]
			
			for d in range(global.DIRECTIONS.size()):
				var dir_text = global.DIRECTIONS_TEXT[d]
				var dir_ok = walls.allowed_dirs[curr_cell.x][curr_cell.y][dir_text] == 0
				
				# don't try to go through walls
				if not dir_ok:
					continue
				
				var next_cell = curr_cell + global.DIRECTIONS[d]
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
				
				# found pacman!
				if next_cell == pacman_grid_pos:
					p.append(next_cell)
					p.pop_front()  # remove ghost starting position (reached already)
					if global.DEBUG:
						for cell in p:
							global.milestone(cell.x, cell.y, Vector2(), global.GHOSTS[ghost_name])
					return p
		
		# no new paths, finished exploring
		if new_paths.size() == 0:
			rpc("die",'no_path2pacman')
			die('no_path2pacman')
			break
		
		paths = new_paths
	
	return []

func find_destination():
	var pacman_grid_pos
	
	var pacman = $'/root/world/pacman'
	match ghost_name:
		'BLINKY':  # red
			# default behaviour: chase pacman
			pacman_grid_pos = global.pos_to_grid(pacman.position)
		
		'INKY':  # green
			# INKY switches between chasing pacman an returning to base
			# its base changes from time to time
			
			# if INKY reaches base, it goes back to following pacman
			if (not inky_normal_behaviour) and global.pos_to_grid(position) == current_base:
				inky_normal_behaviour = true  # back to chasing pacman
				$timer_switch_behaviour.start()
			
			if inky_normal_behaviour:
				pacman_grid_pos = global.pos_to_grid(pacman.position)
			else:
				pacman_grid_pos = current_base
		
		'CLYDE':  # orange
			# CLYDE chases pacman if BLINKY is not present
			# if it is, CLYDE targets a cell that's opposite to BLINKY's position, relatively to pacman
			# this practically results in BLINKY and CLYDE surrounding pacman!
			var destination = global.pos_to_grid(pacman.position)
			
			var ghosts = get_tree().get_nodes_in_group('ghosts')
			for g in ghosts:
				if g.ghost_name == 'BLINKY':
					destination = global.pos_to_grid(pacman.position + (pacman.position - g.position))
					var c = 0
					while !walls.is_in_maze(destination):
						# bring back destination within maze
						c+= 1
						if c > 20:
							prints("[BUG] could not bring back CLYDE's destination within maze")
							destination = global.pos_to_grid(pacman.position)
							break
						for axis in [0,1]:
							if destination[axis] < (walls.get_maze_min_size()[axis] + walls.get_maze_max_size()[axis]) / 2:  # too far left or up
								destination[axis] += 1
							else:  # too far right or down
								destination[axis] -= 1
					break
			
			pacman_grid_pos = destination
		
		'PINKY':  # purple
			# pinky targets X cells ahead of pacman (depending on pacman orientation)
			pacman_grid_pos = global.pos_to_grid(pacman.position)
			
			# if pacman is close enough, target it directly
			# (don't switch back to targeting ahead of pacman for some time)
			var close_to_pacman = (pacman.position - position).length() / global.GRID_SIZE <= pinky_cells_ahead + 1
			if pinky_change_strat_cooldown > 0 or close_to_pacman:
				if pinky_change_strat_cooldown == 0:
					pinky_change_strat_cooldown = 5
				else:
					pinky_change_strat_cooldown -= 1
				return pacman_grid_pos
			
			var cells_ahead_x = 0
			var cells_ahead_y = 0
			match pacman.find_node('sprite').rotation_degrees:
				0.0:
					cells_ahead_x = pinky_cells_ahead   # pacman facing right
				90.0:
					cells_ahead_y = pinky_cells_ahead   # pacman facing down
				180.0:
					cells_ahead_x = -pinky_cells_ahead  # pacman facing left
				-90.0:
					cells_ahead_y = -pinky_cells_ahead  # pacman facing up
			
			for x in range(abs(cells_ahead_x)):
				pacman_grid_pos[0] += sign(cells_ahead_x)
				if not walls.is_in_maze(pacman_grid_pos):
					pacman_grid_pos[0] -= sign(cells_ahead_x)
					break
			for y in range(abs(cells_ahead_y)):
				pacman_grid_pos[1] += sign(cells_ahead_y)
				if not walls.is_in_maze(pacman_grid_pos):
					pacman_grid_pos[1] -= sign(cells_ahead_y)
					break
	
	return pacman_grid_pos


func set_random_base():
	current_base = base_list[randi() % 4]
	if global.DEBUG:
		global.remove_base(null, global.GHOSTS[ghost_name])
		global.show_base(current_base[0], current_base[1], Vector2(), global.GHOSTS[ghost_name])


func collide(c):
	if not lobby.i_am_the_game():
		return
	
	# hurt pacman and die
	if c.collider.is_in_group('pacman'):
		var collider = c.collider.get_parent()
		if collider.is_shadow:  # don't hurt pacman's shadow
			$'/root/world/pacman'.rpc("pacman_free_shadow",collider.name)
			$'/root/world/pacman'.pacman_free_shadow(collider.name)
			return
		
		rpc("die",'hit_pacman')
		die('hit_pacman')
	
	# bounce off pacman-walls
	elif c.collider.is_in_group('pacman-walls'):
		update_direction()
	
	# bounce off tris-shapes
	elif c.collider.is_in_group('tris-shape'):
		# artificially remember that there is a 'wall' here (= bounce off friendly tetris shapes)
		var fake_wall_pos = global.pos_to_grid(position)
		for i in ['x','y']:
			if direction[i] > 0:
				fake_wall_pos[i] += direction[i]
		var rot = 0 if direction.x == 0 else 90
		walls.new_fake_wall(fake_wall_pos.x,fake_wall_pos.y,rot)
		
		direction  = -direction
		update_direction()


remote func set_pos(pos,path):
	position = pos
	path2pacman = path
	var next_cell = path2pacman[0]  # try to reach the next cell on my path
	direction = (next_cell - global.pos_to_grid(position)).normalized()
	
	if global.DEBUG:
		global.milestone(next_cell.x,next_cell.y,Vector2(),global.GHOSTS[ghost_name])


func update_direction():
	if not lobby.i_am_the_game():
		return
	
	position = global.attach_pos_to_grid(position)
	var gridpos = global.pos_to_grid(position)
	
	if global.DEBUG:
		global.remove_milestones(false, global.GHOSTS[ghost_name])
	path2pacman = path_to_pacman()
	if path2pacman.size() == 0:
		path2pacman = [gridpos]  # already on pacman
	
	rpc("set_pos",position,path2pacman)
	set_pos(position,path2pacman)


remote func die(why):
	match why:
		'hit_pacman':
			$'/root/world/pacman'.get_hurt()
			global.remove_from_game(self)
		
		'no_path2pacman':
			find_node('anim').play('shake-and-die')
		
		'crushed_by_tetris_piece':
			find_node('anim').play('shake-and-die')
		
		'hit_by_bullet':
			find_node('anim').play('shake-and-die')


func _on_anim_animation_started(anim_name):
	match anim_name:
		'shake-and-die':
			global.play_sound('ghost_killed',false)
			modulate.a = 0.5
			global.disable_collision(self)
			set_physics_process(false)

func _on_anim_animation_finished(anim_name):
	match anim_name:
		'appear':
			find_node('sprite').modulate.a = 1
			global.enable_collision(self)
			set_random_base()
			update_direction()
			
		'shake-and-die':
			queue_free()


func _on_timer_switch_behaviour_timeout():
	inky_normal_behaviour = !inky_normal_behaviour


func _on_timer_switch_base_timeout():
	set_random_base()
