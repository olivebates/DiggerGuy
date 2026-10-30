extends SceneTree

var game: Node
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	game.speed_learned = true
	game.freeze_learned = true
	game.placement_taught = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.enemies.clear()
	var cell := Vector2i(6, 4)
	game.world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 0}
	var mouse: Vector2 = game.world.cell_position(cell) + Vector2(16, 16)
	game.mine_at(mouse)
	check(game.world.blocks[cell].hp == 2, "Run starts with mining locked until a release")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = mouse
	game._input(event)
	check(game.world.blocks[cell].hp == 2, "A new press does not bypass required release")
	event.pressed = false
	game._input(event)
	event.pressed = true
	game._input(event)
	check(game.world.blocks[cell].hp == 1, "Mining starts after releasing then pressing")
	game.start_run()
	check(game.mining_needs_release, "Every new run requires another release")
	game.player = Vector2(240, 200)
	game.world.blocks.clear()
	game.world.lava.clear()
	game.drops.clear()
	game.inventory.fill(0)
	game.inventory[0] = game.capacity()
	game.full_was_full = true
	game.full_banner_time = 0
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 0, "age": 0.0, "rotation": 0.0})
	game.update_drops(0, 0)
	check(game.full_banner_time == 2.0, "Touching ore with a full bag restarts banner")
	game.full_banner_time = 0.9
	game.update_drops(0, 0)
	check(game.full_banner_time == 0.9, "Continuous contact lets banner animate instead of resetting each frame")
	game.player.x += 100
	game.update_drops(0, 0)
	game.player.x -= 100
	game.update_drops(0, 0)
	check(game.full_banner_time == 2.0, "Leaving and retouching the same ore retriggers banner")
	game.full_banner_time = 0.9
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 1, "age": 0.0, "rotation": 0.0})
	game.update_drops(0, 0)
	check(game.full_banner_time == 2.0, "A different ore contact retriggers banner independently")
	var world := MineWorld.new()
	world.base_depth = 0
	var rocks: Array[Vector2i] = []
	for y in range(40, 140):
		for x in range(100):
			var rock := Vector2i(x, y)
			rocks.append(rock)
			world.blocks[rock] = {"hp": 2, "ore": -1}
	world.blocks[Vector2i(0, 60)].ore = 4
	world.blocks[Vector2i(1, 60)].indestructible = true
	world.rng.seed = 528
	world.place_emeralds(rocks)
	var emeralds := 0
	var too_shallow := false
	for rock in rocks:
		if world.blocks[rock].ore == 8:
			emeralds += 1
			too_shallow = too_shallow or rock.y < 50
	check(not too_shallow and emeralds > 65 and emeralds < 120, "Emeralds roll at approximately one percent only from 50m")
	check(world.blocks[Vector2i(0, 60)].ore == 4 and world.blocks[Vector2i(1, 60)].ore == -1, "Emeralds preserve occupied blocks and hazard supports")
	var normal_pool := true
	for depth in [0, 50, 60, 130, 300, 1000, 3000]:
		for sample in range(200):
			var ore := world.choose_ore(depth)
			normal_pool = normal_pool and ore != 8 and MineCatalog.ORES[ore].depth <= depth
	check(normal_pool, "Normal ore selection respects depth despite emerald's earlier unlock")
	check(MineCatalog.ORES[8].value == 60, "Emerald sells for sixty coins")
	game.synth.muted = false
	game.synth.play_sound("death_shake")
	var first: PackedByteArray = game.synth.sounds.death_shake.data.duplicate()
	game.synth.play_sound("death_shake")
	check(first != game.synth.sounds.death_shake.data, "Every shake generates a different waveform")
	game.inventory.fill(0)
	game.die("test")
	var voices: int = game.synth.voice_index
	game.advance_death(game.death_transition_start() + game.DEATH_IRIS_DURATION + 0.19)
	check(game.synth.voice_index == voices, "Arc sound waits for launch")
	game.advance_death(0.02)
	game.advance_death(0.02)
	check(game.synth.voice_index == voices + 1, "Arc sound plays exactly once at launch")
	game.start_run()
	game.begin_departure()
	voices = game.synth.voice_index
	game._physics_process(game.DEPARTURE_BEAM + game.DEPARTURE_WAIT + game.DEPARTURE_FLOAT - 0.01)
	check(game.synth.voice_index == voices, "Departure stays silent before the circle")
	game._physics_process(0.02)
	game._physics_process(0.02)
	check(game.synth.voice_index == voices, "Departure circle stays silent")
	print("Ore feedback: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
