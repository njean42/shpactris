extends KinematicBody2D

export var MAX_ROTATIONS = 2

const BULLET = preload('res://scenes/shapes/enemy-bullet.tscn')
const BULLET_BAD = preload('res://scenes/shapes/enemy-bullet-bad.tscn')
const BULLET_SPRITE = preload('res://scenes/shapes/enemy-bullet-sprite.tscn')

var RED =   Color(0.5, 0, 0)  # enemy shapes
var GREEN = Color(0.5, 1, 0.5)  # friend shapes
var GREY =  Color(0.5, 0.5, 0.5, 0.33)  # floor shapes
var TRANSPARENT_BLUE =  Color(0.2, 0.6, 0.9, 0.50)  # frozen shapes

export var status = 'ENEMY'
var speed = conf.current.TRIS_SHAPE_SPEED
var destination
var time_since_last_bullet = 0
var time_since_last_friend_move = 0
var force_down = false
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
	global_position = global.attach_pos_to_grid(global_position)
	switch_status(status)


func _physics_process(delta):
	speed = conf.current.TRIS_SHAPE_SPEED  # will be affected by slow-mo
	match status:
		'ENEMY':
			enemy_move(delta)
		'FRIEND':
			friend_move(delta)


func get_random_destination():
	if not lobby.i_am_the_game():
		return
	
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
	
	rpc("set_dest",destination)
	set_dest(destination)
	rpc("set_pos",position)


remote func set_pos(pos):
	position = pos
	
remote func set_rot(rot,pos):
	rotation = rot
	position = pos
	# don't move down for a while after I've rotated
	time_since_last_friend_move = 0

puppet func set_dest(dest):
	destination = global.attach_pos_to_grid(dest)


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


func colorise():
	var color = null
	match status:
		'ENEMY':
			color = RED
		'FRIEND':
			var bullets = get_enemy_bullets()
			var ratio = bullets.size()*1.0 / $'piece/blocks'.get_children().size()
			color = Color(
				GREEN.r + (RED.r - GREEN.r) * ratio,
				GREEN.g + (RED.g - GREEN.g) * ratio,
				GREEN.b + (RED.b - GREEN.b) * ratio
			)
		'FROZEN':
			color = TRANSPARENT_BLUE
		'FLOOR':
			color = GREY
	
	if color != null:  # a destroyed shape has no new color
		for child in $'piece/blocks'.get_children():
			child.get_node('box').modulate = color


func can_switch_status(new_status):
	match new_status:
		'FRIEND':
			# If I can't become a friend, stay an enemy and go some place else
			if status == 'ENEMY' and not is_friendable():
				get_random_destination()
				return false
			
			if not try_landing():
				# could not land while turning into FRIEND
				return false
			
			return true


remote func switch_status(new_status,synced_pos=null,synced_rot=null):
	if status in ['FLOOR','DESTROYED']:
		prints("[desynced?] FLOOR and DESTROYED are final statuses, can't be switched from")
		return
	
	status = new_status
	colorise()
	
	if synced_pos != null:
		global_position = synced_pos
	if synced_rot != null:
		rotation = synced_rot
	
	match new_status:
		'ENEMY':
			# enemies are smaller
			scale = Vector2(0.5,0.5)
			
			# Start off-screen
			var out = global.GRID_SIZE*3
			position.x = floor(rand_range(-out, global.SCREEN_SIZE.x+out))
			position.y = floor(rand_range(-out,-global.GRID_SIZE))
			
			get_random_destination()
			
			set_collision_layer(pow(2,global.LAYER_TETRIS_SHAPE_ENEMIES))
			set_collision_mask(0)
			
		'FRIEND':
			scale = Vector2(1,1)
			set_collision_layer(pow(2,global.LAYER_TETRIS_SHAPE_FRIENDS))
			set_collision_mask(LAYERS['FRIEND'])
			global.reparent(self,$'/root/world/tris-shapes')
			time_since_last_friend_move = 0
		
		'FROZEN':
			set_collision_layer(pow(2,global.LAYER_TETRIS_SHAPE_FROZEN))
			set_collision_mask(
				pow(2,global.LAYER_TETRIS_BLOCKS) +
				pow(2,global.LAYER_WALLS)
			)
			global.reparent(self,$'/root/world/ship')
		
		'FLOOR':
			global.play_sound('tris_shape_down',false)
			global_position = global.attach_pos_to_grid(global_position)
			var block_is_killing_us = false
			
			# end_game if this block is too far up (outside the maze)
			for block in $'piece/blocks'.get_children():
				# discard enemy bullets
				var enemy_bullet = block.find_node('*enemy-bullet*',false,false)
				if enemy_bullet:
					enemy_bullet.queue_free()
				
				var globpos = block.global_position
				var gridpos = global.pos_to_grid( globpos + Vector2(global.GRID_SIZE/2, global.GRID_SIZE/2))
				
				if gridpos.y <= walls.top_wall_row_y:
					block.modulate = Color(1,0,0,1)
					block_is_killing_us = true
				
				block.find_node('gridpos').text = '%s;%s' % [gridpos.x,gridpos.y]
				
				# notify tetris-handler that a new block has been set
				$'/root/world/tetris-handler'.new_block(block)
			
			if block_is_killing_us:
				global.end_game()
			
			# we don't care about the shape anymore, turn it to individual blocks
			detach_blocks()
			return
		
		'DESTROYED':
			# make blocks disappear
			for c in $'piece/blocks'.get_children():
				c.find_node('animation').play('fade-out')
			detach_blocks()
			return


