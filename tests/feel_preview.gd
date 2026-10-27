extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("capture")

func shot(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/%s.png" % label)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data"))
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.synth.muted = true
	game.set_physics_process(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(720, 1200)
	for depth in [0, 300, 660, 1200, 2200]:
		game.selected_depth = depth
		game.start_run()
		game.world.reset(depth, 2026 + depth)
		game.enemies.clear()
		game.spawn_enemies()
		for frame in range(30):
			game._physics_process(1.0 / 60)
		await shot("region-%d" % depth)
	setup_floor()
	game.world.blocks[Vector2i(8, 5)] = {"hp": 2, "ore": -1, "variant": 0}
	game.player = Vector2(244, 384)
	game.player_velocity.x = game.WALK_SPEED
	for frame in range(4):
		game.update_player(1.0 / 60)
	await shot("movement-turn")
	setup_floor()
	for y in range(6, 20):
		for x in range(7, 15):
			game.world.blocks.erase(Vector2i(x, y))
	game.player = Vector2(234, 384)
	var seeded_rng := RandomNumberGenerator.new()
	for seed_value in range(100):
		seeded_rng.seed = seed_value
		if seeded_rng.randf() < game.HESITATION_CHANCE:
			game.hesitation_rng.seed = seed_value
			break
	game.player_velocity.x = game.WALK_SPEED
	for frame in range(2):
		game.update_player(0.05)
	await shot("movement-edge")
	setup_floor(12)
	game.player.y -= 145
	game.grounded = false
	for frame in range(120):
		game.time += 1.0 / 60
		game.update_player(1.0 / 60)
		if game.grounded:
			break
	for frame in range(4):
		game.time += 1.0 / 60
		game.update_player(1.0 / 60)
		game.update_particles(1.0 / 60)
		game.update_landing_rings(1.0 / 60, 0)
	await shot("movement-landing")
	quit()

func setup_floor(row: int = 6) -> void:
	game.selected_depth = 0
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.decorations.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for y in range(row, 22):
		for x in range(15):
			game.world.blocks[Vector2i(x, y)] = {"hp": 2, "ore": -1, "variant": 0}
	game.player = Vector2(240, 208 + row * 32 - 16)
	game.grounded = true
