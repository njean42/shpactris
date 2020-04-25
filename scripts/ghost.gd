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

var colors = [
	Color(231.0/255, 76.0/255, 60.0/255),  # red
	Color(46.0/255, 204.0/255, 113.0/255), # green
	Color(241.0/255, 196.0/255, 15.0/255), # yellow
	Color(155.0/255, 89.0/255, 182.0/255), # purple
]

func _ready():
	# appear
	find_node('anim').get_animation('appear').set_length(conf.current.GHOSTS_SPAWN_DURATION)
	
	# choose random color from available ones
	colors.shuffle()
	var ghosts = get_tree().get_nodes_in_group('ghosts')
	var color = false
	
	for c in colors:
		var color_is_used = false
		for g in ghosts:
			if g != self and g.get_node('sprite').self_modulate == c:
				color_is_used = true
		if not color_is_used:
			color = c
			break
	get_node('sprite').self_modulate = color
	
	# choose random position in the maze
	global.disable_collision(self)
	position = global.get_random_maze_pos()

func _physics_process(delta):
	if direction == null:
		return
	
	speed = conf.current.GHOSTS_SPEED  # will be affected by slow-mo
	
	# we have reached the first cell on path, remove it (move to next cell)
	if path2pacman.size() > 0 and global.pos_to_grid(position) == path2pacman[0]:
		path2pacman.pop_front()
		if global.DEBUG:
			global.remove_milestones(global.attach_pos_to_grid(position))
	
	# at crossroads (on grid positions), try new directions
	var gridpos = global.attach_pos_to_grid(position)
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
			find_node('anim').play('shake-and-die')
			break
		
		paths = new_paths
	
	return []

func collide(c):
	# hurt pacman and die
	if c.collider.is_in_group('pacman'):
		c.collider.get_hurt()
		global.remove_from_game(self)
	
	# bounce off pacman-walls
	if c.collider.is_in_group('pacman-walls'):
		update_direction()
	
	# bounce off tris-shapes
	if c.collider.is_in_group('tris-shape'):
		# artificially remember that there is a 'wall' here (= bounce off friendly tetris shapes)
		var fake_wall_pos = global.pos_to_grid(position)
		for i in ['x','y']:
			if direction[i] > 0:
				fake_wall_pos[i] += direction[i]
		var rot = 0 if direction.x == 0 else 90
		walls.new_fake_wall(fake_wall_pos.x,fake_wall_pos.y,rot)
		
		direction  = -direction
		update_direction()

func update_direction():
	position = global.attach_pos_to_grid(position)
	var gridpos = global.pos_to_grid(position)
	
	if global.DEBUG:
		global.remove_milestones()
	path2pacman = path_to_pacman()
	if path2pacman.size() == 0:
		path2pacman = [gridpos]  # already on pacman
	
	# try to reach the next cell on my path
	var next_cell = path2pacman[0]
	
	if global.DEBUG:
		global.milestone(next_cell.x,next_cell.y,Vector2(),Color(1,0,0))
	
	direction = (next_cell - gridpos).normalized()
	
	# sprite should face left or right
	if direction == global.RIGHT:
		find_node('sprite').flip_h = false
	elif direction == global.LEFT:
		find_node('sprite').flip_h = true

func _on_anim_animation_started(anim_name):
	match anim_name:
		'shake-and-die':
			global.play_sound('ghost_killed')
			modulate.a = 0.5
			global.disable_collision(self)

func _on_anim_animation_finished(anim_name):
	match anim_name:
		'appear':
			find_node('sprite').modulate.a = 1
			global.enable_collision(self)
			update_direction()
			
		'shake-and-die':
			queue_free()
