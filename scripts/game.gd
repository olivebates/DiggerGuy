extends Node2D

const TILE := MineWorld.TILE
const DIG_RADIUS := 24.0
const BOARD_ZOOM := 2.0
const WALK_SPEED := 19.0
const GRAVITY := 620.0
const WALK_ACCELERATION := 95.0
const MAX_FALL_SPEED := 420.0
const TURN_PAUSE := 0.10
const EDGE_PAUSE := 0.15
const HESITATION_CHANCE := 0.30
const DEATH_SHAKE_INTERVAL := 0.2
const DEATH_IRIS_DURATION := 0.55
const DEATH_IRIS_HOLD := 1.5
const DEATH_FINAL_CLOSE := 0.35
const DEATH_BLACK_HOLD := 0.08
const SAVE_PATH := "user://digger_guy_save.json"
const DEPOT_SCENE := preload("res://scenes/depot.tscn")

var player_viewport: SubViewport
var player_visual: Node2D
var terrain_viewport: SubViewport
var terrain_root: Node2D
var terrain_rows: Dictionary = {}
var placement_effects: Dictionary = {}
var placement_held := false
var placement_contacts: Dictionary = {}
var global_pixel_material: ShaderMaterial
var placement_preview: Node2D
var icon_viewport: SubViewport
const DEPARTURE_BEAM := 0.5
const DEPARTURE_WAIT := 0.7
const DEPARTURE_FLOAT := 2.0
const DEPARTURE_CLOSE := 0.55
const DEPARTURE_END := DEPARTURE_BEAM + DEPARTURE_WAIT + DEPARTURE_FLOAT + DEPARTURE_CLOSE + 0.08
var world := MineWorld.new()
var synth: MineSynth
var depot: Node2D
var mode := "playing"
var inventory: Array[int] = []
var credits := 0
var upgrades := {"depth": 0, "power": 0, "capacity": 0, "insurance": 0, "freeze": 1, "speed": 0, "lives": 0, "blocks": 0}
var selected_depth := 0
var selected_speed := 2
var rounds_started := 0
var speed_learned := false
var speed_hold_time := 0.0
var speed_learned_round := -1
var freeze_learned := false
var freeze_use_time := 0.0
var full_bag_time := 0.0
var full_banner_y := 0.0
var lives := 1
var hit_grace := 0.0
var spike_cooldown := 0.0
var full_banner_time := 0.0
var leave_glow := false
var full_was_full := false
var pending_shortcuts: Array[String] = []
var shortcut_popup := false
var placement_taught := false
var tutorial_cell := Vector2i(-999, -999)
var block_shakes: Dictionary = {}
var death_origin := Vector2.ZERO
var blocks_left := 3
var block_counter_pulse := 0.0
var departure_time := 0.0
var departure_origin := Vector2.ZERO
var floating_texts: Array[Dictionary] = []
var best_depth := 0
var run_peak := 0
var run_best_before := 0
var run_credits_before := 0
var run_haul_before := 0
var run_treasure_count := 0
var run_first_treasure := false
var treasure_seen := false
var claimed_milestones: Array[int] = []
var tracked_upgrade := "capacity"
var results: Node2D
var results_from_death := false
var inventory_scroll := 0
var debug_keys: Dictionary = {}
var depot_message := "A warm lamp. A fair trade. One more expedition."
var player := Vector2(240, 172)
var player_velocity := Vector2.ZERO
var direction := 1
var grounded := false
var turn_timer := 0.0
var pending_direction := 0
var edge_timer := 0.0
var noticed_edge := Vector2i(-999, -999)
var ledge_committed := false
var walk_cycle := 0.0
var footstep_index := 0
var player_lean := 0.0
var facing_blend := 1.0
var landing_squash := 0.0
var fall_distance := 0.0
var peak_fall_speed := 0.0
var landing_rings: Array[Dictionary] = []
var frozen_toggle := false
var space_held := false
var speed_held := false
var speed_toggle := false
var inventory_open := false
var mouse_held := false
var mining_needs_release := true
var death_arc_sound_played := false
var cursor_position := Vector2.ZERO
var stroke_contacts: Dictionary = {}
var drops: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickup_flights: Array[Dictionary] = []
var death_flights: Array[Dictionary] = []
var death_time := 0.0
var death_ore_queue: Array[int] = []
var death_shakes_total := 3
var death_shake_count := 0
var death_reason := ""
var death_kept := 0
var death_lost := 0
var spike_height := 0.0
var time := 0.0
var ui_time := 0.0
var run_time := 0.0
var shake := 0.0
var flash := 0.0
var toast := ""
var toast_time := 0.0
var full_notice := 0.0
var bag_pulse := 0.0
var test_mode := false
var rng := RandomNumberGenerator.new()
var hesitation_rng := RandomNumberGenerator.new()
var speed_rect := Rect2(164, 82, 32, 32)
var freeze_rect := Rect2(204, 82, 32, 32)
var bag_rect := Rect2(244, 82, 32, 32)
var home_rect := Rect2(284, 82, 32, 32)

func _ready() -> void:
	rng.randomize()
	hesitation_rng.randomize()
	inventory.resize(MineCatalog.ORES.size())
	inventory.fill(0)
	synth = MineSynth.new()
	add_child(synth)
	load_progress()
	depot = DEPOT_SCENE.instantiate()
	depot.game = self
	depot.visible = false
	depot.dive_requested.connect(start_run)
	depot.sell_requested.connect(sell_ores)
	depot.upgrade_requested.connect(buy_upgrade)
	depot.depth_requested.connect(cycle_depth)
	add_child(depot)
	results = Node2D.new()
	results.set_script(preload("res://scripts/expedition_results.gd"))
	results.game = self
	results.visible = false
	add_child(results)
	var crisp_material := ShaderMaterial.new()
	crisp_material.shader = preload("res://shaders/crisp.gdshader")
	material = crisp_material
	depot.use_parent_material = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().msaa_2d = Viewport.MSAA_DISABLED
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	player_viewport = SubViewport.new()
	player_viewport.size = Vector2i(64, 64)
	player_viewport.transparent_bg = true
	player_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	player_viewport.msaa_2d = Viewport.MSAA_DISABLED
	player_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	player_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(player_viewport)
	player_visual = Node2D.new()
	player_visual.set_script(preload("res://scripts/player_render.gd"))
	player_visual.game = self
	player_visual.material = crisp_material
	player_viewport.add_child(player_visual)
	terrain_viewport = SubViewport.new()
	terrain_viewport.size = Vector2i(480, 800)
	terrain_viewport.transparent_bg = true
	terrain_viewport.msaa_2d = Viewport.MSAA_DISABLED
	terrain_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	terrain_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(terrain_viewport)
	terrain_root = Node2D.new()
	terrain_root.material = crisp_material
	terrain_viewport.add_child(terrain_root)
	icon_viewport = SubViewport.new()
	icon_viewport.size = Vector2i(256, ceili((MineInk.ICONS.size() + MineCatalog.ORES.size()) * MineInk.ICON_VARIANTS / 16.0) * 16)
	icon_viewport.transparent_bg = true
	icon_viewport.msaa_2d = Viewport.MSAA_DISABLED
	icon_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	icon_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(icon_viewport)
	var icon_art := Node2D.new()
	icon_art.set_script(preload("res://scripts/icon_atlas.gd"))
	icon_viewport.add_child(icon_art)
	MineInk.icon_texture = icon_viewport.get_texture()
	placement_preview = Node2D.new()
	placement_preview.set_script(preload("res://scripts/placement_preview.gd"))
	placement_preview.game = self
	placement_preview.material = CanvasItemMaterial.new()
	placement_preview.use_parent_material = false
	add_child(placement_preview)
	var pixel_layer := CanvasLayer.new()
	pixel_layer.layer = 100
	add_child(pixel_layer)
	var filter := ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	global_pixel_material = ShaderMaterial.new()
	global_pixel_material.shader = preload("res://shaders/global_pixels.gdshader")
	global_pixel_material.set_shader_parameter("world_top", MineWorld.TOP / 800.0)
	filter.material = global_pixel_material
	pixel_layer.add_child(filter)
	start_run()

func _process(_delta: float) -> void:
	placement_preview.queue_redraw()
	global_pixel_material.set_shader_parameter("enabled", mode not in ["depot", "results"] and not inventory_open)
	if mode != "depot" and is_instance_valid(player_visual):
		player_visual.queue_redraw()
		if mode != "results":
			update_terrain_cache()
	player_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if mode == "depot" else SubViewport.UPDATE_ALWAYS
	terrain_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if mode in ["depot", "results"] else SubViewport.UPDATE_ALWAYS
	# Rendering and cursor input remain live even when the simulation is frozen.
	queue_redraw()

func visible_ores() -> Array[int]:
	var result: Array[int] = []
	for i in range(inventory.size()):
		if inventory[i] > 0:
			result.append(i)
	result.sort_custom(func(a: int, b: int) -> bool: return MineCatalog.ORES[a].depth < MineCatalog.ORES[b].depth if MineCatalog.ORES[a].depth != MineCatalog.ORES[b].depth else a < b)
	return result

func start_run() -> void:
	depot.finish_sale()
	results.visible = false
	run_best_before = best_depth
	run_peak = selected_depth
	run_credits_before = credits
	run_haul_before = haul_value()
	run_treasure_count = 0
	run_first_treasure = false
	inventory_scroll = 0
	upgrades.freeze = 1
	rounds_started += 1
	speed_hold_time = 0
	freeze_use_time = 0
	if speed_learned and speed_learned_round < 0:
		speed_learned_round = rounds_started
	# Rebuild reminders from persisted learning state, including previously dismissed ones.
	pending_shortcuts.erase("speed")
	pending_shortcuts.erase("freeze")
	if rounds_started >= 2 and not speed_learned and "speed" not in pending_shortcuts:
		pending_shortcuts.append("speed")
	if speed_learned and not freeze_learned and rounds_started >= speed_learned_round + 2:
		pending_shortcuts.append("freeze")
	shortcut_popup = not pending_shortcuts.is_empty()
	tutorial_cell = Vector2i(-999, -999)
	block_shakes.clear()
	mode = "playing"
	for row in terrain_rows.values():
		row.queue_free()
	terrain_rows.clear()
	placement_effects.clear()
	placement_contacts.clear()
	placement_held = false
	depot.visible = false
	inventory_open = false
	frozen_toggle = false
	space_held = false
	speed_held = false
	speed_toggle = false
	mouse_held = false
	mining_needs_release = true
	stroke_contacts.clear()
	drops.clear()
	enemies.clear()
	particles.clear()
	pickup_flights.clear()
	death_flights.clear()
	death_ore_queue.clear()
	death_shake_count = 0
	world.reset(selected_depth)
	update_terrain_cache()
	best_depth = maxi(best_depth, selected_depth)
	player = Vector2(240, 180)
	player_velocity = Vector2.ZERO
	direction = 1
	grounded = false
	turn_timer = 0
	pending_direction = 0
	edge_timer = 0
	noticed_edge = Vector2i(-999, -999)
	ledge_committed = false
	walk_cycle = 0
	footstep_index = 0
	player_lean = 0
	facing_blend = 1
	landing_squash = 0
	fall_distance = 0
	peak_fall_speed = 0
	landing_rings.clear()
	spike_height = 0
	lives = max_lives()
	hit_grace = 0
	spike_cooldown = 0
	full_banner_time = 0
	full_bag_time = 0
	leave_glow = false
	full_was_full = false
	blocks_left = 3 + upgrades.blocks
	block_counter_pulse = 0
	floating_texts.clear()
	run_time = 0
	shake = 0
	flash = 0
	spawn_enemies()
	show_toast("The miner walks on his own. Dig a path below him.", 5)
	synth.play_sound("ui")
	save_progress()

