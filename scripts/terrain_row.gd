extends Node2D

const TILE := MineWorld.TILE
const BOARD_ZOOM := 2.0
var game: Node
var row := 0
var draw_count := 0

func _draw() -> void:
	draw_count += 1
	var world: MineWorld = game.world
	for x in range(MineWorld.COLS):
		var cell := Vector2i(x, row)
		if not world.blocks.has(cell):
			continue
		var pos := Vector2.ZERO
		draw_set_transform(Vector2(cell.x * TILE, 0), 0, Vector2.ONE * BOARD_ZOOM)
		pos = Vector2.ZERO
		var settling: float = game.placement_effects.get(cell, 0.12)
		if settling < 0.12:
			var t := settling / 0.12
			var size := lerpf(0.65, 1.08, t / 0.65) if t < 0.65 else lerpf(1.08, 1.0, (t - 0.65) / 0.35)
			draw_set_transform(Vector2(cell.x * TILE + 16, 16), 0, Vector2.ONE * BOARD_ZOOM * size)
			pos = Vector2(-8, -8)
		var block: Dictionary = world.blocks[cell]
		var base := MineWorld.block_color(cell, world.base_depth)
		draw_rect(Rect2(pos, Vector2(16, 16)), base.darkened(0.48))
		# Borders and bevels occupy whole pixels in the shared 16x16 tile grid.
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(14, 14)), base)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(14, 1)), base.lightened(0.16))
		draw_rect(Rect2(pos + Vector2(1, 2), Vector2(1, 12)), base.lightened(0.07))
		draw_rect(Rect2(pos + Vector2(14, 2), Vector2(1, 12)), base.darkened(0.18))
		draw_rect(Rect2(pos + Vector2(1, 14), Vector2(14, 1)), base.darkened(0.28))
		var dirt_rng := RandomNumberGenerator.new()
		dirt_rng.seed = hash(Vector3i(cell.x, cell.y, int(block.variant)))
		for fragment in range(4):
			var a := pos + Vector2(dirt_rng.randi_range(2, 11), dirt_rng.randi_range(2, 11))
			var w := dirt_rng.randi_range(1, 3)
			var h := dirt_rng.randi_range(1, 2)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(w, -1), a + Vector2(w + 1, h), a + Vector2(1, h + 1)]), base.darkened(dirt_rng.randf_range(0.07, 0.19)))
		if block.ore >= 0:
			MineCatalog.ore_shape(self, pos + Vector2(8, 8), block.ore, 0.75, float(block.variant) * TAU / 7.0)
			if block.ore >= 8:
				draw_circle(pos + Vector2(12, 4), 0.9, MineCatalog.ore_color(block.ore).lightened(0.6))
		if block.hp == 1:
			var crack := Color("201f20")
			draw_polyline(PackedVector2Array([pos + Vector2(3, 0), pos + Vector2(6, 5), pos + Vector2(4, 9), pos + Vector2(10, 12), pos + Vector2(9, 16)]), crack, 1.2)
			draw_polyline(PackedVector2Array([pos + Vector2(6, 5), pos + Vector2(11, 6), pos + Vector2(16, 3)]), crack, 1)
			draw_line(pos + Vector2(4, 9), pos + Vector2(0, 11), crack, 1)
