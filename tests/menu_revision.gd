extends SceneTree

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

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.inventory.fill(0)
	game.inventory[0] = 2
	game.return_to_depot(false)
	var depot: Node = game.depot
	var reserved: Array = [depot.primary_rect, depot.nav_rect(), depot.dive_rect]
	check(reserved[0].end.y < reserved[1].position.y and reserved[1].end.y < reserved[2].position.y, "Sell, navigation, and dive slots have the requested order")
	depot.open_shop()
	check(depot.previous_screen == "depot" and depot.content_offset() == 480, "Shop starts fully outside the right edge while retaining the outgoing depot")
	depot._process(0.2)
	check(depot.content_offset() > 0 and depot.content_offset() < 480, "Incoming and outgoing pages share the slide duration")
	depot._process(0.2)
	check(reserved == [depot.primary_rect, depot.nav_rect(), depot.dive_rect], "Both menus reserve identical action positions")
	depot.change_screen("depot")
	check(depot.content_offset() == -480 and depot.previous_screen == "shop", "Returning depot starts fully outside the opposite edge")
	depot._process(0.4)
	game.inventory[1] = 1
	depot.show_depot()
	depot._process(0.15)
	check(depot.row_characters(0) > 0 and depot.row_characters(1) == 0, "Only the first ore is typing before 0.2 seconds")
	depot._process(0.1)
	check(depot.row_characters(1) > 0 and depot.row_scale(0) == 1, "Second row starts typing without scale animation")
	check(depot.ore_rect(0).size.y <= 42, "Haul rows stay compact and top aligned")
	for index in [0, 1, 2, 3, 6, 7]:
		var upgrade: Dictionary = MineCatalog.UPGRADES[index]
		check(upgrade.max == -1, "Upgrade %s has no level cap" % upgrade.key)
		game.upgrades[upgrade.key] = 23 if upgrade.key in ["depth", "lives"] else 101
		game.credits = MineCatalog.price(index, game.upgrades[upgrade.key])
		var level: int = game.upgrades[upgrade.key]
		game.buy_upgrade(index)
		check(game.upgrades[upgrade.key] == level + 1 and game.credits == 0, "Purchase succeeds beyond former cap for %s" % upgrade.key)
	game.pending_shortcuts.clear()
	game.selected_depth = 0
	game.start_run()
	game.blocks_left = 0
	game.place_block(Vector2(100, 300))
	check(game.block_counter_pulse == 0.5, "Empty placement starts a half-second counter pulse")
	game.inventory_open = true
	game._physics_process(0.25)
	check(is_equal_approx(game.block_counter_pulse, 0.25), "Counter pulse uses real time even while inventory pauses gameplay")
	game.inventory_open = false
	var scroll: float = game.world.scroll
	var original: Vector2 = game.player
	var haul: Array = game.inventory.duplicate()
	game.begin_departure()
	game._physics_process(0.5)
	check(game.mode == "leaving" and game.player == original and game.world.scroll == scroll, "Departure freezes simulation while the beam descends for 0.5 seconds")
	game._physics_process(0.7)
	check(game.player == original, "Miner waits 0.7 seconds after the beam arrives")
	game._physics_process(1)
	check(game.player.y < original.y and game.player_lean < 0 and game.world.scroll == scroll, "Miner floats and rotates while terrain stays frozen")
	game._physics_process(1)
	check(is_equal_approx(game.player.y, original.y - 48), "Lift takes two seconds before the iris starts")
	game._physics_process(game.DEPARTURE_CLOSE + 0.09)
	check(game.mode == "depot" and game.inventory == haul and depot.entrance_time > 0, "Departure closes the iris and opens the depot without losing ore")
	check(game.player_viewport.size == Vector2i(64, 64) and game.player_viewport.msaa_2d == Viewport.MSAA_DISABLED, "Rotated miner uses a low-resolution non-antialiased raster")
	check(MineInk.FONT.resource_path == "res://PixelifySans.ttf", "UI uses the supplied Pixelify Sans font")
	print("Menu revision: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
