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

func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	game._input(event)

func fresh() -> void:
	game.speed_learned = true
	game.freeze_learned = true
	game.inventory.fill(0)
	game.selected_depth = 0
	game.best_depth = 0
	game.upgrades.lives = 0
	game.start_run()
	game.set_physics_process(false)
	game.synth.muted = true
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for x in range(15):
		game.world.blocks[Vector2i(x, 4)] = {"hp": 1, "max_hp": 1, "ore": -1, "variant": 0}
	game.player = Vector2(240, game.world.cell_position(Vector2i(7, 4)).y - 16)
	game.grounded = true

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	fresh()
	var before: Vector2 = game.player
	game.simulate_step(0.1)
	check(game.world.scroll == 0 and game.player.x > before.x, "Miner walks while the terrain waits for the first broken block")
	game.mining_needs_release = false
	game.mine_at(game.world.cell_position(Vector2i(3, 4)) + Vector2(16, 16))
	check(game.run_blocks_broken >= 1, "Breaking real blocks releases the initial rise gate")
	game.simulate_step(0.2)
	check(game.world.scroll > 0, "Terrain starts rising after the first block breaks")
	game.start_run()
	game.set_physics_process(false)
	var cell := Vector2i(3, -1)
	var target: Vector2 = game.world.cell_position(cell) + Vector2(16, 16)
	check(game.can_place_block(target) and game.place_block(target), "Blocks can be placed in the starting air above the ground")
	game.update_terrain_cache()
	check(game.terrain_rows.has(-1) and game.world.blocks.has(cell), "Above-ground placements have visible cached terrain rows")
	check(game.run_blocks_broken == 0 and game.world.scroll == 0, "Placing a block alone does not start the mine rising")
	fresh()
	game.player.y = MineWorld.TOP + 7 * MineWorld.TILE + 1
	game._physics_process(0.25)
	check(game.overlay_alpha == 0, "Depth and block overlays fade out below the seventh visible row")
	game.player.y = 200
	game._physics_process(0.25)
	check(game.overlay_alpha == 1, "Overlays return when the player moves above the threshold")
	fresh()
	game.speed_learned = false
	game.world.blocks[Vector2i(4, 3)] = {"hp": 2, "ore": -1}
	game.world.blocks[Vector2i(10, 3)] = {"hp": 2, "ore": -1}
	check(game.enclosed_walkway(), "Continuous floor with actual walls on both sides is a trapped walkway")
	before = game.player
	game.update_player(0.016)
	check(game.tutorial_prompt == "speed" and game.player == before, "First trapped walkway pauses for the W lesson")
	game._physics_process(0.5)
	check(game.player == before and game.world.scroll == 0, "W lesson holds the simulation still")
	key(KEY_SPACE)
	check(game.tutorial_prompt == "speed", "Other keys cannot dismiss the W lesson")
	key(KEY_W)
	check(game.tutorial_prompt.is_empty() and game.speed_learned and game.speed_held, "W acknowledges the lesson and activates speedup")
	key(KEY_W, false)
	game.world.blocks.erase(Vector2i(4, 3))
	check(not game.enclosed_walkway(), "An open side is not considered an enclosed walkway")
	fresh()
	game.freeze_learned = false
	game.world.lava[Vector2i(8, 3)] = 1.0
	check(game.approaching_hazard(), "Look-ahead detects a lava collision before contact")
	game.update_player(0.016)
	check(game.tutorial_prompt == "freeze", "First approaching hazard pauses for the Space lesson")
	key(KEY_W)
	check(game.tutorial_prompt == "freeze", "W cannot dismiss the freeze lesson")
	key(KEY_SPACE)
	check(game.tutorial_prompt.is_empty() and game.freeze_learned and game.is_frozen(), "Space acknowledges the lesson and freezes time")
	key(KEY_SPACE, false)
	check(not game.is_frozen(), "Releasing Space resumes after learning")
	game.speed_learned = false
	game.freeze_learned = false
	game.depot_seen_this_session = true
	game.rounds_started = 100
	game.start_run()
	game.set_physics_process(false)
	check(not game.shortcut_popup and game.pending_shortcuts.is_empty(), "No round-start W or Space popup remains")
	fresh()
	game.player.y = MineWorld.TOP + 60
	game.update_spikes(0.1)
	check(game.top_spike_height > 0 and game.mode == "playing", "Top spikes emerge as the miner approaches")
	game.player.y = 450
	game.update_spikes(1)
	check(game.top_spike_height == 0, "Top spikes retract when the miner moves away")
	game.player.y = MineWorld.TOP + 18
	game.update_spikes(1)
	check(game.mode == "dying" and "top spikes" in game.death_reason and game.top_spike_height > 0, "Top spikes are a real hazard and remain on a fatal collision")
	fresh()
	game.synth.muted = false
	var voices: int = game.synth.voice_index
	game.begin_departure()
	game._physics_process(game.DEPARTURE_END + 0.01)
	check(is_equal_approx(game.DEPARTURE_END, 1.915) and game.mode == "results", "Extraction lasts exactly half its previous duration")
	check(game.synth.voice_index == voices, "Extraction has no floating or circle sound")
	fresh()
	game.inventory[1] = 10
	game.run_ores_found = 10
	game.die("Test death")
	var closed_at: float = game.death_transition_start() + game.DEATH_IRIS_DURATION + game.DEATH_IRIS_HOLD + game.DEATH_FINAL_CLOSE
	game.advance_death(closed_at + 0.1)
	check(game.death_iris_progress() == 1 and game.mode == "dying", "Closed death iris holds a screen for the lost-ore message")
	game.advance_death(game.DEATH_BLACK_HOLD)
	check(game.mode == "results" and game.results.report.ore_count == 3 and game.results.report.ores_lost == 7, "Death report separates retained ores from the lost amount")
	fresh()
	game.claimed_milestones.clear()
	game.run_peak = 12
	game.finish_expedition(false)
	var results: Node = game.results
	results.age = results.VALUE_END
	check(results.milestone_state().progress == results.milestone_state().old_progress, "Milestone bar waits through the value count-up")
	check(is_equal_approx(results.value_scale(results.VALUE_END), 1) and results.value_scale(results.VALUE_END + 0.15) > 1 and is_equal_approx(results.value_scale(results.REWARD_START), 1), "Value grows and shrinks before milestone animation starts")
	results.age = results.REWARD_START - 0.01
	check(results.milestone_state().progress == results.milestone_state().old_progress, "Milestone bar also waits for the final value bounce")
	game.synth.muted = false
	results.complete_reveal()
	results.show_report(results.report)
	results._process(results.REWARD_START)
	voices = game.synth.voice_index
	results._process(results.reward_beat_time(0) - results.age + 0.01)
	check(results.heard_rewards.has(0) and game.synth.voice_index > voices, "Milestone celebration triggers its reward sound with the confetti beat")
	results.complete_reveal()
	voices = game.synth.voice_index
	results._process(0.1)
	check(game.synth.voice_index == voices, "Skipping celebrations does not play queued sounds afterward")
	print("Run HUD and tutorials: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
