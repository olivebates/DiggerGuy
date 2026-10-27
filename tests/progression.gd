extends SceneTree
var game: Node
var failures := 0
var checks := 0

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
	game.credits = 100000
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for x in range(15):
		game.world.blocks[Vector2i(x, 4)] = {"hp": 2, "ore": -1, "variant": 0}
	game.player = Vector2(208, 320)
	game.grounded = true

func key_event(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.pressed = pressed
	game._input(key)

func click_depot(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	game.depot._input(event)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	fresh()
	check(game.capacity() == 7 and game.lives == 1 and game.max_speed() == 1, "Fresh progression starts with seven spaces, one life, and normal speed")
	key_event(KEY_SPACE, true)
	key_event(KEY_W, true)
	game.toggle_freeze()
	check(not game.is_frozen() and game.game_speed() == 1, "Freeze and speed shortcuts are locked before purchase")
	check([MineCatalog.price(2, 0), MineCatalog.price(2, 1), MineCatalog.price(2, 2), MineCatalog.price(2, 3)] == [30, 37, 46, 57], "Inventory prices increase by 25% of the previous rounded-down price")
	check([MineCatalog.price(0, 0), MineCatalog.price(0, 1), MineCatalog.price(0, 2), MineCatalog.price(0, 3)] == [60, 75, 93, 116], "Depth prices start at 60 and use recursive floor rounding")
	check(MineCatalog.price(1, 0) == 200 and MineCatalog.price(1, 1) == 250, "Click damage starts at 200 with the same growth rule")
	check([MineCatalog.price(3, 0), MineCatalog.price(3, 1), MineCatalog.price(3, 2)] == [500, 625, 781], "Save Ore prices start at 500 with recursive floor rounding")
	check([MineCatalog.price(6, 0), MineCatalog.price(6, 1), MineCatalog.price(6, 2)] == [1200, 3600, 10800], "Life upgrade prices triple from 1200")
	check([MineCatalog.price(5, 0), MineCatalog.price(5, 1), MineCatalog.price(5, 2)] == [200, 500, 1200], "Speed tiers cost exactly 200, 500, and 1200")
	game.return_to_depot(false)
	game.buy_upgrade(2)
	game.buy_upgrade(2)
	check(game.capacity() == 9 and game.credits == 99933, "Each inventory purchase adds one slot and charges the correct successive price")
	game.inventory[0] = 10
	game.inventory[14] = 2
	game.buy_upgrade(3)
	var kept: Array[int] = game.retained_inventory()
	check(kept[14] == 2 and kept[0] == 2, "A Save Ores purchase adds exactly one saved piece, prioritizing rare ores")
	game.inventory.fill(0)
	game.buy_upgrade(4)
	check(game.upgrades.freeze == 1 and game.pending_shortcuts == ["freeze"] and game.depot.has_popup(), "First Freeze purchase unlocks the ability and opens its shortcut popup")
	var wallet: int = game.credits
	game.depot.activate_primary()
	check(game.mode == "depot", "Shortcut popup blocks diving until confirmed")
	click_depot(game.depot.upgrade_rect(2).get_center())
	check(game.credits == wallet, "Popup blocks clicks on upgrades behind it")
	click_depot(game.depot.confirm_rect.get_center())
	check(game.pending_shortcuts.is_empty(), "Confirm closes the shortcut popup")
	game.buy_upgrade(4)
	check(game.credits == wallet and game.upgrades.freeze == 1, "Freeze can only be bought once")
	game.start_run()
	key_event(KEY_SPACE, true)
	check(game.is_frozen(), "Purchased Freeze activates with Space")
	key_event(KEY_SPACE, false)
	check(not game.is_frozen(), "Releasing Space resumes the mine")
	game.return_to_depot(false)
	wallet = game.credits
	game.buy_upgrade(5)
	check(game.selected_speed == 2 and game.max_speed() == 2 and game.credits == wallet - 200 and game.pending_shortcuts == ["speed"], "First speed tier unlocks 2x and shows the W shortcut")
	game.depot.confirm_shortcut()
	game.buy_upgrade(5)
	check(game.selected_speed == 3 and game.credits == wallet - 700 and game.pending_shortcuts.is_empty(), "Second speed tier costs 500 without repeating the tutorial")
	game.buy_upgrade(5)
	check(game.selected_speed == 4 and game.credits == wallet - 1900 and game.max_speed() == 4, "Final speed tier costs 1200 and unlocks 4x")
	game.buy_upgrade(5)
	check(game.credits == wallet - 1900, "Maxed speed cannot be purchased again")
	game.buy_upgrade(0)
	check(game.selected_depth == 100, "Depth upgrade unlocks a 100m starting point")
	for screen in ["depot", "shop"]:
		game.depot.screen = screen
		var rect: Rect2 = game.depot.slider_rect("depth")
		click_depot(Vector2(188, rect.get_center().y))
		check(game.selected_depth == 0, "Depth slider can select the surface on " + screen)
		var move := InputEventMouseMotion.new()
		move.position = Vector2(1000, rect.get_center().y)
		game.depot._input(move)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		game.depot._input(release)
		check(game.selected_depth == 100 and game.depot.dragging.is_empty(), "Depth slider clamps to purchased depth and releases on " + screen)
		game.depot.set_slider("speed", 188)
		check(game.selected_speed == 1, "Speed slider selects 1x on " + screen)
		game.depot.set_slider("speed", 434)
		check(game.selected_speed == 4, "Speed slider selects unlocked 4x on " + screen)
	game.inventory[0] = 2
	game.depot.screen = "shop"
	click_depot(game.depot.primary_rect.get_center())
	check(game.inventory_count() == 0 and game.depot.is_selling(), "Sell All works on the shop screen")
	game.depot.advance_sale(1)
	check(game.depot.primary_label() == "Sell All", "Sell All retains its label after selling; Dig Deeper uses a separate slot")
	click_depot(game.depot.dive_rect.get_center())
	check(game.mode == "playing", "Dig Deeper works directly from the shop")
	fresh()
	game.credits = 0
	game.inventory[14] = 1
	game.return_to_depot(false)
	game.sell_ores()
	game.buy_upgrade(4)
	check(game.credits == 500 and game.depot.displayed_credits == 0, "Spending incoming sale proceeds never shows a negative coin counter")
	game.depot.advance_sale(1)
	check(game.depot.displayed_credits == 500, "Sale completion matches the wallet after a concurrent purchase")
	test_full_bag()
	test_lives()
	test_save()
	check(game.material is ShaderMaterial and game.depot.use_parent_material and not game.material.shader.code.contains("screen_texture"), "Per-object binary-coverage shader is installed without a screen filter")
	print("Progression: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func test_full_bag() -> void:
	fresh()
	game.inventory[0] = 6
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 1, "rotation": 0.0, "age": 0.0})
	game.update_drops(0.01, 0)
	check(game.inventory_count() == 7 and game.full_banner_time == 2 and game.leave_glow, "Collecting the seventh ore starts the two-second full warning and Leave glow")
	game.inventory_open = true
	game._physics_process(1)
	check(game.full_banner_time == 1 and game.leave_glow, "Warning uses real time while the paused Leave glow persists")
	game._physics_process(1.1)
	check(game.full_banner_time == 0 and game.leave_glow, "Warning disappears after two seconds without stopping the Leave glow")
	game.check_full_inventory()
	check(game.full_banner_time == 0, "A full bag does not retrigger the warning every frame")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.home_rect.get_center()
	game._input(click)
	game._physics_process(game.DEPARTURE_END + 0.01)
	check(game.mode == "depot" and not game.leave_glow, "Clicking Leave clears the persistent glow")

func test_lives() -> void:
	fresh()
	game.return_to_depot(false)
	game.buy_upgrade(6)
	check(game.max_lives() == 2 and game.credits == 98800, "First life upgrade adds one permanent life and costs 1200")
	game.start_run()
	check(game.lives == 2, "Each dive refills purchased lives")
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.enemies.clear()
	game.player = Vector2(200, 300)
	game.enemies.append({"pos": game.player, "vel": Vector2.ZERO, "type": 0, "dir": 1, "clock": 0.0, "ground": false, "anchor": 200.0})
	game.update_enemies(0, 0)
	check(game.mode == "playing" and game.lives == 1 and game.enemies.is_empty(), "Enemy contact removes the enemy and spends one life without ending the dive")
	check(game.hit_grace > 0, "Nonfatal contact provides brief protection against repeated same-frame hits")
	game.hit_grace = 0
	game.lose_life("Second hit")
	check(game.lives == 0 and game.mode == "dying", "Losing the final life starts the death sequence")
	fresh()
	game.upgrades.lives = 1
	game.lives = 2
	game.world.lava[Vector2i(6, 3)] = 1.0
	game.world.lava[Vector2i(5, 3)] = 1.0
	game.world.lava[Vector2i(10, 3)] = 1.0
	game.update_player(0.01)
	check(game.lives == 1 and game.mode == "playing" and game.world.lava.size() == 1 and game.world.lava.has(Vector2i(10, 3)), "Lava contact clears the touched connected puddle, spends one life, and preserves other puddles")
	fresh()
	game.lives = 2
	game.world.floor_spikes[Vector2i(6, 4)] = {"height": 10.0}
	game.update_player(0.01)
	check(game.lives == 1 and game.world.floor_spikes.is_empty() and game.world.blocks.has(Vector2i(6, 4)), "Spike contact removes the spikes while preserving their block and spending one life")
	fresh()
	game.lives = 2
	game.player.y = MineWorld.BOTTOM - 10
	game.spike_height = 40
	game.update_spikes(0.01)
	check(game.lives == 1 and game.spike_height == 0 and game.player.y < 650 and game.mode == "playing", "Bottom spikes are cleared and a surviving miner is rescued onto a safe floor")

func test_save() -> void:
	fresh()
	game.upgrades.capacity = 3
	game.upgrades.insurance = 4
	game.upgrades.depth = 2
	game.upgrades.speed = 2
	game.upgrades.freeze = 1
	game.upgrades.lives = 2
	game.selected_depth = 100
	game.selected_speed = 2
	game.pending_shortcuts.append("freeze")
	game.inventory[0] = 12
	game.credits = 1234
	game.test_mode = false
	game.save_progress()
	game.pending_shortcuts.clear()
	game.inventory.fill(0)
	game.credits = 0
	game.upgrades.speed = 0
	game.load_progress()
	check(game.credits == 1234 and game.capacity() == 10 and game.max_lives() == 3 and game.max_speed() == 3, "New progression and wallet persist across save/load")
	check(game.selected_depth == 100 and game.selected_speed == 2 and game.pending_shortcuts == ["freeze"], "Sliders and unconfirmed shortcut tutorial persist across save/load")
	check(game.inventory[0] == 12, "Existing ore is preserved even when the new bag capacity is smaller")
	game.test_mode = true
	game.mode = "playing"
	game.start_run()
	check(game.mode == "depot" and game.depot.has_popup(), "An unconfirmed saved shortcut returns to a blocking confirmation popup")
	game.depot.confirm_shortcut()
	game.start_run()
	check(game.mode == "playing" and game.lives == 3, "Confirming the recovered tutorial permits diving with refilled lives")