func capacity() -> int:
	return 7 + upgrades.capacity

func max_lives() -> int:
	return 1 + upgrades.lives

func max_speed() -> int:
	return 2 + upgrades.speed

func inventory_count() -> int:
	var count := 0
	for amount in inventory:
		count += amount
	return count

func haul_value() -> int:
	var value := 0
	for i in range(inventory.size()):
		value += inventory[i] * MineCatalog.ORES[i].value
	return value

func current_depth() -> int:
	return maxi(selected_depth, selected_depth + floori((world.scroll + player.y - MineWorld.START_Y) / TILE))

func is_frozen() -> bool:
	return frozen_toggle or space_held

func game_speed() -> float:
	return float(clampi(selected_speed, 1, max_speed())) if speed_held or speed_toggle else 1.0

func show_toast(message: String, duration: float = 2.5) -> void:
	toast = message
	toast_time = duration

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		debug_keys.clear()
		mouse_held = false
		placement_held = false
		placement_contacts.clear()
		space_held = false
		speed_held = false
		stroke_contacts.clear()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		save_progress()

func _input(event: InputEvent) -> void:
	if handle_debug_input(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mining_needs_release = false
		mouse_held = false
		stroke_contacts.clear()
	var previous_cursor := cursor_position
	if event is InputEventMouse:
		cursor_position = event.position
	if mode != "playing":
		return
	if inventory_open and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		inventory_scroll = clampi(inventory_scroll + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, visible_ores().size() - 15))
		return
	if shortcut_popup:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Rect2(160, 410, 160, 44).has_point(cursor_position):
			pending_shortcuts.pop_front()
			shortcut_popup = not pending_shortcuts.is_empty()
			save_progress()
		return
	if tutorial_cell.x != -999:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			place_block(cursor_position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		placement_held = event.pressed and not inventory_open
		placement_contacts.clear()
		if placement_held:
			place_drag_at(cursor_position)
		return
	if event is InputEventKey:
		if event.keycode == KEY_W:
			speed_held = event.pressed
			if not event.pressed:
				speed_hold_time = 0
		if event.keycode == KEY_SPACE:
			if event.pressed and not space_held and not inventory_open:
				synth.play_sound("freeze")
			space_held = event.pressed
			if not event.pressed and not frozen_toggle:
				freeze_use_time = 0
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_E, KEY_ESCAPE:
					toggle_inventory()
				KEY_M:
					synth.muted = not synth.muted
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			mouse_held = false
			stroke_contacts.clear()
			return
		var mouse := cursor_position
		if bag_rect.has_point(mouse):
			toggle_inventory()
		elif home_button_rect().has_point(mouse):
			leave_glow = false
			begin_departure()
		elif freeze_rect.has_point(mouse):
			toggle_freeze()
		elif speed_rect.has_point(mouse):
			speed_toggle = not speed_toggle
			synth.play_sound("ui")
		elif inventory_open:
			if Rect2(402, MineWorld.TOP + 30, 30, 30).has_point(mouse):
				toggle_inventory()
			else:
				var ores := satchel_ores()
				for slot in range(ores.size()):
					if discard_rect(slot).has_point(mouse):
						discard_ore(ores[slot])
						break
		elif mouse.y >= MineWorld.TOP and mouse.y < MineWorld.BOTTOM:
			mouse_held = true
			stroke_contacts.clear()
			mine_at(mouse)
	if event is InputEventMouseMotion and mouse_held and not inventory_open:
		mine_at(cursor_position)
	if event is InputEventMouseMotion and placement_held and not inventory_open:
		var samples := maxi(1, ceili(previous_cursor.distance_to(cursor_position) / (TILE * 0.25)))
		for step in range(1, samples + 1):
			place_drag_at(previous_cursor.lerp(cursor_position, float(step) / samples))

func toggle_inventory() -> void:
	inventory_open = not inventory_open
	mouse_held = false
	placement_held = false
	placement_contacts.clear()
	stroke_contacts.clear()
	synth.play_sound("ui")

func toggle_freeze() -> void:
	frozen_toggle = not frozen_toggle
	synth.play_sound("freeze")
	show_toast("Time frozen. You can still dig." if is_frozen() else "The descent continues.")

func _physics_process(delta: float) -> void:
	ui_time += delta
	for cell in block_shakes.keys():
		block_shakes[cell] -= delta
		invalidate_terrain_row(cell.y)
		if block_shakes[cell] <= 0:
			block_shakes.erase(cell)
	if shortcut_popup or tutorial_cell.x != -999:
		speed_hold_time = 0
		freeze_use_time = 0
		return
	block_counter_pulse = maxf(0, block_counter_pulse - delta)
	if mode == "playing" and not inventory_open:
		for cell in placement_effects.keys():
			placement_effects[cell] += delta
			invalidate_terrain_row(cell.y)
			if placement_effects[cell] >= 0.12:
				placement_effects.erase(cell)
	if mode == "leaving":
		var previous_departure := departure_time
		departure_time += delta
		var float_start := DEPARTURE_BEAM + DEPARTURE_WAIT
		if previous_departure < float_start and departure_time >= float_start:
			synth.play_sound("departure_float", -2)
		var close_start := DEPARTURE_BEAM + DEPARTURE_WAIT + DEPARTURE_FLOAT
		if previous_departure < close_start and departure_time >= close_start:
			synth.play_sound("departure_close", -2)
		var float_age := maxf(0, departure_time - DEPARTURE_BEAM - DEPARTURE_WAIT)
		var lift := float_age / DEPARTURE_FLOAT
		player = departure_origin + Vector2(0, -48 * lift)
		player_lean = -0.16 * smoothstep(0, 1, minf(1, lift))
		if departure_time >= DEPARTURE_END:
			finish_expedition(false)
		queue_redraw()
		return
	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i].age += delta
		if floating_texts[i].age > 1.2:
			floating_texts.remove_at(i)
	full_banner_time = maxf(0, full_banner_time - delta)
	hit_grace = maxf(0, hit_grace - delta)
	spike_cooldown = maxf(0, spike_cooldown - delta)
	if mode == "dying":
		advance_death(delta)
		queue_redraw()
		return
	if mode != "playing":
		queue_redraw()
		return
	check_full_inventory()
	if inventory_count() >= capacity():
		full_bag_time += delta
	else:
		full_bag_time = 0
	if not inventory_open and is_frozen() and not freeze_learned:
		freeze_use_time += delta
		if freeze_use_time > 1.5:
			freeze_learned = true
			save_progress()
	elif not is_frozen() or inventory_open:
		freeze_use_time = 0
	if mouse_held and not inventory_open:
		mine_at(cursor_position)
	if not inventory_open:
		toast_time = maxf(0, toast_time - delta)
		bag_pulse = maxf(0, bag_pulse - delta)
		full_notice = maxf(0, full_notice - delta)
	if not inventory_open and not is_frozen():
		if speed_held and game_speed() > 1 and not speed_learned:
			speed_hold_time += delta
			if speed_hold_time > 1.5:
				speed_learned = true
				speed_learned_round = rounds_started
				save_progress()
		var multiplier := game_speed()
		var steps := maxi(1, ceili(delta * multiplier * 60))
		for step in range(steps):
			simulate_step(delta * multiplier / steps)
			if mode != "playing" or tutorial_cell.x != -999:
				break
	else:
		speed_hold_time = 0
	queue_redraw()

func simulate_step(delta: float) -> void:
	time += delta
	run_time += delta
	var rise_speed := minf(12.0, 4.5 + current_depth() * 0.004) * 2.5
	var rise := world.advance(delta, rise_speed)
	var carried_speed := rise / maxf(delta, 0.000001)
	player.y -= rise
	spawn_enemies()
	update_player(delta)
	if mode != "playing" or tutorial_cell.x != -999:
		return
	update_drops(delta, carried_speed)
	update_enemies(delta, carried_speed)
	if mode != "playing":
		return
	update_spikes(delta)
	if mode != "playing":
		return
	update_particles(delta)
	update_landing_rings(delta, carried_speed)
	update_pickups(delta)
	shake = maxf(0, shake - delta * 12)
	flash = maxf(0, flash - delta * 3)
	best_depth = maxi(best_depth, current_depth())
	run_peak = maxi(run_peak, current_depth())

func mine_at(mouse: Vector2) -> void:
	if mode != "playing" or inventory_open or mining_needs_release:
		return
	var current: Dictionary = {}
	if mouse.y < MineWorld.TOP or mouse.y >= MineWorld.BOTTOM:
		stroke_contacts = current
		return
	var first := world.cell_at(mouse - Vector2.ONE * DIG_RADIUS)
	var last := world.cell_at(mouse + Vector2.ONE * DIG_RADIUS)
	var hit_any := false
	var broke_any := false
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not world.blocks.has(cell):
				continue
			var pos := world.cell_position(cell)
			if pos.y < MineWorld.TOP - TILE or pos.y >= MineWorld.BOTTOM:
				continue
			var nearest := mouse.clamp(pos, pos + Vector2(TILE, TILE))
			if nearest.distance_squared_to(mouse) > DIG_RADIUS * DIG_RADIUS:
				continue
			current[cell] = true
			if stroke_contacts.has(cell):
				continue
			hit_any = true
			block_shakes[cell] = 0.18
			var spike_height_before: float = world.floor_spikes.get(cell, {}).get("height", 0.0)
			var result := world.hit(cell, 1 + upgrades.power)
			placement_effects.erase(cell)
			invalidate_terrain_row(cell.y)
			var center := pos + Vector2.ONE * TILE * 0.5
			if result.has("damaged"):
				emit_debris(center, Color("9b8e72"), 3)
			else:
				broke_any = true
				if result.get("treasure", false):
					run_treasure_count += 1
					if not treasure_seen:
						run_first_treasure = true
						treasure_seen = true
					credits += int(result.treasure_coins)
					show_toast("Treasure cache: +%d coins" % result.treasure_coins)
					synth.play_sound("coin")
					save_progress()
				if spike_height_before > 0:
					for tooth in range(3):
						emit_debris(pos + Vector2(7 + tooth * 9, -spike_height_before * 0.5), Color("eedbc3"), 4)
				emit_debris(center, Color("958468"), 6)
				if result.get("ore", -1) >= 0:
					var angle := rng.randf_range(-2.3, -0.8)
					drops.append({"pos": center, "vel": Vector2.from_angle(angle) * rng.randf_range(38, 80), "ore": result.ore, "rotation": rng.randf_range(-PI, PI), "age": 0.0})
	stroke_contacts = current
	if hit_any:
		synth.play_sound("break_block" if broke_any else "hit")

func place_block(mouse: Vector2) -> bool:
	if mode != "playing" or inventory_open or mouse.y < MineWorld.TOP or mouse.y >= MineWorld.BOTTOM or mouse.x < 0 or mouse.x >= 480:
		return false
	if blocks_left <= 0:
		block_counter_pulse = 0.5
		floating_texts.append({"pos": mouse, "age": 0.0})
		return false
	var cell := world.cell_at(mouse)
	if not can_place_block(mouse):
		return false
	if tutorial_cell.x != -999 and cell != tutorial_cell:
		return false
	var health := MineWorld.block_health(world.base_depth + cell.y)
	world.blocks[cell] = {"hp": health, "max_hp": health, "ore": -1, "variant": 0, "placed": true}
	placement_effects[cell] = 0.0
	invalidate_terrain_row(cell.y)
	blocks_left -= 1
	if cell == tutorial_cell:
		placement_taught = true
		tutorial_cell = Vector2i(-999, -999)
		save_progress()
	emit_debris(world.cell_position(cell) + Vector2(16, 24), MineWorld.block_color(cell, world.base_depth), 5)
	synth.play_sound("place", -5, rng.randf_range(0.92, 1.08))
	return true

