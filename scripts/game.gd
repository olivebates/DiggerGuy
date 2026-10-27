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
var upgrades := {"depth": 0, "power": 0, "capacity": 0, "insurance": 0, "freeze": 0, "speed": 0, "lives": 0, "blocks": 0}
var selected_depth := 0
var selected_speed := 1
var lives := 1
var hit_grace := 0.0
var spike_cooldown := 0.0
var full_banner_time := 0.0
var leave_glow := false
var full_was_full := false
var pending_shortcuts: Array[String] = []
var blocks_left := 3
var block_counter_pulse := 0.0
var departure_time := 0.0
var departure_origin := Vector2.ZERO
var floating_texts: Array[Dictionary] = []
var best_depth := 0
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
	inventory.resize(15)
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
	global_pixel_material.set_shader_parameter("enabled", mode != "depot" and not inventory_open)
	if mode != "depot" and is_instance_valid(player_visual):
		player_visual.queue_redraw()
		update_terrain_cache()
	player_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if mode == "depot" else SubViewport.UPDATE_ALWAYS
	terrain_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if mode == "depot" else SubViewport.UPDATE_ALWAYS
	# Rendering and cursor input remain live even when the simulation is frozen.
	queue_redraw()

func visible_ores() -> Array[int]:
	var result: Array[int] = []
	for i in range(inventory.size()):
		if inventory[i] > 0:
			result.append(i)
	return result

func start_run() -> void:
	if not pending_shortcuts.is_empty():
		if mode != "depot":
			return_to_depot(false)
		return
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

func capacity() -> int:
	return 7 + upgrades.capacity

func max_lives() -> int:
	return 1 + upgrades.lives

func max_speed() -> int:
	return 1 + upgrades.speed

func inventory_count() -> int:
	var count := 0
	for amount in inventory:
		count += amount
	return count

func haul_value() -> int:
	var value := 0
	for i in range(15):
		value += inventory[i] * MineCatalog.ORES[i].value
	return value

func current_depth() -> int:
	return maxi(selected_depth, selected_depth + floori((world.scroll + player.y - 208) / TILE))

func is_frozen() -> bool:
	return upgrades.freeze > 0 and (frozen_toggle or space_held)

func game_speed() -> float:
	return float(clampi(selected_speed, 1, max_speed())) if upgrades.speed > 0 and (speed_held or speed_toggle) else 1.0

func show_toast(message: String, duration: float = 2.5) -> void:
	toast = message
	toast_time = duration

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_held = false
		placement_held = false
		placement_contacts.clear()
		space_held = false
		speed_held = false
		stroke_contacts.clear()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		save_progress()

func _input(event: InputEvent) -> void:
	var previous_cursor := cursor_position
	if event is InputEventMouse:
		cursor_position = event.position
	if mode != "playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		placement_held = event.pressed and not inventory_open
		placement_contacts.clear()
		if placement_held:
			place_drag_at(cursor_position)
		return
	if event is InputEventKey:
		if event.keycode == KEY_W:
			speed_held = event.pressed and upgrades.speed > 0
		if event.keycode == KEY_SPACE:
			if event.pressed and not space_held and not inventory_open and upgrades.freeze > 0:
				synth.play_sound("freeze")
			space_held = event.pressed and upgrades.freeze > 0
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
		elif home_rect.has_point(mouse):
			leave_glow = false
			begin_departure()
		elif freeze_rect.has_point(mouse):
			toggle_freeze()
		elif speed_rect.has_point(mouse):
			if upgrades.speed > 0:
				speed_toggle = not speed_toggle
				synth.play_sound("ui")
		elif inventory_open:
			if Rect2(402, MineWorld.TOP + 30, 30, 30).has_point(mouse):
				toggle_inventory()
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
	if upgrades.freeze == 0:
		return
	frozen_toggle = not frozen_toggle
	synth.play_sound("freeze")
	show_toast("Time frozen. You can still dig." if is_frozen() else "The descent continues.")

func _physics_process(delta: float) -> void:
	ui_time += delta
	block_counter_pulse = maxf(0, block_counter_pulse - delta)
	if mode == "playing" and not inventory_open:
		for cell in placement_effects.keys():
			placement_effects[cell] += delta
			invalidate_terrain_row(cell.y)
			if placement_effects[cell] >= 0.12:
				placement_effects.erase(cell)
	if mode == "leaving":
		departure_time += delta
		var float_age := maxf(0, departure_time - DEPARTURE_BEAM - DEPARTURE_WAIT)
		var lift := float_age / DEPARTURE_FLOAT
		player = departure_origin + Vector2(0, -48 * lift)
		player_lean = -0.16 * smoothstep(0, 1, minf(1, lift))
		if departure_time >= DEPARTURE_END:
			return_to_depot(true)
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
	if mouse_held and not inventory_open:
		mine_at(cursor_position)
	if not inventory_open:
		toast_time = maxf(0, toast_time - delta)
		bag_pulse = maxf(0, bag_pulse - delta)
		full_notice = maxf(0, full_notice - delta)
	if not inventory_open and not is_frozen():
		var multiplier := game_speed()
		var steps := maxi(1, ceili(delta * multiplier * 60))
		for step in range(steps):
			simulate_step(delta * multiplier / steps)
			if mode != "playing":
				break
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
	if mode != "playing":
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

