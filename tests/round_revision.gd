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
	game.speed_learned = true
	game.freeze_learned = true
	game.pending_shortcuts.clear()
	game.placement_taught = true
	for key in game.upgrades:
		game.upgrades[key] = 0
	game.selected_depth = 0
	game.selected_speed = 3
	game.inventory.fill(0)
	game.start_run()
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for x in range(15):
		game.world.blocks[Vector2i(x, 4)] = {"hp": 2, "ore": -1, "variant": 0}
	game.player = Vector2(208, game.world.cell_position(Vector2i(6, 4)).y - 16)
	game.grounded = true

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = pressed
	game._input(event)

func confirm() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(240, 432)
	game._input(event)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check(game.max_speed() == 2 and game.selected_speed == 2, "Fresh game has x2 speed selected and unlocked")
	check(game.rounds_started == 1 and not game.shortcut_popup, "First round has no speed reminder")
	game.start_run()
	check(game.shortcut_popup and game.pending_shortcuts == ["speed"], "Second round teaches W")
	confirm()
	game.start_run()
	check(game.shortcut_popup, "Reminder repeats while W remains unlearned")
	confirm()
	fresh()
	game.speed_learned = false
	key(true)
	game._physics_process(0.8)
	key(false)
	key(true)
	game._physics_process(0.8)
	check(not game.speed_learned, "Separate W holds do not meet the continuous hold threshold")
	game._physics_process(0.71)
	check(game.speed_learned, "More than 1.5 real seconds holding W learns speed")
	key(false)
	game.start_run()
	check(not game.shortcut_popup, "Learned W stops future reminders")
	fresh()
	check(game.capacity() == 7, "Starting capacity is seven")
	check(ceili((MineWorld.START_Y - MineWorld.TOP) / MineWorld.TILE) == 5, "Starting airspace is five tile rows")
	check([MineCatalog.price(5, 0), MineCatalog.price(5, 1), MineCatalog.price(5, 2)] == [200, 600, 1800], "Speed price triples from 200")
	game.credits = 10000000
	for purchase in range(8):
		game.buy_upgrade(5)
	check(game.upgrades.speed == 8 and game.max_speed() == 10, "Speed continues upgrading beyond previous cap")
	check(game.depot.upgrade_values("speed", 8) == Vector2i(10, 11), "Speed card shows the current and next multiplier")
	check(game.depot.upgrade_values("lives", 0) == Vector2i(0, 1), "Extra life card starts at zero")
	fresh()
	game.inventory[0] = 4
	game.credits = 20
	game.return_to_depot(false)
	check(game.depot.primary_rect == game.depot.dive_rect and game.depot.primary_label() == "Sell All", "Sell All occupies bottom dive slot")
	game.depot.activate_primary()
	check(game.depot.primary_label() == "Dig Deeper" and game.depot.is_selling() and game.credits == 32, "Sell replaces button immediately and credits once")
	game.depot.activate_primary()
	check(game.mode == "playing" and game.depot.sale_flights.is_empty() and game.depot.displayed_credits == 32 and game.depot.wallet_visual == 32, "Early dive instantly finishes sale and visible coin counter")
	fresh()
	game.player.y = 550
	game.inventory[0] = 7
	game.check_full_inventory()
	check(game.inventory_banner_rect().end.x < 0 and game.full_banner_y < 400, "Full banner enters from left above a lower player")
	game.full_banner_time = 1.0
	check(game.inventory_banner_rect().position.x == 28, "Full banner rests onscreen")
	game.full_banner_time = 0.01
	check(game.inventory_banner_rect().position.x > 480, "Full banner exits to right")
	game.full_was_full = false
	game.player.y = 300
	game.check_full_inventory()
	check(game.full_banner_y > 400, "Full banner appears below an upper player")
	for hazard in ["spike", "lava", "enemy", "bottom"]:
		fresh()
		game.placement_taught = false
		for x in range(7, 15):
			game.world.blocks.erase(Vector2i(x, 4))
		if hazard == "spike":
			game.world.blocks[Vector2i(7, 7)] = {"hp": 2, "ore": -1, "variant": 0}
			game.world.floor_spikes[Vector2i(7, 7)] = {"height": 10.0}
		elif hazard == "lava":
			game.world.lava[Vector2i(7, 6)] = 1.0
		elif hazard == "enemy":
			game.enemies.append({"pos": game.world.cell_position(Vector2i(7, 6)) + Vector2(16, 16)})
		game.update_player(1.0 / 60)
		check(game.tutorial_cell == Vector2i(7, 3) and game.player.x == 208, "Centre of tile warns before " + hazard)
		game.enemies.clear()
		game.place_block(game.world.cell_position(game.tutorial_cell) + Vector2(16, 16))
		for step in range(90):
			game.update_player(1.0 / 60)
		check(game.direction == -1 and game.player.x < 208, "Placed wall turns miner away from " + hazard)
	fresh()
	for x in range(15):
		if x != 4:
			game.world.blocks.erase(Vector2i(x, 4))
	var position: Vector2 = game.world.cell_position(Vector2i(4, 4)) + Vector2(16, -12)
	var enemy := {"pos": position, "vel": Vector2.ZERO, "type": 1, "dir": 1, "clock": 0.4, "ground": true, "anchor": position.x}
	game.enemies.append(enemy)
	for step in range(120):
		game.update_enemies(1.0 / 60, 0)
	check(enemy.pos == position and enemy.dir == 1 and enemy.clock == 0.4 and enemy.vel == Vector2.ZERO, "Single-tile enemy remains still without flipping or animating")
	game.world.blocks[Vector2i(5, 4)] = {"hp": 2, "ore": -1, "variant": 0}
	game.update_enemies(0.1, 0)
	check(not enemy.still and enemy.pos.x > position.x, "Enemy resumes when its platform gains space")
	print("Round revision: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
