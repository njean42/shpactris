extends KinematicBody2D

const INVINCIBILITY_TIME = 3
const BUBBLE_TIME = 20

var invincible = false
var bubbled = false
var time_invincible = 0
var time_bubble = 0


func _process(delta):
	# Invincibility
	if invincible:
		time_invincible += delta
		
		if time_invincible >= INVINCIBILITY_TIME:
			invincible = false
			time_invincible = 0
			find_node('anim').stop()
			find_node('anim').seek(0,true)
	
	# Bubble
	time_bubble += delta
	
	if bubbled:
		var ratio = time_bubble / BUBBLE_TIME
		$'bubble'.modulate.a = 1-ratio
		
		if lobby.i_am_the_game() and time_bubble >= BUBBLE_TIME:
			rpc("lose_bubble")
			lose_bubble()


func get_hurt():
	if not lobby.i_am_the_game():
		return
	
	if invincible:
		return
	
	if bubbled:
		rpc("lose_bubble")
		lose_bubble()
		return
	
	rpc("sync_get_hurt")
	sync_get_hurt()

remote func sync_get_hurt():
	# lose life and become invincible
	$'/root/world'.lose_life(self)
	time_invincible = 0
	invincible = true
	find_node('anim').play('invincibility')


remote func activate_bubble():
	time_bubble = 0
	bubbled = true
	$'bubble'.modulate.a = 1


remote func lose_bubble():
	bubbled = false
	$'bubble'.modulate.a = 0
