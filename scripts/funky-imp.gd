extends Node2D

"""
The Funky Imp is a malicious creature that fools around with our game:
- move a random wall in the maze, periodically
- ..?
"""

var time_since_last_wall_move = 0


func _ready():
	if not(get_tree().get_network_unique_id() in [0,1]):
		set_physics_process(false)


func _physics_process(delta):
	# move walls
	time_since_last_wall_move += delta
	if time_since_last_wall_move >= conf.current.PACMAN_WALLS_MOVE_INTERVAL:
		time_since_last_wall_move = 0
		walls.wall_move()
