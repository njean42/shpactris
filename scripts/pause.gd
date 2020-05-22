extends Node2D


var waiting_for_players = false
var game_is_over = false


func _input(event):
	if name == 'game-over-menu':
		return
	
	if game_is_over:
		return
	
	if Input.is_action_just_pressed('ui_pause'):
		pause_all()


func pause_all():
	if waiting_for_players:
		return
	
	rpc("pause")
	pause()


func wait_for_players():
	find_node('error-msg').text = 'Waiting for players'
	pause()
	waiting_for_players = true


remote func players_ready():
	waiting_for_players = false
	find_node('error-msg').text = ''
	pause()


remote func pause(game_over=false):
	if waiting_for_players:
		return
	if game_is_over:
		return
	
	var go_to_pause = game_over or not get_tree().is_paused()
	visible = go_to_pause and not game_over
	
	if visible:
		$'timer'.start()  # will focus on a button after a few seconds
	
	game_is_over = game_over
	
	get_tree().set_pause(go_to_pause)


func _on_btcontinue_pressed():
	pause_all()


func _on_timer_timeout():
	for b in ['bt-continue','bt-back-to-menu']:
		var bt = find_node(b)
		if bt.visible:
			bt.grab_focus()
			break
	$'timer'.stop()


func _on_btbacktomenu_pressed():
	get_tree().set_pause(false)
	get_tree().change_scene("res://scenes/menus/main-menu.tscn")
