extends KinematicBody2D

export var MAX_ROTATIONS = 2

const BULLET = preload('res://scenes/shapes/enemy-bullet.tscn')

var RED =   Color(0.5, 0, 0)  # enemy shapes
var GREEN = Color(0.5, 1, 0.5)  # friend shapes
var GREY =  Color(0.5, 0.5, 0.5, 0.50)  # floor shapes
var TRANSPARENT_BLUE =  Color(0.2, 0.6, 0.9, 0.50)  # frozen shapes

export var status = 'ENEMY'
var speed = conf.current.TRIS_SHAPE_SPEED
var destination
var time_since_last_bullet = 0
var time_since_last_friend_move = 0
var force_down = false
var rotation_counter = 0
onready var bullet_interval = conf.current.TRIS_SHAPE_BULLET_INTERVAL + rand_range(
	-conf.current.TRIS_SHAPE_BULLET_INTERVAL/2,
	conf.current.TRIS_SHAPE_BULLET_INTERVAL/2
	)

var LAYERS = {
	'FRIEND': global.get_layer([
		global.LAYER_WALLS,
		global.LAYER_TETRIS_BLOCKS,
		global.LAYER_PACMAN,
		global.LAYER_GHOSTS,
	]),
	'BLOCK_ROTATION': global.get_layer([
		global.LAYER_WALLS,
		global.LAYER_TETRIS_BLOCKS,
		global.LAYER_PACMAN,
	]),
}


func _ready():
	position = global.attach_pos_to_grid(position)
	switch_status(status,true)

func _physics_process(delta):
	speed = conf.current.TRIS_SHAPE_SPEED  # will be affected by slow-mo
	match status:
		'ENEMY':
			enemy_move(delta)
		'FRIEND':
			friend_move(delta)

func get_random_destination():
	# Get a destination above other shapes
	destination = Vector2(
		floor(rand_range(
			global.GRID_SIZE/2,
			global.SCREEN_SIZE.x-global.GRID_SIZE/2
		)),
		floor(rand_range(
			global.GRID_SIZE/2,
			$'/root/world/tetris-handler'.get_friendable_zone_bottom()
		))
	)
	destination = global.attach_pos_to_grid(destination)

func is_friendable():
	# can't become a friend if there are too many already
	if global.get_shapes(['FRIEND','FROZEN']).size() >= conf.current.TRIS_SHAPE_MAX_FRIENDS:
		return false
	
	# can't become a friend if my position is too low screen, or outside left and right borders
	var max_y = $'/root/world/tetris-handler'.get_friendable_zone_bottom()
	if position.y > max_y:
		return false
	if position.x < global.GRID_SIZE*2:
		return false
	if position.x > global.SCREEN_SIZE.x - global.GRID_SIZE*2:
		return false
	
	return true

func colorise(color):
	for child in $'blocks'.get_children():
		if child.has_node('box'):
			child.get_node('box').modulate = color

func switch_status(new_status,just_spawned=false):
	match new_status:
		'ENEMY':
			# enemies are more red-ish, and smaller
			colorise(RED)
			scale = Vector2(0.5,0.5)
			
			# Start off-screen
			var out = global.GRID_SIZE*3
			position.x = floor(rand_range(-out, global.SCREEN_SIZE.x+out))
			position.y = floor(rand_range(-out,-global.GRID_SIZE))
			
			get_random_destination()
			
		'FRIEND':
			# If I can't become a friend, stay an enemy and go some place else
			if not just_spawned and not is_friendable():
				get_random_destination()
				return false
			
			if not try_landing():
				# could not land while turning into FRIEND
				return false
			
			scale = Vector2(1,1)
			
			# ... Otherwise, become a friend
			colorise(GREEN)
			set_collision_layer(pow(2,global.LAYER_TETRIS_SHAPE_FRIENDS))
			set_collision_mask(LAYERS['FRIEND'])
		
		'FROZEN':
			colorise(TRANSPARENT_BLUE)
			
			set_collision_layer(pow(2,global.LAYER_TETRIS_SHAPE_FROZEN))
			set_collision_mask(
				pow(2,global.LAYER_TETRIS_BLOCKS) +
				pow(2,global.LAYER_WALLS)
			)
			
		'FLOOR':
			global.play_sound('tris_shape_down')
			position = global.attach_pos_to_grid(position)
			var block_is_killing_us = false
			
			# end_game if this block is too far up (outside the maze)
			for block in $'blocks'.get_children():
				if not block.has_node('box'):
					continue
				
				# discard enemy bullet
				var enemy_bullet = block.find_node('*enemy-bullet*',false,false)
				if enemy_bullet:
					enemy_bullet.queue_free()
				
				var globpos = block.global_position
				var gridpos = global.pos_to_grid( globpos + Vector2(global.GRID_SIZE/2, global.GRID_SIZE/2))
				
				if gridpos.y <= walls.top_wall_row_y:
					block.modulate = Color(1,0,0,1)
					block_is_killing_us = true
				
				block.find_node('gridpos').text = str(gridpos)
				
				# notify parent that a new block has been set
				$'/root/world/tetris-handler'.new_block(block)
			
			if block_is_killing_us:
				global.end_game()
			
			# we don't care about the shape anymore, turn it to individual blocks
			detach_blocks()
			
			return true
	
	status = new_status
	return true