func can_place_block(mouse: Vector2) -> bool:
	if mode != "playing" or inventory_open or mouse.y < MineWorld.TOP or mouse.y >= MineWorld.BOTTOM or mouse.x < 0 or mouse.x >= 480 or blocks_left <= 0:
		return false
	var cell := world.cell_at(mouse)
	var rect := Rect2(world.cell_position(cell), Vector2.ONE * TILE)
	if world.solid(cell) or world.lava.has(cell) or rect.intersects(Rect2(player - Vector2(12, 16), Vector2(24, 32))):
		return false
	for enemy in enemies:
		if rect.intersects(Rect2(enemy.pos - Vector2(12, 12), Vector2(24, 24))):
			return false
	return true

func place_drag_at(mouse: Vector2) -> void:
	var cell := world.cell_at(mouse)
	if placement_contacts.has(cell):
		return
	placement_contacts[cell] = true
	place_block(mouse)

func invalidate_terrain_row(row: int) -> void:
	if terrain_rows.has(row):
		terrain_rows[row].queue_redraw()

func update_terrain_cache() -> void:
	if not is_instance_valid(terrain_root):
		return
	var first := maxi(0, world.cell_at(Vector2(0, MineWorld.TOP - TILE)).y)
	var last := world.cell_at(Vector2(0, 800 + TILE)).y
	for row in terrain_rows.keys():
		if row < first or row > last:
			terrain_rows[row].queue_free()
			terrain_rows.erase(row)
	for row in range(first, last + 1):
		if not terrain_rows.has(row):
			var visual := Node2D.new()
			visual.set_script(preload("res://scripts/terrain_row.gd"))
			visual.game = self
			visual.row = row
			visual.use_parent_material = true
			terrain_root.add_child(visual)
			terrain_rows[row] = visual
		terrain_rows[row].position.y = MineWorld.START_Y + row * TILE - world.scroll
	terrain_root.position = camera_offset()

func move_body(pos: Vector2, velocity: Vector2, half: Vector2, delta: float) -> Dictionary:
	var hit_x := false
	var hit_y := false
	var steps := maxi(1, ceili(velocity.length() * delta / 3.0))
	var step := velocity * delta / steps
	for i in range(steps):
		var next := pos + Vector2(step.x, 0)
		if not world.collides(Rect2(next - half, half * 2)):
			pos.x = next.x
		elif absf(step.x) > 0.0001:
			hit_x = true
			var edge := world.cell_at(next + Vector2(half.x if step.x > 0 else -half.x, 0))
			pos.x = edge.x * TILE - half.x if step.x > 0 else (edge.x + 1) * TILE + half.x
		next = pos + Vector2(0, step.y)
		if not world.collides(Rect2(next - half, half * 2)):
			pos.y = next.y
		elif absf(step.y) > 0.0001:
			hit_y = true
			var edge := world.cell_at(next + Vector2(0, half.y if step.y > 0 else -half.y))
			var boundary := world.cell_position(edge).y
			pos.y = boundary - half.y if step.y > 0 else boundary + TILE + half.y
	return {"pos": pos, "hit_x": hit_x, "hit_y": hit_y}

func update_player(delta: float) -> void:
	var before := player
	var was_grounded := grounded
	var supported := world.collides(Rect2(player + Vector2(-11.99, 16), Vector2(23.98, 0.75)))
	landing_squash = move_toward(landing_squash, 0, delta * 1.9)
	if pending_direction != 0:
		turn_timer = maxf(0, turn_timer - delta)
		if turn_timer <= 0:
			direction = pending_direction
			pending_direction = 0
			ledge_committed = false
	if edge_timer > 0:
		edge_timer = maxf(0, edge_timer - delta) if supported else 0.0
	if was_grounded and supported and pending_direction == 0 and not ledge_committed:
		var ledge := upcoming_ledge()
		if not ledge.is_empty() and not placement_taught and blocks_left > 0:
			var center_x := world.cell_position(ledge.cell).x + TILE * 0.5
			if (center_x - player.x) * direction <= absf(player_velocity.x) * delta + 1 and dangerous_drop(ledge):
				player.x = center_x
				tutorial_cell = ledge.cell + Vector2i(direction, -1)
				player_velocity.x = 0
				return
		if not ledge.is_empty() and ledge.distance <= 2.0 + absf(player_velocity.x) * delta:
			noticed_edge = ledge.cell
			ledge_committed = true
			if hesitation_rng.randf() < HESITATION_CHANCE:
				player.x = ledge.drop_x - direction * 2.0
				edge_timer = EDGE_PAUSE
				player_velocity.x = 0
	var paused := pending_direction != 0 or edge_timer > 0
	var target_speed := 0.0 if paused else WALK_SPEED * direction
	player_velocity.x = move_toward(player_velocity.x, target_speed, WALK_ACCELERATION * delta)
	player_velocity.y = minf(MAX_FALL_SPEED, player_velocity.y + GRAVITY * delta)
	var impact_speed := player_velocity.y
	var motion := move_body(player, player_velocity, Vector2(12, 16), delta)
	player = motion.pos
	if motion.hit_x and pending_direction == 0:
		pending_direction = -direction
		turn_timer = TURN_PAUSE
		player_velocity.x = 0
	grounded = motion.hit_y and impact_speed > 0
	if grounded:
		var landing_distance := fall_distance + maxf(0, player.y - before.y)
		if not was_grounded and landing_distance > 4:
			land_player(landing_distance, maxf(peak_fall_speed, impact_speed))
		if not was_grounded and landing_distance > 2:
			noticed_edge = Vector2i(-999, -999)
			ledge_committed = false
		fall_distance = 0
		peak_fall_speed = 0
	else:
		fall_distance += maxf(0, player.y - before.y)
		peak_fall_speed = maxf(peak_fall_speed, impact_speed)
	if motion.hit_y:
		player_velocity.y = 0
	var moved := absf(player.x - before.x)
	if grounded:
		walk_cycle += moved / 24.0 * TAU
		var step_index := floori(walk_cycle / PI)
		if step_index != footstep_index:
			footstep_index = step_index
			synth.play_sound("step", -15, 0.95 if step_index % 2 == 0 else 1.05)
			if step_index % 2 == 0 and moved > 0:
				emit_landing_dust(0.0, 1)
	var lean := sin(walk_cycle) * 0.025 * minf(1, absf(player_velocity.x) / WALK_SPEED)
	if pending_direction != 0:
		lean = -direction * 0.16
	elif edge_timer > 0:
		lean = direction * 0.14
	elif not grounded:
		lean = direction * 0.035
	player_lean = lerpf(player_lean, lean, 1.0 - exp(-delta * 20))
	facing_blend = lerpf(facing_blend, direction, 1.0 - exp(-delta * 18))
	if world.touches_lava(Rect2(player - Vector2(10, 14), Vector2(20, 28))):
		if hit_grace <= 0:
			if lives > 1:
				world.clear_lava_contact(Rect2(player - Vector2(10, 14), Vector2(20, 28)))
			lose_life("Caught in a lava spill")
	elif world.touches_floor_spikes(Rect2(player - Vector2(10, 14), Vector2(20, 30))):
		if hit_grace <= 0:
			if lives > 1:
				world.clear_spike_contact(Rect2(player - Vector2(10, 14), Vector2(20, 30)))
			lose_life("Caught on cave spikes")
	elif player.y < MineWorld.TOP + 15:
		lose_life("Caught by the rising mine", true)
	elif player.y > MineWorld.BOTTOM + 16:
		lose_life("Lost beneath the mine", true)

func upcoming_ledge() -> Dictionary:
	var first := world.cell_at(player + Vector2(-11.99, 16.25))
	var last := world.cell_at(player + Vector2(11.99, 16.25))
	var support_x := -999 if direction > 0 else 999
	for x in range(first.x, last.x + 1):
		if world.solid(Vector2i(x, first.y)):
			support_x = maxi(support_x, x) if direction > 0 else mini(support_x, x)
	if absi(support_x) == 999:
		return {}
	var drop_x := (support_x + 1) * TILE + 12.0 if direction > 0 else support_x * TILE - 12.0
	var after_drop := Vector2(drop_x + direction * 0.05, player.y)
	if world.collides(Rect2(after_drop + Vector2(-11.99, 16), Vector2(23.98, 0.75))):
		return {}
	return {"cell": Vector2i(support_x, first.y), "drop_x": drop_x, "distance": (drop_x - player.x) * direction}

func dangerous_drop(ledge: Dictionary) -> bool:
	var cell: Vector2i = ledge.cell + Vector2i(direction, 0)
	if not can_place_block(world.cell_position(cell + Vector2i.UP) + Vector2(16, 16)):
		return false
	var point := world.cell_position(cell) + Vector2(16, -16)
	for step in range(80):
		var body := Rect2(point + Vector2(-10, -14), Vector2(20, 30))
		if world.touches_floor_spikes(body) or world.touches_lava(body) or body.end.y >= MineWorld.BOTTOM - 16:
			return true
		for enemy in enemies:
			if body.intersects(Rect2(enemy.pos - Vector2(12, 12), Vector2(24, 24))):
				return true
		if world.collides(body):
			return false
		point.y += 8
	return false

func draw_tutorial() -> void:
	if tutorial_cell.x != -999:
		var rect := Rect2(world.cell_position(tutorial_cell), Vector2.ONE * TILE)
		draw_rect(rect, Color(1, 0.85, 0, 0.45 + 0.15 * sin(ui_time * 6)))
		MineInk.outline(self, rect, Color.YELLOW)
		MineInk.centered(self, "Right click to place block", 320, 22, Color.WHITE)
	if shortcut_popup:
		draw_rect(Rect2(0, 0, 480, 800), Color(0, 0, 0, 0.8))
		MineInk.panel(self, Rect2(24, 294, 432, 182))
		var message := "You can press space to freeze the game" if pending_shortcuts[0] == "freeze" else "You can hold W to speed up the game"
		var line := ""
		var y := 342.0
		for word in message.split(" "):
			var next := word if line.is_empty() else line + " " + word
			if MineInk.FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > 388:
				MineInk.centered(self, line, y, 15, Color.WHITE)
				y += 26
				line = word
			else:
				line = next
		MineInk.centered(self, line, y, 15, Color.WHITE)
		MineInk.button(self, Rect2(160, 410, 160, 44), "Confirm", true, false)

func land_player(distance: float, impact_speed: float) -> void:
	var strength := clampf((distance - 8) / 170.0, 0, 1)
	landing_squash = 0.10 + strength * 0.26
	emit_landing_dust(strength, 3 + roundi(strength * 10))
	landing_rings.append({"pos": player + Vector2(0, 15), "age": 0.0, "strength": strength})
	synth.play_sound("land", lerpf(-12, -1, strength), lerpf(1.2, 0.85, strength))
	if distance > TILE * 2 and impact_speed > 220:
		shake = maxf(shake, lerpf(0.6, 2.8, strength))

func emit_landing_dust(strength: float, count: int) -> void:
	var color := MineWorld.region_color(current_depth(), "rock").lightened(0.25)
	for i in range(count):
		particles.append({"pos": player + Vector2(rng.randf_range(-12, 12), 14), "vel": Vector2(rng.randf_range(-35, 35) * (1 + strength), rng.randf_range(-38, -12) * (1 + strength)), "life": rng.randf_range(0.18, 0.4), "color": color, "size": rng.randf_range(1, 2.5)})

func update_landing_rings(delta: float, rise_speed: float) -> void:
	for i in range(landing_rings.size() - 1, -1, -1):
		landing_rings[i].age += delta
		landing_rings[i].pos.y -= rise_speed * delta
		if landing_rings[i].age > 0.32:
			landing_rings.remove_at(i)
