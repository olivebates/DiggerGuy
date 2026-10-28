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
	game.inventory.fill(0)
	game.selected_depth = 0
	game.start_run()
	game.synth.muted = true
	game.set_physics_process(false)
	game.world.spawn_queue.clear()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.enemies.clear()

func report_run(previous: int, peak: int, cash: int, copper: int, goal: String = "power") -> void:
	fresh()
	game.credits = cash
	game.run_credits_before = cash
	game.run_haul_before = 0
	game.run_best_before = previous
	game.best_depth = previous
	game.run_peak = peak
	game.claimed_milestones.clear()
	for depth in range(10, previous + 1, 10):
		game.claimed_milestones.append(depth)
	game.inventory[1] = copper
	game.tracked_upgrade = goal
	game.finish_expedition(false)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	report_run(0, 100, 120, 9)
	var results: Node = game.results
	check(results.report.hero_kind == "record" and results.report.hero_title == "Your deepest expedition", "A new depth record is the featured achievement")
	check(results.depth_at(0) == 0 and results.depth_at(results.finish_time) == 100, "Depth map travels from previous record to new depth")
	var kinds: Dictionary = {}
	var ordered := true
	var last_depth := -1
	for event in results.events:
		kinds[event.kind] = true
		ordered = ordered and event.depth >= last_depth
		last_depth = event.depth
		check(absf(results.depth_at(event.reveal_at) - float(event.depth)) < 0.01, "Map reaches " + str(event.name))
	check(ordered and kinds.size() == 3, "Ordered discoveries include ores, wildlife, and cave milestones")
	var emerald: Dictionary = results.events[0]
	check(emerald.name == "Emerald" and "60 coins" in emerald.detail, "Ore reveal includes its specimen and unit value")
	check("Flutters" in MineCatalog.discovery_events(79, 80)[0].detail, "Animal reveal explains its behavior")
	check(results.animated_funds(0) == 120 and results.animated_funds(results.FUNDS_START + results.HAUL_DURATION) == 165, "Haul visibly adds to the pre-run amount")
	check(results.animated_funds(results.finish_time) == 440 and results.report.bonus_earned == 275, "Milestone bonus follows haul and settles at exact total")
	var midway: int = results.animated_funds(results.FUNDS_START + results.HAUL_DURATION / 2)
	check(midway > 120 and midway < 165 and results.animated_funds(results.finish_time) == results.report.funds_after, "Bar has intermediate values and an exact remaining amount")
	var credits: int = game.credits
	var inventory: Array = game.inventory.duplicate()
	results._process(0.1)
	check(game.credits == credits and game.inventory == inventory, "Presentation never spends or prematurely sells real inventory")
	results.age = 0.15
	check(results.visible_character_count("abcdefghij", 0) == 5 and results.STEP == 0.2, "Normal letters reveal at 0.03 seconds while panels retain 0.2-second staggering")
	check(results.visible_character_count("abcdefghij", 0, true) < 5, "Major discovery text gets a slower deliberate reveal")
	results.age = 0
	game.synth.muted = false
	var voices: int = game.synth.voice_index
	results._process(emerald.reveal_at + 0.001)
	check(not results.heard_materials.has(8), "Unlocking an uncollected ore does not play a material discovery chime")
	results._process(0.1)
	check(not results.heard_materials.has(8), "Uncollected ore remains absent from collection celebrations")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(240, 752)
	results._input(click)
	check(game.mode == "results" and results.is_revealed(), "First click completes all reveals without continuing")
	voices = game.synth.voice_index
	results._process(0.1)
	check(game.synth.voice_index == voices, "Finishing reveal does not play a backlog of discovery sounds")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(300, 200)
	results._input(wheel)
	check(game.discovered_materials.size() == 1 and game.discovered_materials[0] == 1, "Journal contains only the material carried this run")
	results._input(click)
	check(game.mode == "depot" and not results.visible, "Second click on Continue opens depot")
	report_run(100, 50, 15, 2, "capacity")
	check(results.report.hero_kind == "upgrade" and "Inventory Size" in results.report.hero_detail, "Newly affordable upgrade gets prominence when there is no record")
	check(results.events.is_empty() and results.report.fallback.context == "BEST FIND", "Ordinary runs still display a tangible retained find")
	game.synth.muted = false
	voices = game.synth.voice_index
	results._process(results.VALUE_START + 0.4)
	check(results.last_tick >= 0, "Value count-up plays quiet ticks")
	results._process(results.VALUE_END - results.age + 0.01)
	check(results.value_landed, "Value count-up lands with its final chime")
	report_run(100, 50, 0, 0)
	check(results.report.hero_kind == "progress" and results.report.hero_title in MineProgressionText.TITLES, "Empty runs show truthful neutral feedback")
	check(results.report.fallback.context == "NEXT DISCOVERY", "Empty inventory shows the next discovery instead of a fabricated find")
	fresh()
	game.run_best_before = 100
	game.best_depth = 100
	game.run_peak = 50
	game.run_first_treasure = true
	game.finish_expedition(false)
	check(results.report.hero_kind == "treasure", "First treasure room can be the featured achievement")
	report_run(99, 130, 0, 0)
	check(results.depth_at(0) == 0 and results.depth_at(results.finish_time) == 130 and results.map_to == 140, "Record map spans starting depth to the next milestone")
	fresh()
	game.credits = 1000
	var before: Dictionary = game.upgrades.duplicate()
	game.buy_upgrade(1)
	check(game.depot.purchase_before == before and game.depot.purchase_after.power == before.power + 1, "Successful purchase captures exact before-and-after equipment")
	check(game.depot.purchase_compare_time == 2.5 and "damage" in MineCatalog.upgrade_benefit("power", before.power), "Purchase confirmation pairs equipment changes with practical benefit")
	var actual_level: int = game.upgrades.power
	game.finish_expedition(false)
	check(game.upgrades.power == actual_level and results.report.equipment_after.power == actual_level + 1, "Next-equipment preview never purchases or mutates actual upgrades")
	fresh()
	game.run_best_before = 100
	game.best_depth = 100
	game.run_peak = 50
	game.credits = 0
	game.run_credits_before = 0
	game.run_haul_before = 30
	game.inventory[0] = 1
	game.finish_expedition(true)
	check(results.animated_funds(0) == 30 and results.animated_funds(results.finish_time) == 3, "Losing carried ore animates a decrease rather than inventing earnings")
	game.test_mode = false
	game.treasure_seen = true
	game.save_progress()
	game.treasure_seen = false
	game.load_progress()
	game.test_mode = true
	check(game.treasure_seen, "First-treasure celebration is remembered across saves")
	print("Results satisfaction: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