func mine_at(mouse: Vector2) -> void:
	if mode != "playing" or inventory_open:
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
			var spike_height_before: float = world.floor_spikes.get(cell, {}).get("height", 0.0)
			var result := world.hit(cell, 1 + upgrades.power)
			placement_effects.erase(cell)
			invalidate_terrain_row(cell.y)
			var center := pos + Vector2.ONE * TILE * 0.5
			if result.has("damaged"):
				emit_debris(center, Color("9b8e72"), 3)
			else:
				broke_any = true
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
	world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 0, "placed": true}
	placement_effects[cell] = 0.0
	invalidate_terrain_row(cell.y)
	blocks_left -= 1
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
		terrain_rows[row].position.y = 208 + row * TILE - world.scroll
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
			world.clear_lava_contact(Rect2(player - Vector2(10, 14), Vector2(20, 28)))
			lose_life("Caught in a lava spill")
	elif world.touches_floor_spikes(Rect2(player - Vector2(10, 14), Vector2(20, 30))):
		if hit_grace <= 0:
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
		if drop.pos.distance_to(player) < 25:
			if inventory_count() < capacity():
				inventory[drop.ore] += 1
				check_full_inventory()
				pickup_flights.append({"start": drop.pos, "ore": drop.ore, "t": 0.0})
				synth.play_sound("pickup")
				drops.remove_at(i)
				continue
			elif full_notice <= 0:
				show_toast("Bag full. Press Q to sell your haul.")
				full_notice = 4
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
		enemy.clock += delta
		if enemy.pos.y < MineWorld.TOP - 40 or enemy.pos.y > MineWorld.BOTTOM + 440:
			enemies.remove_at(i)
			continue
		var data: Dictionary = MineCatalog.ENEMIES[enemy.type]
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
		full_banner_time = 2.0
		leave_glow = true
	full_was_full = full

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
	kept.resize(15)
	kept.fill(0)
	var remaining: int = 3 + upgrades.insurance
	for i in range(14, -1, -1):
		kept[i] = mini(remaining, inventory[i])
		remaining -= kept[i]
	return kept
func die(reason: String) -> void:
	if mode != "playing":
		return
	mode = "dying"
	lives = 0
	death_reason = reason
	death_time = 0
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
	for i in range(15):
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
		return_to_depot(true)

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
	var level: int = upgrades[upgrade.key]
	if upgrade.max >= 0 and level >= upgrade.max:
		return
	var price := MineCatalog.price(index, level)
	if credits < price:
		depot.purchase_feedback(index, false)
		return
	credits -= price
	upgrades[upgrade.key] += 1
	if upgrade.key == "depth":
		selected_depth = upgrades.depth * MineCatalog.DEPTH_STEP
	if upgrade.key == "speed":
		selected_speed = max_speed()
	if level == 0 and upgrade.key in ["freeze", "speed"]:
		pending_shortcuts.append(upgrade.key)
	depot.purchase_feedback(index, true)
	synth.play_sound("purchase", -6, 1.15)
	save_progress()
func cycle_depth() -> void:
	selected_depth += MineCatalog.DEPTH_STEP
	if selected_depth > upgrades.depth * MineCatalog.DEPTH_STEP:
		selected_depth = 0
	synth.play_sound("ui")
	save_progress()

func save_progress() -> void:
	if test_mode:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 3, "credits": credits, "upgrades": upgrades, "inventory": inventory, "depth": selected_depth, "speed": selected_speed, "tutorials": pending_shortcuts, "best": best_depth, "muted": synth.muted}))

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
	var saved_upgrades = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for upgrade in MineCatalog.UPGRADES:
			upgrades[upgrade.key] = maxi(0, int(saved_upgrades.get(upgrade.key, 0)))
			if upgrade.max >= 0:
				upgrades[upgrade.key] = mini(upgrades[upgrade.key], upgrade.max)
	var saved_inventory = data.get("inventory", [])
	if saved_inventory is Array:
		for i in range(mini(15, saved_inventory.size())):
			inventory[i] = clampi(int(saved_inventory[i]), 0, 1000000)
	var saved_step := 100 if int(data.get("version", 1)) < 3 else MineCatalog.DEPTH_STEP
	selected_depth = clampi(int(data.get("depth", 0)) / saved_step * MineCatalog.DEPTH_STEP, 0, upgrades.depth * MineCatalog.DEPTH_STEP)
	selected_speed = clampi(int(data.get("speed", 1)), 1, max_speed())
	pending_shortcuts.clear()
	var tutorials = data.get("tutorials", [])
	if tutorials is Array:
		for tutorial in tutorials:
			if tutorial in ["freeze", "speed"] and tutorial not in pending_shortcuts:
				pending_shortcuts.append(tutorial)
	synth.muted = bool(data.get("muted", false))

