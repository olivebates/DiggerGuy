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

func frame_image() -> Image:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 1600)
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	game.speed_learned = true
	game.freeze_learned = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.selected_depth = 30
	game.run_peak = 95
	game.best_depth = 95
	game.run_best_before = 80
	game.claimed_milestones.assign([10, 20, 30, 40, 50, 60, 70, 80])
	for ore in range(45):
		game.discover_material(ore, false)
		game.materials_sold[ore] = ore * 10
	game.run_materials_before = game.discovered_materials.duplicate()
	game.run_materials_before.erase(8)
	game.inventory[1] = 3
	game.inventory[8] = 2
	game.run_ores_found = 5
	game.run_blocks_broken = 26
	game.finish_expedition(false)
	game.results.age = 1.5
	game.cursor_position = Vector2.ZERO
	var during := await frame_image()
	during.save_png("res://.test-data/materials-reward-animation.png")
	game.results.complete_reveal()
	game.cursor_position = Vector2.ZERO
	var full := await frame_image()
	full.save_png("res://.test-data/materials-results.png")
	check(during.get_data() != full.get_data(), "Reward progress, counts, and newly collected icons animate before settling")
	check(game.results.material_rect(44).end.x <= 460 and game.results.material_rect(44).end.y < 464, "All forty-five material tiles fit the journal")
	game.cursor_position = game.results.material_rect(8).get_center()
	var hover := await frame_image()
	hover.save_png("res://.test-data/materials-tooltip.png")
	var art: Image = game.results.graphics_viewport.get_texture().get_image()
	var binary := true
	var visible_pixels := 0
	for y in range(art.get_height()):
		for x in range(art.get_width()):
			var alpha := art.get_pixel(x, y).a
			binary = binary and (alpha == 0 or alpha == 1)
			visible_pixels += int(alpha == 1)
	check(binary and visible_pixels > 500, "Pixel-shaded progression art has binary alpha and visible graphics")
	var scale := hover.get_width() / 480
	var pixel_size := scale * 2
	var uniform := true
	var colors: Dictionary = {}
	for y in range(534 * scale, 604 * scale, pixel_size):
		for x in range(48 * scale, 116 * scale, pixel_size):
			var color := hover.get_pixel(x, y)
			colors[color.to_html()] = true
			for dy in range(pixel_size):
				for dx in range(pixel_size):
					uniform = uniform and hover.get_pixel(x + dx, y + dy) == color
	check(uniform and colors.size() > 2, "Large material tooltip icon preserves solid two-game-pixel blocks")
	game.cursor_position = Vector2.ZERO
	var normal := await frame_image()
	game.cursor_position = game.results.CONTINUE.get_center()
	var highlighted := await frame_image()
	check(normal.get_pixel(26 * scale, 740 * scale) != highlighted.get_pixel(26 * scale, 740 * scale), "Continue gains the same growing highlight as other buttons")
	highlighted.save_png("res://.test-data/materials-continue-hover.png")
	game.continue_to_depot()
	game.best_depth = 0
	game.credits = 1000000
	game.depot.open_shop()
	game.depot.transition = 0
	game.cursor_position = Vector2.ZERO
	var locked := await frame_image()
	locked.save_png("res://.test-data/materials-shop-locked.png")
	game.best_depth = 90
	var unlocked := await frame_image()
	unlocked.save_png("res://.test-data/materials-shop-unlocked.png")
	check(locked.get_data() != unlocked.get_data(), "Locked translucent cards and reached milestones render differently")
	print("Materials native: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
