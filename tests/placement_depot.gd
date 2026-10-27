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

func fresh() -> void:
	game.pending_shortcuts.clear()
	for key in game.upgrades:
		game.upgrades[key] = 0
	game.selected_depth = 0
	game.selected_speed = 1
	game.inventory.fill(0)
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	game.drops.clear()
	game.player = Vector2(240, 180)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	fresh()
	check(game.blocks_left == 3, "Each new run starts with three placeable blocks")
	check(game.place_block(Vector2(80, 320)) and game.blocks_left == 2, "Right-click placement consumes one block")
	check(not game.place_block(Vector2(80, 320)) and game.blocks_left == 2, "An occupied target does not consume a placement")
	check(not game.place_block(game.player) and game.blocks_left == 2, "Placement cannot trap the player inside a block")
	check(not game.place_block(Vector2(-1, 320)) and game.blocks_left == 2, "Placement respects the play-area boundaries")
	game.world.lava[game.world.cell_at(Vector2(112, 320))] = 1.0
	check(not game.place_block(Vector2(112, 320)) and game.blocks_left == 2, "Placement cannot overwrite a lava cell")
	game.world.lava.clear()
	check(game.place_block(Vector2(112, 320)) and game.place_block(Vector2(144, 320)) and game.blocks_left == 0, "Exactly three placements are available by default")
	check(not game.place_block(Vector2(176, 320)) and game.floating_texts.size() == 1, "An exhausted placement creates mouse-position feedback")
	check(game.floating_texts[0].pos == Vector2(176, 320), "No-more-blocks feedback originates at the attempted position")
	game.inventory_open = true
	game._physics_process(0.6)
	check(game.floating_texts[0].age > 0.5, "Placement feedback rises using real time while the game is paused")
	game._physics_process(0.7)
	check(game.floating_texts.is_empty(), "Placement feedback expires instead of accumulating")
	game.inventory_open = false
	game.return_to_depot(false)
	game.credits = 1000
	game.buy_upgrade(7)
	check(game.upgrades.blocks == 1 and game.credits == 900 and MineCatalog.price(7, 1) == 125, "Placement upgrade starts at 100 and uses the normal 25% price growth")
	game.start_run()
	check(game.blocks_left == 4, "A placement upgrade refills four blocks for the next run")
	fresh()
	var cell := Vector2i(6, 5)
	game.world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 0}
	game.world.floor_spikes[cell] = {"height": 10.0}
	var mouse: Vector2 = game.world.cell_position(cell) + Vector2(16, 16)
	game.mine_at(mouse)
	check(game.world.floor_spikes.has(cell), "Cracking a spike support does not break the spikes early")
	var before: int = game.particles.size()
	game.stroke_contacts.clear()
	game.mine_at(mouse)
	var spike_particles := 0
	for particle in game.particles:
		if particle.color == Color("eedbc3"):
			spike_particles += 1
	check(not game.world.floor_spikes.has(cell) and game.particles.size() >= before + 18 and spike_particles >= 12, "Destroying a spiked block emits spike-colored debris along with the dirt debris")
	game.upgrades.power = 1
	game.rng.seed = 123
	var minimum := PI
	var maximum := -PI
	for sample in range(24):
		cell = Vector2i(sample % 14, 6 + sample / 14)
		game.world.blocks[cell] = {"hp": 2, "ore": 0, "variant": 0}
		game.stroke_contacts.clear()
		game.mine_at(game.world.cell_position(cell) + Vector2(16, 16))
		minimum = minf(minimum, game.drops.back().rotation)
		maximum = maxf(maximum, game.drops.back().rotation)
	check(minimum < -2 and maximum > 2, "Ore drops spawn with rotations spanning the full circle")
	fresh()
	game.inventory_open = true
	game._physics_process(1.0 / 60)
	game.inventory_open = false
	game.simulate_step(1.0 / 60)
	check(absf(game.world.scroll + game.world.scroll_remainder - 4.5 * 2.5 / 60) < 0.001, "Pixel-step scrolling accumulates the intended 2.5x rise speed")
	game.player.y = 730
	game.lives = 2
	game.spike_height = 0
	game.update_spikes(0.2)
	check(game.spike_height <= 17, "Bottom spikes never extend beyond one triangle height")
	for amount in range(3):
		fresh()
		game.inventory[0] = amount
		game.die("Low ore test")
		check(game.death_shakes_total == amount, "A death with %d ores has exactly %d shakes" % [amount, amount])
		game.advance_death(amount * game.DEATH_SHAKE_INTERVAL)
		check(game.death_shake_count == amount, "The short ore-dependent shake sequence completes correctly")
	fresh()
	game.die("Iris hold test")
	game.advance_death(0.59)
	check(game.death_iris_progress() == 0, "The iris waits 0.6 seconds after the final shake")
	game.advance_death(0.01 + game.DEATH_IRIS_DURATION)
	check(is_equal_approx(game.death_iris_progress(), 0.94), "The iris reaches its player-sized opening")
	game.advance_death(1.49)
	check(is_equal_approx(game.death_iris_progress(), 0.94) and game.mode == "dying", "The player-sized opening holds for 1.5 seconds")
	game.advance_death(0.02)
	check(game.death_iris_progress() > 0.94 and game.death_iris_progress() < 1, "The final closure starts only after the hold")
	game.advance_death(game.death_duration() - game.death_time + 0.01)
	check(game.mode == "depot" and game.depot.position.y == -800 and game.depot.entrance_time > 0, "Death brings the depot in from above the viewport")
	game.depot._process(0.2)
	check(game.depot.position.y > -800 and game.depot.position.y < 0, "The depot entrance moves downward toward its final position")
	game.depot._process(0.2)
	check(game.depot.position.y == 0 and game.depot.entrance_time == 0, "The depot entrance ends flush with the viewport")
	game.inventory[0] = 2
	game.inventory[1] = 3
	game.inventory[4] = 1
	game.depot.show_depot()
	check(game.depot.row_scale(0) == 0 and game.depot.row_scale(1) == 0, "Haul rows start hidden")
	game.depot._process(0.2)
	check(game.depot.row_scale(0) > 0 and game.depot.row_scale(1) == 0, "Haul rows begin at 0.2-second intervals")
	game.depot._process(0.04)
	check(game.depot.row_characters(0) > game.depot.row_characters(1) and game.depot.row_characters(1) > 0, "Haul labels type one character at a time with staggered starts")
	game.depot._process(0.16)
	check(is_equal_approx(game.depot.row_scale(0), 1) and game.depot.row_scale(2) == 0, "A row settles after 0.4 seconds as later rows continue appearing")
	check(absf(game.depot.primary_rect.position.y - game.depot.haul_rect().end.y - 16 - game.depot.slider_count() * 60) < 0.001, "Sell All sits immediately beneath the haul")
	check(is_equal_approx(game.depot.ore_rect(1).position.y, game.depot.ore_rect(0).end.y), "Haul entries form a single continuous vertical list")
	check(game.material is ShaderMaterial and not game.material.shader.code.contains("color_steps") and not game.material.shader.code.contains("screen_texture"), "Rendering uses object-local coverage without posterization or a screen filter")
	print("Placement/depot: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
