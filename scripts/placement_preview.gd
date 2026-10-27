extends Node2D

var game: Node

func target_rect() -> Rect2:
	if game == null or not game.can_place_block(game.cursor_position):
		return Rect2()
	var cell: Vector2i = game.world.cell_at(game.cursor_position)
	var origin: Vector2 = game.world.cell_position(cell) + game.camera_offset()
	return Rect2(origin, Vector2.ONE * MineWorld.TILE).intersection(Rect2(0, MineWorld.TOP, 480, MineWorld.BOTTOM - MineWorld.TOP))

func _draw() -> void:
	var rect := target_rect()
	if rect.has_area():
		# Deliberate exception to hard-alpha world art: this placement guide blends.
		draw_rect(rect, Color(0.5, 0.5, 0.5, 0.5))
