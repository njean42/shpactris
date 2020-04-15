extends 'ship-pacman.gd'

var direction = false
var prev_dir = 'right'
var speed = false
var time_since_last_shadow = 0
var is_shadow = false

var SHADOW = null
var MAX_ENEMY_BULLETS = 10


func _ready():
	position = global.attach_pos_to_grid(position)


func _physics_process(delta):
	if not is_shadow:
		player_move(delta)
	move(delta)


func move(delta):
	var velocity = Vector2()
	match direction:
		'right':
			velocity.x = 1
			find_node('sprite').rotation_degrees = 0
		'left':
			velocity.x = -1
			find_node('sprite').rotation_degrees = 180
		'down':
			velocity.y = 1
			find_node('sprite').rotation_degrees = 90
		'up':
			velocity.y = -1
			find_node('sprite').rotation_degrees = -90
	
	if direction:
		var c = move_and_collide(velocity * speed * delta)
		collide(c)
	
	# remove if off screen (only shadows should go off screen)
	if position.y > global.SCREEN_SIZE.y or position.y < 0 or position.x > global.SCREEN_SIZE.x or position.x < 0:
		queue_free()


func player_move(delta):
	direction = false
	speed = conf.current.PACMAN_SPEED  # may have been updated (level up)
	if Input.is_action_pressed("any_mode_pacman_right"):
		direction = 'right'
	elif Input.is_action_pressed("any_mode_pacman_left"):
		direction = 'left'
	elif Input.is_action_pressed("any_mode_pacman_down"):
		direction = 'down'
	elif Input.is_action_pressed("any_mode_pacman_up"):
		direction = 'up'
	
	if direction and prev_dir and direction != prev_dir:
		position = global.attach_pos_to_grid(position)
	
	if direction:
		prev_dir = direction
	
	if time_since_last_shadow < conf.current.PACMAN_SHADOW_INTERVAL:
		time_since_last_shadow += delta
		return
	
	var mode = 'any_mode_' if global.PLAYERS.mode_1p else '2p_mode_'
	if Input.is_action_pressed(mode+'pacman_fire_shadow'):
		time_since_last_shadow = 0
		fire_shadow()


func collide(c):
	if not c:
		return
	
	for g in ['enemy-bullets','ghosts','tris-shape']:
		if not c.collider.is_in_group(g):
			continue
		match g:
			# eat enemy bullets
			'enemy-bullets':
				absorb(c.collider)
				
			# get hurt by ghosts
			'ghosts':
				get_hurt()
				c.collider.queue_free()
			
			# push friendly tetris shapes
			'tris-shape':
				# try to push shape
				global.play_sound('tris_shape_pushed')
				c.collider.friend_move_dir(-c.get_normal())
				# stick to grid and stop
				position = global.attach_pos_to_grid(position)
				position = position + c.get_normal().normalized() * global.GRID_SIZE/4
				direction = false
			
			# collide against walls => clamp to grid
			'pacman-walls':
				position = global.attach_pos_to_grid(position)
				direction = false

# absorb enemy bullet (gather around pacman)
func absorb(bullet):
	if bullet.is_in_group('enemy-bullets-bad'):
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
	
	# random power-up when pacman gathers 10 bullets
	if nb_bullets >= MAX_ENEMY_BULLETS:
		for b in bullets_list.get_children():
			b.queue_free()
		bullet.queue_free()
		
		var item = [
			global.HEART,
			global.BUBBLE,
			global.SLOW_MO
		][floor(rand_range(0,3))]
		
		$'/root/world/items'.add_child(item.instance())

func fire_shadow():
	if SHADOW == null:
		SHADOW = load('res://scenes/pacman-shadow.tscn')
	
	var shadow = SHADOW.instance()
	$'/root/world'.add_child(shadow)
	shadow.global_position = global_position
	shadow.is_shadow = true
	shadow.direction = direction if direction else prev_dir
	shadow.speed = conf.current.PACMAN_SPEED * 2  # shadows travel twice as fast as pacman

