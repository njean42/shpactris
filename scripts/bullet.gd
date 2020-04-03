extends KinematicBody2D

var speed = conf.current.SHIP_BULLET_SPEED


func _physics_process(delta):
	var c = move_and_collide(Vector2(0,-1)*speed*delta)
	if c:
		# kill ghosts
		if c.collider.is_in_group('ghosts'):
			c.collider.find_node('anim').play('shake-and-die')
			global.enemy_hit(self)
			global.remove_from_game(self)
		
		# rotate tetris shapes
		if c.collider.is_in_group('tris-shape'):
			global.play_sound('tris_shape_hit')
			global.remove_from_game(self)
			c.collider.friend_move_rotate(PI/2,false)
		
		return
	
	if position.y < 0:
		global.remove_from_game(self)