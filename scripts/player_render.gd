extends Node2D

var game: Node

func _draw() -> void:
	if game == null:
		return
	# The helmet and ears share one rigid pivot; only the boots have a walking gait.
	draw_set_transform(Vector2(32, 32), game.player_lean)
	draw_player()
	for x in [-3.5, 2.5]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -16), Vector2(x, -22), Vector2(x + 2, -16)]), Color("ee8b38"))
	# Rasterize the eye after rotating the body so it is always one native pixel wide.
	var eye := (Vector2(32, 32) + Vector2(game.facing_blend * 3, -11).rotated(game.player_lean)).floor()
	draw_set_transform(Vector2.ZERO)
	if not game.blink_closed(game.time, 0):
		draw_rect(Rect2(eye, Vector2(1, 2)), Color("253038"))

func draw_player() -> void:
	# Animate around the feet. The physical 24×32 collision box never changes.
	var p := Vector2(0, -8)
	var walking := minf(1, absf(game.player_velocity.x) / game.WALK_SPEED)
	var step := sin(game.walk_cycle) * walking if game.grounded else 0.15
	# Alternating boots swing along the ground rather than moving the body collider.
	draw_rect(Rect2(p + Vector2(-5 - step * 0.6, 4), Vector2(4, 4 - maxf(0, step) * 0.8)), Color("17232a"))
	draw_rect(Rect2(p + Vector2(1 - step * 0.6, 4), Vector2(4, 4 - maxf(0, -step) * 0.8)), Color("17232a"))
	draw_rect(Rect2(p + Vector2(-6, -1), Vector2(11, 7)), Color("70bcb4"))
	var pack := p + Vector2(-game.facing_blend * 7 - 2, -1)
	draw_rect(Rect2(pack, Vector2(4, 6)), Color("946c4d"))
	draw_line(pack + Vector2(0, 1), pack + Vector2(4, 1), Color("c49b62"), 1)
	draw_rect(Rect2(p + Vector2(-4, -6), Vector2(9, 6)), Color("ee8b38"))
	draw_rect(Rect2(p + Vector2(-6, -8), Vector2(11, 4)), Color("eab65c"))
	draw_line(p + Vector2(-7, -4), p + Vector2(7, -4), Color("ffe1a0"), 2)

