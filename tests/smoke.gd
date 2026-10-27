extends SceneTree

var failures := 0
var checks := 0
var game: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	# Earlier mechanics checks run with the now-purchasable abilities unlocked.
	game.upgrades.freeze = 1
	game.upgrades.speed = 3
	game.selected_speed = 4
	check(game.inventory.size() == 15, "15 ore inventory slots")
	check(MineCatalog.ENEMIES.size() == 10, "10 enemy species")
	check(game.mode == "playing", "Main scene starts a run")
	test_generation()
	test_mining()
	test_physics_and_freeze()
	test_lava()
	test_inventory_and_economy()
	test_enemy_simulation()
	test_revision_regressions()
	test_movement_feel()
	test_room_generation()
	test_depot_and_color_updates()
	test_speed_spikes_and_new_death()
	print("DiggerGuy: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func test_generation() -> void:
	var world := MineWorld.new()
	world.reset(0, 1122)
	check(world.generated_cave_cells > 100, "Cave strokes remove solid cells")
	check(world.lava.is_empty(), "No lava at starting depth")
	var starter_ores := true
	for cell in world.blocks:
		var block: Dictionary = world.blocks[cell]
		if world.cell_position(cell).y < 800 and block.ore > 1:
			starter_ores = false
	check(starter_ores, "First terrain contains only iron and copper")
	var starter_enemies := true
	for spawn in world.spawn_queue:
		if spawn.type > 1:
			starter_enemies = false
	check(starter_enemies, "Only two easiest enemies initially")
	check(world.solid(Vector2i(-1, 2)) and world.solid(Vector2i(MineWorld.COLS, 2)), "Offscreen side walls are solid")
	check(world.hit(Vector2i(-1, 2), 999).is_empty() and world.solid(Vector2i(-1, 2)), "Side walls cannot be destroyed")
	world.reset(2200, 1122)
	var eternium := false
	for seed_value in range(1, 25):
		world.reset(2200, seed_value)
		for block in world.blocks.values():
			if block.ore == 14:
				eternium = true
	check(eternium, "Eternium unlocks in deep terrain")
	check(not world.lava.is_empty(), "Deep caves contain lava")
	world.scroll = 10000
	world.ensure_rows()
	check(world.blocks.size() < 2200, "Old terrain is culled during infinite generation")
	var reproducible := MineWorld.new()
	reproducible.reset(0, 1122)
	world.reset(0, 1122)
	check(world.blocks == reproducible.blocks, "Seeded generation is deterministic")

func setup_mining() -> Vector2:
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.enemies.clear()
	game.world.blocks[Vector2i(10, 5)] = {"hp": 2, "ore": 1, "variant": 0}
	return game.world.cell_position(Vector2i(10, 5)) + Vector2(8, 8)

func test_mining() -> void:
	var mouse := setup_mining()
	var cell := Vector2i(10, 5)
	game.mine_at(mouse)
	check(game.world.blocks[cell].hp == 1, "First cursor entry cracks a two-hit block")
	for i in range(20):
		game.mine_at(mouse)
	check(game.world.blocks[cell].hp == 1, "Holding on a block never repeats damage")
	game.mine_at(mouse + Vector2(100, 0))
	game.mine_at(mouse)
	check(not game.world.blocks.has(cell), "Leaving and reentering damages the same block again")
	check(game.drops.size() == 1 and game.drops[0].ore == 1, "Destroyed ore block produces a physical ore")
	check(game.drops[0].vel.y < 0, "Ore is ejected at an upward angle")
	mouse = setup_mining()
	game.mine_at(mouse)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._input(release)
	game.mine_at(mouse)
	check(not game.world.blocks.has(cell), "Mouse release allows the next click to hit again")
	mouse = setup_mining()
	game.inventory_open = true
	game.mine_at(mouse)
	check(game.world.blocks[cell].hp == 2, "Inventory blocks mining")
	game.inventory_open = false
	game.frozen_toggle = true
	game.mine_at(mouse)
	check(game.world.blocks[cell].hp == 1, "Mining works while frozen")
	mouse = setup_mining()
	game.upgrades.power = 1
	game.mine_at(mouse)
	check(not game.world.blocks.has(cell), "Click upgrade breaks a block in one hit")
	game.upgrades.power = 0

func test_physics_and_freeze() -> void:
	game.start_run()
	game.enemies.clear()
	var x: float = game.player.x
	for i in range(60):
		game._physics_process(1.0 / 60)
	check(game.player.x > x + 15 and game.player.x < x + 22, "Miner walks slowly without keyboard input")
	check(game.grounded, "Gravity lands the miner on tiles")
	game.player = Vector2(473.9, 170)
	game.direction = 1
	game.update_player(0.1)
	check(game.pending_direction == -1 and game.direction == 1, "Miner anticipates a wall turn before reversing")
	game.update_player(0.11)
	check(game.direction == -1, "Miner automatically reverses at right wall")
	game.frozen_toggle = true
	var before: Vector2 = game.player
	var scroll: float = game.world.scroll
	var simulation_time: float = game.time
	game._physics_process(0.5)
	check(game.player == before and game.world.scroll == scroll and game.time == simulation_time, "Freeze halts player, terrain, and simulation clock")
	game.frozen_toggle = false
	game.space_held = true
	game._physics_process(0.5)
	check(game.player == before and game.world.scroll == scroll, "Hold-space freeze works independently")
	game.space_held = false
	game.inventory_open = true
	game._physics_process(0.5)
	check(game.player == before and game.world.scroll == scroll, "Inventory pauses the simulation")
	game.inventory_open = false
	game.player = Vector2(240, MineWorld.BOTTOM - 10)
	game.spike_height = 40
	game.update_spikes(0.1)
	check(game.mode == "dying", "Rising bottom spikes kill on contact")

func test_lava() -> void:
	var world := MineWorld.new()
	world.reset(0, 1)
	world.blocks.clear()
	world.lava.clear()
	for x in range(MineWorld.COLS):
		world.blocks[Vector2i(x, 10)] = {"hp": 2, "ore": -1, "variant": 0}
	world.lava[Vector2i(6, 5)] = 1.0
	world.lava[Vector2i(7, 5)] = 1.0
	for i in range(24):
		world.flow_lava()
	var volume := 0.0
	var spread := false
	for cell in world.lava:
		volume += world.lava[cell]
		if cell.y == 9 and cell.x < 6:
			spread = true
	check(absf(volume - 2.0) < 0.02, "Lava conserves volume while falling and spreading")
	check(spread, "Lava forms spreading puddles on a floor")
	var pos := world.cell_position(Vector2i(6, 9))
	check(world.touches_lava(Rect2(pos, Vector2.ONE * MineWorld.TILE)), "Lava volume is lethal on contact")
	world.hit(Vector2i(6, 10), 2)
	for i in range(12):
		world.flow_lava()
	var spilled := false
	for cell in world.lava:
		if cell.y > 10:
			spilled = true
	check(spilled, "Removing basin floor makes lava spill through")

func test_inventory_and_economy() -> void:
	game.start_run()
	game.enemies.clear()
	game.inventory.fill(0)
	game.drops.clear()
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 1, "rotation": 0.0, "age": 0.0})
	game.update_drops(0.01, 0)
	check(game.inventory[1] == 1 and game.drops.is_empty(), "Touching ore collects it")
	check(game.pickup_flights.size() == 1, "Pickup starts a flight to the bag button")
	game.inventory[0] = 29
	game.drops.clear()
	game.drops.append({"pos": game.player, "vel": Vector2.ZERO, "ore": 0, "rotation": 0.0, "age": 0.0})
	game.update_drops(0.01, 0)
	check(game.inventory_count() == 30 and game.drops.size() == 1, "Full inventory leaves ore in the world")
	game.return_to_depot(false)
	check(game.mode == "depot" and game.depot.visible and game.inventory_count() == 30, "Voluntary extraction preserves all ore")
	game.credits = 0
	game.sell_ores()
	check(game.credits == 92 and game.inventory_count() == 0, "Selling pays correct ore values")
	game.buy_upgrade(2)
	check(game.capacity() == 8 and game.credits == 62, "Capacity purchase charges 30 and adds one space")
	game.buy_upgrade(1)
	check(game.upgrades.power == 0 and game.credits == 62, "Unaffordable purchases do not charge")
	game.credits = 1000
	game.buy_upgrade(0)
	check(game.selected_depth == 100, "Starting depth upgrade selects unlocked depth")
	game.start_run()
	check(game.world.base_depth == 100, "New expedition starts in purchased stratum")
	game.inventory.fill(0)
	game.inventory[0] = 10
	game.inventory[13] = 2
	game.inventory[14] = 2
	game.upgrades.insurance = 0
	game.die("Test cave-in")
	check(game.inventory_count() == 3 and game.inventory[14] == 2 and game.inventory[13] == 1, "Death preserves exactly three rarest pieces")
	check(game.mode == "dying" and game.death_ore_queue.size() > 0 and game.death_flights.is_empty(), "Death freezes the mine and queues ore for the timed shakes")
	var scroll: float = game.world.scroll
	game._physics_process(1)
	check(game.mode == "dying" and game.world.scroll == scroll, "Death animation freezes mine")
	game._physics_process(game.death_duration())
	check(game.mode == "depot", "Death animation transitions to separate depot scene")
	game.inventory.fill(1)
	game.upgrades.insurance = 2
	var kept: Array[int] = game.retained_inventory()
	var count := 0
	for amount in kept:
		count += amount
	check(count == 5, "Two save upgrades preserve five rare pieces")
	game.upgrades.insurance = 12
	check(game.retained_inventory() == game.inventory, "Maximum insurance retains all ore")
	game.test_mode = false
	game.save_progress()
	game.credits = 0
	game.upgrades.insurance = 0
	game.inventory.fill(0)
	game.load_progress()
	check(game.credits == 940 and game.upgrades.insurance == 12 and game.inventory_count() == 15, "Credits, upgrades, and ores survive save/load")
	game.test_mode = true