func _draw() -> void:
	if mode == "depot":
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
	if is_instance_valid(player_viewport):
		var sprite_origin := (player + Vector2(-64, -48) + shake_offset).snapped(Vector2.ONE * BOARD_ZOOM)
		draw_texture_rect(player_viewport.get_texture(), Rect2(sprite_origin, Vector2(128, 128)), false)
	draw_set_transform(shake_offset)
	for p in particles:
		if p.pos.y > MineWorld.TOP and p.pos.y < MineWorld.BOTTOM:
			var c: Color = p.color
			c.a = minf(1, p.life * 4)
			draw_rect(Rect2(MineInk.snap(p.pos), Vector2.ONE * maxf(2, snappedf(p.size, 2))), c)
	draw_spikes()
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
	elif mode == "leaving":
		draw_departure()
	elif full_banner_time > 0 and not inventory_open:
		MineInk.panel(self, Rect2(28, 356, 424, 82))
		MineInk.centered(self, "Inventory Full", 411, 40)
	if mode == "playing":
		for message in floating_texts:
			var pos: Vector2 = message.pos + Vector2(0, -message.age * 34)
			MineInk.centered(self, "No more blocks", pos.y, 18, Color("ff6565"), clampf(pos.x, 85, 395))

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

func draw_enemy(enemy: Dictionary) -> void:
	var p := Vector2.ZERO
	var color := Color(MineCatalog.ENEMIES[enemy.type].color)
	var kind: String = MineCatalog.ENEMIES[enemy.type].kind
	var phase: float = enemy.clock
	var frame := enemy_pose(phase)
	match kind:
		"slime":
			draw_circle(p + Vector2(0, 1), 6, color.darkened(0.2))
			draw_rect(Rect2(p + Vector2(-6, 1), Vector2(12, 5)), color)
			draw_arc(p + Vector2(0, 1), 5, PI, TAU, 10, color.lightened(0.25), 1)
		"beetle":
			for side in [-1, 1]:
				for j in range(3):
					draw_line(p + Vector2(side * 3, j * 3 - 3), p + Vector2(side * 7, j * 3 - 2), color.darkened(0.1), 1)
			draw_circle(p, 5, color)
			draw_line(p + Vector2(0, -5), p + Vector2(0, 5), color.darkened(0.5), 1)
		"bat":
			var flap := -3 if frame == 0 else 3
			for side in [-1, 1]:
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 8, -4 + flap), p + Vector2(side * 6, 3), p + Vector2(side * 3, 1)]), color)
			draw_circle(p, 3, color.lightened(0.2))
		"hopper":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 5), p + Vector2(-4, -3), p + Vector2(1, -7), p + Vector2(6, 3)]), color)
			draw_line(p + Vector2(-5, 3), p + Vector2(-7, 7), color, 2)
			draw_line(p + Vector2(4, 3), p + Vector2(7, 7), color, 2)
		"spider":
			for side in [-1, 1]:
				for j in range(4):
					var step := -1 if (frame + j) % 2 == 0 else 1
					draw_polyline(PackedVector2Array([p, p + Vector2(side * 5, j * 3 - 6), p + Vector2(side * 7, j * 3 - 4 + step)]), color, 1)
			draw_circle(p, 3.5, color.darkened(0.2))
		"wisp":
			draw_circle(p, 9, Color(color, 0.08))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(5, 1), p + Vector2(2, 6), p + Vector2(-4, 4), p + Vector2(-5, -1)]), color)
			if blink_closed(time, phase):
				draw_line(p + Vector2(-2, 2), p + Vector2(2, 2), Color("fff2b7"), 0.5)
			else:
				draw_circle(p + Vector2(0, 2), 2, Color("fff2b7"))
		"crab":
			draw_rect(Rect2(p + Vector2(-5, -3), Vector2(10, 8)), color)
			for side in [-1, 1]:
				draw_line(p + Vector2(side * 4, 1), p + Vector2(side * 7, -3), color, 2)
				draw_circle(p + Vector2(side * 6, -5), 2, color.lightened(0.3))
				draw_line(p + Vector2(side * 4, 4), p + Vector2(side * 7, 6), color, 1)
		"worm":
			for j in range(4):
				var step := -2 if (frame + j) % 2 == 0 else 2
				draw_circle(p + Vector2((j - 1.5) * 4, step), 3, color.lightened(j * 0.06))
		"eye":
			draw_circle(p, 8, Color(color, 0.08))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(0, -5), p + Vector2(8, 0), p + Vector2(0, 5)]), color)
			draw_circle(p, 0.5 if blink_closed(time, phase) else 3, Color("f5e5ed"))
			if not blink_closed(time, phase):
				draw_circle(p + (player - Vector2(enemy.pos)).normalized().round(), 1, Color("482a62"))
		"sentinel":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, -3), p + Vector2(5, 6), p + Vector2(0, 8), p + Vector2(-5, 6), p + Vector2(-7, -3)]), color.darkened(0.3))
			draw_line(p + Vector2(-3, -2), p + Vector2(3, -2), color.lightened(0.5), 0.5 if blink_closed(time, phase) else 2)
			draw_line(p + Vector2(0, 0), p + Vector2(0, 5), color, 2)
	if kind not in ["eye", "sentinel", "wisp"]:
		for x in [-2, 2]:
			if blink_closed(time, enemy.type * 1.73 + enemy.pos.x * 0.01):
				draw_line(p + Vector2(x - 1, -1), p + Vector2(x + 1, -1), Color("17212b"), 0.5)
			else:
				draw_circle(p + Vector2(x, -1), 1, Color("17212b"))

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
	draw_indicator(4, "Lives", str(lives), "heart")
	for pair in [[speed_rect, "speed"], [freeze_rect, "freeze"], [bag_rect, "bag"], [home_rect, "home"]]:
		var rect: Rect2 = pair[0]
		var active: bool = (pair[1] == "speed" and game_speed() > 1) or (pair[1] == "freeze" and is_frozen()) or (pair[1] == "bag" and inventory_open)
		var hover := rect.has_point(cursor_position)
		var locked: bool = (pair[1] == "speed" and upgrades.speed == 0) or (pair[1] == "freeze" and upgrades.freeze == 0)
		MineInk.panel(self, rect.grow(2 if hover else 0), MineInk.PANEL, MineInk.LINE.darkened(0.4) if locked else MineInk.LINE)
		MineInk.icon(self, pair[1], rect.get_center(), MineInk.MUTED.darkened(0.3) if locked else MineInk.TEXT)
		if locked:
			MineInk.icon(self, "lock", rect.position + Vector2(26, 26), MineInk.LINE, 0.6)
		if pair[1] == "home" and leave_glow:
			var glow := 0.5 + sin(ui_time * 7) * 0.5
			MineInk.outline(self, rect.grow(2), Color(MineInk.LINE, 0.25 + glow * 0.5))
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
	var ores := visible_ores()
	for slot in range(ores.size()):
		var ore := ores[slot]
		var y := MineWorld.TOP + 96 + slot * 31
		MineInk.panel(self, Rect2(48, y - 16, 384, 28), MineInk.PANEL, MineInk.LINE, 5)
		MineInk.ore_icon(self, Vector2(65, y - 2), ore, 0.95)
		MineInk.text(self, "%s  × %d" % [MineCatalog.ORES[ore].name, inventory[ore]], Vector2(86, y + 3), 13, MineCatalog.ore_color(ore))

