extends SceneTree

const TEXTS := preload("res://scripts/progression_text.gd")
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

func event_key(key: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	event.shift_pressed = true
	game._input(event)

func lines_required(value: String, size: int, width: float) -> int:
	var lines := 1
	var line := ""
	for word in value.split(" "):
		var next := word if line.is_empty() else line + " " + word
		if MineInk.FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines += 1
			line = word
		else:
			line = next
	return lines

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check(game.discovered_materials.is_empty() and game.materials_sold.size() == 45, "Fresh game has an empty lifetime material journal")
	var required := {"power": [10, 40, 70], "capacity": [20, 50, 80], "insurance": [30, 60, 90], "speed": [0, 120, 210], "blocks": [60, 150, 240], "lives": [90, 180, 270], "depth": [10, 30, 60]}
	for key in required:
		var correct := true
		for level in range(3):
			correct = correct and MineCatalog.upgrade_required_depth(key, level) == required[key][level]
		check(correct, "Depth requirements scale for " + key)
	game.credits = 1000000
	for index in MineCatalog.SHOP_UPGRADES:
		var key: String = MineCatalog.UPGRADES[index].key
		var boundary := MineCatalog.upgrade_required_depth(key, 0)
		game.best_depth = boundary - 1
		game.upgrades[key] = 0
		var cash: int = game.credits
		game.buy_upgrade(index)
		check(game.upgrades[key] == 0 and game.credits == cash and not game.upgrade_is_unlocked(index), "Coins cannot bypass " + key + " milestone")
		game.best_depth = boundary
		game.buy_upgrade(index)
		check(game.upgrades[key] == 1 and game.credits < cash, "Reaching exact " + key + " milestone allows purchase")
	game.upgrades.depth = 1
	game.best_depth = 29
	var cash: int = game.credits
	game.buy_upgrade(0)
	check(game.upgrades.depth == 1 and game.credits == cash, "Second starting-depth upgrade waits for 30m")
	game.best_depth = 30
	game.buy_upgrade(0)
	check(game.selected_depth == 30 and game.upgrades.depth == 2, "Reached starting depth can be selected after purchase")
	check(game.depot.portrait_rect().size == game.depot.upgrade_rect(0).size and game.depot.portrait_rect().position.x < game.depot.upgrade_rect(0).position.x, "Current miner occupies the first shop card")
	game.discovered_materials.clear()
	game.materials_sold.fill(0)
	game.inventory.fill(0)
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.player = Vector2(240, 200)
	game.drops.clear()
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 8, "age": 0.0, "rotation": 0.0})
	game.update_drops(0, 0)
	check(game.inventory[8] == 1 and game.run_ores_found == 1 and game.discovered_materials == [8], "Actual pickup records a material")
	game.inventory[8] = 2
	game.inventory[0] = 1
	game.return_to_depot(false)
	cash = game.credits
	game.sell_ores()
	check(game.materials_sold[8] == 2 and game.materials_sold[0] == 1 and game.credits == cash + 123, "Selling records lifetime quantities and correct value")
	game.depot.finish_sale()
	game.sell_ores()
	check(game.materials_sold[8] == 2, "Skipping coin flights and selling an empty bag cannot double-count sales")
	game.start_run()
	game.inventory[9] = 1
	game.inventory_open = true
	game.discard_ore(9)
	check(9 in game.discovered_materials and game.materials_sold[9] == 0, "Discarded material remains discovered without counting as sold")
	check(game.next_material() == 1, "Next material is the earliest uncollected ore")
	game.inventory_open = false
	game.selected_depth = 30
	game.start_run()
	game.run_peak = 95
	game.run_best_before = 80
	game.best_depth = 95
	game.claimed_milestones.clear()
	for depth in range(10, 90, 10):
		game.claimed_milestones.append(depth)
	cash = game.credits
	game.finish_expedition(false)
	check(game.credits == cash + 45 and game.claimed_milestones.has(90), "New 90m milestone pays its one-time 45-coin reward")
	check(15 not in game.discovered_materials and game.discovered_materials.size() == 3, "Reaching depths does not fabricate inventory discoveries")
	check(game.results.map_from == 30 and game.results.map_to == 100 and game.results.depth_at(game.results.finish_time) == 95, "Depth meter spans starting depth to next milestone")
	check(game.results.report.best_depth == 95 and game.results.report.next_milestone.reward == 50, "Meter best and next milestone amount are accurate")
	var monotonic := true
	for depth in range(10, 1000, 10):
		monotonic = monotonic and MineCatalog.milestone_reward(depth + 10) > MineCatalog.milestone_reward(depth)
	check(monotonic and MineCatalog.milestone_reward(10) == 5, "Every depth milestone gives an increasing reward")
	game.continue_to_depot()
	game.start_run()
	game.run_peak = 95
	cash = game.credits
	game.finish_expedition(false)
	check(game.credits == cash, "Repeating depth cannot claim milestone money again")
	game.results.complete_reveal()
	game.cursor_position = game.results.material_rect(0).get_center()
	check(game.results.hovered_material() == game.discovered_materials[0], "Material hover resolves the corresponding journal entry")
	check(game.results.graphics_viewport.size == Vector2i(240, 400) and game.results.graphics_art.material.shader.resource_path == "res://shaders/crisp.gdshader", "Progression graphics use a native-resolution viewport and pixel shader")
	check(TEXTS.FLAVOR.size() == 150 and TEXTS.TIPS.size() == 50, "Exactly 150 flavor messages and 50 tips")
	var unique_flavor: Dictionary = {}
	var unique_tips: Dictionary = {}
	var fit := true
	for line in TEXTS.FLAVOR:
		unique_flavor[line] = true
		fit = fit and lines_required(line, 16, 408) <= 3
	for line in TEXTS.TIPS:
		unique_tips[line] = true
		fit = fit and lines_required(line, 12, 408) <= 2
	check(unique_flavor.size() == 150 and unique_tips.size() == 50 and fit, "All messages are unique and fit their assigned boxes")
	var flavor: String = game.results.report.flavor
	var title: String = game.results.report.hero_title
	game.results._process(0.1)
	check((flavor in TEXTS.FLAVOR or flavor in TEXTS.CONTEXT_FLAVOR.get(game.results.report.flavor_context, [])) and title in TEXTS.TITLES and game.results.report.flavor == flavor and game.results.report.hero_title == title, "Random flavor and motivational title are chosen once per report")
	var titles: Dictionary = {}
	for heading in TEXTS.TITLES:
		titles[heading] = true
	check(TEXTS.TITLES.size() == 100 and titles.size() == 100, "Exactly 100 unique motivational titles")
	check(game.results.report.ore_count == game.inventory_count() and game.results.report.haul_value == game.haul_value(), "Header reports actual carried ore count and total value")
	game.continue_to_depot()
	game.depot_seen_this_session = false
	game.speed_learned = false
	game.freeze_learned = false
	game.rounds_started = 100
	game.start_run()
	check(not game.shortcut_popup, "Returning player sees no startup reminder before a depot visit this session")
	game.return_to_depot(false)
	game.start_run()
	check(not game.shortcut_popup, "Depot visit does not create startup W reminders")
	game.speed_learned = true
	game.speed_learned_round = 0
	game.depot_seen_this_session = false
	game.start_run()
	check(not game.shortcut_popup, "Freeze reminder also respects the session depot gate")
	game.return_to_depot(false)
	game.start_run()
	check(not game.shortcut_popup, "Depot visit does not create startup freeze reminders")
	game.shortcut_popup = false
	cash = game.credits
	event_key(KEY_I)
	check(game.credits == cash, "Coin shortcut requires Z")
	event_key(KEY_Z)
	event_key(KEY_I)
	check(game.credits == cash + 1000000, "Shift Z I grants exactly one million coins")
	game.test_mode = false
	game.save_progress()
	game.discovered_materials.clear()
	game.materials_sold.fill(0)
	game.load_progress()
	game.test_mode = true
	check(game.discovered_materials.size() == 3 and game.materials_sold[8] == 2 and game.materials_sold[9] == 0, "Material journal and sold totals survive save/load")
	var clone = load("res://scenes/game.tscn").instantiate()
	root.add_child(clone)
	clone.set_physics_process(false)
	clone.synth.muted = true
	check(not clone.depot_seen_this_session and not clone.shortcut_popup and clone.discovered_materials.size() == 3, "A fresh opening loads collection but not the session depot flag")
	clone.queue_free()
	game.discovered_materials.clear()
	for ore in range(45):
		game.discover_material(ore, false)
	check(game.next_material() == -1 and game.results.material_rect(44).end.y < 464, "Completed collection fits all 45 icons and has no next material")
	print("Materials and milestones: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
