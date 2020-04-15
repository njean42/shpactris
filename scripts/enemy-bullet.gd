extends KinematicBody2D

var speed = conf.current.TRIS_SHAPE_BULLET_SPEED
var follow = conf.current.TRIS_SHAPE_BULLET_FOLLOW
var follow_characters = ['ship']
var direction = Vector2(0,1)

var collisions = {
	'layer': [global.LAYER_TETRIS_BULLET],
	'mask': [global.LAYER_SHIP, global.LAYER_TETRIS_SHAPE_FRIENDS]
}


func set_direction(dir):
	direction = dir


func _process(delta):
	if position.y > global.SCREEN_SIZE.y or position.y < 0 or position.x > global.SCREEN_SIZE.x or position.x < 0:
		queue_free()


func _physics_process(delta):
	update_speed()
	update_direction(delta)
	
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

func update_direction(delta):
	# tweak direction to head towards the character·s, whichever is closest
	var angle = direction.angle_to(get_closest_char().position - position)
	direction = direction.rotated(sign(angle) * deg2rad(follow) * delta)


func collide(collider):
	if collider.is_in_group('ship'):
		collider.get_hurt()
		global.remove_from_game(self)
	if collider.is_in_group('pacman'):
		collider.absorb(self)
	
	if collider.is_in_group('tris-shape'):
		collider.absorb(self)