func enemy_move(delta):
	# When position is reached, stop there and (maybe) become a friend
	if position.distance_to(destination) < speed * delta:
		position = destination
		switch_status('FRIEND')
		return
	
	var direction = (destination-position).normalized()
	position += direction * speed * delta
	
	# Fire an enemy bullet?
	time_since_last_bullet += delta
	if time_since_last_bullet >= bullet_interval:
		fire_enemy_bullet()
		time_since_last_bullet = 0

func fire_enemy_bullet():
	var bullet = BULLET.instance()
	bullet.global_position = global_position
	bullet.set_direction($'/root/world/ship'.global_position - global_position)
	$'/root/world/bullets'.add_child(bullet)

func friend_move(delta):
	# player(s) can force friendly tetris shapes to go down fast
	var mode = '1p_mode_' if global.PLAYERS.mode_1p else '2p_mode_'
	force_down = Input.is_action_just_pressed(mode+"pacman_drop") or force_down and Input.is_action_pressed(mode+"pacman_drop")
	
	# move down one square
	time_since_last_friend_move += delta
	if not force_down and time_since_last_friend_move < conf.current.TRIS_SHAPE_DOWN_INTERVAL:
		return
	
	time_since_last_friend_move = 0
	friend_move_dir(Vector2(0,1))

var COLLISION_SHOULD_STOP_MOVE = ['wall-bottom','tris-block-box']

func is_in_groups(obj,what):
	for g in what:
		if obj.is_in_group(g):
			return true
	return false

func absorb(enemy_bullet):
	# find an empty block to stick on
	var empty_block = null
	var bullets = []
	for block in $'blocks'.get_children():
		if not block.has_node('box'):
			continue
		var bullet = block.find_node('*enemy-bullet*',false,false)
		if bullet == null:
			empty_block = block
			break
		bullets.append(bullet)
	
	if empty_block == null:
		global.play_sound('tris_shape_break')
		# fire bullets (give them new directions so that they form a downward rainbow)
		for i in range(bullets.size()):
			var angle = deg2rad(45) + deg2rad(90) * i / bullets.size()
			var direction = Vector2.RIGHT.rotated(angle)
			global.enable_collision(bullets[i])
			bullets[i].set_physics_process(true)
			global.reparent(bullets[i],$'/root/world/bullets')
			bullets[i].set_direction(direction)
		
		# make blocks disappear
		for c in $'blocks'.get_children():
			if c.is_in_group('tris-block'):
				c.find_node('animation').play('fade-out')
		
		detach_blocks()
		return
	
	# stick to the tetris shape
	global.disable_collision(enemy_bullet)
	enemy_bullet.set_physics_process(false)
	global.reparent(enemy_bullet,empty_block,Vector2(0,0))
	
	# turn slowly to red as the number of bullets increases
	var ratio = (bullets.size()+1) / 4.0
	colorise(Color(
		GREEN.r + (RED.r - GREEN.r) * ratio,
		GREEN.g + (RED.g - GREEN.g) * ratio,
		GREEN.b + (RED.b - GREEN.b) * ratio
	))

func friend_move_dir(dir,step=0):
	var c = move_and_collide(dir * global.GRID_SIZE)
	position = global.attach_pos_to_grid(position)
	if c:
		if c.collider.is_in_group('enemy-bullets'):
			absorb(c.collider)
			friend_move_dir(c.remainder/global.GRID_SIZE,step+1)
			return
		
		if collide_and_kill(c):
			# move down by the rest of the collision move (we're killin that ghost and/or bullet after all)
			friend_move_dir(c.remainder/global.GRID_SIZE,step+1)
			return
		
		collide_stop_on_floor(c)
		force_down = false
	
	# I'm being pushed, don't move down before some time
	time_since_last_friend_move = 0

