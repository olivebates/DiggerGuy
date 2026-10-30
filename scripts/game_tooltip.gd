extends Node2D

var game: Node

func _draw() -> void:
	if is_instance_valid(game) and game.mode == "playing":
		game.draw_game_tooltip(self)