func enemy_move(delta):
	if destination == null: # may happen in network mode when clients are waiting for the destination given by the server
		return
	
	# When position is reached, stop there and (maybe) become a friend
	if lobby.i_am_the_game() and position.distance_to(destination) < speed * delta:
		position = destination
		if can_switch_status('FRIEND'):
			rpc("switch_status",'FRIEND',global_position,rotation)
			switch_status('FRIEND')
		return
	
	var direction = (destination-position).normalized()
	position += direction * speed * delta
	
	# Fire an enemy bullet?
	if lobby.i_am_the_game():
		time_since_last_bullet += delta
		if time_since_last_bullet >= bullet_interval:
			fire_enemy_bullets()
			time_since_last_bullet = 0


func fire_enemy_bullets():
	var type = 'regular' if randf() <= 0.9 else 'bad'
	var dir = $'/root/world/ship'.global_position - global_position
	rpc("sync_fire_enemy_bullet",global_position,global.enemy_bullet_i,type,dir)
	sync_fire_enemy_bullet(global_position,global.enemy_bullet_i,type,dir)
	global.enemy_bullet_i += 1


puppet func sync_fire_enemy_bullet(pos,i,type,dir):
	var bullet = (BULLET if type == 'regular' else BULLET_BAD).instance()
	bullet.global_position = pos
	bullet.name = 'enemy-bullet-' + type + '-' + str(i)
	bullet.direction = dir
	$'/root/world/bullets'.add_child(bullet)


func friend_move(delta):
	if not lobby.i_am_pacman():
		return
	
	# player(s) can force friendly tetris shapes to go down fast
	# any_mode if pacman is playing on keyboard or solo, otherwise 2p_mode (controller-only)
	var mode = 'any_mode_' if global.PLAYERS.mode_1p or global.PLAYERS.pacman == null else '2p_mode_'
	force_down = Input.is_action_just_pressed(mode+"pacman_drop") or force_down and Input.is_action_pressed(mode+"pacman_drop")
	
	# move down one square
	time_since_last_friend_move += delta
	if not force_down and time_since_last_friend_move < conf.current.TRIS_SHAPE_DOWN_INTERVAL:
		return
	
	time_since_last_friend_move = 0
	friend_move_dir(Vector2(0,1))


func get_enemy_bullets():
	var bullets = []
	for block in $'piece/blocks'.get_children():
		var bullet = block.find_node('*enemy-bullet*',false,false)
		if bullet != null:
			bullets.append(bullet)
	return bullets


