extends Node2D

var nb_enemies_left = 0
var time_since_last_shape = 0
var time_since_last_ghost = 0

var spawned_special = []
onready var last_level_with_special = global.SHAPES_SPECIAL.keys().max()


func _physics_process(delta):
	
	# check if we should level up
	if nb_enemies_left == 0 and global.get_shapes(['ENEMY','FRIEND','FROZEN']).size() == 0:
		
		# spawn special shapes?
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
		spawn_ghost()
	
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

func spawn_ghost():
	var ghosts = get_tree().get_nodes_in_group('ghosts')
	if ghosts.size()+1 > conf.current.GHOSTS_MAX_NB_SIMULT:
		return
	global.remove_milestones()
	$'/root/world/ghosts'.add_child(global.GHOST.instance())
