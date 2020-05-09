extends KinematicBody2D

var speed = conf.current.TRIS_SHAPE_BULLET_SPEED
var follow_characters = ['ship']
var direction = null

var collisions = {
	'layer': [global.LAYER_TETRIS_BULLET],
	'mask': [global.LAYER_PACMAN, global.LAYER_SHIP, global.LAYER_TETRIS_SHAPE_FRIENDS]
}


func _ready():
	global.enable_collision(self)
	
	# only the server computes bullet collisions
	if not lobby.i_am_the_game():
		$'collision-shape'.disabled = true


func _process(delta):
	if position.y > global.SCREEN_SIZE.y or position.y < 0 or position.x > global.SCREEN_SIZE.x or position.x < 0:
		queue_free()
	# TODO: sync pos every second?


func _physics_process(delta):
	update_speed()
	
	if direction == null:  # may happen while the clients wait for the bullet direction
		return
	
	var c = move_and_collide(direction.normalized()*speed*delta)
	if c:
		collide(c.collider)


func get_closest_char():
	var min_dist2char = INF
	var closest = null
	for c in follow_characters:
		c = $'/root/world'.get_node(c)
		var dist = (c.position - position).length()
		if dist < min_dist2char:
			min_dist2char = dist
			closest = c
	return closest


func update_speed():
	speed = conf.current.TRIS_SHAPE_BULLET_SPEED  # will be affected by slow-mo


func collide(collider):
	if collider.is_in_group('ship'):
		rpc("be_gone",'hit_ship')
		be_gone('hit_ship')
	
	if collider.name == 'hitbox':
		rpc("be_absorbed",collider.get_parent().name)
		be_absorbed(collider.get_parent().name)
	
	elif collider.is_in_group('pacman') or collider.is_in_group('tris-shape'):
		rpc("be_absorbed",collider.name)
		be_absorbed(collider.name)


puppet func be_gone(why):
	match why:
		'hit_ship':
			$'/root/world/ship'.get_hurt()
	
	global.remove_from_game(self)


remote func be_absorbed(collider_name):
	var collider = null
	if collider_name.begins_with('pacman'):
		collider = $'/root/world'.get_node(collider_name)
	else:
		collider = $'/root/world/tris-shapes'.get_node(collider_name)
	collider.absorb(self)