func update_drops(delta: float, rise_speed: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var drop := drops[i]
		drop.pos.y -= rise_speed * delta
		drop.age += delta
		drop.vel.y = minf(230, drop.vel.y + GRAVITY * delta)
		var motion := move_body(drop.pos, drop.vel, Vector2(6, 8), delta)
		drop.pos = motion.pos
		if motion.hit_y:
			drop.vel.y = -drop.vel.y * 0.18 if drop.vel.y > 35 else 0.0
			drop.vel.x *= 0.78
		if motion.hit_x:
			drop.vel.x *= -0.5
		var touching: bool = drop.pos.distance_to(player) < 25
		if touching:
			if inventory_count() < capacity():
				inventory[drop.ore] += 1
				check_full_inventory()
				pickup_flights.append({"start": drop.pos, "ore": drop.ore, "t": 0.0})
				synth.play_sound("pickup")
				drops.remove_at(i)
				continue
			elif not drop.get("touching_player", false):
				show_inventory_full()
		drop.touching_player = touching
		if drop.pos.y < MineWorld.TOP - 32 or drop.pos.y > MineWorld.BOTTOM + 80 or world.touches_lava(Rect2(drop.pos - Vector2(2, 2), Vector2(4, 4))):
			drops.remove_at(i)

func spawn_enemies() -> void:
	var pending: Array[Dictionary] = []
	for spawn in world.spawn_queue:
		var pos := world.cell_position(spawn.cell) + Vector2.ONE * TILE * 0.5
		if pos.y > MineWorld.BOTTOM + 128:
			pending.append(spawn)
			continue
		if pos.y < MineWorld.TOP - 40 or pos.distance_to(player) < 90 or world.solid(spawn.cell):
			continue
		enemies.append({"pos": pos, "vel": Vector2.ZERO, "type": spawn.type, "dir": -1 if rng.randf() < 0.5 else 1, "clock": rng.randf_range(0, 5), "ground": false, "anchor": pos.x})
	world.spawn_queue = pending

func update_enemies(delta: float, rise_speed: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		enemy.pos.y -= rise_speed * delta

		if enemy.pos.y < MineWorld.TOP - 40 or enemy.pos.y > MineWorld.BOTTOM + 440:
			enemies.remove_at(i)
			continue
		var data: Dictionary = MineCatalog.ENEMIES[enemy.type]
		var support := world.cell_at(enemy.pos + Vector2(0, 13))
		var supported := world.solid(support)
		var left_blocked := not world.solid(support + Vector2i.LEFT) or world.solid(support + Vector2i(-1, -1))
		var right_blocked := not world.solid(support + Vector2i.RIGHT) or world.solid(support + Vector2i(1, -1))
		enemy.still = data.kind not in ["bat", "wisp", "eye"] and supported and left_blocked and right_blocked
		if enemy.still:
			enemy.vel = Vector2.ZERO
			enemy.ground = true
		else:
			enemy.clock += delta
			var offset: Vector2 = player - enemy.pos
			var speed: float = data.speed
			var was_grounded: bool = enemy.ground
			enemy.vel.x = enemy.dir * speed
			enemy.vel.y = minf(200, enemy.vel.y + GRAVITY * delta)
			match data.kind:
				"slime":
					enemy.vel.x *= 0.5 if enemy_pose(enemy.clock, 2) == 0 else 1.0
					if was_grounded and fmod(enemy.clock, 3.4) < delta:
						enemy.vel.y = -70
				"beetle":
					if was_grounded and not world.solid(world.cell_at(enemy.pos + Vector2(enemy.dir * 23, 26))):
						enemy.dir *= -1
				"bat":
					enemy.vel.y = -23 if enemy_pose(enemy.clock, 1) == 0 else 23
				"hopper":
					if was_grounded and fmod(enemy.clock, 1.6) < delta:
						enemy.vel.y = -130
						enemy.dir = 1 if offset.x > 0 else -1
				"spider":
					enemy.vel.x *= 1.7 if fmod(enemy.clock, 2.5) < 0.5 else 0.45
				"wisp":
					enemy.vel = offset.normalized() * speed if offset.length() < 140 else Vector2(-speed if enemy_pose(enemy.clock, 1) == 0 else speed, -15 if enemy_pose(enemy.clock, 2) == 0 else 15)
				"crab":
					if absf(offset.x) < 110 and absf(offset.y) < 25:
						enemy.dir = 1 if offset.x > 0 else -1
						enemy.vel.x = enemy.dir * speed * 2.1
				"worm":
					enemy.vel.x *= 0.45 if enemy_pose(enemy.clock, 3) == 0 else 1.35
					if was_grounded and fmod(enemy.clock, 2.2) < delta:
						enemy.vel.y = -95
				"eye":
					var target := player + Vector2(-25 if enemy_pose(enemy.clock, 1) == 0 else 25, -20)
					enemy.vel = (target - enemy.pos).normalized() * speed
				"sentinel":
					if offset.length() < 170:
						enemy.dir = 1 if offset.x > 0 else -1
						enemy.vel.x = enemy.dir * speed * (2.0 if fmod(enemy.clock, 3) < 0.6 else 0.65)
					if was_grounded and fmod(enemy.clock, 1.2) < delta:
						enemy.vel.y = -145
			match data.get("behavior", ""):
				"graze":
					if fmod(enemy.clock, 3.5) < 1.2:
						enemy.vel.x = 0
				"shy":
					if offset.length() < 120:
						enemy.dir = -1 if offset.x > 0 else 1
						enemy.vel.x = enemy.dir * speed * 1.4
				"charge":
					if absf(offset.x) < 170:
						enemy.dir = 1 if offset.x > 0 else -1
						enemy.vel.x = enemy.dir * speed * (0.0 if fmod(enemy.clock, 3.0) < 0.7 else 1.8)
				"bound":
					if was_grounded and fmod(enemy.clock, 1.8) < delta:
						enemy.vel.y = -125
				"herd":
					if absf(enemy.pos.x - enemy.get("anchor", enemy.pos.x)) > 70:
						enemy.dir = 1 if enemy.pos.x < enemy.get("anchor", enemy.pos.x) else -1
						enemy.vel.x = enemy.dir * speed
				"glide":
					enemy.vel.y = sin(enemy.clock * 1.5) * 20
			var motion := move_body(enemy.pos, enemy.vel, Vector2(12, 12), delta)
			enemy.pos = motion.pos
			enemy.ground = motion.hit_y and enemy.vel.y > 0
			if motion.hit_y:
				enemy.vel.y = 0
			if motion.hit_x:
				enemy.dir *= -1
				if data.kind == "spider":
					enemy.pos.y -= 1.0
		if world.touches_lava(Rect2(enemy.pos - Vector2(5, 5), Vector2(10, 10))) and data.kind not in ["wisp", "sentinel"]:
			emit_debris(enemy.pos, Color(data.color), 5)
			enemies.remove_at(i)
			continue
		if hit_grace <= 0 and absf(player.x - enemy.pos.x) < 21 and absf(player.y - enemy.pos.y) < 26:
			synth.play_sound("enemy_hit", -2)
			if lives > 1:
				enemies.remove_at(i)
			lose_life("Caught by a %s" % data.name.to_lower())
			return

func update_spikes(delta: float) -> void:
	if spike_cooldown > 0:
		spike_height = 0
		return
	var target := clampf((player.y - (MineWorld.BOTTOM - 98)) * 0.8, 0, 16)
	spike_height = clampf(move_toward(spike_height, target, delta * (58 if target > spike_height else 20)), 0, 16)
	if hit_grace <= 0 and spike_height > 3 and player.y + 15 >= MineWorld.BOTTOM - spike_height:
		if lives > 1:
			spike_height = 0
			spike_cooldown = 1.5
		lose_life("Caught by the bottom spikes", true)

func emit_debris(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		particles.append({"pos": pos + Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5)), "vel": Vector2(rng.randf_range(-65, 65), rng.randf_range(-85, -15)), "life": rng.randf_range(0.25, 0.55), "color": color, "size": rng.randf_range(1, 3)})
	# Frozen mining may create lots of debris; keep memory bounded.
	while particles.size() > 450:
		particles.pop_front()

func update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		p.life -= delta
		p.vel.y += 190 * delta
		p.pos += p.vel * delta
		if p.life <= 0:
			particles.remove_at(i)

func update_pickups(delta: float) -> void:
	for i in range(pickup_flights.size() - 1, -1, -1):
		pickup_flights[i].t += delta / 0.65
		if pickup_flights[i].t >= 1:
			pickup_flights.remove_at(i)
			bag_pulse = 0.3

func check_full_inventory() -> void:
	var full := inventory_count() >= capacity()
	if full and not full_was_full:
		full_bag_time = 0
		show_inventory_full()
	full_was_full = full

func show_inventory_full() -> void:
	full_banner_time = 2.0
	full_banner_y = MineWorld.TOP + 12 if player.y > 400 else MineWorld.BOTTOM - 94
	leave_glow = true

func lose_life(reason: String, rescue: bool = false) -> void:
	if mode != "playing" or hit_grace > 0:
		return
	lives = maxi(0, lives - 1)
	if lives == 0:
		die(reason)
		return
	hit_grace = 0.65
	shake = 2.2
	synth.play_sound("death_shake", -5, 1.2)
	if rescue:
		rescue_player()

func rescue_player() -> void:
	var best := Vector2.INF
	var distance := INF
	for cell: Vector2i in world.blocks:
		var pos := world.cell_position(cell) + Vector2(TILE * 0.5, -16)
		if pos.y < 160 or pos.y > 630:
			continue
		var body := Rect2(pos - Vector2(12, 16), Vector2(24, 32))
		if world.collides(body) or world.touches_lava(body) or world.touches_floor_spikes(body):
			continue
		if pos.distance_squared_to(player) < distance:
			distance = pos.distance_squared_to(player)
			best = pos
	if best == Vector2.INF:
		best = Vector2(clampf(player.x, 48, 432), 352)
		var center := world.cell_at(best)
		for y in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				var cell := Vector2i(x, y)
				world.blocks.erase(cell)
				world.lava.erase(cell)
				world.floor_spikes.erase(cell)
		var floor_cell := center + Vector2i.DOWN
		world.blocks[floor_cell] = {"hp": 2, "ore": -1, "variant": 0}
		best = world.cell_position(floor_cell) + Vector2(TILE * 0.5, -16)
	player = best
	player_velocity = Vector2.ZERO
	grounded = true
	fall_distance = 0
	peak_fall_speed = 0

func retained_inventory() -> Array[int]:
	var kept: Array[int] = []
	kept.resize(inventory.size())
	kept.fill(0)
	var remaining: int = 3 + upgrades.insurance
	var valuable_first := range(MineCatalog.ORES.size())
	valuable_first.sort_custom(func(a: int, b: int) -> bool: return MineCatalog.ORES[a].value > MineCatalog.ORES[b].value)
	for i in valuable_first:
		kept[i] = mini(remaining, inventory[i])
		remaining -= kept[i]
	return kept
func die(reason: String) -> void:
	if mode != "playing":
		return
	mode = "dying"
	run_peak = maxi(run_peak, current_depth())
	lives = 0
	death_reason = reason
	death_time = 0
	death_arc_sound_played = false
	death_origin = player
	death_shake_count = 0
	death_shakes_total = inventory_count() if inventory_count() < 3 else rng.randi_range(3, 4)
	inventory_open = false
	mouse_held = false
	speed_held = false
	stroke_contacts.clear()
	death_flights.clear()
	death_ore_queue.clear()
	pickup_flights.clear()
	landing_rings.clear()
	shake = 0
	var kept := retained_inventory()
	death_kept = 0
	death_lost = 0
	for i in range(inventory.size()):
		death_kept += kept[i]
		death_lost += inventory[i] - kept[i]
		for piece in range(inventory[i] - kept[i]):
			death_ore_queue.append(i)
	for i in range(death_ore_queue.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var ore := death_ore_queue[i]
		death_ore_queue[i] = death_ore_queue[other]
		death_ore_queue[other] = ore
	inventory = kept
	save_progress()

func death_transition_start() -> float:
	return death_shakes_total * DEATH_SHAKE_INTERVAL + 0.6

func death_duration() -> float:
	return death_transition_start() + DEATH_IRIS_DURATION + DEATH_IRIS_HOLD + DEATH_FINAL_CLOSE + DEATH_BLACK_HOLD

func death_iris_progress() -> float:
	var elapsed := death_time - death_transition_start()
	if elapsed <= 0:
		return 0
	if elapsed < DEATH_IRIS_DURATION:
		return smoothstep(0, 1, elapsed / DEATH_IRIS_DURATION) * 0.94
	if elapsed < DEATH_IRIS_DURATION + DEATH_IRIS_HOLD:
		return 0.94
	return lerpf(0.94, 1, smoothstep(0, 1, clampf((elapsed - DEATH_IRIS_DURATION - DEATH_IRIS_HOLD) / DEATH_FINAL_CLOSE, 0, 1)))

func advance_death(delta: float) -> void:
	death_time += delta
	var arc_age := maxf(0, death_time - death_transition_start() - DEATH_IRIS_DURATION - 0.2)
	if arc_age > 0 and not death_arc_sound_played:
		death_arc_sound_played = true
		synth.play_sound("death_arc", -2)
	player = death_origin + Vector2(direction * 65 * arc_age, -260 * arc_age + 700 * arc_age * arc_age)
	player_lean = direction * arc_age * 0.45
	while death_shake_count < death_shakes_total and death_time + 0.000001 >= (death_shake_count + 1) * DEATH_SHAKE_INTERVAL:
		var remaining_shakes := death_shakes_total - death_shake_count
		var count := ceili(float(death_ore_queue.size()) / remaining_shakes)
		death_shake_count += 1
		var born := death_shake_count * DEATH_SHAKE_INTERVAL
		for piece in range(count):
			var ore: int = death_ore_queue.pop_back()
			death_flights.append({"ore": ore, "born": born, "velocity": Vector2(rng.randf_range(-85, 85), rng.randf_range(-80, -25)), "offset": Vector2(rng.randf_range(-5, 5), rng.randf_range(-3, 4))})
		synth.play_sound("death_shake", -2, 0.94 + death_shake_count * 0.04)
	if death_time >= death_duration():
		finish_expedition(true)

func camera_offset() -> Vector2:
	if mode != "dying":
		return MineInk.snap(Vector2(sin(time * 61), cos(time * 53)) * shake)
	if death_shake_count == 0:
		return Vector2.ZERO
	var age := death_time - death_shake_count * DEATH_SHAKE_INTERVAL
	var strength := 5.0 * clampf(1.0 - age / 0.16, 0, 1)
	return MineInk.snap(Vector2(sin(death_time * 95 + death_shake_count * 2), cos(death_time * 83)) * strength)
func return_to_depot(from_death: bool) -> void:
	if mode == "depot":
		return
	mode = "depot"
	depot.visible = true
	depot.show_depot(from_death)
	inventory_open = false
	mouse_held = false
	space_held = false
	stroke_contacts.clear()
	if from_death:
		depot_message = "%s. Saved %d · Lost %d." % [death_reason, death_kept, death_lost]
	else:
		depot_message = "Safely home. Every piece of your haul is yours to sell."
		synth.play_sound("ui")
	save_progress()

func sell_ores() -> void:
	if inventory_count() == 0:
		return
	var total := haul_value()
	if mode == "depot":
		depot.begin_sale(inventory.duplicate(), credits)
	credits += total
	inventory.fill(0)
	depot_message = "Haul sold for %d credits. Make the next descent count." % total
	synth.play_sound("sell")
	save_progress()

func buy_upgrade(index: int) -> void:
	if index < 0 or index >= MineCatalog.UPGRADES.size():
		return
	var upgrade: Dictionary = MineCatalog.UPGRADES[index]
	if index not in MineCatalog.SHOP_UPGRADES:
		return
	tracked_upgrade = upgrade.key
	save_progress()
	var level: int = upgrades[upgrade.key]
	if upgrade.max >= 0 and level >= upgrade.max:
		return
	var price := MineCatalog.price(index, level)
	if credits < price:
		depot.purchase_feedback(index, false)
		return
	credits -= price
	var equipment_before := upgrades.duplicate()
	upgrades[upgrade.key] += 1
	if upgrade.key == "depth":
		selected_depth = MineCatalog.starting_depth(upgrades.depth)
	if upgrade.key == "speed":
		selected_speed = max_speed()
	depot.purchase_feedback(index, true)
	depot.show_purchase_comparison(index, equipment_before)
	synth.play_sound("purchase", -6, 1.15)
	save_progress()
func cycle_depth() -> void:
	var level := roundi(sqrt(0.25 + float(selected_depth) / 5.0) - 0.5)
	selected_depth = MineCatalog.starting_depth(level + 1)
	if selected_depth > MineCatalog.starting_depth(upgrades.depth):
		selected_depth = 0
	synth.play_sound("ui")
	save_progress()

func save_progress() -> void:
	if test_mode:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 8, "treasure_seen": treasure_seen, "claimed_milestones": claimed_milestones, "tracked_upgrade": tracked_upgrade, "freeze_learned": freeze_learned, "speed_learned_round": speed_learned_round, "rounds_started": rounds_started, "speed_learned": speed_learned, "credits": credits, "upgrades": upgrades, "inventory": inventory, "depth": selected_depth, "speed": selected_speed, "placement_taught": placement_taught, "tutorials": pending_shortcuts, "best": best_depth, "muted": synth.muted}))