func blink_closed(clock: float, offset: float) -> bool:
	var cycle := fposmod(clock + offset, 4.7)
	return cycle < 0.12 or (cycle > 2.83 and cycle < 2.93)

func begin_departure() -> void:
	if mode != "playing":
		return
	mode = "leaving"
	departure_time = 0
	departure_origin = player
	inventory_open = false
	mouse_held = false
	placement_held = false
	stroke_contacts.clear()
	synth.play_sound("freeze", -8, 1.3)

func draw_departure() -> void:
	var beam_bottom := lerpf(MineWorld.TOP, departure_origin.y + 28, smoothstep(0, 1, minf(1, departure_time / DEPARTURE_BEAM)))
	for band in range(8, 0, -1):
		var width := band * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(departure_origin.x - width * 0.5, MineWorld.TOP), Vector2(departure_origin.x + width * 0.5, MineWorld.TOP), Vector2(departure_origin.x + width, beam_bottom), Vector2(departure_origin.x - width, beam_bottom)]), Color(1, 0.91, 0.62, 0.04 + (8 - band) * 0.018))
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
		var pos: Vector2 = MineInk.snap(player + offset + flight.offset + flight.velocity * age + Vector2(0, 180 * age * age))
		MineCatalog.ore_shape(self, pos, flight.ore, 1.15)
	var progress := death_iris_progress()
	if progress <= 0:
		return
	if progress >= 1:
		draw_rect(Rect2(0, 0, 480, 800), Color.BLACK)
		return
	var center := player.clamp(Vector2.ZERO, Vector2(480, 800))
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
