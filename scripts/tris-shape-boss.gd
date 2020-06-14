extends 'tris-shape.gd'


var ttl = 10  # times to bounce before turning into a friend
var nb_bullets = conf.current.BOSS_ZONE_NB_BULLETS


func _ready():
	# shoot quicker
	bullet_interval = conf.current.TRIS_SHAPE_BULLET_INTERVAL / 2
	
	# TODO online: only the server should handle the damage zone
	var timer = Timer.new()
	timer.name = 'damage_zone_timer'
	timer.connect("timeout",self,"fire_enemy_damage_zone")
	timer.set_wait_time(max(2,conf.current.BOSS_ZONE_INTERVAL))
	timer.set_one_shot(true)
	add_child(timer)
	timer.start()


func is_friendable():
	# die slower
	if ttl > 0:
		ttl -= 1
		return false
	
	return .is_friendable()


func fire_enemy_bullets():
	for i in range(nb_bullets):
		var type = 'bad' if randf() <= 0.9 else 'regular'
		var dir = Vector2(0,1).rotated(2*PI/nb_bullets*i)
		rpc("sync_fire_enemy_bullet",global_position,global.enemy_bullet_i,type,dir)
		sync_fire_enemy_bullet(global_position,global.enemy_bullet_i,type,dir)
		global.enemy_bullet_i += 1


func fire_enemy_damage_zone():
	if status != "ENEMY":
		return
	
	var timer = Timer.new()
	timer.connect("timeout", self, "damage_player_with_rectangle")
	timer.set_wait_time(max(2,conf.current.BOSS_ZONE_DURATION))
	timer.set_one_shot(true)
	add_child(timer)
	timer.start()
	
	var polygon = [
		# 4 values: xmin, ymin, xmax, ymax
		[0, 0, global.SCREEN_SIZE.x, global.SCREEN_SIZE.y / 2],  # up
		[0, global.SCREEN_SIZE.y / 2, global.SCREEN_SIZE.x, global.SCREEN_SIZE.y],  # down
		[0, 0, global.SCREEN_SIZE.x / 2, global.SCREEN_SIZE.y],  # left
		[global.SCREEN_SIZE.x / 2, 0, global.SCREEN_SIZE.x, global.SCREEN_SIZE.y],  # right
	][randi() % 4]
	
	polygon = PoolVector2Array([
		Vector2(polygon[0], polygon[1]),  # top-left
		Vector2(polygon[2], polygon[1]),  # top-right
		Vector2(polygon[2], polygon[3]),  # bottom-right
		Vector2(polygon[0], polygon[3]),  # bottom-left
	])
	
	$'/root/world/damage-zone/damage-rectangle'.polygon = polygon
	$'/root/world/damage-zone'.visible = true


func damage_player_with_rectangle():
	var p = $'/root/world/damage-zone/damage-rectangle'.polygon
	var rect = Rect2(p[0].x, p[0].y, p[2].x - p[0].x, p[2].y - p[0].y)
	
	for c in ['ship','pacman']:
		var character = $'/root/world'.get_node(c)
		var coords = character.position
		if c == 'pacman':  # pacman coordinates are those of its top-left corner
			coords += Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2)
		
		if rect.has_point(coords):
			character.get_hurt() # TODO: sync online!
	
	# hide damage zone and start timer for the next one
	$'/root/world/damage-zone'.visible = false
	$damage_zone_timer.start()
