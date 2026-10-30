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

func capture(path: String) -> Image:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.save_png("res://.test-data/" + path + ".png")
	return pixels

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
	game.cursor_position = Vector2(10, 100)
	game.place_block(game.world.cell_position(Vector2i(3, -1)) + Vector2(16, 16))
	game.update_terrain_cache()
	var hud := await capture("run-new-hud")
	game.overlay_alpha = 0
	var faded := await capture("run-hud-faded")
	check(hud.get_region(Rect2i(320, 1480, 640, 110)).get_data() != faded.get_region(Rect2i(320, 1480, 640, 110)).get_data(), "Depth and block count render as bottom overlays and fade out")
	game.overlay_alpha = 1
	game.cursor_position = game.freeze_rect.get_center()
	var tooltip := await capture("run-hotkey-tooltip")
	check(hud.get_region(Rect2i(400, 220, 400, 100)).get_data() != tooltip.get_region(Rect2i(400, 220, 400, 100)).get_data(), "Button hover draws the hotkey popup below the mouse")
	game.cursor_position = Vector2.ZERO
	game.top_spike_height = 16
	await capture("run-top-spikes")
	game.top_spike_height = 0
	game.upgrades.lives = 1
	var lives := await capture("run-upgraded-lives")
	check(hud.get_region(Rect2i(744, 20, 180, 125)).get_data() != lives.get_region(Rect2i(744, 20, 180, 125)).get_data(), "Lives appear only after an extra-life upgrade")
	game.inventory[1] = 10
	game.run_ores_found = 10
	game.run_best_before = 80
	game.best_depth = 80
	game.run_peak = 95
	game.claimed_milestones.assign([10, 20, 30, 40, 50, 60, 70, 80])
	game.world.scroll = 95 * MineWorld.TILE
	game.player.y = MineWorld.START_Y
	game.die("Native death preview")
	var closed_at: float = game.death_transition_start() + game.DEATH_IRIS_DURATION + game.DEATH_IRIS_HOLD + game.DEATH_FINAL_CLOSE
	game.advance_death(closed_at + 0.2)
	var lost := await capture("run-death-ores-lost")
	var white := 0
	for y in range(720, 850):
		for x in range(160, 800):
			var color := lost.get_pixel(x, y)
			white += int(color.r > 0.9 and color.g > 0.9 and color.b > 0.9)
	check(white > 100 and lost.get_pixel(20, 20).r == 0, "Death iris closes to a black screen with large white ore-loss text")
	game.advance_death(game.DEATH_BLACK_HOLD)
	var results: Node = game.results
	results.set_process(false)
	results._process(0)
	results.age = results.reward_beat_time(0) + 0.15
	results.queue_redraw()
	results.graphics_art.queue_redraw()
	await capture("run-milestone-confetti")
	var art: Image = results.graphics_viewport.get_texture().get_image()
	var colored := 0
	for y in range(245, 300):
		for x in range(18, 224):
			var color := art.get_pixel(x, y)
			colored += int(color.a > 0 and ((color.r > 0.85 and color.g < 0.7) or (color.b > 0.8 and color.r < 0.7)))
	check(colored > 8, "Colored milestone confetti bursts from the progress bar on the pixel grid")
	results.complete_reveal()
	await capture("run-retained-ore-results")
	check(results.report.ore_count == 3 and results.report.ores_lost == 7, "Rendered death results use retained and lost quantities separately")
	print("Run HUD native: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
