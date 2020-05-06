extends 'tris-shape.gd'


var ttl = 10  # times to bounce before turning into a friend


func _ready():
	# shoot quicker
	bullet_interval = conf.current.TRIS_SHAPE_BULLET_INTERVAL / 2


func is_friendable():
	# die slower
	if ttl > 0:
		ttl -= 1
		return false
	
	return .is_friendable()


# TODO
#func fire_enemy_bullet():
#	var nb_bullets = 8
#	for i in range(nb_bullets):
#		var bullet = (BULLET_BAD if randf()>0.2 else BULLET).instance()
#		bullet.global_position = global_position
#		bullet.set_direction(Vector2(0,1).rotated(2*PI/nb_bullets*i))
#		$'/root/world/bullets'.add_child(bullet)

