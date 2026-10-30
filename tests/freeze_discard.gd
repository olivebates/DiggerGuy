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

func confirm() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(240, 432)
	game._input(event)

func fresh() -> void:
	game.speed_learned = true
	game.freeze_learned = true
	game.inventory.fill(0)
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check(game.upgrades.freeze == 1, "Freeze is owned from first round")
	game.space_held = true
	var position: Vector2 = game.player
	game._physics_process(0.1)
	check(game.is_frozen() and game.player == position, "Free Freeze pauses simulation")
	game.space_held = false
	game.speed_learned = true
	game.speed_learned_round = game.rounds_started
	game.return_to_depot(false)
	game.start_run()
	check(not game.shortcut_popup, "First round after learning W has no freeze reminder")
	game.start_run()
	check(not game.shortcut_popup, "Freeze is taught by a hazard rather than a startup reminder")
	confirm()
	game.start_run()
	check(not game.shortcut_popup, "Unlearned freeze does not create a startup dialog")
	confirm()
	game.frozen_toggle = true
	game._physics_process(1.5)
	check(not game.freeze_learned, "Freeze learning requires more than 1.5 seconds")
	game._physics_process(0.01)
	check(game.freeze_learned, "Freeze use learns reminder permanently")
	game.start_run()
	check(not game.shortcut_popup, "Learned Freeze stops future reminders")
	var learned_round: int = game.speed_learned_round
	game.test_mode = false
	game.save_progress()
	game.freeze_learned = false
	game.speed_learned_round = -1
	game.upgrades.freeze = 0
	game.load_progress()
	game.test_mode = true
	check(game.freeze_learned and game.speed_learned_round == learned_round and game.upgrades.freeze == 1, "Freeze learning and tutorial schedule survive save and reload")
	game.freeze_learned = false
	game.speed_learned = false
	game.rounds_started = 0
	game.start_run()
	game.frozen_toggle = true
	game._physics_process(1.51)
	game.speed_learned = true
	game.speed_learned_round = game.rounds_started
	game.return_to_depot(false)
	game.start_run()
	game.start_run()
	check(not game.shortcut_popup, "Using freeze before tutorial becomes due suppresses it")
	check(MineCatalog.price(2, 0) == 20 and MineCatalog.price(2, 1) == 25, "Capacity starts at twenty coins and retains price scaling")
	check(MineWorld.block_health(0) == 2 and MineWorld.block_health(99) == 2, "Base blocks require two hits below 100m")
	var boundaries := true
	for increase in range(1, 16):
		boundaries = boundaries and MineWorld.block_health(increase * 100 - 1) == increase + 1 and MineWorld.block_health(increase * 100) == increase + 2
	check(boundaries, "All first fifteen health increases occur at exact 100m boundaries")
	var world := MineWorld.new()
	world.reset(95, 1288)
	var generated := true
	for cell in world.blocks:
		generated = generated and world.blocks[cell].hp == MineWorld.block_health(95 + cell.y)
	check(generated, "Generated health uses individual absolute block depth")
	fresh()
	game.world.base_depth = 200
	game.player = Vector2(32, 180)
	var cell := Vector2i(6, 4)
	game.place_block(game.world.cell_position(cell) + Vector2(16, 16))
	check(game.world.blocks[cell].hp == 4, "Placed blocks also use depth health")
	game.world.hit(cell, 2)
	check(game.world.blocks[cell].hp == 2 and game.world.blocks[cell].max_hp == 4, "Mining power reduces depth health correctly")
	check(MineCatalog.ORES[9].value == 70 and MineCatalog.ORES[9].depth == 70, "Rubies unlock at 70m and sell for seventy coins")
	var ruby_seen := false
	var ruby_early := false
	for sample in range(1000):
		ruby_seen = ruby_seen or world.choose_ore(70) == 9
		ruby_early = ruby_early or world.choose_ore(69) == 9
	check(ruby_seen and not ruby_early, "Ruby rolls respect the seventy-metre threshold")
	fresh()
	game.inventory_open = true
	game.inventory[0] = game.capacity()
	game._physics_process(4.9)
	check(game.home_button_rect() == game.home_rect, "Full bag does not shake home before five seconds")
	game._physics_process(0.18)
	check(game.home_button_rect() != game.home_rect, "Home starts shaking after five seconds")
	game._physics_process(1.0)
	check(game.home_button_rect() == game.home_rect, "Home rests between reminder shakes")
	game._physics_process(1.0)
	check(game.home_button_rect() != game.home_rect, "Reminder shake repeats every two seconds")
	game.synth.muted = false
	var voices: int = game.synth.voice_index
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.discard_rect(0).get_center()
	game._input(click)
	check(game.inventory[0] == 6 and game.inventory_open, "Trash click removes exactly one ore and keeps satchel open")
	check(game.full_bag_time == 0 and game.home_button_rect() == game.home_rect and not game.leave_glow, "Discard stops home shaking and blinking")
	check(game.synth.voice_index == voices + 1 and game.synth.voices[voices % 8].stream == game.synth.sounds.discard, "Discard plays its new sound once")
	game.inventory[0] = 1
	game._input(click)
	check(game.visible_ores().is_empty() and not game.discard_ore(0), "Discarding last ore removes row and cannot remove below zero")
	fresh()
	game.begin_departure()
	voices = game.synth.voice_index
	game._physics_process(game.DEPARTURE_BEAM + game.DEPARTURE_WAIT - 0.01)
	check(game.synth.voice_index == voices, "Float sound waits for upward movement")
	game._physics_process(0.02)
	game._physics_process(0.02)
	check(game.synth.voice_index == voices, "Floating on extraction is silent")
	for extra_lives in [0, 1]:
		fresh()
		game.lives = 1 + extra_lives
		game.enemies.append({"pos": game.player, "vel": Vector2.ZERO, "type": 0, "dir": 1, "clock": 0.0, "ground": false, "anchor": game.player.x})
		voices = game.synth.voice_index
		game.update_enemies(0, 0)
		check(game.synth.voices[voices % 8].stream == game.synth.sounds.enemy_hit, "Enemy contact sounds on " + ("fatal" if extra_lives == 0 else "survived") + " hit")
	print("Freeze and discard: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
