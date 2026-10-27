extends SceneTree

class GuiProbe extends Node2D:
	func _draw() -> void:
		MineInk.panel(self, Rect2(11.3, 13.7, 100.3, 60.6))
		for i in range(MineInk.ICONS.size()):
			var center := Vector2(24.3 + (i % 6) * 36, 110.7 + (i / 6) * 42)
			MineInk.icon(self, MineInk.ICONS[i], center, MineInk.TEXT, 0.75 + (i % 4) * 0.25)

var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(480, 800)
	var world := MineWorld.new()
	world.reset(0, 24)
	var integer_steps := true
	var accumulated := 0.0
	for step in range(240):
		var movement := world.advance(1.0 / 60, 11.25)
		accumulated += movement
		integer_steps = integer_steps and (movement == 0 or movement == 2) and fmod(world.scroll, 2) == 0
	check(integer_steps, "Slow terrain scrolling advances only one whole game pixel at a time")
	check(absf(accumulated + world.scroll_remainder - 45) < 0.00001, "Fractional speed accumulation preserves distance over four seconds")
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	game.world.scroll = 0
	game.player = Vector2(240, 180)
	game.time = 1.2
	game.cursor_position = Vector2(-10, -10)
	for row in game.terrain_rows.values():
		row.queue_redraw()
	await frames()
	var background: Image = root.get_texture().get_image().get_region(Rect2i(24, 300, 140, 200))
	game.land_player(200, 350)
	var flicker := false
	for phase in range(6):
		game.time = 1.2 + phase * 0.017
		await frames(2)
		var current: Image = root.get_texture().get_image().get_region(Rect2i(24, 300, 140, 200))
		flicker = flicker or current.get_data() != background.get_data()
	check(not flicker, "A heavy landing leaves background colors and dither coverage unchanged")
	game.shake = 0
	game.particles.clear()
	game.landing_rings.clear()
	game.time = 1.2
	await frames()
	var light: Image = root.get_texture().get_image()
	var lit := 0
	var unlit := 0
	var warm := Color("ffe1a0")
	for y in range(152, 190, 2):
		for x in range(286, 326, 2):
			var color := light.get_pixel(x, y)
			if absf(color.r - warm.r) + absf(color.g - warm.g) + absf(color.b - warm.b) < 0.015:
				lit += 1
			else:
				unlit += 1
	check(lit == 0 and unlit > 0, "The player emits no lamp cone or nearby light")
	var still: PackedByteArray = light.get_data()
	game.player += Vector2(0.2, 0.2)
	await frames()
	check(still == root.get_texture().get_image().get_data(), "Subpixel physics offsets do not move the rendered miner between grid pixels")
	game.cursor_position = Vector2(80, 798)
	check(game.can_place_block(game.cursor_position), "Placement reaches the final screen row")
	check(game.placement_preview.target_rect().end.y == 800, "Placement preview clips precisely to the screen bottom")
	check(game.place_block(game.cursor_position), "A block can be placed below the old play-area border")
	game.player = Vector2(240, 730)
	game.spike_height = 16
	game.update_spikes(0)
	check(game.mode == "playing", "The former bottom border no longer kills the miner")
	game.player.y = 790
	game.update_spikes(0)
	check(game.mode == "dying", "Spike contact at the actual screen bottom still kills")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(GuiProbe.new())
	await frames()
	var gui := viewport.get_texture().get_image()
	var mismatch := 0
	var visible := 0
	for y in range(0, 256, 2):
		for x in range(0, 256, 2):
			var color := gui.get_pixel(x, y)
			if color != gui.get_pixel(x + 1, y) or color != gui.get_pixel(x, y + 1) or color != gui.get_pixel(x + 1, y + 1):
				mismatch += 1
			if color.a > 0.99 and y >= 100:
				visible += 1
	check(mismatch == 0 and visible > 100, "GUI outlines and all icon variants align to uniform global 2x2 pixel squares")
	check(gui.get_pixel(12, 14) == MineInk.LINE and gui.get_pixel(13, 15) == MineInk.LINE and gui.get_pixel(14, 16) == MineInk.PANEL, "GUI outlines are exactly one game pixel thick")
	print("Pixel grid/UI: %d checks, %d failures; %d GUI grid mismatches" % [checks, failures, mismatch])
	viewport.queue_free()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
