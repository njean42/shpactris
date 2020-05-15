extends KinematicBody2D

var speed = conf.current.GHOSTS_SPEED
var direction = null
var path2pacman = null


var collisions = {
	'layer': [global.LAYER_GHOSTS],
	'mask': [
		global.LAYER_BULLETS,
		global.LAYER_TETRIS_SHAPE_FRIENDS,
		global.LAYER_PACMAN_KILL
	]
}

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
			global.remove_milestones(global.attach_pos_to_grid(position))
	
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
	var pacman_grid_pos = global.pos_to_grid(pacman.position)
	
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
							global.milestone(cell.x, cell.y, Vector2(), Color(0.33,0.66,0.33))
					return p
		
		# no new paths, finished exploring
		if new_paths.size() == 0:
			rpc("die",'no_path2pacman')
			die('no_path2pacman')
			break
		
		paths = new_paths
	
	return []


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
		global.milestone(next_cell.x,next_cell.y,Vector2(),Color(1,0,0))


func update_direction():
	if not lobby.i_am_the_game():
		return
	
	position = global.attach_pos_to_grid(position)
	var gridpos = global.pos_to_grid(position)
	
	if global.DEBUG:
		global.remove_milestones()
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
			update_direction()
			
		'shake-and-die':
			queue_free()