func load_progress() -> void:
	if test_mode or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	credits = maxi(0, int(data.get("credits", 0)))
	best_depth = maxi(0, int(data.get("best", 0)))
	treasure_seen = bool(data.get("treasure_seen", false))
	var saved_upgrades = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for upgrade in MineCatalog.UPGRADES:
			upgrades[upgrade.key] = maxi(0, int(saved_upgrades.get(upgrade.key, 0)))
			if upgrade.max >= 0:
				upgrades[upgrade.key] = mini(upgrades[upgrade.key], upgrade.max)
	var saved_inventory = data.get("inventory", [])
	if saved_inventory is Array:
		for i in range(mini(inventory.size(), saved_inventory.size())):
			inventory[i] = clampi(int(saved_inventory[i]), 0, 1000000)
	var saved_version := int(data.get("version", 1))
	claimed_milestones.clear()
	var saved_milestones = data.get("claimed_milestones", [])
	if saved_milestones is Array:
		for claimed in saved_milestones:
			claimed_milestones.append(int(claimed))
	if saved_version < 7:
		for milestone in MineCatalog.MILESTONES:
			if milestone.depth <= best_depth and milestone.depth not in claimed_milestones:
				claimed_milestones.append(milestone.depth)
	tracked_upgrade = str(data.get("tracked_upgrade", "capacity"))
	if saved_version < 7:
		selected_speed = 2
	var saved_depth := int(data.get("depth", 0))
	if saved_version < 4:
		var saved_step := 100 if saved_version < 3 else 20
		selected_depth = MineCatalog.starting_depth(clampi(saved_depth / saved_step, 0, upgrades.depth))
	else:
		selected_depth = clampi(saved_depth, 0, MineCatalog.starting_depth(upgrades.depth))
	selected_speed = clampi(int(data.get("speed", 2)), 1, max_speed())
	if saved_version < 7:
		selected_speed = 2
	rounds_started = maxi(0, int(data.get("rounds_started", 0)))
	speed_learned = bool(data.get("speed_learned", false))
	freeze_learned = bool(data.get("freeze_learned", false))
	speed_learned_round = int(data.get("speed_learned_round", rounds_started if speed_learned else -1))
	upgrades.freeze = 1
	placement_taught = bool(data.get("placement_taught", false))
	pending_shortcuts.clear()
	var tutorials = data.get("tutorials", [])
	if tutorials is Array:
		for tutorial in tutorials:
			if tutorial in ["freeze", "speed"] and tutorial not in pending_shortcuts:
				pending_shortcuts.append(tutorial)
	synth.muted = bool(data.get("muted", false))

func _draw() -> void:
	if mode in ["depot", "results"]:
		draw_rect(Rect2(0, 0, 480, 800), Color.BLACK)
		return
	draw_rect(Rect2(0, 0, 480, 800), MineInk.BG)
	var shake_offset := camera_offset()
	draw_set_transform(Vector2.ZERO)
	draw_background()
	draw_set_transform(shake_offset)
	draw_blocks()
	draw_formations()
	draw_liquid()
	draw_floor_spikes()
	for drop in drops:
		if drop.pos.y > MineWorld.TOP and drop.pos.y < MineWorld.BOTTOM + 8:
			draw_set_transform(MineInk.snap(drop.pos + shake_offset), drop.rotation)
			MineCatalog.ore_shape(self, Vector2.ZERO, drop.ore, 1.6)
			draw_set_transform(shake_offset)
	for enemy in enemies:
		if enemy.pos.y > MineWorld.TOP - 8 and enemy.pos.y < MineWorld.BOTTOM + 8:
			draw_set_transform(MineInk.snap(enemy.pos + shake_offset), 0, Vector2.ONE * BOARD_ZOOM)
			draw_enemy(enemy)
	for ring in landing_rings:
		var age: float = ring.age
		var ring_color := MineWorld.region_color(current_depth(), "accent")
		var alpha := (1.0 - age / 0.32) * 0.35
		draw_set_transform(MineInk.snap(ring.pos + shake_offset), 0, Vector2(1, 0.24))
		draw_arc(Vector2.ZERO, 10 + age * (70 + ring.strength * 80), PI, TAU, 24, Color(ring_color, alpha), 1.5)
	draw_set_transform(Vector2.ZERO)
	draw_set_transform(shake_offset)
	for p in particles:
		if p.pos.y > MineWorld.TOP and p.pos.y < MineWorld.BOTTOM:
			var c: Color = p.color
			c.a = minf(1, p.life * 4)
			draw_rect(Rect2(MineInk.snap(p.pos), Vector2.ONE * maxf(2, snappedf(p.size, 2))), c)
	draw_spikes()
	draw_set_transform(Vector2.ZERO)
	if mode == "leaving":
		draw_departure_beam()
	if is_instance_valid(player_viewport):
		if not death_arc_active():
			draw_player_sprite(shake_offset)

	draw_set_transform(Vector2.ZERO)
	if is_frozen() and mode == "playing":
		MineInk.outline(self, Rect2(0, MineWorld.TOP, 480, MineWorld.BOTTOM - MineWorld.TOP), Color("81cbd2"))
	draw_hud()
	for flight in pickup_flights:
		var pos := pickup_position(flight)
		draw_circle(pos, 8, Color(0.8, 0.9, 0.7, 0.08))
		MineInk.ore_icon(self, pos, flight.ore, 0.8)
	if inventory_open:
		draw_inventory()
	elif mode == "playing":
		draw_cursor()
	if mode == "dying":
		draw_death()
		if death_arc_active() and death_iris_progress() < 1:
			draw_player_sprite(shake_offset)
	elif mode == "leaving":
		draw_departure()
	elif full_banner_time > 0 and not inventory_open:
		var banner := inventory_banner_rect()
		MineInk.panel(self, banner)
		MineInk.centered(self, "Inventory Full", banner.position.y + 55, 40, MineInk.TEXT, banner.get_center().x)
	if mode == "playing":
		for message in floating_texts:
			var pos: Vector2 = message.pos + Vector2(0, -message.age * 34)
			MineInk.centered(self, "No more blocks", pos.y, 18, Color("ff6565"), clampf(pos.x, 85, 395))

	draw_tutorial()