func test_enemy_simulation() -> void:
	game.selected_depth = 2200
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.enemies.clear()
	game.player = Vector2(240, 150)
	for i in range(10):
		game.enemies.append({"pos": Vector2(25 + i * 44, 450), "vel": Vector2.ZERO, "type": i, "dir": 1, "clock": 0.0, "ground": false, "anchor": 25.0 + i * 44})
	for i in range(90):
		game.update_enemies(1.0 / 60, 5)
	check(game.enemies.size() == 10, "All ten enemy behaviors simulate without errors")
	game.enemies[0].pos = game.player
	game.update_enemies(0, 0)
	check(game.mode == "dying", "Enemy contact triggers death")

func test_revision_regressions() -> void:
	check(MineWorld.COLS * MineWorld.TILE == 480 and MineWorld.COLS == 15, "Zoomed board fits 15 double-size tiles across the view")
	var world := MineWorld.new()
	var rock_count := 0
	var ore_count := 0
	var layouts: Dictionary = {}
	for seed_value in range(1, 81):
		world.reset(0, seed_value)
		var layout: Array = world.blocks.keys()
		layouts[hash(layout)] = true
		for block in world.blocks.values():
			rock_count += 1
			if block.ore >= 0:
				ore_count += 1
	var density := float(ore_count) / rock_count
	check(density > 0.055 and density < 0.065, "Ore density is approximately 6%, twice its previous frequency")
	check(layouts.size() == 80, "Different seeds produce different cave layouts, beyond ore/color variation")
	world.reset(0)
	var first_layout: Array = world.blocks.keys()
	world.reset(0)
	check(first_layout != world.blocks.keys(), "New unseeded games receive fresh cave layouts")
	game.selected_depth = 0
	game.upgrades.insurance = 0
	game.upgrades.power = 0
	game.inventory.fill(0)
	var mouse := setup_mining()
	var first_cell := Vector2i(10, 5)
	var second_cell := Vector2i(12, 5)
	game.world.blocks[second_cell] = {"hp": 2, "ore": -1, "variant": 0}
	game.frozen_toggle = true
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mouse
	game._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = game.world.cell_position(second_cell) + Vector2.ONE * MineWorld.TILE * 0.5
	game._input(motion)
	check(game.cursor_position == motion.position and game.world.blocks[second_cell].hp == 1, "Cursor and held-brush mining follow motion events while frozen")
	motion.position = mouse
	game._input(motion)
	check(not game.world.blocks.has(first_cell), "Frozen cursor can leave and reenter to break blocks")
	check(game.world.scroll == 0, "Frozen mouse input does not advance terrain")
	game.frozen_toggle = false
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	game._input(key)
	check(not game.is_frozen(), "F no longer toggles freeze")
	var far_cell := Vector2i(12, 5)
	game.world.blocks[far_cell] = {"hp": 2, "ore": -1, "variant": 0}
	game.mine_at(mouse)
	check(game.world.blocks[far_cell].hp == 2, "24px radius does not damage a tile outside the brush")
	game.mouse_held = false
	game.inventory.fill(0)
	check(game.visible_ores().is_empty(), "Empty bag shows no ore types in inventory or depot")
	game.inventory[1] = 2
	game.inventory[4] = 1
	check(game.visible_ores() == [1, 4], "Only currently carried ore types appear in both inventory views")
	game.sell_ores()
	check(game.visible_ores().is_empty(), "Sold ore disappears from the depot haul")
	game.inventory[0] = 20
	game.inventory[13] = 2
	game.inventory[14] = 2
	game.mode = "playing"
	game.pickup_flights.append({"start": game.player, "ore": 14, "t": 0.0})
	game.die("Test fireworks")
	check(game.death_ore_queue.size() == game.death_lost and game.death_lost == 21, "Every lost ore piece is queued for shake bursts, including stacks larger than twelve")
	game.advance_death(game.death_shakes_total * game.DEATH_SHAKE_INTERVAL)
	var only_lost := true
	for flight in game.death_flights:
		if flight.ore == 14 or flight.has("kept"):
			only_lost = false
	check(only_lost and game.pickup_flights.is_empty(), "Kept ore stays in inventory and no ore flies toward the bag during death")
	game.synth.muted = false
	game.synth.break_cooldown = 0
	var voices_before: int = game.synth.voice_index
	game.synth.play_sound("break_block")
	game.synth.play_sound("break_block")
	game.synth._process(0.19)
	game.synth.play_sound("break_block")
	check(game.synth.voice_index == voices_before + 1, "Destruction audio plays at most once within 0.2 seconds")
	game.synth._process(0.02)
	game.synth.play_sound("break_block")
	check(game.synth.voice_index == voices_before + 2, "Destruction sound becomes available after 0.2 seconds")
	game.synth.muted = true
	for fps in [30, 60, 144]:
		game.start_run()
		game.world.blocks.clear()
		game.world.lava.clear()
		game.enemies.clear()
		for x in range(MineWorld.COLS):
			game.world.blocks[Vector2i(x, 0)] = {"hp": 2, "ore": -1, "variant": 0}
		game.player = Vector2(240, 192)
		game.player_velocity = Vector2.ZERO
		game.enemies.append({"pos": Vector2(64, 196), "vel": Vector2.ZERO, "type": 1, "dir": 1, "clock": 0.0, "ground": true, "anchor": 64.0})
		var stable := true
		for frame in range(fps * 2):
			var delta: float = 1.0 / fps
			game.world.scroll += 4.5 * delta
			game.player.y -= 4.5 * delta
			game.update_player(delta)
			game.update_enemies(delta, 4.5)
			var surface: float = 208 - game.world.scroll
			if absf(game.player.y + 16 - surface) > 0.001 or not game.grounded:
				stable = false
			if absf(game.enemies[0].pos.y + 12 - surface) > 0.001 or not game.enemies[0].ground:
				stable = false
		check(stable, "Player and walking enemy stay attached to rising terrain at %d FPS without bouncing" % fps)

