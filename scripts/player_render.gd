extends Node2D

var game: Node

func _draw() -> void:
	if game == null:
		return
	draw_set_transform(Vector2(32, 32), game.player_lean)
	var walking := minf(1, absf(game.player_velocity.x) / game.WALK_SPEED)
	var step := sin(game.walk_cycle) * walking if game.grounded else 0.15
	draw_body(self, game.upgrades, game.facing_blend, step)
	var eye := (Vector2(32, 32) + Vector2(game.facing_blend * 3 + (1 if game.direction < 0 else 0), -11).rotated(game.player_lean)).floor()
	draw_set_transform(Vector2.ZERO)
	if not game.blink_closed(game.time, 0):
		draw_rect(Rect2(eye, Vector2(1, 2)), Color("253038"))

static func draw_equipment(canvas: CanvasItem, feet: Vector2, levels: Dictionary, scale_value: float = 2.0, step: float = 0.0) -> void:
	canvas.draw_set_transform(feet.round(), 0, Vector2.ONE * scale_value)
	draw_body(canvas, levels, 1.0, step)
	canvas.draw_rect(Rect2(3, -11, 1, 2), Color("253038"))
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_body(canvas: CanvasItem, levels: Dictionary, facing: float, step: float) -> void:
	var p := Vector2(0, -8)
	var capacity: int = levels.get("capacity", 0)
	var power: int = levels.get("power", 0)
	var speed: int = levels.get("speed", 0)
	var armour: int = levels.get("lives", 0)
	var insurance: int = levels.get("insurance", 0)
	var depth: int = levels.get("depth", 0)
	canvas.draw_rect(Rect2(p + Vector2(-5 - step * 0.6, 4), Vector2(4, 4 - maxf(0, step) * 0.8)), Color("17232a"))
	canvas.draw_rect(Rect2(p + Vector2(1 - step * 0.6, 4), Vector2(4, 4 - maxf(0, -step) * 0.8)), Color("17232a"))
	if speed > 0:
		for x in [-5, 1]:
			canvas.draw_rect(Rect2(p + Vector2(x, 5), Vector2(4, 1 + mini(speed, 2))), Color("edbd64"))
	var pack := p + Vector2(-facing * 7 - 2, -1)
	var pack_size := Vector2(4, 6) if capacity == 0 else Vector2(5, 7 + mini(3, capacity / 2))
	canvas.draw_rect(Rect2(pack - Vector2(0, mini(2, capacity / 2)), pack_size), Color("946c4d") if capacity == 0 else Color("a78353"))
	for strap in range(mini(3, 1 + capacity)):
		canvas.draw_line(pack + Vector2(0, strap * 2), pack + Vector2(pack_size.x - 1, strap * 2), Color("e0c185"), 1)
	canvas.draw_rect(Rect2(p + Vector2(-6, -1), Vector2(11, 7)), Color("70bcb4"))
	canvas.draw_rect(Rect2(p + Vector2(-4, -6), Vector2(9, 6)), Color("ee8b38"))
	var helmet := Color("eab65c") if power == 0 else (Color("c4d5dc") if power < 4 else Color("dfc472"))
	canvas.draw_rect(Rect2(p + Vector2(-6, -8), Vector2(11, 4)), helmet)
	canvas.draw_line(p + Vector2(-7, -4), p + Vector2(7, -4), Color("ffe1a0"), 2)
	if power > 0:
		for notch in range(mini(power, 4)):
			canvas.draw_rect(Rect2(p + Vector2(-4 + notch * 2, -7), Vector2(1, 2)), helmet.darkened(0.35))
		canvas.draw_rect(Rect2(p + Vector2(3, -6), Vector2(2, 2)), Color("f5f0be"))
	if armour > 0:
		canvas.draw_rect(Rect2(p + Vector2(-5, 1), Vector2(9, 1 + mini(armour, 3))), Color("91d5d0"))
	if insurance > 0:
		canvas.draw_rect(Rect2(p + Vector2(1, 0), Vector2(3, 3)), Color("e5d1a0"))
		canvas.draw_rect(Rect2(p + Vector2(2, 0), Vector2(1, mini(insurance, 3))), Color("7a895d"))
	if depth > 0:
		canvas.draw_rect(Rect2(p + Vector2(-4, 0), Vector2(2, 2)), Color("bad3e5"))
	if levels.get("blocks", 0) > 0:
		canvas.draw_rect(Rect2(p + Vector2(-2, 4), Vector2(2 + mini(2, int(levels.blocks)), 2)), Color("caa377"))
	for x in [-3.5, 2.5]:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -16), Vector2(x, -22), Vector2(x + 2, -16)]), Color("ee8b38"))
