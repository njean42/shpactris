extends 'enemy-bullet.gd'

var accel = 1.1

func _init():
	collisions = {
		'layer': [global.LAYER_TETRIS_BULLET_BAD],
		'mask': [global.LAYER_SHIP, global.LAYER_PACMAN_KILL]
	}


func update_speed():
	speed = conf.current.TRIS_SHAPE_BULLET_SPEED * accel # will be affected by slow-mo