puppet func absorb_bullet():
	# find an empty block to stick on
	var empty_block = null
	for block in $'piece/blocks'.get_children():
		var bullet = block.find_node('*enemy-bullet*',false,false)
		if bullet == null:
			empty_block = block
			break
	
	var bullets = get_enemy_bullets()
	
	if empty_block == null:
		global.play_sound('tris_shape_break',false)
		
		# fire bad bullets in a circle
		if lobby.i_am_the_game():
			for i in range(bullets.size()+1):
				var angle = 0 + deg2rad(180) * i / bullets.size()
				var dir = Vector2.RIGHT.rotated(angle)
				rpc("sync_fire_enemy_bullet",global_position,global.enemy_bullet_i,'bad',dir)
				sync_fire_enemy_bullet(global_position,global.enemy_bullet_i,'bad',dir)
				global.enemy_bullet_i += 1
			
			rpc("switch_status",'DESTROYED',global_position,rotation)
			switch_status('DESTROYED')
		
		return
	
	# stick to the tetris shape
	var bullet_sprite = BULLET_SPRITE.instance()
	empty_block.add_child(bullet_sprite)
	
	# turn slowly to red as the number of bullets increases
	colorise()


func friend_move_dir(dir):
	if not lobby.i_am_pacman():
		return
	
	# I've been pushed (or went down), don't move down before some time
	time_since_last_friend_move = 0
	
	var c = move_and_collide(dir * global.GRID_SIZE)
	global_position = global.attach_pos_to_grid(global_position)
	var moving_again = false
	if c:
		if c.collider.is_in_group('ghosts'):
			c.collider.rpc("die",'crushed_by_tetris_piece')
			c.collider.die('crushed_by_tetris_piece')
			friend_move_dir(c.remainder/global.GRID_SIZE)
			moving_again = true
		
		if status == 'FRIEND' and (
			c.collider.is_in_group('wall-bottom') or
			c.collider.is_in_group('tris-block-box')):
			
			# check that this is a collision after moving or being pushed down (not left or right, as this results in tetris shapes wrongly "attaching" to other ground shapes)
			if dir.x == 0 and dir.y > 0:  # moving down
				rpc("switch_status",'FLOOR',global_position,rotation)
				switch_status('FLOOR')
				force_down = false
				return
	
	if not moving_again:
		rpc("set_pos",position)


func friend_move_rotate(angle = PI/2):
	var rotated = friend_move_rotate_try(angle)
	if rotated:
		rpc("set_rot",rotation,position)
		if angle != 0:
			global.play_sound('tris_shape_hit')
	return rotated

func friend_move_rotate_try(angle):
	if angle != 0 and MAX_ROTATIONS == 0:
		return false
	
	var rotations = round((rotation+angle) / deg2rad(90))
	if rotations >= MAX_ROTATIONS:
		angle = -rotation  # don't rotate another 90°, rotate "back" to 0°
	
	rotate(angle)
	
	if status == 'FROZEN' and angle != 0:  # frozen pieces can rotate freely
		return true
	
	global_position = global.attach_pos_to_grid(global_position)
	var orig_pos = global_position
	
	var step = 1
	var chosen_dir = null
	var colliding = test_collisions('BLOCK_ROTATION')
	var colliders = []
	while colliding.size() > 0:
		if step == 1:
			colliders = colliding
		if step > 2:
			# two many escape moves, rotate back
			rotate(-angle)
			global_position = orig_pos
			refused(colliders)
			return false
		step += 1
		
		# can move left or right to "slide" against a wall, tetris blocks, or pacman
		var blocker = null
		for c in colliding:
			blocker = c
			if c.is_in_group('wall-bottom'):
				# unauthorised rotation, rotate back
				rotate(-angle)
				global_position = orig_pos
				refused([blocker])
				return false
			
			if not c.is_in_group('walls'):
				# 2 steps only allowed to escape when moving away from a wall (left or right), not pacman or a floor block
				step += 1
		
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
			
			if chosen_dir == 0:
				chosen_dir = 1 if randf() < 0.5 else -1
		
		var move = Vector2(global.GRID_SIZE * chosen_dir, 0)
		global_position += move
		colliding = test_collisions('BLOCK_ROTATION')
	
	# don't move down for a while after I've rotated
	time_since_last_friend_move = 0
	
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
			anim.rpc("play_me")
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
			rotation,
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


func detach_blocks():
	for block in $'piece/blocks'.get_children():
		# become collisionable floor blocks
		block.get_node('box').set_collision_layer_bit(global.LAYER_TETRIS_BLOCKS,1)
		
		# append to general parent container 'tetris-handler'
		global.reparent(block,$'/root/world/tetris-handler')
	
	global.remove_from_game(self)
