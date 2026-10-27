extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data"))
	var game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.synth.muted = true
	game.credits = 125
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(720, 1200)
	for i in range(20):
		await process_frame
	game.frozen_toggle = true
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/game.png")
	game.inventory[0] = 3
	game.inventory[1] = 1
	game.inventory_open = true
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/inventory.png")
	game.return_to_depot(false)
	for capture_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/depot.png")
	game.credits = 320
	game.depot.open_shop()
	game.depot.queue_redraw()
	for capture_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/shop.png")
	game.depot.screen = "depot"
	game.depot.activate_primary()
	game.depot.advance_sale(0.4)
	game.depot.queue_redraw()
	for capture_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/selling.png")
	game.depot.advance_sale(2)
	game.depot.queue_redraw()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/depot-sold.png")
	game.selected_depth = 600
	game.start_run()
	game.world.reset(600, 2026)
	game.enemies.clear()
	game.spawn_enemies()
	for i in range(80):
		game.world.flow_lava()
	game.frozen_toggle = true
	game.mine_at(Vector2(240, 270))
	game.queue_redraw()
	for capture_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/deep-mine.png")
	game.inventory[0] = 10
	game.inventory[13] = 2
	game.inventory[14] = 2
	game.die("Caught in a lava spill")
	game.set_physics_process(false)
	game.advance_death(0.42)
	game.queue_redraw()
	for capture_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/death.png")
	game.advance_death(game.death_transition_start() + 0.275 - game.death_time)
	game.queue_redraw()
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/death-iris.png")
	game.advance_death(game.death_duration() - game.death_time - 0.02)
	game.queue_redraw()
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/death-black.png")
	game.advance_death(0.03)
	game.queue_redraw()
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/death-depot.png")
	quit()
