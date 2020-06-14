extends Node2D

var nb_enemies_left = 0
var time_since_last_shape = 0
var time_since_last_ghost = 0

var spawned_special = []
onready var last_level_with_special = global.SHAPES_SPECIAL.keys().max()


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
		var ghost_names = global.GHOSTS.keys()
		ghost_names.shuffle()
		var living_ghosts = get_tree().get_nodes_in_group('ghosts')
		if living_ghosts.size()+1 <= conf.current.GHOSTS_MAX_NB_SIMULT:
			var new_ghost = false
			for g in ghost_names:
				var c = global.GHOSTS[g]
				var color_is_used = false
				for lg in living_ghosts:
					if lg.ghost_name == g:
						color_is_used = true
				if not color_is_used:
					new_ghost = g
					break
			
			var name = 'ghost-' + str(ghost_i)
			ghost_i += 1
			rpc("spawn_ghost",pos,new_ghost,name)
			spawn_ghost(pos,new_ghost,name)
	
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


puppet func spawn_ghost(pos,ghost_name,instance_name):
	global.remove_milestones()
	var ghost = global.GHOST.instance()
	ghost.position = pos
	ghost.get_node('sprite').self_modulate = global.GHOSTS[ghost_name]
	ghost.ghost_name = ghost_name
	ghost.name = instance_name
	$'/root/world/ghosts'.add_child(ghost)
