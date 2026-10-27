extends SceneTree

var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw

func row_draws() -> int:
	var count := 0
	for row in game.terrain_rows.values():
		count += row.draw_count
	return count

func button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	event.position = point
	game._input(event)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(480, 800)
	await frames(4)
	var populated_draws := row_draws()
	var populated_started := Time.get_ticks_usec()
	await frames(20)
	check(row_draws() == populated_draws, "A populated mine also reuses every unchanged terrain row")
	print("Populated mine: %d blocks, %d terrain rebuilds in 20 frames, %.2f ms/frame" % [game.world.blocks.size(), row_draws() - populated_draws, float(Time.get_ticks_usec() - populated_started) / 20000.0])
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	game.player = Vector2(240, 150)
	game.upgrades.freeze = 1
	game.frozen_toggle = true
	var cell := Vector2i(9, 5)
	game.world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 1}
	for row in game.terrain_rows.values():
		row.queue_redraw()
	game.update_terrain_cache()
	await frames(4)
	var draws := row_draws()
	var started := Time.get_ticks_usec()
	await frames(20)
	check(row_draws() == draws, "Unchanged terrain retains its draw commands across 20 frames")
	print("Steady terrain rebuilds: %d across 20 frames; %.2f ms/frame" % [row_draws() - draws, float(Time.get_ticks_usec() - started) / 20000.0])
	game.world.scroll += 1
	game.update_terrain_cache()
	await frames(2)
	check(row_draws() == draws, "Scrolling moves cached rows without rebuilding their vectors")
	game.mine_at(game.world.cell_position(cell) + Vector2(16, 16))
	await frames(2)
	check(row_draws() == draws + 1, "Damaging one block rebuilds only its row")
	var position := Vector2(80, 350)
	check(game.can_place_block(position), "Empty cell previews as a valid placement")
	button(position, true)
	check(game.blocks_left == 2 and game.placement_effects.size() == 1 and game.particles.size() >= 5, "Placement consumes one budget unit and starts settling plus dirt feedback")
	var motion := InputEventMouseMotion.new()
	motion.position = position + Vector2(96, 0)
	game._input(motion)
	check(game.blocks_left == 0 and game.placement_effects.size() == 3, "A fast drag fills crossed cells until its budget runs out")
	var notices: int = game.floating_texts.size()
	game._input(motion)
	check(game.floating_texts.size() == notices, "Holding over the same cell does not spam placement attempts")
	button(motion.position, false)
	button(motion.position, true)
	check(game.floating_texts.size() == notices + 1 and game.block_counter_pulse == 0.5, "A new press retries the cell and pulses the empty counter")
	button(motion.position, false)
	game._physics_process(0.06)
	check(game.placement_effects.size() == 3, "Placement has a short settling phase even while mining is frozen")
	game._physics_process(0.07)
	check(game.placement_effects.is_empty(), "The settling animation finishes after 0.12 seconds")
	check(not game.can_place_block(position), "Occupied or exhausted cells preview as invalid")
	check(game.world.last_row >= game.world.cell_at(Vector2(0, 800)).y + 50, "Generation stays at least 50 rows below the full screen edge")
	check(game.global_pixel_material.shader.code.contains("240.0, 400.0"), "All world shapes share a global grid with 16 pixels per block")
	game.cursor_position = Vector2(400, 400)
	game.time = 1.2
	game.player_lean = 0.35
	await frames(3)
	var sprite: Image = game.player_viewport.get_texture().get_image()
	var eye_columns: Dictionary = {}
	var eye_pixels := 0
	for y in range(64):
		for x in range(64):
			var pixel := sprite.get_pixel(x, y)
			var eye := Color("253038")
			if pixel.a > 0.99 and absf(pixel.r - eye.r) + absf(pixel.g - eye.g) + absf(pixel.b - eye.b) < 0.015:
				eye_columns[x] = true
				eye_pixels += 1
	check(eye_columns.size() == 1 and eye_pixels == 2, "Rotating the miner preserves a one-pixel-wide eye")
	var image: Image = root.get_texture().get_image()
	var mismatches := 0
	for y in range(100, 800, 2):
		for x in range(0, 480, 2):
			var color := image.get_pixel(x, y)
			if color != image.get_pixel(x + 1, y) or color != image.get_pixel(x, y + 1) or color != image.get_pixel(x + 1, y + 1):
				mismatches += 1
	check(mismatches == 0, "Rendered world pixels align to identical global 2x2 squares")
	print("Global grid mismatches: %d" % mismatches)
	print("Placement feel: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