func flat_test_world(floor_row: int = 4) -> void:
	game.selected_depth = 0
	game.start_run()
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for x in range(MineWorld.COLS):
		game.world.blocks[Vector2i(x, floor_row)] = {"hp": 2, "ore": -1, "variant": 0}
	game.player = Vector2(200, 208 + floor_row * MineWorld.TILE - 16)
	game.grounded = true

func landing_sample(distance: float) -> Dictionary:
	flat_test_world(8)
	game.player.y -= distance
	game.grounded = false
	for frame in range(180):
		game.update_player(1.0 / 60)
		if game.grounded:
			break
	return {"grounded": game.grounded, "squash": game.landing_squash, "shake": game.shake, "dust": game.particles.size(), "rings": game.landing_rings.size()}

func test_movement_feel() -> void:
	flat_test_world()
	game.update_player(0.05)
	check(game.player_velocity.x > 0 and game.player_velocity.x < game.WALK_SPEED * 0.5, "Automatic walking accelerates gradually")
	for frame in range(4):
		game.update_player(0.05)
	check(is_equal_approx(game.player_velocity.x, game.WALK_SPEED), "Walking reaches its slow target speed in about 0.2 seconds")
	for frame in range(90):
		game.update_player(1.0 / 60)
	check(game.walk_cycle > TAU and game.footstep_index >= 2, "Footfalls and gait advance with distance traveled")
	check(game.shake == 0, "Ordinary walking does not shake the camera")
	flat_test_world()
	for x in range(7, MineWorld.COLS):
		game.world.blocks.erase(Vector2i(x, 4))
	game.player.x = 234
	force_hesitation()
	game.player_velocity.x = game.WALK_SPEED
	var x_before: float = game.player.x
	game.update_player(0.05)
	check(game.edge_timer > 0 and game.player.x == x_before and game.grounded, "Miner pauses and looks down before stepping off a ledge")
	for frame in range(20):
		game.update_player(1.0 / 60)
	check(game.player.x > x_before and game.edge_timer == 0, "Ledge hesitation ends automatically instead of trapping the miner")
	flat_test_world()
	game.player = Vector2(468, game.player.y)
	game.direction = 1
	game.player_velocity.x = game.WALK_SPEED
	game.update_player(1.0 / 60)
	check(game.pending_direction == -1 and game.player_lean < 0, "Wall contact starts a backward lean before turning")
	for frame in range(30):
		game.update_player(1.0 / 60)
	check(game.direction == -1 and game.player_velocity.x < 0 and game.facing_blend < -0.8, "Miner eases into walking the other way and the lamp follows")
	var light := landing_sample(24)
	var heavy := landing_sample(145)
	check(light.grounded and heavy.grounded, "Both short and substantial falls land safely on a floor")
	check(heavy.squash > light.squash and heavy.dust > light.dust, "Landing squash and dust scale with fall distance")
	check(light.shake == 0 and heavy.shake > 0, "Only substantial landings shake the camera")
	check(light.rings == 1 and heavy.rings == 1, "Each landing produces one contact ring")
	var shape := Rect2(game.player - Vector2(12, 16), Vector2(24, 32))
	check(not game.world.collides(shape) and game.grounded, "Landing animation leaves the physical collision box unchanged")
	var particles_before: int = game.particles.size()
	for frame in range(10):
		game.update_player(1.0 / 60)
	check(game.landing_rings.size() == 1 and game.particles.size() <= particles_before + 1, "Stable grounded contact does not repeatedly trigger landing effects")
	game.frozen_toggle = true
	game.turn_timer = 0.08
	game.pending_direction = -1
	var animated_state := [game.turn_timer, game.edge_timer, game.walk_cycle, game.landing_squash, game.facing_blend, game.player_lean, game.landing_rings.duplicate(true)]
	game._physics_process(0.5)
	check(animated_state == [game.turn_timer, game.edge_timer, game.walk_cycle, game.landing_squash, game.facing_blend, game.player_lean, game.landing_rings], "Freeze suspends anticipation, gait, squash, lamp motion, and landing rings")
	flat_test_world(18)
	game.player = Vector2(240, 150)
	game.grounded = false
	for frame in range(45):
		game.update_player(1.0 / 60)
	check(game.player_velocity.y > 350 and game.player_velocity.y <= game.MAX_FALL_SPEED, "Falling accelerates decisively and respects terminal speed")
	flat_test_world()
	game.world.spawn_queue.clear()
	game.world.spawn_queue.append({"cell": Vector2i(4, 30), "type": 0})
	game.spawn_enemies()
	check(game.enemies.is_empty() and game.world.spawn_queue.size() == 1, "Enemies in future rooms wait until the room approaches the screen")