func draw_background() -> void:
	var background := MineWorld.region_color(current_depth(), "back")
	var accent := MineWorld.region_color(current_depth(), "accent")
	draw_rect(Rect2(0, MineWorld.TOP, 480, 800 - MineWorld.TOP), background)
	# Layered, vector-cut cave silhouettes and sparse mineral dust.
	for i in range(12):
		var x := snappedf(float(i * 47 - 20), 2)
		var y := snappedf(150 + fmod(i * 83.0 - world.scroll * 0.18, 600), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 22, y - 90), Vector2(x + 28, y - 40), Vector2(x + 15, y + 110), Vector2(x - 38, y + 45)]), Color(background.lightened(0.06), 0.28))
	for i in range(24):
		var pos := MineInk.snap(Vector2(fmod(i * 127.7, 480), 105 + fposmod(i * 61.3 - world.scroll * 0.35, 640)))
		draw_circle(pos, 0.65, Color(accent, 0.14))
	# The steel guide rails cover indestructible colliders just beyond x=0 and x=480.
	for x in [0, 478]:
		draw_rect(Rect2(x, MineWorld.TOP, 2, 800 - MineWorld.TOP), Color("61706b"))

func draw_blocks() -> void:
	# Terrain rows retain their vector draw commands; scrolling only changes transforms.
	if is_instance_valid(terrain_viewport):
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(terrain_viewport.get_texture(), Rect2(0, 0, 480, 800), false)
		draw_set_transform(camera_offset())

func draw_formations() -> void:
	for prop in world.decorations:
		var cell: Vector2i = prop.cell
		var pos := world.cell_position(cell)
		if pos.y < MineWorld.TOP or pos.y > MineWorld.BOTTOM or world.solid(cell):
			continue
		var support := cell + (Vector2i.UP if prop.ceiling else Vector2i.DOWN)
		if not world.solid(support):
			continue
		var color := MineWorld.region_color(world.base_depth + cell.y, "accent")
		var anchor := pos + Vector2(16, 1 if prop.ceiling else 31)
		var sign_y := 1.0 if prop.ceiling else -1.0
		match prop.kind:
			"prism":
				for shard in range(3):
					var root := anchor + Vector2((shard - 1) * 6, 0)
					var tint := Color.from_hsv(fposmod(prop.variant + shard * 0.2, 1), 0.4, 0.85)
					draw_colored_polygon(PackedVector2Array([root + Vector2(-4, 0), root + Vector2(shard - 1, sign_y * (12 + shard * 5)), root + Vector2(4, 0)]), tint)
			"garden":
				draw_line(anchor, anchor + Vector2(-4, sign_y * 15), Color("699b66"), 2)
				draw_line(anchor + Vector2(-2, sign_y * 6), anchor + Vector2(7, sign_y * 10), Color("92c978"), 2)
				draw_rect(Rect2(anchor + Vector2(-6, sign_y * 16), Vector2(4, 4)), Color("c3e69b"))
			"spire":
				draw_colored_polygon(PackedVector2Array([anchor + Vector2(-8, 0), anchor + Vector2(-3, sign_y * 26), anchor + Vector2(2, sign_y * 31), anchor + Vector2(7, 0)]), color.darkened(0.25))
				draw_line(anchor + Vector2(0, sign_y * 5), anchor + Vector2(1, sign_y * 24), color.lightened(0.2), 2)
			"slate":
				draw_colored_polygon(PackedVector2Array([anchor + Vector2(-10, 0), anchor + Vector2(-5, sign_y * 5), anchor + Vector2(6, sign_y * 3), anchor + Vector2(12, 0)]), color.darkened(0.5))
			"crystal":
				for i in range(3):
					var x := (i - 1) * 5
					var tip := anchor + Vector2(x + 1, sign_y * (5 + (2 - i) * 2 + prop.variant * 3))
					draw_colored_polygon(PackedVector2Array([anchor + Vector2(x - 3, 0), tip, anchor + Vector2(x + 3, 0)]), color.darkened(i * 0.13))
					draw_line(tip, anchor + Vector2(x, 0), color.lightened(0.2), 1)
			"ember":
				draw_circle(anchor, 11, Color(color, 0.035))
				draw_polyline(PackedVector2Array([anchor + Vector2(-9, 0), anchor + Vector2(-4, sign_y * 3), anchor + Vector2(2, sign_y), anchor + Vector2(8, sign_y * 4)]), color.darkened(0.15), 1)

func draw_liquid() -> void:
	for cell: Vector2i in world.lava:
		var amount: float = world.lava[cell]
		var pos := world.cell_position(cell)
		if amount < 0.01 or pos.y < MineWorld.TOP - TILE or pos.y > MineWorld.BOTTOM:
			continue
		var height := amount * TILE
		var surface := pos + Vector2(0, TILE - height)
		draw_rect(Rect2(surface, Vector2(TILE, height)), Color("d74e35"))
		draw_rect(Rect2(surface, Vector2(TILE, minf(3, height))), Color("ffc86b"))
		if height > 5:
			draw_line(surface + Vector2(3, 5), surface + Vector2(TILE - 3, 5), Color("f88943"), 1)

func draw_floor_spikes() -> void:
	for cell: Vector2i in world.floor_spikes:
		var pos := world.cell_position(cell)
		if pos.y < MineWorld.TOP or pos.y > MineWorld.BOTTOM + 12:
			continue
		for triangle in world.spike_triangles(cell):
			draw_colored_polygon(triangle, Color("eedbc3"))
			var midpoint := (triangle[0] + triangle[1]) * 0.5
			draw_colored_polygon(PackedVector2Array([midpoint, triangle[1], triangle[2]]), Color("985d58"))

func enemy_pose(clock: float, fps: float = 6) -> int:
	return floori(clock * fps) % 2

func draw_enemy(enemy: Dictionary, canvas: CanvasItem = null, presentation: bool = false, presentation_scale: float = 4.0) -> void:
	if canvas == null:
		canvas = self
	var color := Color(MineCatalog.ENEMIES[enemy.type].color)
	var animal: int = MineCatalog.ENEMIES[enemy.type].get("art", enemy.type)
	var facing: int = enemy.dir
	var step := 1 if enemy_pose(enemy.clock) == 0 else -1
	canvas.draw_set_transform(MineInk.snap(enemy.pos if presentation else enemy.pos + camera_offset()), 0, Vector2(facing, 1) * (presentation_scale if presentation else BOARD_ZOOM))
	if animal in [2, 5, 8]:
		var flap := -4 if step > 0 else 2
		for side in [-1, 1]:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 1), Vector2(side * 8, flap - 3), Vector2(side * 6, 4), Vector2(side * 2, 3)]), color)
		canvas.draw_rect(Rect2(-2, -3, 4, 9), color.lightened(0.2))
		if animal == 2:
			for x in [-2, 1]:
				canvas.draw_rect(Rect2(x, -6, 2, 4), color)
		elif animal == 5:
			for side in [-1, 1]:
				canvas.draw_line(Vector2(side, -3), Vector2(side * 3, -6), color, 1)
		else:
			canvas.draw_rect(Rect2(2, -7, 3, 9), color)
			canvas.draw_rect(Rect2(4, -7, 4, 2), Color("efba64"))
	else:
		# Four feet, a broad body, and a side-facing herbivore head.
		for x in [-5, 3]:
			canvas.draw_rect(Rect2(x, 3, 3, 4 + (step if x < 0 else -step)), color.darkened(0.3))
		canvas.draw_rect(Rect2(-7, -3, 12, 8), color)
		canvas.draw_rect(Rect2(2, -6, 6, 7), color.lightened(0.12))
		match animal:
			0: # Rabbit: tall ears and a white tail.
				for x in [2, 5]:
					canvas.draw_rect(Rect2(x, -12, 2, 7), color)
				canvas.draw_rect(Rect2(-9, -1, 3, 3), Color("eee3d1"))
			1: # Capybara: broad square muzzle and tiny ears.
				canvas.draw_rect(Rect2(4, -4, 6, 5), color)
				canvas.draw_rect(Rect2(2, -8, 2, 3), color.darkened(0.2))
			3: # Kangaroo: long tail, ears and large hind foot.
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5, 1), Vector2(-12, 6), Vector2(-4, 5)]), color)
				canvas.draw_rect(Rect2(3, -11, 2, 6), color)
				canvas.draw_rect(Rect2(-6, 6, 7, 2), color)
			4: # Deer: branching antlers and slender legs.
				for x in [3, 6]:
					canvas.draw_line(Vector2(x, -5), Vector2(x - 1, -12), Color("ddccaa"), 1)
					canvas.draw_line(Vector2(x, -9), Vector2(x + 2, -11), Color("ddccaa"), 1)
			6: # Tortoise: domed shell with plate markings.
				canvas.draw_circle(Vector2(-2, 0), 6, color.darkened(0.3))
				canvas.draw_rect(Rect2(-6, 0, 9, 4), color.darkened(0.3))
				canvas.draw_line(Vector2(-2, -5), Vector2(-2, 3), color.lightened(0.3), 1)
				canvas.draw_line(Vector2(-6, -1), Vector2(3, -1), color.lightened(0.3), 1)
			7: # Elephant: large ear, trunk and tusk.
				canvas.draw_rect(Rect2(6, -4, 3, 11), color)
				canvas.draw_rect(Rect2(0, -5, 4, 7), color.darkened(0.2))
				canvas.draw_rect(Rect2(5, 1, 2, 2), Color("f2e5c7"))
			9: # Bison: shoulder hump, beard and pale horns.
				canvas.draw_rect(Rect2(-3, -7, 7, 9), color.darkened(0.2))
				canvas.draw_rect(Rect2(4, 0, 3, 5), color.darkened(0.4))
				for x in [2, 7]:
					canvas.draw_rect(Rect2(x, -9, 2, 4), Color("eee0bf"))
	if not blink_closed(time, enemy.type * 1.73):
		canvas.draw_rect(Rect2(5 if animal not in [2, 5, 8] else 0, -4, 1, 1), Color("17212b"))
	if enemy.type >= 10:
		var species: String = MineCatalog.ENEMIES[enemy.type].name
		if species in ["Zebra", "Okapi", "Giant panda", "Glyptodon"]:
			for stripe in range(3):
				canvas.draw_rect(Rect2(-5 + stripe * 3, -2, 1, 6), color.darkened(0.55))
		elif species in ["Moose", "Ibex", "Gazelle", "Antelope", "Reindeer", "Musk ox"]:
			for horn in [2, 6]:
				canvas.draw_line(Vector2(horn, -6), Vector2(horn - 2, -13), Color("eadbb9"), 1)
		elif species in ["Rhinoceros", "Woolly mammoth"]:
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(6, -3), Vector2(9, -10), Vector2(9, -2)]), Color("eee0bd"))
		elif species in ["Alpaca", "Giraffe", "Megatherium"]:
			canvas.draw_rect(Rect2(3, -12, 3, 8), color)
			canvas.draw_rect(Rect2(3, -14, 6, 4), color.lightened(0.15))
		elif species in ["Porcupine", "Beaver", "Sloth", "Koala"]:
			for tuft in range(4):
				canvas.draw_line(Vector2(-7 + tuft * 3, -3), Vector2(-9 + tuft * 3, -7), color.lightened(0.25), 1)
		else:
			canvas.draw_rect(Rect2(-4, -2, 3, 3), color.lightened(0.35))

