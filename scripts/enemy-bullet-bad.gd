extends 'enemy-bullet.gd'

var accel = 1.1

func _init():
	follow_characters = ['ship','pacman']
	follow *= accel
	
	collisions = {
		'layer': [global.LAYER_TETRIS_BULLET],
		'mask': [global.LAYER_SHIP, global.LAYER_PACMAN]
	}


func update_speed():
	speed = conf.current.TRIS_SHAPE_BULLET_SPEED * accel # will be affected by slow-mo
