extends 'ship-pacman.gd'

const BULLET = preload('res://scenes/bullet.tscn')
const FROST_BEAM = preload('res://scenes/frost-beam.tscn')

var time_moved = 0  # number of seconds that the ship has kept moving
var time_since_last_bullet = 0
var time_since_last_frost_beam = 0
var shape_frozen = null


func _ready():
	for i in range(0,5):
		get_beam()


func _physics_process(delta):
	
	var moves = {
		'ship_right': {'axis': 'x', 'dir':  1},
		'ship_left':  {'axis': 'x', 'dir': -1},
		'ship_up':    {'axis': 'y', 'dir': -1},
		'ship_down':  {'axis': 'y', 'dir':  1},
	}
	
	var mode = 'any_mode_' if global.PLAYERS.mode_1p else '2p_mode_'
	
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
			fire_bullet()
	
	# frost beam
	time_since_last_frost_beam += delta
	if Input.is_action_pressed(mode+"ship_frost_beam"):
		if time_since_last_frost_beam >= conf.current.SHIP_FROST_BEAM_RATE:
			if frost_beam():
				time_since_last_frost_beam = 0


func fire_bullet():
	var bullet = BULLET.instance()
	bullet.global_position = global_position
	$'/root/world/bullets'.add_child(bullet)


func get_beam():
	var nb_beams = $'beams'.get_children().size()
	if nb_beams >= 10:
		return
	
	var x = nb_beams * 4
	
	var beam = Line2D.new()
	beam.default_color = Color(102.0/255, 128.0/255, 1)
	beam.width = 2
	beam.points = [
		Vector2(x,0),
		Vector2(x,10)
	]
	$'beams'.add_child(beam)


func frost_beam():
	if not is_physics_processing():  # has to be, otherwise ray casting may not work
		prints('[BUG] not physics processing... (ship.frost_beam())')
		return false
	
	if shape_frozen != null:
		var can_land = shape_frozen.switch_status('FRIEND',true)
		if not can_land:
			return false
		
		# undraw frost beam
		var beams = get_tree().get_nodes_in_group('frost-beam')
		for b in beams:
			b.queue_free()
		
		# shape becomes a friend again
		global.reparent(shape_frozen,$'/root/world/tris-shapes')
		shape_frozen = null
		return true
	
	# fire frost beam (not releasing an already frozen piece)
	if $'beams'.get_children().size() == 0:
		return
	$'beams'.get_children()[-1].queue_free()
	
	global.play_sound('frost_beam');
	
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(
		global_position,
		Vector2(global_position.x, 0),
		[self],
		pow(2,global.LAYER_TETRIS_SHAPE_FRIENDS)
	)
	
	# draw beam
	var beam_stops_at = Vector2(0, -global_position.y)
	if result:
		var bta = beam_stops_at
		beam_stops_at = Vector2(0, result.collider.global_position.y - global_position.y)
	
	var beam = FROST_BEAM.instance()
	beam.points = [
		Vector2(0,0),
		beam_stops_at
	]
	add_child(beam)
	
	if not result:
		return true
	
	# only free the frost beam when shape is released (otherwise frees itself)
	beam.set_process(false)
	
	# attach tetris shape, it will move with the ship until released
	shape_frozen = result.collider
	shape_frozen.switch_status('FROZEN')
	global.reparent(shape_frozen,self)
	
	return true
	