func draw_spikes() -> void:
	if spike_height <= 0:
		return
	var bottom := MineWorld.BOTTOM
	for x in range(0, 480, 16):
		var tip := Vector2(x + 8, bottom - floorf(spike_height / 2) * 2)
		var base_y := minf(bottom, tip.y + 17)
		draw_colored_polygon(PackedVector2Array([Vector2(x, base_y), tip, Vector2(x + 16, base_y)]), Color("e2a18a"))
		draw_colored_polygon(PackedVector2Array([tip, Vector2(x + 8, base_y), Vector2(x + 16, base_y)]), Color("a9635b"))

func indicator_center(index: int) -> Vector2:
	return Vector2(64 + index * 88, 56)

func pickup_position(flight: Dictionary) -> Vector2:
	var t: float = clampf(flight.t, 0, 1)
	var eased := 1 - pow(1 - t, 2)
	return MineInk.snap(Vector2(flight.start).lerp(indicator_center(2), eased) + Vector2(-sin(t * PI) * 35, -sin(t * PI) * 30))

func draw_indicator(index: int, label: String, value: String, icon: String = "", color: Color = MineInk.TEXT, pulse: float = 1.0) -> void:
	var center := indicator_center(index)
	MineInk.centered(self, label, 30, 13, MineInk.TEXT, center.x)
	var size := roundi((20 if index < 2 else 17) * pulse)
	var gap := snappedf(20 * pulse, 2) if not icon.is_empty() else 0.0
	while size > 8 and MineInk.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap > 76:
		size -= 1
	var width := MineInk.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var left := snappedf(center.x - (width + gap) * 0.5, 2)
	if not icon.is_empty():
		MineInk.icon(self, icon, Vector2(left + gap * 0.5 - 2, 56), color, 0.9 * pulse)
	MineInk.text(self, value, Vector2(left + gap, 62), size, color)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, 480, MineWorld.TOP), MineInk.BG)
	MineInk.panel(self, Rect2(8, 8, 464, 112))
	draw_indicator(0, "Depth", "%d m" % current_depth())
	draw_indicator(1, "Value", str(haul_value()), "coin")
	draw_indicator(2, "Ores", "%d/%d" % [inventory_count(), capacity()], "", MineInk.TEXT, 1 + bag_pulse * 0.3)
	var block_color := Color("ff6565") if blocks_left == 0 else MineInk.TEXT
	var pulse := 1 + sin((1 - block_counter_pulse / 0.5) * PI) * 0.45 if block_counter_pulse > 0 else 1.0
	draw_indicator(3, "Blocks", str(blocks_left), "block", block_color, pulse)
	draw_indicator(4, "Lives", str(maxi(0, lives - 1)), "heart")
	for pair in [[speed_rect, "speed"], [freeze_rect, "freeze"], [bag_rect, "bag"], [home_rect, "home"]]:
		var rect: Rect2 = home_button_rect() if pair[1] == "home" else pair[0]
		var active: bool = (pair[1] == "speed" and game_speed() > 1) or (pair[1] == "freeze" and is_frozen()) or (pair[1] == "bag" and inventory_open)
		var hover := rect.has_point(cursor_position)
		var locked := false
		MineInk.panel(self, rect.grow(2 if hover else 0), MineInk.PANEL, MineInk.LINE.darkened(0.4) if locked else MineInk.LINE)
		MineInk.icon(self, pair[1], rect.get_center(), MineInk.MUTED.darkened(0.3) if locked else MineInk.TEXT)
		if locked:
			MineInk.icon(self, "lock", rect.position + Vector2(26, 26), MineInk.LINE, 0.6)
		if pair[1] == "home" and leave_glow:
			if floori(ui_time * 3) % 2 == 0:
				var outline_rect := rect.grow(2 if hover else 0)
				MineInk.outline(self, outline_rect.grow(-2), MineInk.LINE)
				MineInk.outline(self, outline_rect.grow(-4), MineInk.LINE)
		if active:
			draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(2, 2)), MineInk.TEXT)

func cursor_center() -> Vector2:
	return MineInk.snap(cursor_position)

func draw_cursor() -> void:
	var mouse := cursor_center()
	if mouse.y < MineWorld.TOP or mouse.y >= MineWorld.BOTTOM or mouse.x < 0 or mouse.x > 480:
		return
	var color := Color("f5c477") if mouse_held else Color("d9dfc5")
	var ring := MineInk.ring_texture(roundi(DIG_RADIUS / MineInk.PIXEL))
	draw_texture_rect(ring, Rect2(mouse - Vector2.ONE * DIG_RADIUS, Vector2.ONE * DIG_RADIUS * 2), false, color)
	for offset in [Vector2(-28, 0), Vector2(22, 0)]:
		draw_rect(Rect2(mouse + offset, Vector2(6, 2)), color)
	for offset in [Vector2(0, -28), Vector2(0, 22)]:
		draw_rect(Rect2(mouse + offset, Vector2(2, 6)), color)
	draw_rect(Rect2(mouse, Vector2(2, 2)), color)

func draw_inventory() -> void:
	draw_rect(Rect2(0, MineWorld.TOP, 480, 800 - MineWorld.TOP), Color(MineInk.BG, 0.9))
	MineInk.panel(self, Rect2(32, MineWorld.TOP + 20, 416, 581), MineInk.PANEL, MineInk.LINE, 12)
	MineInk.text(self, "Satchel  %d / %d" % [inventory_count(), capacity()], Vector2(52, MineWorld.TOP + 57), 25)
	MineInk.icon(self, "close", Vector2(417, MineWorld.TOP + 45), MineInk.MUTED)
	if visible_ores().size() > 15:
		MineInk.text(self, "Mouse wheel: ores %d-%d of %d" % [inventory_scroll + 1, mini(inventory_scroll + 15, visible_ores().size()), visible_ores().size()], Vector2(52, MineWorld.TOP + 73), 11, MineInk.MUTED)
	MineInk.text(self, "Ore", Vector2(86, MineWorld.TOP + 86), 13, MineInk.MUTED)
	MineInk.text(self, "Qty", Vector2(198, MineWorld.TOP + 86), 13, MineInk.MUTED)
	MineInk.text(self, "Each", Vector2(245, MineWorld.TOP + 86), 13, MineInk.MUTED)
	MineInk.text(self, "Total", Vector2(310, MineWorld.TOP + 86), 13, MineInk.MUTED)
	var ores := satchel_ores()
	for slot in range(ores.size()):
		var ore := ores[slot]
		var y := MineWorld.TOP + 110 + slot * 28
		MineInk.panel(self, Rect2(48, y - 16, 384, 26), MineInk.PANEL, MineInk.LINE, 5)
		MineInk.ore_icon(self, Vector2(65, y - 2), ore, 0.95)
		MineInk.fitted_text(self, MineCatalog.ORES[ore].name, Vector2(86, y + 3), 104, 13, MineCatalog.ore_color(ore))
		MineInk.fitted_text(self, str(inventory[ore]), Vector2(198, y + 3), 40, 13)
		MineInk.fitted_text(self, str(MineCatalog.ORES[ore].value), Vector2(245, y + 3), 56, 13, MineInk.GOLD)
		MineInk.fitted_text(self, str(inventory[ore] * MineCatalog.ORES[ore].value), Vector2(310, y + 3), 86, 13, MineInk.GOLD)
		var trash := discard_rect(slot)
		var red := Color("ff6565")
		MineInk.panel(self, trash, Color("4b2020") if trash.has_point(cursor_position) else MineInk.PANEL, red)
		MineInk.icon(self, "trash", trash.get_center(), red, 1.0)
	MineInk.panel(self, Rect2(48, MineWorld.TOP + 540, 384, 44))
	MineInk.text(self, "Total", Vector2(62, MineWorld.TOP + 568), 18)
	MineInk.fitted_text(self, "%d coins" % haul_value(), Vector2(210, MineWorld.TOP + 568), 208, 18, MineInk.GOLD)

func blink_closed(clock: float, offset: float) -> bool:
	var cycle := fposmod(clock + offset, 4.7)
	return cycle < 0.12 or (cycle > 2.83 and cycle < 2.93)

func begin_departure() -> void:
	if mode != "playing":
		return
	mode = "leaving"
	full_bag_time = 0
	leave_glow = false
	departure_time = 0
	departure_origin = player
	inventory_open = false
	mouse_held = false
	placement_held = false
	stroke_contacts.clear()

func draw_departure_beam() -> void:
	var beam_bottom := lerpf(MineWorld.TOP, departure_origin.y + 28, smoothstep(0, 1, minf(1, departure_time / DEPARTURE_BEAM)))
	for band in range(8, 0, -1):
		var width := band * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(departure_origin.x - width * 0.5, MineWorld.TOP), Vector2(departure_origin.x + width * 0.5, MineWorld.TOP), Vector2(departure_origin.x + width, beam_bottom), Vector2(departure_origin.x - width, beam_bottom)]), Color(1, 0.86 + band * 0.006, 0.55 + band * 0.012))

func draw_departure() -> void:
	var close_start := DEPARTURE_BEAM + DEPARTURE_WAIT + DEPARTURE_FLOAT
	if departure_time > close_start:
		var radius := 0.0
		for corner in [Vector2.ZERO, Vector2(480, 0), Vector2(480, 800), Vector2(0, 800)]:
			radius = maxf(radius, player.distance_to(corner) + 2)
		radius *= 1 - smoothstep(0, 1, minf(1, (departure_time - close_start) / DEPARTURE_CLOSE))
		draw_iris(player, radius)

func draw_iris(center: Vector2, radius: float) -> void:
	if radius <= 0:
		draw_rect(Rect2(0, 0, 480, 800), Color.BLACK)
		return
	for i in range(96):
		var a := Vector2.from_angle(TAU * i / 96)
		var b := Vector2.from_angle(TAU * (i + 1) / 96)
		draw_colored_polygon(PackedVector2Array([center + a * radius, center + a * 2000, center + b * 2000, center + b * radius]), Color.BLACK)

func draw_death() -> void:
	var offset := camera_offset()
	for flight in death_flights:
		var age: float = maxf(0, death_time - flight.born)
		var pos: Vector2 = MineInk.snap(death_origin + offset + flight.offset + flight.velocity * age + Vector2(0, 180 * age * age))
		MineCatalog.ore_shape(self, pos, flight.ore, 1.15)
	var progress := death_iris_progress()
	if progress <= 0:
		return
	if progress >= 1:
		draw_rect(Rect2(0, 0, 480, 800), Color.BLACK)
		return
	var center := death_origin.clamp(Vector2.ZERO, Vector2(480, 800))
	var radius := 0.0
	for corner in [Vector2.ZERO, Vector2(480, 0), Vector2(480, 800), Vector2(0, 800)]:
		radius = maxf(radius, center.distance_to(corner) + 4)
	var elapsed := death_time - death_transition_start()
	if elapsed < DEATH_IRIS_DURATION:
		radius = lerpf(radius, 42, smoothstep(0, 1, elapsed / DEATH_IRIS_DURATION))
	elif elapsed < DEATH_IRIS_DURATION + DEATH_IRIS_HOLD:
		radius = 42
	else:
		radius = 42 * (1 - smoothstep(0, 1, clampf((elapsed - DEATH_IRIS_DURATION - DEATH_IRIS_HOLD) / DEATH_FINAL_CLOSE, 0, 1)))
	# Quads form a black annulus around the shrinking circular opening.
	for i in range(96):
		var a := Vector2.from_angle(TAU * i / 96)
		var b := Vector2.from_angle(TAU * (i + 1) / 96)
		draw_colored_polygon(PackedVector2Array([center + a * radius, center + a * 2000, center + b * 2000, center + b * radius]), Color.BLACK)

