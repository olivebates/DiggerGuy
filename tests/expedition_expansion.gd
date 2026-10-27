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
	game.selected_depth = 0
	game.inventory.fill(0)
	game.start_run()
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	game.placement_taught = true

func debug_event(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.shift_pressed = true
	game._input(event)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check(game.inventory.size() == 45 and MineCatalog.ORES.size() == 45, "Forty-five ore types and matching inventory slots")
	check(MineCatalog.ENEMIES.size() == 40, "Forty animal enemies")
	check(game.max_speed() == 2 and game.selected_speed == 2, "Default speed is x2")
	check(4 not in MineCatalog.SHOP_UPGRADES and MineCatalog.SHOP_UPGRADES.size() == 7, "Freeze is removed from the shop")
	var ore_names: Dictionary = {}
	var animal_names: Dictionary = {}
	for ore in MineCatalog.ORES:
		ore_names[ore.name] = true
	for animal in MineCatalog.ENEMIES:
		animal_names[animal.name] = true
	check(ore_names.size() == 45 and animal_names.size() == 40, "All new ores and animals have unique names")
	check(MineCatalog.ORES[8].name == "Emerald" and MineCatalog.ORES[9].name == "Ruby", "Original ore IDs remain stable for saves")
	check(MineCatalog.ORES[14].depth == 5200 and MineCatalog.ORES[4].depth == 400, "Later original ores move deeper")
	var depth_rules := true
	var world := MineWorld.new()
	world.rng.seed = 98
	for depth in [0, 60, 70, 100, 300, 2000, 4000, 6000]:
		for sample in range(300):
			var ore := world.choose_ore(depth)
			depth_rules = depth_rules and MineCatalog.ORES[ore].depth <= depth and ore != 8
	check(depth_rules, "Expanded normal ore pool respects unlock depths")
	var caches := 0
	var vaults := 0
	var garden := false
	var prism := false
	var new_species: Dictionary = {}
	for seed_value in range(1, 51):
		world.reset(3000, seed_value)
		for room in world.rooms:
			vaults += int(room.kind == "treasure")
		for block in world.blocks.values():
			caches += int(block.get("treasure", false))
		for prop in world.decorations:
			prism = prism or prop.kind == "prism"
		world.reset(110, seed_value)
		for prop in world.decorations:
			garden = garden or prop.kind == "garden"
		world.reset(6500, seed_value)
		for spawn in world.spawn_queue:
			if spawn.type >= 10:
				new_species[spawn.type] = true
	check(caches > 0 and vaults > 0, "Occasional treasure rooms contain mineable caches")
	check(garden and prism, "Depth milestones add visibly distinct cave features")
	check(new_species.size() >= 25, "Most new species spawn across deep seeded worlds")
	fresh()
	game.credits = 0
	game.claimed_milestones.clear()
	game.best_depth = 0
	game.run_best_before = 0
	game.run_credits_before = 0
	game.run_peak = 100
	game.inventory[0] = 1
	game.finish_expedition(false)
	check(game.mode == "results" and game.results.visible and not game.depot.visible, "Results precede depot")
	check(game.results.report.title == "NEW DEEPEST RUN!" and game.best_depth == 100, "New record is visible and retained")
	check(game.credits == 20 and game.inventory[0] == 1, "Milestone bonus awards once without prematurely selling haul")
	check("Haul: 3 coins" in game.results.report.stats and "Bonus: 20 coins" in game.results.report.stats, "Results distinguish haul value and awarded bonus")
	check("130 m" in game.results.report.next_goal and "Silver" in game.results.report.next_goal, "Results show the next discovery goal")
	check(game.results.report.upgrade_progress == 1.0 and "Inventory Size" in game.results.report.affordable, "Chosen-upgrade progress includes retained haul and new affordability")
	game.finish_expedition(false)
	check(game.credits == 20, "Results cannot award milestones twice")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(240, 752)
	game.results.age = 0
	game.results._input(click)
	check(game.mode == "results" and game.results.STEP == 0.2 and game.results.is_revealed(), "First click finishes staggered reveals without leaving results")
	game.results.age = game.results.finish_time + 1
	game.results._input(click)
	check(game.mode == "depot" and not game.results.visible and game.depot.visible, "Single Continue button opens depot")
	game.start_run()
	game.run_peak = 100
	game.finish_expedition(false)
	check(game.credits == 20 and game.results.report.title == "EXPEDITION COMPLETE", "Repeating a milestone gives no duplicate reward or new record")
	fresh()
	game.credits = 0
	game.buy_upgrade(1)
	check(game.tracked_upgrade == "power" and game.upgrades.power == 0, "Clicking unaffordable upgrade tracks it without charging")
	fresh()
	game.begin_departure()
	game._physics_process(game.DEPARTURE_END + 0.01)
	check(game.mode == "results", "Voluntary extraction opens results")
	fresh()
	game.die("test")
	game.advance_death(game.death_duration() + 0.01)
	check(game.mode == "results" and game.results_from_death, "Fatal death opens results")
	fresh()
	game.inventory.fill(1)
	game.inventory_scroll = 30
	var visible: Array[int] = game.satchel_ores()
	check(visible.size() == 15, "Large satchel scrolls through fifteen visible rows")
	game.inventory_open = true
	var ore: int = visible[0]
	click.position = game.discard_rect(0).get_center()
	game._input(click)
	check(game.inventory[ore] == 0 and game.inventory_count() == 44, "Scrolled trash button removes the correct ore")
	fresh()
	var cache := Vector2i(6, 4)
	game.world.blocks[cache] = {"hp": 1, "max_hp": 2, "ore": -1, "variant": 0, "treasure": true, "treasure_coins": 40}
	game.mining_needs_release = false
	var credits: int = game.credits
	game.mine_at(game.world.cell_position(cache) + Vector2(16, 16))
	check(game.credits == credits + 40 and not game.world.blocks.has(cache), "Mining treasure awards its cache coins")
	fresh()
	var original_depth: int = game.current_depth()
	debug_event(KEY_O)
	check(game.current_depth() == original_depth, "Depth shortcut requires Z")
	debug_event(KEY_Z)
	debug_event(KEY_O)
	check(game.current_depth() == original_depth + 10, "Shift Z O adds ten depth")
	debug_event(KEY_L)
	check(game.current_depth() == original_depth, "Shift Z L subtracts ten depth")
	debug_event(KEY_L)
	check(game.selected_depth == 0, "Depth shortcut clamps at zero")
	game.credits = 999
	game.upgrades.power = 3
	debug_event(KEY_M)
	check(game.credits == 0 and game.upgrades.power == 0 and game.rounds_started == 1 and game.mode == "playing" and game.inventory_count() == 0, "Shift Z M resets progress and starts from the beginning")
	check(game.selected_speed == 2 and game.upgrades.freeze == 1 and game.claimed_milestones.is_empty(), "Reset restores free abilities and clears milestones")
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	check('if OS.has_feature("web") or not event is InputEventKey:' in source and 'if OS.has_feature("web"):' in source, "Both debug dispatch and destructive reset are guarded on web")
	game.test_mode = false
	var legacy := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 6, "credits": 123, "inventory": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "speed": 3, "best": 500, "upgrades": {"capacity": 2}}))
	legacy.close()
	game.load_progress()
	game.test_mode = true
	check(game.inventory.size() == 45 and game.inventory[8] == 9 and game.inventory[14] == 15 and game.inventory[44] == 0, "Legacy fifteen-ore save migrates without moving items")
	check(game.selected_speed == 2 and game.claimed_milestones.has(300), "Legacy speed migrates to x2 and old milestones are not rewarded again")
	game.tracked_upgrade = "blocks"
	game.test_mode = false
	game.save_progress()
	game.tracked_upgrade = "capacity"
	game.claimed_milestones.clear()
	game.load_progress()
	game.test_mode = true
	check(game.tracked_upgrade == "blocks" and game.claimed_milestones.has(300), "Tracked goal and milestone claims persist")
	print("Expedition expansion: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
