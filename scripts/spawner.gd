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
		prints(get_tree().get_network_unique_id(), "not network master, won't spawn ghosts or tetris pieces")
		set_physics_process(false)


func _physics_process(delta):
	
	# check if we should level up
	if nb_enemies_left == 0 and global.get_shapes(['ENEMY','FRIEND','FROZEN']).size() == 0:
		
		# spawn special shapes (bosses)?
		var level = $'/root/world'.level
		var equiv_level = null
		if not(level in spawned_special):
			var special = null
			for l in global.SHAPES_SPECIAL:
				if l == level:
					special = global.SHAPES_SPECIAL[l]
					break
				elif (level%last_level_with_special) % l == 0:
					equiv_level = l
			
			if special == null and equiv_level != null:
				# cycle through previous special pieces
				special = global.SHAPES_SPECIAL[equiv_level]
			
			if special:
				conf.announce_level('BOSS')
				spawned_special.append(level)
				$'/root/world/tris-shapes'.add_child(special.instance())
				return
		
		# or level up
		$'/root/world'.level_up()
		return
	
	# spawn new ghost
	time_since_last_ghost += delta
	if time_since_last_ghost >= conf.current.GHOSTS_SPAWN_INTERVAL:
		time_since_last_ghost = 0
		var pos = global.get_random_maze_pos()
		
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
		
		rpc("spawn_ghost",pos,color)
		spawn_ghost(pos,color)
		
	
	# spawn new shape
	time_since_last_shape += delta
	if time_since_last_shape >= conf.current.TRIS_SHAPE_SPAWN_INTERVAL:
		time_since_last_shape = 0
		spawn_shape()


func spawn_shape():
	var enemies = global.get_shapes('ENEMY')
	if nb_enemies_left == 0 or enemies.size() >= conf.current.TRIS_SHAPE_MAX_ENEMIES_SIMULT:
		return
	nb_enemies_left -= 1
	
	# random shape
	var s = floor(rand_range(0,global.SHAPES.size()))
	var shape = global.SHAPES[s]
	$'/root/world/tris-shapes'.add_child(shape.instance())


puppet func spawn_ghost(pos,color):
	var ghosts = get_tree().get_nodes_in_group('ghosts')
	if ghosts.size()+1 > conf.current.GHOSTS_MAX_NB_SIMULT:
		return
	global.remove_milestones()
	var ghost = global.GHOST.instance()
	ghost.position = pos
	ghost.get_node('sprite').self_modulate = color
	$'/root/world/ghosts'.add_child(ghost)
