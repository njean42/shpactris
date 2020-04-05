extends KinematicBody2D

var speed = conf.current.TRIS_SHAPE_BULLET_SPEED
var follow = conf.current.TRIS_SHAPE_BULLET_FOLLOW
var direction = Vector2(0,1)
var orig_angle

var collisions = {
	'layer': [global.LAYER_TETRIS_BULLET],
	'mask': [global.LAYER_SHIP, global.LAYER_TETRIS_SHAPE_FRIENDS]
}


func set_direction(dir):
	direction = dir
	orig_angle = direction.angle()

func _physics_process(delta):
	
	# tweak direction to head towards the ship
	var angle2ship = direction.angle_to($'/root/world/ship'.position - position)
	direction = direction.rotated(sign(angle2ship) * deg2rad(follow) * delta)
	
	# restrict direction to deviate (from original dir) by at most max_dev
	var angle = direction.angle()
	var max_dev = deg2rad(45)
	if angle < orig_angle - max_dev:
		direction = direction.rotated(orig_angle - max_dev - angle)
	if angle > orig_angle + max_dev:
		direction = direction.rotated(orig_angle + max_dev - angle)
	
	var c = move_and_collide(direction.normalized()*speed*delta)
	if c:
		collide(c.collider)
	
	if position.y > global.SCREEN_SIZE.y or position.y < 0 or position.x > global.SCREEN_SIZE.x or position.x < 0:
		queue_free()

func collide(collider):
	if collider.is_in_group('ship'):
		collider.get_hurt()
		global.remove_from_game(self)
	if collider.is_in_group('pacman'):
		global.enemy_hit(self)
		global.remove_from_game(self)
	
	if collider.is_in_group('tris-shape'):
		collider.absorb(self)