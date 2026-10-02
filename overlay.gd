extends Node2D
var game
func _draw():
	if game: game.draw_gui(self)
