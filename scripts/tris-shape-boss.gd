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


func fire_enemy_bullets():
	var nb_bullets = 8
	for i in range(nb_bullets):
		var type = 'bad' if randf() <= 0.9 else 'regular'
		var dir = Vector2(0,1).rotated(2*PI/nb_bullets*i)
		rpc("sync_fire_enemy_bullet",global_position,global.enemy_bullet_i,type,dir)
		sync_fire_enemy_bullet(global_position,global.enemy_bullet_i,type,dir)
		global.enemy_bullet_i += 1

