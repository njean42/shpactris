extends Area2D


func _ready():
	if not lobby.i_am_the_game():
		$'collision-shape'.disabled = true


remote func be_gone():
	queue_free()
