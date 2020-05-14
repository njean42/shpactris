extends 'ship-pacman.gd'

var direction = null
var prev_dir = 'right'
var speed = false
var is_shadow = false

var SHADOW = null
var MAX_ENEMY_BULLETS = 8


func _ready():
	position = global.attach_pos_to_grid(position)
	# TODO: if not i_am_pacman: disable some collisions?


func _physics_process(delta):
	if is_shadow:
		move(delta)
		return
	
	if lobby.i_am_pacman():
		player_move()
		move(delta)


func move(delta):
	
	var prev_pos = position
	var prev_rot = find_node('sprite').rotation_degrees
	
	var velocity = Vector2()
	var new_rot = null
	match direction:
		'right':
			velocity.x = 1
			new_rot = 0
		'left':
			velocity.x = -1
			new_rot = 180
		'down':
			velocity.y = 1
			new_rot = 90
		'up':
			velocity.y = -1
			new_rot = -90
	
	if new_rot != null and new_rot != prev_rot:
		rpc("set_rot",new_rot)
		set_rot(new_rot)
	
	if direction != null:
		var c = move_and_collide(velocity * speed * delta)
		collide(c)
	
	if lobby.i_am_pacman() and not is_shadow:  # shadow pos is computed on each server/client
		if position != prev_pos:  # don't clutter the network if pacman didn't move
			rpc_unreliable("set_pos",position)
			# TODO: limit to n times/second?
	
	# remove if off-maze (only shadows should go off screen)
	if lobby.i_am_pacman() and not walls.is_in_maze(global.pos_to_grid(position)):
		rpc("free_shadow")
		free_shadow()


puppet func set_pos(pos):
	position = pos

puppet func set_rot(rot):
	find_node('sprite').rotation_degrees = rot


func player_move():
	direction = null
	speed = conf.current.PACMAN_SPEED  # may have been updated (level up)
	if Input.is_action_pressed("any_mode_pacman_right"):
		direction = 'right'
	elif Input.is_action_pressed("any_mode_pacman_left"):
		direction = 'left'
	elif Input.is_action_pressed("any_mode_pacman_down"):
		direction = 'down'
	elif Input.is_action_pressed("any_mode_pacman_up"):
		direction = 'up'
	
	# Stay on intersections (~cells) when Pacman stops moving
	if prev_dir != null and direction == null:
		position = global.attach_pos_to_grid(position)
		rpc("set_pos",position)
	
	# Also when changing direction
	if direction != null and prev_dir != null and direction != prev_dir:
		position = global.attach_pos_to_grid(position)
	
	prev_dir = direction
	
	var mode = 'any_mode_' if global.PLAYERS.mode_1p else '2p_mode_'
	if Input.is_action_just_pressed(mode+'pacman_fire_shadow'):
		fire_shadow()
	if Input.is_action_just_released(mode+'pacman_fire_shadow'):
		teleport()


func collide(c):
	if not c:
		return
	
	if c.collider.is_in_group('enemy-bullets'):
		c.collider.rpc("be_absorbed",name)
		c.collider.be_absorbed(name)
	
	if c.collider.is_in_group('tris-shape'):
		# push friendly tetris shapes
		global.play_sound('tris_shape_pushed')
		c.collider.friend_move_dir(-c.get_normal())
		# stick to grid and stop
		position = global.attach_pos_to_grid(position)
		position = position + c.get_normal().normalized() * global.GRID_SIZE/4
		direction = null


# absorb enemy bullet (gather around pacman)
func absorb(bullet):
	if bullet.is_in_group('enemy-bullets-bad'):
		# hitting a bad enemy bullet with pacman's shadow doesn't lose life; the shadow disappears
		if is_shadow:
			free_shadow()  # already in sync
			return
		
		get_hurt()
		global.remove_from_game(bullet)
		return
	
	global.enemy_hit(bullet)
	var bullets_list = $'/root/world/pacman/enemy-bullets'
	
	# display
	var nb_bullets = bullets_list.get_children().size()
	var angle = 2*PI / MAX_ENEMY_BULLETS * nb_bullets
	var pos = Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2) + (Vector2.UP * global.GRID_SIZE/2).rotated(angle)
	bullet.modulate.a = 0.5
	bullet.scale *= 0.75
	
	# reparent and remove from collisions
	global.reparent(bullet,bullets_list,pos)
	global.disable_collision(bullet)
	bullet.set_physics_process(false)
	nb_bullets += 1
	
	# random power-up when pacman gathers X bullets
	if nb_bullets >= MAX_ENEMY_BULLETS:
		for b in bullets_list.get_children():
			b.queue_free()
		bullet.queue_free()
		
		if lobby.i_am_pacman():
			$'/root/world'.new_item()

var can_teleport
var shadow_i = 0
func fire_shadow():
	can_teleport = true
	
	var shadow = get_tree().get_nodes_in_group('pacman-shadow')
	if shadow.size() > 0:
		shadow[0].rpc("free_shadow")
		shadow[0].free_shadow()
	
	var dir = {
		'0': 'right',
		'180': 'left',
		'90': 'down',
		'-90': 'up'
	}[str(find_node('sprite').rotation_degrees)]
	var speed = conf.current.PACMAN_SPEED * 2  # shadows travel twice as fast as pacman
	var rot = find_node('sprite').rotation_degrees
	rpc("synced_fire_shadow",global_position,dir,rot,speed,shadow_i)
	synced_fire_shadow(global_position,dir,rot,speed,shadow_i)
	shadow_i += 1


puppet func synced_fire_shadow(pos,dir,rot,speed,i):
	if SHADOW == null:
		SHADOW = load('res://scenes/pacman-shadow.tscn')
	
	var shadow = SHADOW.instance()
	shadow.global_position = pos
	shadow.is_shadow = true
	shadow.add_to_group('pacman-shadow')
	shadow.direction = dir
	shadow.speed = speed
	shadow.set_rot(rot)
	shadow.name = 'pacman-shadow-' + str(i)
	
	$'/root/world'.add_child(shadow)
	if get_tree().get_network_peer() != null:
		shadow.set_network_master(lobby.pacman)


func teleport():
	if not can_teleport:
		return
	
	# switch position with existing shadow
	var shadow = get_tree().get_nodes_in_group('pacman-shadow')
	if shadow.size() == 0:
		return
	shadow = shadow[0]
	
	# don't teleport just next to previous position
	var dist2pacman = (global_position - shadow.global_position).length()
	if floor(dist2pacman/global.GRID_SIZE) < 2: # traveled at least two cells
		can_teleport = false
		return
	
	var shadow_pos = global.pos_to_grid(shadow.global_position)
	if walls.is_in_maze(shadow_pos):
		var current_pos = global_position
		global_position = global.grid_to_pos(shadow_pos)
		
		# check that pacman won't collide with (step on) a friendly tetris piece
		var transform = get_transform()
		transform.origin = global_position
		var collision = test_move(transform,Vector2(0,0))
		if collision:
			can_teleport = false
			global_position = current_pos
			return
		
		rpc("set_pos",global_position)
		shadow.rpc("free_shadow")
		shadow.free_shadow()


remote func free_shadow():
	if not is_shadow:
		prints('[BUG] asking to free shadow on',name)
	queue_free()
