extends Node2D

var nb_enemies_left = 0
var time_since_last_shape = 0
var time_since_last_ghost = 0

var spawned_special = []
onready var last_level_with_special = global.SHAPES_SPECIAL.keys().max()

var colors = [
	Color(231.0/255, 76.0/255, 60.0/255),  # red
	Color(46.0/255, 204.0/255, 113.0/255), # green
	Color(241.0/255, 196.0/255, 15.0/255), # yellow
	Color(155.0/255, 89.0/255, 182.0/255), # purple
]


func _ready():
	if not lobby.i_am_the_game():
		set_physics_process(false)


var shape_i = 0
var ghost_i = 0
func _physics_process(delta):
	
	# check if we should level up
	if nb_enemies_left == 0 and global.get_shapes(['ENEMY','FRIEND','FROZEN']).size() == 0:
		
		# spawn special shapes (bosses)?
		var level = $'/root/world'.level
		var equiv_level = null
		if not(level in spawned_special):
			var s = null
			for l in global.SHAPES_SPECIAL:
				if l == level:
					s = l
					break
				elif (level%last_level_with_special) % l == 0:
					equiv_level = l
			
			if s == null and equiv_level != null:
				# cycle through previous special pieces
				s = equiv_level
			
			if s != null:
				conf.announce_level('BOSS',true)
				spawned_special.append(level)
				var shape_name = 'tris-shape-boss-' + str(shape_i)
				shape_i += 1
				rpc("spawn_special_shape",s,shape_name)
				spawn_special_shape(s,shape_name)
				return
		
		# or level up
		$'/root/world'.rpc("level_up")
		$'/root/world'.level_up()
		walls.rpc("new_walls")
		walls.new_walls()
		return
	
	# spawn new ghost
	time_since_last_ghost += delta
	if time_since_last_ghost >= conf.current.GHOSTS_SPAWN_INTERVAL:
		time_since_last_ghost = 0
		var pos = global.get_random_maze_pos()
		
		# choose random color from available ones
		colors.shuffle()
		var ghosts = get_tree().get_nodes_in_group('ghosts')
		if ghosts.size()+1 <= conf.current.GHOSTS_MAX_NB_SIMULT:
			var color = false
			for c in colors:
				var color_is_used = false
				for g in ghosts:
					if g != self and g.get_node('sprite').self_modulate == c:
						color_is_used = true
				if not color_is_used:
					color = c
					break
			
			var ghost_name = 'ghost-' + str(ghost_i)
			ghost_i += 1
			rpc("spawn_ghost",pos,color,ghost_name)
			spawn_ghost(pos,color,ghost_name)
	
	# spawn new shape
	time_since_last_shape += delta
	if time_since_last_shape >= conf.current.TRIS_SHAPE_SPAWN_INTERVAL:
		time_since_last_shape = 0
		
		var enemies = global.get_shapes('ENEMY')
		if nb_enemies_left == 0 or enemies.size() >= conf.current.TRIS_SHAPE_MAX_ENEMIES_SIMULT:
			return
		nb_enemies_left -= 1
		
		# random shape
		var s = floor(rand_range(0,global.SHAPES.size()))
		var shape_name = 'tris-shape-' + str(shape_i)
		shape_i += 1
		rpc("spawn_shape",s,shape_name)
		spawn_shape(s,shape_name)


puppet func spawn_shape(s,shape_name):
	var shape = global.SHAPES[s].instance()
	shape.name = shape_name
	$'/root/world/tris-shapes'.add_child(shape)


puppet func spawn_special_shape(s,shape_name):
	var shape = global.SHAPES_SPECIAL[s].instance()
	shape.name = shape_name
	$'/root/world/tris-shapes'.add_child(shape)


puppet func spawn_ghost(pos,color,ghost_name):
	global.remove_milestones()
	var ghost = global.GHOST.instance()
	ghost.position = pos
	ghost.get_node('sprite').self_modulate = color
	ghost.name = ghost_name
	$'/root/world/ghosts'.add_child(ghost)
