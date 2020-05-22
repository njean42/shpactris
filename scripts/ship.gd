extends 'ship-pacman.gd'

const BULLET = preload('res://scenes/bullet.tscn')
const FROST_BEAM = preload('res://scenes/frost-beam.tscn')

var time_moved = 0  # number of seconds that the ship has kept moving
onready var prev_pos = get_position()
var time_since_last_bullet = 0
var time_since_last_frost_beam = 0
var shape_frozen = null


var bullet_i = 0
var time_since_last_rpc = 0
var last_reliable_rpc_pos = null
func _physics_process(delta):
	
	var cheat = lobby.i_am_pacman() and OS.get_environment('TESTING') == 'true'
	if not lobby.i_am_the_ship() and not cheat:
		set_physics_process(false)
		return
	
	var moves = {
		'ship_right': {'axis': 'x', 'dir':  1},
		'ship_left':  {'axis': 'x', 'dir': -1},
		'ship_up':    {'axis': 'y', 'dir': -1},
		'ship_down':  {'axis': 'y', 'dir':  1},
	}
	
	# any_mode if the ship is playing on keyboard or solo, otherwise 2p_mode (controller-only)
	var mode = 'any_mode_' if global.PLAYERS.mode_1p or global.PLAYERS.ship == null else '2p_mode_'
	
	var velocity = Vector2()
	for m in moves:
		var move = Input.get_action_strength(mode+m)
		if abs(move) >= 0.2:
			var a = moves[m].axis
			var d = moves[m].dir
			velocity[a] += move*d
	
	if velocity.length() == 0:
		time_moved = 0
	else:
		time_moved += delta
		var speed = conf.current.SHIP_SPEED if time_moved > conf.current.SHIP_MAX_SPEED_AFTER else conf.current.SHIP_SPEED/2
		
		var c = move_and_collide(velocity * speed * delta)
		if c and c.collider.is_in_group('enemy-bullets'):
			c.collider.collide(self)
		position.x = clamp(position.x, global.GRID_SIZE/2, global.SCREEN_SIZE.x - global.GRID_SIZE/2)
		position.y = clamp(position.y, global.GRID_SIZE/2, global.SCREEN_SIZE.y - global.GRID_SIZE / 2)
	
	# shoot
	time_since_last_bullet += delta
	if Input.is_action_pressed(mode+"ship_shoot"):
		if time_since_last_bullet >= conf.current.SHIP_BULLET_RATE:
			time_since_last_bullet = 0
			var bullet_name = 'bullet-'+str(bullet_i)
			bullet_i += 1
			rpc("fire_bullet",global_position,bullet_name)
			fire_bullet(global_position,bullet_name)
	
	# frost beam
	time_since_last_frost_beam += delta
	if Input.is_action_just_pressed(mode+"ship_frost_beam"):
		if time_since_last_frost_beam >= conf.current.SHIP_FROST_BEAM_RATE:
			if frost_beam():
				time_since_last_frost_beam = 0
	
	 # sync position, at most X times per second
	time_since_last_rpc += delta
	if time_since_last_rpc >= 1.0/25:
		if prev_pos != position and velocity.length() != 0:
			time_since_last_rpc = 0
			prev_pos = position
			rpc_unreliable("set_pos",position)
		
		# if the ship isn't moving, reliably send position once
		elif velocity.length() == 0 and position != last_reliable_rpc_pos and position != prev_pos:
			last_reliable_rpc_pos = position
			rpc("set_pos",position,true)


remote func set_pos(pos,reliable=false):
	position = pos
	prev_pos = position
	if reliable:
		last_reliable_rpc_pos = pos


remote func fire_bullet(pos,bullet_name):
	var bullet = BULLET.instance()
	bullet.global_position = pos
	bullet.name = bullet_name
	$'/root/world/bullets'.add_child(bullet)


func get_beam():
	if not lobby.i_am_the_game():
		return
	
	var nb_beams = $'beams'.get_children().size()
	if nb_beams >= 10:
		return
	
	rpc("sync_get_beam",nb_beams)
	sync_get_beam(nb_beams)


remote func sync_get_beam(nb_beams):
	var x = nb_beams * 4
	var beam = Line2D.new()
	beam.default_color = Color(102.0/255, 128.0/255, 1)
	beam.width = 2
	beam.points = [
		Vector2(x,0),
		Vector2(x,10)
	]
	$'beams'.add_child(beam)


remote func lose_beam():
	$'beams'.get_children()[-1].queue_free()


func frost_beam():
	if not is_physics_processing():  # has to be, otherwise ray casting may not work
		prints('[BUG] not physics processing... (ship.frost_beam())')
		return false
	
	if shape_frozen != null:
		if not shape_frozen.can_switch_status('FRIEND'):
			return false
		
		# undraw frost beam
		rpc("undraw_beam")
		undraw_beam()
		
		# shape becomes a friend again
		shape_frozen.global_position = global.attach_pos_to_grid(shape_frozen.global_position)
		shape_frozen.rpc("switch_status",'FRIEND',shape_frozen.global_position,shape_frozen.rotation)
		shape_frozen.switch_status('FRIEND')
		shape_frozen = null
		return true
	
	# fire frost beam (not releasing an already frozen piece)
	if $'beams'.get_children().size() == 0:
		return
	
	rpc("lose_beam")
	lose_beam()
	
	global.play_sound('frost_beam')
	
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(
		global_position,
		Vector2(global_position.x, 0),
		[self],
		pow(2,global.LAYER_TETRIS_SHAPE_FRIENDS)
	)
	
	var successful = true if result else false
	
	# draw beam
	var beam_stops_at = Vector2(0, -global_position.y)
	if successful:
		beam_stops_at = Vector2(0, result.collider.global_position.y - global_position.y)
	
	rpc('draw_beam',beam_stops_at,successful)
	draw_beam(beam_stops_at,successful)
	
	if successful:
		# attach tetris shape, it will move with the ship until released
		shape_frozen = result.collider
		shape_frozen.rpc("switch_status",'FROZEN',shape_frozen.global_position,shape_frozen.rotation)
		shape_frozen.switch_status('FROZEN')
	
	return true


remote func draw_beam(beam_stops_at,successful):
	var beam = FROST_BEAM.instance()
	beam.points = [
		Vector2(0,0),
		beam_stops_at
	]
	add_child(beam)
	
	if successful:
		# only free the frost beam when shape is released (otherwise frees itself)
		beam.set_process(false)

remote func undraw_beam():
	for b in get_tree().get_nodes_in_group('frost-beam'):
		b.queue_free()