func test_room_generation() -> void:
	var world := MineWorld.new()
	var styles: Dictionary = {}
	var room_types: Dictionary = {}
	var short_drops := true
	var valid_veins := true
	var connected_veins := true
	var valid_spawns := true
	var valid_basins := true
	var dry_route := true
	var rock_count := 0
	var ore_count := 0
	var prop_kinds: Dictionary = {}
	for depth in [0, 300, 660, 1200, 2200]:
		for seed_value in range(1, 21):
			world.reset(depth, seed_value)
			for section in world.sections:
				styles[section.style] = true
				for cell in section.basin:
					if not world.solid(cell + Vector2i.DOWN) or world.solid(cell):
						valid_basins = false
					if (section.safe_left and cell.x < 7) or (not section.safe_left and cell.x > 7):
						dry_route = false
			for room in world.rooms:
				room_types[room.kind] = true
			for x in range(MineWorld.COLS):
				var run_length := 0
				for y in range(world.last_row + 1):
					if world.solid(Vector2i(x, y)):
						run_length = 0
					else:
						run_length += 1
					if run_length > MineWorld.MAX_OPEN_DROP:
						short_drops = false
			for vein in world.veins:
				if vein.cells.size() < 2 or vein.cells.size() > 5:
					valid_veins = false
				var reachable: Dictionary = {vein.cells[0]: true}
				var frontier: Array = [vein.cells[0]]
				while not frontier.is_empty():
					var cell: Vector2i = frontier.pop_back()
					for neighbor in [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
						if neighbor in vein.cells and not reachable.has(neighbor):
							reachable[neighbor] = true
							frontier.append(neighbor)
				if reachable.size() != vein.cells.size():
					connected_veins = false
				for cell in vein.cells:
					if not world.blocks.has(cell) or world.blocks[cell].ore != vein.ore or depth + cell.y < MineCatalog.ORES[vein.ore].depth:
						valid_veins = false
			for block in world.blocks.values():
				rock_count += 1
				if block.ore >= 0:
					ore_count += 1
			for spawn in world.spawn_queue:
				var cell: Vector2i = spawn.cell
				var flying: bool = MineCatalog.ENEMIES[spawn.type].kind in ["bat", "wisp", "eye"]
				if world.solid(cell) or world.lava.has(cell) or world.lava.has(cell + Vector2i.DOWN):
					valid_spawns = false
				if not flying and not world.solid(cell + Vector2i.DOWN):
					valid_spawns = false
				if flying and (world.solid(cell + Vector2i.LEFT) or world.solid(cell + Vector2i.RIGHT) or world.solid(cell + Vector2i.UP) or world.solid(cell + Vector2i.DOWN)):
					valid_spawns = false
			for prop in world.decorations:
				prop_kinds[prop.kind] = true
	check(styles.size() == 5, "All five room layouts occur across random mines")
	check(room_types.has("shaft") and room_types.has("chamber") and room_types.has("branch") and room_types.has("terrace") and room_types.has("pocket"), "Generation includes shafts, broad rooms, branches, terraces, and enclosed pockets")
	check(short_drops, "Generated shelves limit uninterrupted vertical openings to five blocks across 100 mines")
	check(valid_veins and connected_veins, "Ore veins contain two to five connected blocks of one depth-appropriate ore")
	var density := float(ore_count) / rock_count
	check(density > 0.055 and density < 0.065, "Clustered ores have an overall 6% density")
	check(valid_spawns, "Walking enemies spawn on floors and flying enemies in open spaces away from lava")
	check(valid_basins and dry_route, "Lava starts in supported basins on the riskier side, leaving the alternate route dry")
	check(not prop_kinds.has("roots") and prop_kinds.has("slate") and prop_kinds.has("crystal") and prop_kinds.has("ember"), "Depth regions have mineral formations without underground grass")
	check(MineWorld.region_color(0, "rock") != MineWorld.region_color(660, "rock") and MineWorld.region_color(660, "back") != MineWorld.region_color(1200, "back"), "Rock and cave palettes change with depth")
	var at_boundary := MineWorld.region_color(580, "rock")
	var after_boundary := MineWorld.region_color(581, "rock")
	check(at_boundary.r > 0 and absf(at_boundary.r - after_boundary.r) < 0.01, "Region palette transitions are gradual")
	world.reset(660, 77)
	var saved_blocks := world.blocks.duplicate(true)
	var saved_sections := world.sections.duplicate(true)
	var saved_spawns := world.spawn_queue.duplicate(true)
	world.reset(660, 77)
	check(saved_blocks == world.blocks and saved_sections == world.sections and saved_spawns == world.spawn_queue, "A seed reproduces rooms, veins, hazards, and spawns together")
	world.scroll = 40000
	world.ensure_rows()
	check(world.sections.size() < 6 and world.rooms.size() < 30 and world.decorations.size() < 150 and world.veins.size() < 20, "Room, vein, and formation metadata are culled during long expeditions")

func test_depot_and_color_updates() -> void:
	var color_before := MineWorld.block_color(Vector2i(5, 137), 0)
	var world := MineWorld.new()
	world.reset(0, 1)
	world.reset(0, 999)
	MineWorld.color_anchors.clear()
	check(color_before == MineWorld.block_color(Vector2i(5, 137), 0), "Block colors are reproducible after cache reset and independent of layout seeds")
	check(color_before == MineWorld.block_color(Vector2i(5, 37), 100), "The same absolute depth has the same block color from different starting depths")
	var continuous := true
	for depth in range(0, 3000):
		var a := MineWorld.region_color(depth, "rock")
		var b := MineWorld.region_color(depth + 1, "rock")
		if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.008:
			continuous = false
	check(continuous, "Terrain colors change continuously through every region boundary")
	check(MineWorld.region_color(80, "rock") != MineWorld.region_color(100, "rock") and MineWorld.region_color(1900, "rock") != MineWorld.region_color(2000, "rock"), "Color progression continues both between early regions and below the final region")
	check(MineInk.BG == Color.BLACK and MineInk.PANEL == Color.BLACK and MineInk.LINE == Color("d9c9a5"), "HUD, depot, and shop share black fills and beige outlines")
	game.selected_depth = 0
	game.start_run()
	game.inventory.fill(0)
	game.inventory[0] = 4
	game.inventory[1] = 3
	game.inventory[14] = 2
	game.credits = 50
	var value: int = game.haul_value()
	check(value == 3027, "Live ore value uses every currently held ore")
	game.return_to_depot(false)
	check(game.depot.screen == "depot" and game.depot.primary_label() == "Sell All", "Returning with ore opens depot with Sell All in the primary slot")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.depot.nav_rect().get_center()
	game.depot._input(click)
	game.depot._process(0.4)
	check(game.depot.screen == "shop" and game.mode == "depot", "Shop button opens a separate paused upgrade interface")
	game.upgrades.power = 0
	var wallet_before: int = game.credits
	click.position = game.depot.upgrade_rect(1).get_center()
	game.depot._input(click)
	check(game.upgrades.power == 0 and game.credits == wallet_before, "Shop rejects unaffordable upgrades without charging")
	game.credits = 500
	game.depot._input(click)
	check(game.upgrades.power == 1 and game.credits == 300, "Shop card buys its upgrade and updates wallet")
	click.position = game.depot.nav_rect().get_center()
	game.depot._input(click)
	check(game.depot.screen == "depot" and game.inventory_count() == 9, "Back button returns to depot without altering the haul")
	game.depot._process(0.4)
	wallet_before = game.credits
	click.position = game.depot.primary_rect.get_center()
	game.depot._input(click)
	check(game.inventory_count() == 0 and game.credits == wallet_before + value, "Sell All clears the haul and pays exactly once")
	check(game.depot.sale_flights.size() == 9 and game.depot.displayed_credits == wallet_before, "Every sold piece starts a flight and the visible counter begins at its old value")
	check(game.depot.primary_label() == "Sell All" and game.depot.is_selling(), "Sell All remains reserved while the sale animation runs")
	game.depot.activate_primary()
	game.depot.open_shop()
	check(game.mode == "depot" and game.depot.screen == "shop" and game.credits == wallet_before + value, "Shop can open during a sale without duplicating credits")
	game.depot.advance_sale(0.7)
	check(game.depot.displayed_credits >= wallet_before and game.depot.displayed_credits <= game.credits, "Visible coin count rises as sale flights arrive")
	game.depot.advance_sale(1)
	check(not game.depot.is_selling() and game.depot.displayed_credits == game.credits and game.depot.primary_label() == "Sell All", "Completing the sale matches the wallet while Sell All keeps its own reserved slot")
	game.depot._process(0.4)
	click.position = game.depot.dive_rect.get_center()
	game.depot._input(click)
	check(game.mode == "playing" and not game.depot.visible, "Dig Deeper starts a new expedition")
	for walk_direction in [-1, 1]:
		flat_test_world()
		for x in range(MineWorld.COLS):
			if (walk_direction == 1 and x >= 7) or (walk_direction == -1 and x < 7):
				game.world.blocks.erase(Vector2i(x, 4))
		game.player.x = 208 if walk_direction == 1 else 240
		game.direction = walk_direction
		game.player_velocity.x = game.WALK_SPEED * walk_direction
		force_hesitation()
		var pause_starts := 0
		var previous_timer := 0.0
		var pause_x := 0.0
		var pause_end_frame := -1
		var drop_frame := -1
		for frame in range(240):
			game.world.scroll += 4.5 / 60
			game.player.y -= 4.5 / 60
			game.update_player(1.0 / 60)
			if previous_timer == 0 and game.edge_timer > 0:
				pause_starts += 1
				pause_x = game.player.x
			if previous_timer > 0 and game.edge_timer == 0:
				pause_end_frame = frame
			if not game.grounded and drop_frame < 0:
				drop_frame = frame
			previous_timer = game.edge_timer
			if drop_frame >= 0 and frame > drop_frame + 10:
				break
		var expected_x := 234.0 if walk_direction == 1 else 214.0
		check(pause_starts == 1 and absf(pause_x - expected_x) < 0.01, "Ledge hesitation starts once at the final foothold when moving %d" % walk_direction)
		check(drop_frame >= 0 and pause_end_frame >= 0 and drop_frame - pause_end_frame < 20, "Miner drops promptly after the single hesitation when moving %d" % walk_direction)

func force_hesitation() -> void:
	var seeded_rng := RandomNumberGenerator.new()
	for seed_value in range(100):
		seeded_rng.seed = seed_value
		if seeded_rng.randf() < game.HESITATION_CHANCE:
			game.hesitation_rng.seed = seed_value
			return

func test_speed_spikes_and_new_death() -> void:
	check(game.DIG_RADIUS == 24, "Mining cursor has a 24px radius")
	check(game.speed_rect.position.x < game.freeze_rect.position.x and game.freeze_rect.position.x < game.bag_rect.position.x and game.bag_rect.position.x < game.home_rect.position.x, "HUD buttons are ordered Speedup, Freeze, Inventory, Leave")
	flat_test_world()
	for frame in range(60):
		game._physics_process(1.0 / 60)
	var normal_position: Vector2 = game.player
	var normal_scroll: float = game.world.scroll
	flat_test_world()
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	game._input(key)
	check(game.game_speed() == 4, "Holding W enables 4x game speed")
	for frame in range(15):
		game._physics_process(1.0 / 60)
	check(game.player.distance_to(normal_position) < 0.001 and absf(game.world.scroll - normal_scroll) < 0.001 and absf(game.run_time - 1.0) < 0.001, "A quarter-second at 4x matches one second of normal movement and terrain simulation")
	key.pressed = false
	game._input(key)
	check(game.game_speed() == 1, "Releasing W restores normal speed")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.speed_rect.get_center()
	game._input(click)
	check(game.game_speed() == 4, "Speedup icon toggles 4x speed")
	key.pressed = true
	game._input(key)
	check(game.game_speed() == 4, "Holding W and toggling Speedup do not multiply into 16x")
	game.frozen_toggle = true
	var before: Vector2 = game.player
	var scroll: float = game.world.scroll
	game._physics_process(0.25)
	check(game.player == before and game.world.scroll == scroll, "Freeze overrides 4x speed")
	game.frozen_toggle = false
	game.inventory_open = true
	game._physics_process(0.25)
	check(game.player == before and game.world.scroll == scroll, "Inventory pauses the accelerated game")
	game.inventory_open = false
	key.keycode = KEY_Q
	game._input(key)
	check(game.mode == "playing", "Q has no action")
	click.position = game.home_rect.get_center()
	game._input(click)
	game._physics_process(game.DEPARTURE_END + 0.01)
	check(game.mode == "depot", "Leave icon returns after the extraction animation")
	flat_test_world()
	for x in range(7, MineWorld.COLS):
		game.world.blocks.erase(Vector2i(x, 4))
	var hesitations := 0
	var rolled_once := true
	for seed_value in range(1, 601):
		game.player = Vector2(234, 320)
		game.player_velocity = Vector2(game.WALK_SPEED, 0)
		game.direction = 1
		game.grounded = true
		game.pending_direction = 0
		game.edge_timer = 0
		game.ledge_committed = false
		game.fall_distance = 0
		game.walk_cycle = 0
		game.footstep_index = 0
		game.hesitation_rng.seed = seed_value
		game.update_player(1.0 / 60)
		if game.edge_timer > 0:
			hesitations += 1
		var state: int = game.hesitation_rng.state
		for frame in range(4):
			game.update_player(1.0 / 60)
		if state != game.hesitation_rng.state:
			rolled_once = false
	var rate := float(hesitations) / 600
	check(rate > 0.25 and rate < 0.35, "Approximately 30% of ledges trigger hesitation across 600 independent trials")
	check(rolled_once, "Ledge hesitation is rolled once rather than retried every frame")
	var world := MineWorld.new()
	var spike_count := 0
	var supported := true
	var protected_start := true
	var safe_spawns := true
	for seed_value in range(1, 41):
		world.reset(660, seed_value)
		spike_count += world.floor_spikes.size()
		for cell in world.floor_spikes:
			if not world.solid(cell) or world.solid(cell + Vector2i.UP) or world.lava.has(cell + Vector2i.UP):
				supported = false
			if cell.y < 4:
				protected_start = false
		for spawn in world.spawn_queue:
			if world.floor_spikes.has(spawn.cell + Vector2i.DOWN):
				safe_spawns = false
	check(spike_count > 20 and supported, "Random spikes spawn on exposed supported blocks outside lava")
	check(protected_start and safe_spawns, "Spikes avoid the starting platform and enemy spawn points")
	world.blocks.clear()
	world.floor_spikes.clear()
	var cell := Vector2i(6, 7)
	world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 0}
	world.floor_spikes[cell] = {"height": 10.0}
	var pos := world.cell_position(cell)
	var contact := Rect2(pos + Vector2(5, -9), Vector2(5, 8))
	check(world.touches_floor_spikes(contact) and not world.touches_floor_spikes(Rect2(pos + Vector2(-20, -12), Vector2(5, 5))), "Spike contact follows its triangle geometry")
	world.hit(cell, 1)
	check(world.floor_spikes.has(cell), "Cracking the support leaves its spikes in place")
	world.hit(cell, 1)
	check(not world.floor_spikes.has(cell) and not world.touches_floor_spikes(contact), "Destroying a supporting block removes its spikes")
	flat_test_world()
	game.world.floor_spikes[Vector2i(6, 4)] = {"height": 10.0}
	game.player = Vector2(207, 320)
	game.update_player(1.0 / 60)
	check(game.mode == "dying", "Touching block-top spikes kills the miner")
	flat_test_world()
	game.inventory.fill(0)
	game.inventory[0] = 10
	game.inventory[1] = 4
	game.inventory[14] = 2
	game.upgrades.insurance = 0
	game.speed_toggle = true
	game.synth.muted = false
	var voices_before: int = game.synth.voice_index
	var player_before: Vector2 = game.player
	var scroll_before: float = game.world.scroll
	var clock_before: float = game.time
	game.die("Test shake sequence")
	check(game.death_shakes_total >= 3 and game.death_shakes_total <= 4 and game.death_shake_count == 0 and game.death_flights.is_empty(), "Death queues three or four shakes without an immediate ore burst")
	game._physics_process(0.199)
	check(game.death_shake_count == 0 and game.synth.voice_index == voices_before, "Death waits 0.2 real seconds even with speedup toggled")
	game._physics_process(0.001)
	check(game.death_shake_count == 1 and game.death_flights.size() > 0 and game.synth.voice_index == voices_before + 1, "First shake releases ore and plays one sound at 0.2 seconds")
	check(game.camera_offset().length() > 1, "A death shake visibly offsets the frozen world")
	var emitted: int = game.death_flights.size()
	game._physics_process(0.2)
	check(game.death_shake_count == 2 and game.death_flights.size() > emitted and game.synth.voice_index == voices_before + 2, "Second shake releases another batch and sound at 0.4 seconds")
	game._physics_process((game.death_shakes_total - 2) * game.DEATH_SHAKE_INTERVAL)
	check(game.death_flights.size() == 13 and game.death_ore_queue.is_empty() and game.death_shake_count == game.death_shakes_total, "All lost ore is released across the complete shake sequence")
	check(game.synth.voice_index == voices_before + game.death_shakes_total, "Every shake plays exactly one effect")
	check(game.player == player_before and game.world.scroll == scroll_before and game.time == clock_before, "Player, terrain, and world animation remain frozen throughout death")
	check(game.inventory_count() == 3 and game.inventory[14] == 2 and game.inventory[1] == 1, "Only the three rarest pieces stay in the bag")
	game._physics_process(0.59)
	check(game.death_iris_progress() == 0, "Closing circle waits until the last shake has settled")
	game._physics_process(0.285)
	check(game.mode == "dying" and game.death_iris_progress() > 0.4 and game.death_iris_progress() < 0.6, "Circle closes smoothly around the player before leaving the mine")
	game._physics_process(game.death_duration() - game.death_time - 0.02)
	check(game.mode == "dying" and game.death_iris_progress() == 1, "Transition reaches complete black before switching scenes")
	game._physics_process(0.03)
	check(game.mode == "depot" and game.depot.visible and game.depot.screen == "depot", "Death cuts straight to the depot after the closing circle")
	game.synth.muted = true
