extends 'ship-pacman.gd'

var direction = null
var prev_dir = 'right'
var speed = false
var is_shadow = false
var use_mouse = global.PLAYERS.mouse == 'pacman'

var SHADOW = null

const BULLET_SPRITE = preload('res://scenes/shapes/enemy-bullet-sprite.tscn')


func _ready():
	position = global.attach_pos_to_grid(position)


func _physics_process(delta):
	if is_shadow:
		move(delta)
		return
	
	if lobby.i_am_pacman():
		player_move()
		move(delta)


var last_rpc_pos = null
var time_since_last_rpc = 0
func move(delta):
	
	var prev_pos = position
	
	var velocity = Vector2()
	var new_rot = null
	match direction:
		'right':
			velocity.x = 1
		'left':
			velocity.x = -1
		'down':
			velocity.y = 1
		'up':
			velocity.y = -1
	
	if direction == null and use_mouse:
		direction = next_mouse_dir()
	
	set_rot_from_direction()
	
	if direction != null:
		var c = move_and_collide(velocity * speed * delta)
		collide(c)
	
	time_since_last_rpc += delta
	if lobby.i_am_pacman() and not is_shadow:  # shadow pos is computed on each server/client
		if time_since_last_rpc >= 1.0/25 and position != last_rpc_pos:  # don't clutter the network if pacman didn't move
			time_since_last_rpc = 0
			last_rpc_pos = position
			rpc_unreliable("set_pos",position)
	
	# remove if off-maze (only shadows should go off screen)
	if lobby.i_am_pacman() and not walls.is_in_maze(global.pos_to_grid(position)):
		$'/root/world/pacman'.rpc("pacman_free_shadow",name)
		$'/root/world/pacman'.pacman_free_shadow(name)


func set_rot_from_direction():
	var dir = direction
	if dir == null and use_mouse:
		dir = mouse_facing()
	
	var new_rot = null
	match dir:
		'right':
			new_rot = 0
		'left':
			new_rot = 180
		'down':
			new_rot = 90
		'up':
			new_rot = -90
	
	var prev_rot = find_node('sprite').rotation_degrees
	if new_rot != null and new_rot != prev_rot:
		rpc("set_rot",new_rot)
		set_rot(new_rot)


func mouse_facing():
	var facing = get_global_mouse_position() - position
	if abs(facing.x) > abs(facing.y):
		return 'left' if sign(facing.x) < 0 else 'right'
	return 'up' if sign(facing.y) < 0 else 'down'


puppet func set_pos(pos):
	position = pos

puppet func set_rot(rot):
	find_node('sprite').rotation_degrees = rot


var path2mouse = []
var prev_right_click_pressed = false
func player_move():
	direction = null
	speed = conf.current.PACMAN_SPEED  # may have been updated (level up)
	
	# any_mode if pacman is playing on keyboard or solo, otherwise 2p_mode (controller-only)
	var mode = 'any_mode_' if global.PLAYERS.mode_1p or global.PLAYERS.pacman == null else '2p_mode_'
	
	if Input.is_action_pressed(mode+"pacman_right"):
		direction = 'right'
	elif Input.is_action_pressed(mode+"pacman_left"):
		direction = 'left'
	elif Input.is_action_pressed(mode+"pacman_down"):
		direction = 'down'
	elif Input.is_action_pressed(mode+"pacman_up"):
		direction = 'up'
	
	# enable mouse control
	if use_mouse:
		if direction == null:
			direction = next_mouse_dir()
	
		# face direction given by mouse (even when mouse is on pacman)
		if direction == null:
			set_rot_from_direction()
	
	# Stay on intersections (~cells) when Pacman stops moving
	if prev_dir != null and direction == null:
		position = global.attach_pos_to_grid(position)
		rpc("set_pos",position)
	
	# Also when changing direction
	if direction != null and prev_dir != null and direction != prev_dir:
		position = global.attach_pos_to_grid(position)
	
	prev_dir = direction
	
	var right_click_pressed = Input.is_mouse_button_pressed(BUTTON_RIGHT)
	
	if Input.is_action_just_pressed(mode+'pacman_fire_shadow') or use_mouse and not prev_right_click_pressed and right_click_pressed:
		fire_shadow()
	if Input.is_action_just_released(mode+'pacman_fire_shadow') or use_mouse and prev_right_click_pressed and not right_click_pressed:
		teleport()
	
	prev_right_click_pressed = right_click_pressed


