extends KinematicBody2D


var invincible = false
var time_invincible = 0
var time_invicible_max = 3

func _process(delta):
	if invincible:
		time_invincible += delta
		
		if time_invincible >= time_invicible_max:
			invincible = false
			time_invincible = 0
			find_node('anim').stop()
			find_node('anim').seek(0,true)


func get_hurt():
	if invincible:
		return
	
	# lose life and become invincible
	$'/root/world'.lose_life(self)
	time_invincible = 0
	invincible = true
	find_node('anim').play('invincibility')
