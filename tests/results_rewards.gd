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

func prepare(previous: int, peak: int) -> void:
	game.speed_learned = true
	game.freeze_learned = true
	game.inventory.fill(0)
	game.selected_depth = 0
	game.best_depth = previous
	game.start_run()
	game.set_physics_process(false)
	game.run_peak = peak
	game.claimed_milestones.clear()
	for depth in range(10, previous + 1, 10):
		game.claimed_milestones.append(depth)
	game.synth.muted = true

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.discover_material(1, false)
	prepare(100, 135)
	game.inventory[1] = 3
	game.inventory[8] = 1
	game.discover_material(8, false)
	game.run_ores_found = 4
	game.run_blocks_broken = 17
	var cash: int = game.credits
	game.finish_expedition(false)
	var results: Node = game.results
	check(results.report.new_materials == [8], "Only the first-ever inventory find is new")
	check(results.material_reveal_at(8) > results.material_reveal_at(1), "Old materials stay still while new specimens arrive")
	check(results.report.hero_title == "Your deepest expedition", "Depth record earns a specific title")
	check(results.report.flavor_context == "record" and results.report.flavor in MineProgressionText.CONTEXT_FLAVOR.record, "Record flavor matches the run")
	check(results.report.earned_milestones.size() == 3 and game.credits == cash + 180, "Three first-time milestones pay exactly once")
	check(results.displayed_bonus(0) == 0 and results.displayed_bonus(3) == 180, "Reward flights settle to the real milestone bonus")
	check(results.displayed_bonus(results.reward_beat_time(0) + 0.1) == 0 and results.displayed_bonus(results.reward_beat_time(0) + 0.23) == 55, "Bonus counter waits for the reward flight to land")
	check(results.stat_count(60, 1.3, 0.8, 1.3) == 0 and results.stat_count(60, 1.3, 0.8, 1.7) == 30 and results.stat_count(60, 1.3, 0.8, 2.1) == 60, "Count-up starts at zero, passes intermediate value, ends exactly")
	check(results.finish_time == 3.0 and results.record_at > 0 and results.record_at < results.map_finish, "Record crossing and entire sequence finish within three seconds")
	check(absf(results.depth_at(results.record_at) - 100) < 0.1, "Record celebration occurs at the actual old-best crossing")
	check(results.SUMMARY_SIZE == 22, "Value and milestone use the same smaller type size")
	var carried: Array = game.inventory.duplicate()
	cash = game.credits
	game.synth.muted = false
	results._process(0.8)
	check(results.heard_materials.has(8) and not results.heard_materials.has(1), "New material receives one discovery sound")
	results._process(0.7)
	check(results.last_tick >= 0, "Value count-up emits quiet ticks")
	results._process(0.65)
	check(results.value_landed, "Value ends with a landing chime")
	results.complete_reveal()
	var voices: int = game.synth.voice_index
	results._process(0.1)
	check(game.synth.voice_index == voices, "Skipping suppresses every outstanding reward and goal sound")
	check(game.inventory == carried and game.credits == cash, "Celebrations never sell ore or pay bonuses a second time")
	prepare(135, 100)
	game.inventory[1] = 2
	game.inventory[8] = 1
	game.finish_expedition(false)
	check(results.report.new_materials.is_empty() and results.report.earned_milestones.is_empty(), "Repeat finds and repeat depths receive no new tags or payouts")
	prepare(135, 100)
	game.inventory[1] = 7
	game.best_haul = 0
	game.finish_expedition(false)
	check(results.report.hero_title == "Your richest haul" and game.best_haul == game.haul_value(), "Personal-best retained value receives a richest-haul title")
	prepare(135, 100)
	game.inventory[9] = 1
	game.discover_material(9, false)
	game.finish_expedition(false)
	check(results.report.hero_title == "1 new material", "First material collection gets a truthful title")
	prepare(135, 100)
	game.inventory[1] = 1
	game.death_lost = 5
	game.finish_expedition(true)
	check(results.report.from_death and results.report.ore_count == 1 and results.report.ores_lost == 5 and results.report.haul_value == 5, "Death separates retained sale value and lost ores")
	check(results.report.flavor_context == "death", "Death draws from its own supportive flavor pool")
	prepare(135, 100)
	game.finish_expedition(false)
	check(results.report.flavor_context == "empty" and results.report.hero_title in MineProgressionText.TITLES, "Ordinary empty run retains motivational title and tailored flavor")
	prepare(135, 100)
	game.inventory[1] = 1
	game.upgrades.lives = 1
	game.lives = 1
	game.finish_expedition(false)
	check(results.report.flavor_context == "escape", "Returning on last life gets narrow-escape flavor")
	prepare(135, 100)
	game.run_treasure_count = 1
	game.finish_expedition(false)
	check(results.report.flavor_context == "treasure", "Treasure finds have their own flavor")
	prepare(0, 1000)
	game.finish_expedition(false)
	check(results.reward_beats.size() == 5 and results.displayed_bonus(3) == 25250, "Long runs group payouts into five beats without losing a coin")
	check(results.depth_at(3) == 1000 and results.finish_time == 3, "A large number of discoveries cannot lengthen the sequence")
	prepare(100, 50)
	game.credits = 15
	game.run_credits_before = 15
	game.inventory[1] = 2
	game.tracked_upgrade = "capacity"
	game.finish_expedition(false)
	check("Inventory Size" in results.report.affordable_upgrades, "Retained earnings identify newly affordable purchases")
	prepare(95, 97)
	game.finish_expedition(false)
	results.complete_reveal()
	var state: Dictionary = results.milestone_state()
	check(state.goal == 100 and state.depth == 97 and state.remaining == 3, "Milestone footer pairs actual best depth with remaining meters")
	check(is_equal_approx(state.old_progress, 0.5) and is_equal_approx(state.progress, 0.7), "Progress bar separates previous five meters from two new meters")
	prepare(97, 50)
	game.finish_expedition(false)
	results.complete_reveal()
	state = results.milestone_state()
	check(is_equal_approx(state.old_progress, state.progress) and state.run_depth == 50 and state.remaining == 50, "A shorter run preserves the bar but reports this run's depth and remaining meters")
	prepare(95, 105)
	game.finish_expedition(false)
	results.age = results.reward_beat_time(0) + 0.01
	state = results.milestone_state()
	check(state.complete and state.remaining == 0 and state.goal == 100, "Earned milestone stamps complete before switching to the next goal")
	results.complete_reveal()
	state = results.milestone_state()
	check(not state.complete and state.goal == 110 and results.displayed_bonus() == 50, "Upcoming reward and paid bonus remain separate after celebration")
	prepare(95, 50)
	game.player.y = MineWorld.START_Y + 12 * MineWorld.TILE
	game.die("Test collision")
	game.player.y = -1000
	game.finish_expedition(true)
	results.complete_reveal()
	state = results.milestone_state()
	check(state.run_depth == 12 and state.remaining == 88, "Death footer uses collision depth before the death arc, rather than best or peak depth")
	game.test_mode = false
	game.best_haul = 987
	game.save_progress()
	game.best_haul = 0
	game.load_progress()
	game.test_mode = true
	check(game.best_haul == 987, "Richest-haul record persists between openings")
	print("Results rewards: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
