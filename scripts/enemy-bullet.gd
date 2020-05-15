extends Area2D

var speed = conf.current.TRIS_SHAPE_BULLET_SPEED
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


func _physics_process(delta):
	update_speed()
	
	if direction == null:  # may happen while the clients wait for the bullet direction
		return
	
	position += direction.normalized()*speed*delta


func update_speed():
	speed = conf.current.TRIS_SHAPE_BULLET_SPEED  # will be affected by slow-mo


func _on_enemybullet_body_entered(collider):
	var be_gone_because = false
	
	if collider.is_in_group('ship'):
		be_gone_because = 'hit_ship'
	
	# hit pacman's (or shadow's) hurtbox (enemy-bullet-bad only)
	elif collider.name == 'hitbox':
		collider = collider.get_parent()
		
		if collider.is_shadow:
			$'/root/world/pacman'.rpc("pacman_free_shadow", collider.name)  # called on pacman, not its shadow
			$'/root/world/pacman'.pacman_free_shadow(collider.name)
		else:
			be_gone_because = 'hit_pacman_bad'
	
	# hit pacman (or shadow)
	elif collider.is_in_group('pacman'):
		$'/root/world/pacman'.rpc('absorb_bullet')
		$'/root/world/pacman'.absorb_bullet()
		be_gone_because = 'absorbed'
	
	# hit a tetris shape
	elif collider.is_in_group('tris-shape'):
		collider.rpc('absorb_bullet')
		collider.absorb_bullet()
		be_gone_because = 'hit_tris_shape'
	
	if be_gone_because:
		rpc("be_gone",be_gone_because)
		be_gone(be_gone_because)


puppet func be_gone(why):
	match why:
		'hit_ship':
			$'/root/world/ship'.get_hurt()
		'hit_pacman_bad':
			$'/root/world/pacman'.get_hurt()
	
	global.remove_from_game(self)

