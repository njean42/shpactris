extends Node2D


var show = true
var min_time_between_hints = 10
var time_since_last_hint = min_time_between_hints

var hints = {
	# game start
	'move_ship_and_pacman': 'move #pacman and #theship around',
	
	# ghosts
	'ghost_spawned': "#ghosts chase #pacman, run away!\n#theship can shoot them",
	
	# enemy bullets
	'tris_shape_shoot_ship': "#redtris shoot at #theship (#yb#rb)\n#pacman can eat #yb",
	'tris_shape_shoot_ship_shadow': "#pacman can throw its own shadow (eats #yb too)",
	'tris_shape_shoot_ship_teleport': "#pacman can teleport: hold & release shadow key",
	'pacman_collect_bullets': "collect 8#yb with #pacman to earn an item",
	
	# tetris pieces & lines
	'tris_shape_friended': "#redtris regularly turn into #greentris\npush them around with #pacman",
	'tris_shape_friended2': "shoot #greentris with #theship to rotate them",
	'tris_shape_ship_freeze': "#theship can also beam-freeze #greentris and move them freely (limited)",
	'tris_shape_down': "#pacman can rush #greentris down",
	'tris_lines_frost_beam': "building tetris lines gives you #frostbeams back",
}
var nb_hints = hints.keys().size()

var hashtags = {
	'#pacman': '[color=#f1c40f]pacman[/color]',
	'#theship': '[color=#3498db]the ship[/color]',
	'#ghosts': '[color=#bdc3c7]ghosts[/color]',
	'#redtris': '[color=#c0392b]red tetris[/color]',
	'#greentris': '[color=#27ae60]green tetris[/color]',
	'#yb': '[color=#f1c40f]⚫[/color]',  # watch out, there is a 'black circle' utf8 char here
	'#rb': '[color=#c0392b]⚫[/color]',  # same here
	'#frostbeams': '[color=#3498db]frost beams[/color]',
}


func _process(delta):
	time_since_last_hint += delta


func display(hint_id):
	if not show:
		return
	
	if not(hint_id in hints):
		return
	
	var world = $'/root/world'
	if world == null:
		return
	
	if time_since_last_hint < min_time_between_hints:
		return
	
	time_since_last_hint = 0
	
	var txt = str(nb_hints-hints.keys().size()+1) + '/' + str(nb_hints) +': '+ hints[hint_id]
	for h in hashtags:
		txt = txt.replacen(h,hashtags[h])
	
	hints.erase(hint_id)
	var hintbox = world.find_node('hint')
	hintbox.get_node('anim').stop()
	hintbox.get_node('anim').play('fadein')
	hintbox.get_node('text').bbcode_text = '[center]'+txt+'[/center]'
