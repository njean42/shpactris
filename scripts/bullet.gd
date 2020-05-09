extends KinematicBody2D

var speed = conf.current.SHIP_BULLET_SPEED


func _ready():
	# only the server computes bullet collisions
	if not lobby.i_am_the_game():
		$'collision-shape'.disabled = true


func _physics_process(delta):
	var c = move_and_collide(Vector2(0,-1)*speed*delta)
	if c:
		# kill ghosts
		if c.collider.is_in_group('ghosts'):
			c.collider.rpc("die",'hit_by_bullet')
			c.collider.die('hit_by_bullet')
			rpc("be_gone",'enemy_hit')
			be_gone('enemy_hit')
		
		# rotate tetris shapes
		if c.collider.is_in_group('tris-shape'):
			c.collider.friend_move_rotate(PI/2)
			rpc("be_gone",'tris_shape_hit')
			be_gone('tris_shape_hit')
		
		return
	
	if lobby.i_am_the_game() and position.y < 0:
		rpc("be_gone",'off_screen')
		be_gone('off_screen')


puppet func be_gone(why):
	if why == 'enemy_hit':
		global.enemy_hit(self)
	global.remove_from_game(self)
