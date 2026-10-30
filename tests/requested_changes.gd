extends SceneTree

var game: Node
var failures := 0
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	game.depot_seen_this_session = true
	game.speed_learned = true
	game.freeze_learned = true
	game.pending_shortcuts.clear()
	game.upgrades.lives = 0
	game.selected_depth = 0
	game.start_run()
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	game.placement_taught = false

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check([MineCatalog.starting_depth(1), MineCatalog.starting_depth(2), MineCatalog.starting_depth(3)] == [10, 30, 60], "Depth increments grow by ten each purchase")
	var singles := 0
	var veins := 0
	for seed_value in range(20):
		var world := MineWorld.new()
		world.reset(0, seed_value + 450)
		veins += world.veins.size()
		for block in world.blocks.values():
			if block.get("single", false):
				singles += 1
	check(singles == veins * 3, "Three single deposits spawn per vein across twenty mines")
	for ability in ["freeze", "speed"]:
		fresh()
		if ability == "freeze":
			game.freeze_learned = false
			game.speed_learned_round = game.rounds_started - 2
		else:
			game.speed_learned = false
		game.start_run()
		var position: Vector2 = game.player
		var scroll: float = game.world.scroll
		game._physics_process(1.0)
		check(not game.shortcut_popup and game.world.scroll == scroll, "First run has no startup popup for " + ability)
		var click := InputEventMouseButton.new()
		click.position = Vector2(240, 432)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		game._input(click)
		check(not game.shortcut_popup and game.pending_shortcuts.is_empty(), "Confirm dismisses and remembers " + ability)
	fresh()
	game.world.blocks[Vector2i(6, 4)] = {"hp": 2, "ore": -1, "variant": 0}
	game.world.blocks[Vector2i(7, 7)] = {"hp": 2, "ore": -1, "variant": 0}
	game.world.floor_spikes[Vector2i(7, 7)] = {"height": 10.0}
	game.player = Vector2(208, 384)
	game.grounded = true
	game.direction = 1
	game.player_velocity = Vector2(19, 0)
	game.update_player(0.1)
	check(game.tutorial_cell == Vector2i(7, 3), "Dangerous first ledge highlights adjacent turning wall")
	var before: Vector2 = game.player
	game._physics_process(1.0)
	check(game.player == before, "Placement lesson pauses simulation")
	check(not game.place_block(game.world.cell_position(Vector2i(8, 4)) + Vector2(16, 16)), "Other placement cannot dismiss lesson")
	check(game.place_block(game.world.cell_position(Vector2i(7, 3)) + Vector2(16, 16)) and game.placement_taught and game.tutorial_cell.x == -999, "Required block completes lesson")
	fresh()
	var spike_cell := Vector2i(6, 4)
	game.world.blocks[spike_cell] = {"hp": 2, "ore": -1, "variant": 0}
	game.world.floor_spikes[spike_cell] = {"height": 10.0}
	game.player = Vector2(207, 384)
	game.update_player(1.0 / 60)
	check(game.mode == "dying" and game.world.floor_spikes.has(spike_cell), "Fatal spike remains in world")
	game.advance_death(game.death_transition_start() + game.DEATH_IRIS_DURATION + 0.19)
	check(game.player == game.death_origin, "Death arc waits for iris and delay")
	game.advance_death(0.11)
	check(game.player.y < game.death_origin.y and absf(game.player_lean) > 0, "Death arc launches upward and rotates")
	game.advance_death(1.2)
	check(game.player.y > 800, "Death arc falls off screen")
	fresh()
	game.enemies.append({"pos": game.player, "vel": Vector2.ZERO, "type": 0, "dir": 1, "clock": 0.0, "ground": false, "home": game.player, "cooldown": 0.0})
	game.update_enemies(0.001, 0)
	check(game.mode == "dying" and game.enemies.size() == 1, "Fatal enemy remains in world")
	print("Requested changes: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