func death_arc_active() -> bool:
	return mode == "dying" and death_time > death_transition_start() + DEATH_IRIS_DURATION + 0.2

func draw_player_sprite(offset: Vector2) -> void:
	var origin := (player + Vector2(-64, -48) + offset).snapped(Vector2.ONE * BOARD_ZOOM)
	draw_texture_rect(player_viewport.get_texture(), Rect2(origin, Vector2(128, 128)), false)

func inventory_banner_rect() -> Rect2:
	var age := 2.0 - full_banner_time
	var x := 28.0
	if age < 0.3:
		x = lerpf(-452, 28, smoothstep(0, 1, age / 0.3))
	elif full_banner_time < 0.3:
		x = lerpf(28, 508, smoothstep(0, 1, 1 - full_banner_time / 0.3))
	return Rect2(MineInk.snap(Vector2(x, full_banner_y)), Vector2(424, 82))

func discard_rect(slot: int) -> Rect2:
	return Rect2(404, MineWorld.TOP + 96 + slot * 28, 24, 22)

func discard_ore(ore: int) -> bool:
	if mode != "playing" or not inventory_open or ore < 0 or ore >= inventory.size() or inventory[ore] <= 0:
		return false
	inventory[ore] -= 1
	full_bag_time = 0
	leave_glow = false
	full_banner_time = 0
	full_was_full = inventory_count() >= capacity()
	synth.play_sound("discard", -2)
	save_progress()
	return true

func home_button_rect() -> Rect2:
	var rect := home_rect
	if mode == "playing" and inventory_count() >= capacity() and full_bag_time >= 5:
		var age := fmod(full_bag_time - 5, 2.0)
		if age < 0.35:
			rect.position.x += snappedf(sin(age * 65) * 6 * (1 - age / 0.35), MineInk.PIXEL)
	return rect

func satchel_ores() -> Array[int]:
	var ores := visible_ores()
	inventory_scroll = clampi(inventory_scroll, 0, maxi(0, ores.size() - 15))
	return ores.slice(inventory_scroll, inventory_scroll + 15)

func upgrade_index(key: String) -> int:
	for index in MineCatalog.SHOP_UPGRADES:
		if MineCatalog.UPGRADES[index].key == key:
			return index
	return 2

func discovery_goal() -> String:
	var next_depth := 2147483647
	var description := "Explore beyond your best depth of %d m." % best_depth
	for ore in MineCatalog.ORES:
		if ore.depth > best_depth and ore.depth < next_depth:
			next_depth = ore.depth
			description = "Reach %d m to discover %s." % [ore.depth, ore.name]
	for milestone in MineCatalog.MILESTONES:
		if milestone.depth > best_depth and milestone.depth < next_depth:
			next_depth = milestone.depth
			description = "Reach %d m to unlock %s." % [milestone.depth, milestone.name]
	for animal in MineCatalog.ENEMIES:
		if animal.depth > best_depth and animal.depth < next_depth:
			next_depth = animal.depth
			description = "Reach %d m to encounter %s." % [animal.depth, animal.name]
	return description

func finish_expedition(from_death: bool) -> void:
	if mode in ["results", "depot"]:
		return
	results_from_death = from_death
	best_depth = maxi(best_depth, run_peak)
	var milestone_bonus := 0
	var milestones_earned := 0
	var milestone_name := "No new milestone this expedition."
	var milestone_detail := "Every deeper run brings new discoveries."
	for milestone in MineCatalog.MILESTONES:
		if milestone.depth <= run_peak and milestone.depth not in claimed_milestones:
			claimed_milestones.append(milestone.depth)
			milestones_earned += 1
			milestone_bonus += milestone.reward
			milestone_name = "%d m: %s" % [milestone.depth, milestone.name]
			milestone_detail = milestone.detail
	credits += milestone_bonus
	var new_ores: Array[String] = []
	var new_animals: Array[String] = []
	for ore in MineCatalog.ORES:
		if ore.depth > run_best_before and ore.depth <= run_peak:
			new_ores.append(ore.name)
	for animal in MineCatalog.ENEMIES:
		if animal.depth > run_best_before and animal.depth <= run_peak:
			new_animals.append(animal.name)
	new_ores.sort_custom(func(a: String, b: String) -> bool: return MineCatalog.ORES[MineCatalog.ore_id(a)].depth < MineCatalog.ORES[MineCatalog.ore_id(b)].depth)
	var rewards := milestone_name + "\n" + milestone_detail
	if milestones_earned > 0:
		rewards = "%d milestones | +%d coins\n" % [milestones_earned, milestone_bonus] + rewards
	if not new_ores.is_empty():
		rewards += "\nNew ores: %d | %s" % [new_ores.size(), new_ores[-1]]
	if not new_animals.is_empty():
		rewards += "\nNew wildlife: %d | %s" % [new_animals.size(), new_animals[-1]]
	var affordable: Array[String] = []
	var budget := credits + haul_value()
	for index in MineCatalog.SHOP_UPGRADES:
		var upgrade: Dictionary = MineCatalog.UPGRADES[index]
		var price := MineCatalog.price(index, upgrades[upgrade.key])
		if price > run_credits_before + run_haul_before and price <= budget:
			affordable.append(upgrade.name)
	var tracked := upgrade_index(tracked_upgrade)
	var target: Dictionary = MineCatalog.UPGRADES[tracked]
	var target_price := MineCatalog.price(tracked, upgrades[target.key])
	var stats := "Depth: %d m | Best: %d m\nHaul: %d coins | Bonus: %d coins\n%s" % [run_peak, best_depth, haul_value(), credits - run_credits_before, "Saved %d ores | Lost %d" % [death_kept, death_lost] if from_death else "Safely extracted"]
	var affordable_text := "Keep saving toward your tracked upgrade."
	if not affordable.is_empty():
		affordable_text = "Newly affordable: " + ", ".join(affordable.slice(0, 2))
		if affordable.size() > 2:
			affordable_text += " (+%d more)" % (affordable.size() - 2)
	var events := MineCatalog.discovery_events(run_best_before, run_peak)
	var future := MineCatalog.discovery_events(best_depth, 2147483647)
	var fallback: Dictionary = future[0].duplicate() if not future.is_empty() else {"kind": "milestone", "id": -1, "name": "The unexplored deep", "depth": best_depth + 100, "detail": "Keep exploring beyond your deepest run."}
	fallback.context = "NEXT DISCOVERY"
	var best_find := -1
	for ore in visible_ores():
		if best_find < 0 or MineCatalog.ORES[ore].value > MineCatalog.ORES[best_find].value:
			best_find = ore
	if events.is_empty() and best_find >= 0:
		var found: Dictionary = MineCatalog.ORES[best_find]
		fallback = {"kind": "ore", "id": best_find, "name": found.name, "depth": found.depth, "value": found.value, "detail": "%d carried | %d coins each" % [inventory[best_find], found.value], "context": "BEST FIND"}
	var hero_kind := "progress"
	var hero_title := "A LITTLE CLOSER"
	var contribution := budget - run_credits_before - run_haul_before
	var hero_detail := "%+d coins toward your next upgrade." % contribution
	if run_peak > run_best_before:
		hero_kind = "record"
		hero_title = "NEW DEPTH RECORD!"
		hero_detail = "+%d m beyond your previous best." % (run_peak - run_best_before)
	elif run_first_treasure:
		hero_kind = "treasure"
		hero_title = "FIRST TREASURE ROOM!"
		hero_detail = "A lost cache discovered and brought home."
	elif not events.is_empty():
		hero_kind = "discovery"
		hero_title = "A NEW DISCOVERY!"
		hero_detail = events[-1].name + " joins your discoveries."
	elif not affordable.is_empty():
		hero_kind = "upgrade"
		hero_title = "UPGRADE WITHIN REACH!"
		hero_detail = affordable[0] + " is ready after selling."
	elif contribution <= 0:
		hero_title = "EXPEDITION COMPLETE"
		hero_detail = "Your next discovery is waiting below."
	if hero_kind == "treasure" and events.is_empty():
		fallback = {"kind": "milestone", "id": -1, "name": "Lost treasure cache", "depth": run_peak, "detail": "Treasure recovered | +%d coins" % (credits - run_credits_before), "context": "TREASURE", "value": credits - run_credits_before}
	var equipment_next := upgrades.duplicate()
	equipment_next[target.key] += 1
	var data := {"title": "NEW DEEPEST RUN!" if run_peak > run_best_before else "EXPEDITION COMPLETE", "stats": stats, "rewards": rewards, "next_goal": discovery_goal(), "upgrade_goal": "Goal: %s\nAfter selling: %d / %d coins" % [target.name, budget, target_price], "upgrade_progress": clampf(float(budget) / maxf(1, target_price), 0, 1), "affordable": affordable_text}
	data.merge({"hero_kind": hero_kind, "hero_title": hero_title, "hero_detail": hero_detail, "previous_best": run_best_before, "peak_depth": run_peak, "start_depth": selected_depth, "events": events, "fallback": fallback, "funds_before": run_credits_before + run_haul_before, "funds_after": budget, "haul_change": haul_value() - run_haul_before, "bonus_earned": credits - run_credits_before, "haul_value": haul_value(), "outcome": "Saved %d ores | Lost %d" % [death_kept, death_lost] if from_death else "Safely extracted", "target_name": target.name, "target_price": target_price, "target_key": target.key, "equipment_before": upgrades.duplicate(), "equipment_after": equipment_next, "benefit": MineCatalog.upgrade_benefit(target.key, upgrades[target.key])})
	mode = "results"
	inventory_open = false
	mouse_held = false
	placement_held = false
	shortcut_popup = false
	depot.visible = false
	player_lean = 0
	player_velocity = Vector2.ZERO
	results.show_report(data)
	save_progress()

func continue_to_depot() -> void:
	if mode != "results":
		return
	results.visible = false
	return_to_depot(false)

func handle_debug_input(event: InputEvent) -> bool:
	if OS.has_feature("web") or not event is InputEventKey:
		return false
	debug_keys[event.keycode] = event.pressed
	if not event.pressed or event.echo or not event.shift_pressed or not debug_keys.get(KEY_Z, false):
		return false
	if event.keycode == KEY_M:
		reset_progress()
		return true
	if event.keycode in [KEY_O, KEY_L]:
		change_debug_depth(10 if event.keycode == KEY_O else -10)
		return true
	return false

func change_debug_depth(amount: int) -> void:
	if mode != "playing":
		return
	var shift := maxi(0, selected_depth + amount) - selected_depth
	selected_depth += shift
	world.base_depth = selected_depth
	for cell in world.blocks:
		var block: Dictionary = world.blocks[cell]
		var health := MineWorld.block_health(world.base_depth + cell.y)
		block.hp = maxi(1, block.hp + health - block.get("max_hp", block.hp))
		block.max_hp = health
		invalidate_terrain_row(cell.y)
	run_peak = maxi(run_peak, current_depth())
	best_depth = maxi(best_depth, run_peak)
	show_toast("Depth: %d m" % current_depth())

func reset_progress() -> void:
	if OS.has_feature("web"):
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	credits = 0
	for key in upgrades:
		upgrades[key] = 0
	upgrades.freeze = 1
	inventory.fill(0)
	selected_depth = 0
	selected_speed = 2
	best_depth = 0
	rounds_started = 0
	speed_learned = false
	freeze_learned = false
	speed_learned_round = -1
	placement_taught = false
	claimed_milestones.clear()
	treasure_seen = false
	tracked_upgrade = "capacity"
	pending_shortcuts.clear()
	debug_keys.clear()
	start_run()