func friend_move_rotate(angle = PI/2, escape = true):
	rotate(angle)
	var orig_pos = global_position
	global_position = global.attach_pos_to_grid(global_position)
	
	var step = 1
	var chosen_dir = null
	var colliding = test_collisions('BLOCK_ROTATION')
	while colliding.size() > 0:
		if step > 2:
			# two many escape moves, rotate back
			rotate(-angle)
			global_position = orig_pos
			refused()
			return false
		step += 1
		
		if not escape:
			# cant escape moves, rotate back
			rotate(-angle)
			global_position = orig_pos
			refused()
			return false
		
		# can move left or right to "slide" against a wall (left or right, or tetris blocks)
		var blocker = null
		for c in colliding:
			blocker = c
			if c.is_in_group('wall-bottom') or c.is_in_group('pacman'):
				# unauthorised rotation, rotate back
				rotate(-angle)
				global_position = orig_pos
				refused([blocker])
				return false
		
		# try to move left of right to not stay stuck in walls or laying blocks
		if chosen_dir == null:
			chosen_dir = sign((global_position - blocker.global_position).x)
			# force moving right if too far left are left if too far right
			if global_position.x <= global.GRID_SIZE * 2:
				# forcing dir *right*, too far left
				chosen_dir = 1
			elif global_position.x >= global.SCREEN_SIZE.x - global.GRID_SIZE * 2:
				# forcing dir *left*, too far right
				chosen_dir = -1
		
		var move = Vector2(global.GRID_SIZE * chosen_dir, 0)
		global_position += move
		colliding = test_collisions('BLOCK_ROTATION')
	
	rotation_counter += angle / (PI/2)
	if rotation_counter >= MAX_ROTATIONS:
		rotation_counter = 0
		rotation = 0
	
	time_since_last_friend_move = 0  # don't move down for a while after I've rotated
	return true

func try_landing():  # when a tetris shape turns into a friend (from ENEMY or FROZEN state)
	var globpos = global_position
	global_position = global.attach_pos_to_grid(global_position)
	
	# TODO: crush ghosts?
	
	var could_land = friend_move_rotate(0)
	if not could_land:
		global_position = globpos
		
	return could_land

func refused(colliders=[]):
	global.play_sound('refused')
	colliders.append(self)
	for c in colliders:
		var anim = c.find_node('shake-refused')
		if anim:
			anim.play_me()

func test_collisions(layer):
	if not is_physics_processing():  # has to be, otherwise ray casting may not work
		prints('[BUG] not physics processing... (ship.test_collisions(',layer,'))')
		return []
	
	var space_state = get_world_2d().direct_space_state
	var col_layer = LAYERS[layer]
	
	var colliders = []
	for i in shape_owner_get_shape_count(0):  # can owner be != 0 ?
		var shape = shape_owner_get_shape(0,i)
		var trans = Transform2D(
			get_transform().get_rotation(),
			global_position # + shape.get_transform().get_origin()
		)
		
		var query = Physics2DShapeQueryParameters.new()
		query.set_shape(shape)
		query.set_transform(trans)
		query.collision_layer = col_layer
		
		var result = space_state.intersect_shape(query)
		for r in result:
			if not(r.collider in colliders):
				colliders.append(r.collider)
	
	return colliders

func collide_and_kill(c):
	# destroy ghosts and bullets on the way
	if c.collider.is_in_group('bullets'):
		global.remove_from_game(c.collider)
		return true
	
	if (c.collider.is_in_group('ghosts')):
		c.collider.find_node('anim').play('shake-and-die')
		return true
	
	return false

func collide_stop_on_floor(c):
	if c:
		if status == 'FRIEND' and is_in_groups(c.collider,COLLISION_SHOULD_STOP_MOVE):
			# check that this is a collision after moving or being pushed down (not left or right, as this results in tetris shapes "attaching" to other ground shapes)
			var normal = c.get_normal()
			if abs(normal.x) <= abs(normal.y) and normal.y < 0:
				switch_status('FLOOR')
				return true
	return false

func detach_blocks():
	colorise(GREY)
	
	for block in $'blocks'.get_children():
		if not block.has_node('box'):
			continue
		
		# become grayish-transparent and collisionable blocks
		block.get_node('box').set_collision_layer_bit(global.LAYER_TETRIS_BLOCKS,1)
		
		# append to general parent container 'tetris-handler'
		global.reparent(block,$'/root/world/tetris-handler')
	
	global.remove_from_game(self)