func next_mouse_dir():
	if path2mouse.size() == 0:
		return null
	
	var next_cell = global.grid_to_pos(path2mouse[0])
	var vect2cell = next_cell - position
	if vect2cell.length() < global.GRID_SIZE / 10:
		path2mouse.pop_front()
		if path2mouse.size() == 0:  # done moving
			return null
		next_cell = global.grid_to_pos(path2mouse[0])
		vect2cell = next_cell - position
	
	if abs(vect2cell.x) > abs(vect2cell.y):
		return 'left' if sign(vect2cell.x) < 0 else 'right'
	return 'up' if sign(vect2cell.y) < 0 else 'down'


func _input(event):
	if not use_mouse or not lobby.i_am_pacman():
		return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == BUTTON_LEFT:
		var mousepos = event.position - Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2)
		path2mouse = global.path_find(
			global.pos_to_grid(self.position),
			global.pos_to_grid(mousepos),
			Color.yellow
		)
		get_tree().set_input_as_handled()


func collide(c):
	if not c:
		return
	
	if c.collider.is_in_group('tris-shape'):
		# push friendly tetris shapes
		global.play_sound('tris_shape_pushed')
		c.collider.friend_move_dir(-c.get_normal())
		# stick to grid and stop
		position = global.attach_pos_to_grid(position)
		position = position + c.get_normal().normalized() * global.GRID_SIZE/4
		direction = null
		
		# stop trying to reach last click position (mouse gameplay)
		path2mouse = []


# absorb enemy bullet (gather around pacman)
remote func absorb_bullet():
	global.enemy_hit(self)
	var bullets_list = $'/root/world/pacman/enemy-bullets'
	
	# display
	var nb_bullets = bullets_list.get_children().size()
	var angle = 2*PI / conf.current.PACMAN_MAX_ENEMY_BULLETS * nb_bullets
	var pos = Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2) + (Vector2.UP * global.GRID_SIZE/2).rotated(angle)
	
	var bullet = BULLET_SPRITE.instance()
	bullet.modulate.a = 0.5
	bullet.scale *= 0.75
	bullet.position = pos
	bullets_list.add_child(bullet)
	
	nb_bullets += 1
	
	# random power-up when pacman gathers X bullets
	if nb_bullets >= conf.current.PACMAN_MAX_ENEMY_BULLETS:
		for b in bullets_list.get_children():
			b.queue_free()
		bullet.queue_free()
		
		if lobby.i_am_pacman():
			$'/root/world'.new_item()

var can_teleport
var shadow_i = 0
func fire_shadow():
	can_teleport = true
	
	var shadow = get_shadow()
	if shadow != null:
		rpc("pacman_free_shadow",shadow.name)
		pacman_free_shadow(shadow.name)
	
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


func get_shadow():
	var shadow = get_tree().get_nodes_in_group('pacman-shadow')
	if shadow.size() == 0:
		return null
	return shadow[0]


func teleport():
	if not can_teleport:
		return
	
	# switch position with existing shadow
	var shadow = get_shadow()
	if shadow == null:
		return
	
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
		rpc("pacman_free_shadow",shadow.name)
		pacman_free_shadow(shadow.name)


var last_freed_shadow = ''
remote func pacman_free_shadow(shadow_name):
	if not lobby.i_am_pacman():
		return
	
	if shadow_name == last_freed_shadow:
		return
	last_freed_shadow = shadow_name
	
	var shadow = $'/root/world'.get_node(shadow_name)
	if shadow != null:
		shadow.rpc("free_shadow")
		shadow.free_shadow()


remote func free_shadow():
	if not is_shadow:
		prints('[BUG] asking to free shadow on',name)
		return
	queue_free()
