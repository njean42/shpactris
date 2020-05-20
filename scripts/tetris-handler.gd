extends Node2D

var cells = []
var lines_being_deleted = {}


func _init():
	# init 2-dimensional array knowledge about cells occupation (tetris blocks presence)
	for y in range(17):
		cells.append([])
		for x in range(10):
			cells[y].append(null)


func _physics_process(delta):
	
	# move lines down a notch (if one or more just got removed)
	moves_upper_lines_down()
	check_tetris_lines()


func new_block(block):
	var gridpos = global.pos_to_grid(block.global_position - Vector2(global.GRID_SIZE/2,global.GRID_SIZE/2))
	if cells[gridpos.y][gridpos.x]:
		prints('[BUG] a new block has arrived at pos',gridpos,"but it's occupied already...", block, cells)
	
	cells[gridpos.y][gridpos.x] = block
	
	set_physics_process(true)
	
	debug_cells()

func get_blocks(kind='HIGHEST'):
	var highest_block = null
	
	for line in cells:
		for block in line:
			if block != null and (highest_block == null or block.position.y < highest_block.position.y):
				highest_block = block
	
	match kind:
		'HIGHEST':
			return highest_block
	return null

func get_friendable_zone_bottom():
	var highest_block = get_blocks('HIGHEST')
	if highest_block == null:
		return global.SCREEN_SIZE.y/2
	return min(
		global.SCREEN_SIZE.y/2,
		highest_block.position.y - 3*global.GRID_SIZE
	)

func check_tetris_lines():
	var y = cells.size()-1
	var full_line_sets = {}
	
	while y >= 0:
		if tetris_line_full(y) and not (y in lines_being_deleted):
			global.play_sound('line_disappears',false)
			lines_being_deleted[y] = 10  # number of blocks to wait for anim end
			if y+1 in full_line_sets:
				# store lines together in a set
				full_line_sets[y+1].append(y)
				full_line_sets[y] = full_line_sets[y+1]
				full_line_sets.erase(y+1)
			else:
				# create a new set containing this one line
				full_line_sets[y] = [y]
		y -= 1
	
	# check for full lines and make them disappear
	var mult = 0
	for s in full_line_sets:
		for y in full_line_sets[s]:
			mult += 1
			# get frost beam
			for m in range(0,mult):
				$'/root/world/ship'.get_beam()
			
			for block in cells[y]:
				block.modulate = Color(1,1,1,1)
				block.get_node('animation').line_nb = y
				block.get_node('animation').play('fade-out')
				# earn gold
				$'/root/world'.earn_gold(block,100*mult)
	
	if lines_being_deleted.size() == 0:
		set_physics_process(false)

func tetris_line_full(y):
	var nb_cells = 0
	for cell in cells[y]:
		if cell != null:
			nb_cells += 1
	return nb_cells == cells[y].size()

func tetris_line_empty(y):
	var nb_cells = 0
	for cell in cells[y]:
		if cell != null:
			nb_cells += 1
	return nb_cells == 0

func block_removed_from_line(y):
	lines_being_deleted[y] -= 1

func moves_upper_lines_down():
	for y in range(0,18):
		if y in lines_being_deleted and lines_being_deleted[y] == 0:
			for upper_y in range(y-1,-1,-1):
				# update the cells map
				var empty_line = []
				for i in range(10): empty_line.append(null)
				cells[upper_y+1] = cells[upper_y] if upper_y > 0 else empty_line
				
				# move down all upper lines' blocks by one cell
				for block in cells[upper_y]:
					if block != null:
						block.position.y += global.GRID_SIZE
			lines_being_deleted.erase(y)

func debug_cells():
	return
	print("--------------------\n")
	for y in range(cells.size()):
		if y<13:
			continue
		var txt = ''
		for cell in cells[y]:
			txt += ('·' if cell == null else 'O')
		print(txt)
	print("--------------------\n\n")
