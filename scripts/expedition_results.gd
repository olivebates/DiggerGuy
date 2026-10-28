extends Node2D

const STEP := 0.2
const LETTER_TIME := 0.03
const MAJOR_LETTER_TIME := 0.045
const MAP_START := 0.6
const FUNDS_START := 1.2
const HAUL_DURATION := 0.9
const BONUS_START := 2.2
const BONUS_DURATION := 0.8
const CONTINUE := Rect2(28, 730, 424, 46)
const PLAYER_ART := preload("res://scripts/player_render.gd")
const MATERIALS := Rect2(176, 78, 284, 224)
const MATERIAL_TOOLTIP := Rect2(28, 494, 424, 154)
const SUMMARY_SIZE := 22
const VALUE_START := 1.3
const VALUE_END := 2.1
const REWARD_START := 0.7
const REWARD_END := 2.5

var game: Node
var age := 0.0
var report: Dictionary = {}
var events: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var finish_time := 4.0
var map_finish := 0.0
var map_from := 0.0
var map_to := 0.0
var heard_events: Dictionary = {}
var record_heard := false
var goal_heard := false
var goal_ready_at := -10.0
var selected_discovery := -1
var graphics_viewport: SubViewport
var graphics_art: Node2D
var reward_beats: Array[Dictionary] = []
var heard_materials: Dictionary = {}
var heard_rewards: Dictionary = {}
var value_landed := false
var last_tick := -1
var record_at := -1.0

func _ready() -> void:
	graphics_viewport = SubViewport.new()
	graphics_viewport.size = Vector2i(240, 400)
	graphics_viewport.transparent_bg = true
	graphics_viewport.msaa_2d = Viewport.MSAA_DISABLED
	graphics_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	graphics_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(graphics_viewport)
	graphics_art = Node2D.new()
	graphics_art.set_script(preload("res://scripts/progression_art.gd"))
	graphics_art.results = self
	graphics_art.scale = Vector2.ONE * 0.5
	var pixels := ShaderMaterial.new()
	pixels.shader = preload("res://shaders/crisp.gdshader")
	pixels.set_shader_parameter("dither_pixel_size", 1.0)
	graphics_art.material = pixels
	graphics_viewport.add_child(graphics_art)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_report(data: Dictionary) -> void:
	report = data.duplicate(true)
	age = 0
	heard_events.clear()
	record_heard = false
	goal_heard = false
	selected_discovery = -1
	heard_materials.clear()
	heard_rewards.clear()
	value_landed = false
	last_tick = -1
	events.clear()
	for entry in report.get("events", []):
		if entry.depth >= report.start_depth:
			events.append(entry.duplicate())
	build_timeline()
	visible = true
	queue_redraw()
	graphics_art.queue_redraw()

func build_timeline() -> void:
	segments.clear()
	map_from = float(report.start_depth)
	map_to = float(report.next_milestone.depth)
	var distance := maxf(1, float(report.peak_depth) - map_from)
	var cursor := map_from
	var clock := MAP_START
	for event in events:
		var depth: float = event.depth
		if depth > cursor:
			var duration := maxf(0.12, (depth - cursor) / distance * 2.0)
			segments.append({"start": clock, "end": clock + duration, "from": cursor, "to": depth})
			clock += duration
		event.reveal_at = clock
		segments.append({"start": clock, "end": clock + 0.4, "from": depth, "to": depth})
		clock += 0.4
		cursor = depth
	if float(report.peak_depth) > cursor:
		var duration := maxf(0.12, (float(report.peak_depth) - cursor) / distance * 2.0)
		segments.append({"start": clock, "end": clock + duration, "from": cursor, "to": float(report.peak_depth)})
		clock += duration
	map_finish = clock
	# A long run still receives a brisk reveal; no extra wait per discovery.
	var time_scale := 1.9 / maxf(0.01, map_finish - MAP_START)
	for segment in segments:
		segment.start = MAP_START + (float(segment.start) - MAP_START) * time_scale
		segment.end = MAP_START + (float(segment.end) - MAP_START) * time_scale
	for event in events:
		event.reveal_at = MAP_START + (float(event.reveal_at) - MAP_START) * time_scale
	map_finish = MAP_START + 1.9
	record_at = -1
	if report.peak_depth > report.previous_best:
		for segment in segments:
			if segment.to > report.previous_best:
				var t := clampf((float(report.previous_best) - float(segment.from)) / maxf(1, float(segment.to) - float(segment.from)), 0, 1)
				# Inverse smoothstep locates the crossing within the moving segment.
				t = 0.5 - sin(asin(1 - 2 * t) / 3)
				record_at = lerpf(segment.start, segment.end, t)
				break
	build_reward_beats()
	finish_time = 3.0

func build_reward_beats() -> void:
	reward_beats.clear()
	var earned: Array = report.get("earned_milestones", [])
	# Group exceptionally deep runs into at most five readable celebrations.
	var batch := maxi(1, ceili(earned.size() / 5.0))
	for start in range(0, earned.size(), batch):
		var stop := mini(start + batch, earned.size())
		var reward := 0
		for i in range(start, stop):
			reward += int(earned[i].reward)
		reward_beats.append({"depth": earned[stop - 1].depth, "reward": reward, "count": stop - start})

func stat_count(value: int, start: float, duration: float, clock: float = -1) -> int:
	var at := age if clock < 0 else clock
	return roundi(value * smoothstep(0, 1, clampf((at - start) / duration, 0, 1)))

func material_reveal_at(ore: int) -> float:
	var fresh: Array = report.get("new_materials", [])
	var index := fresh.find(ore)
	return 0.65 + index * 0.9 / maxi(1, fresh.size()) if index >= 0 else STEP * 2

func reward_beat_time(index: int) -> float:
	return REWARD_START + (REWARD_END - REWARD_START) * (index + 0.7) / maxi(1, reward_beats.size())

func displayed_bonus(clock: float = -1) -> int:
	var at := age if clock < 0 else clock
	var total := 0
	for i in range(reward_beats.size()):
		if at >= reward_beat_time(i) + 0.22:
			total += int(reward_beats[i].reward)
	return total

func _process(delta: float) -> void:
	graphics_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not visible or report.is_empty():
		return
	age += delta
	for i in range(events.size()):
		if age >= float(events[i].reveal_at) and not heard_events.has(i):
			heard_events[i] = true
			# Material collection alone earns its discovery sound in the journal.
			if events[i].kind != "ore":
				game.synth.play_sound("discovery_" + str(events[i].kind), -6)
	for ore in report.get("new_materials", []):
		if age >= material_reveal_at(ore) and not heard_materials.has(ore):
			heard_materials[ore] = true
			game.synth.play_sound("discovery_ore", -7)
	for i in range(reward_beats.size()):
		if age >= reward_beat_time(i) and not heard_rewards.has(i):
			heard_rewards[i] = true
			game.synth.play_sound("results_reward", -7, 1 + i * 0.05)
	if age >= record_at and record_at >= 0 and not record_heard:
		record_heard = true
		game.synth.play_sound("depth_record", -5)
	if age >= VALUE_START and age < VALUE_END:
		var tick := floori((age - VALUE_START) / 0.085)
		if tick != last_tick and report.haul_value > 0:
			last_tick = tick
			game.synth.play_sound("results_tick", -11, 1 + 0.025 * tick)
	if age >= VALUE_END and not value_landed:
		value_landed = true
		if report.haul_value > 0:
			game.synth.play_sound("results_value", -5)
	if age >= 2.6 and not goal_heard:
		goal_heard = true
		if not report.get("affordable_upgrades", []).is_empty():
			game.synth.play_sound("goal_ready", -7)
	queue_redraw()
	graphics_art.queue_redraw()

func is_revealed() -> bool:
	return age >= finish_time

func complete_reveal() -> void:
	age = maxf(age, finish_time)
	for i in range(events.size()):
		heard_events[i] = true
	record_heard = true
	goal_heard = true
	value_landed = true
	for ore in report.get("new_materials", []):
		heard_materials[ore] = true
	for i in range(reward_beats.size()):
		heard_rewards[i] = true
	queue_redraw()
	graphics_art.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or report.is_empty():
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var entered: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER
	if not clicked and not entered:
		return
	get_viewport().set_input_as_handled()
	if not is_revealed():
		complete_reveal()
		return
	if entered or CONTINUE.has_point(event.position):
		game.continue_to_depot()

func depth_at(clock: float = -1.0) -> float:
	var at := age if clock < 0 else clock
	var depth := map_from
	for segment in segments:
		if at < segment.start:
			break
		var t := clampf((at - float(segment.start)) / maxf(0.001, float(segment.end) - float(segment.start)), 0, 1)
		depth = lerpf(segment.from, segment.to, smoothstep(0, 1, t))
		if at < segment.end:
			return depth
	return depth

func animated_funds(clock: float = -1.0) -> int:
	var at := age if clock < 0 else clock
	var haul_t := smoothstep(0, 1, clampf((at - FUNDS_START) / HAUL_DURATION, 0, 1))
	var bonus_t := smoothstep(0, 1, clampf((at - BONUS_START) / BONUS_DURATION, 0, 1))
	return roundi(float(report.funds_before) + float(report.haul_change) * haul_t + float(report.bonus_earned) * bonus_t)

func current_event_index() -> int:
	var index := -1
	for i in range(events.size()):
		if age >= float(events[i].reveal_at):
			index = i
	return index

func visible_character_count(value: String, start: float, major: bool = false) -> int:
	return clampi(floori((age - start) / (MAJOR_LETTER_TIME if major else LETTER_TIME)), 0, value.length())

func typed(value: String, pos: Vector2, width: float, size: int, start: float, color: Color = MineInk.TEXT, major: bool = false, max_lines: int = 3) -> void:
	if age < start:
		return
	var remaining := visible_character_count(value, start, major)
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var next := word if line.is_empty() else line + " " + word
			if MineInk.FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and not line.is_empty():
				lines.append(line)
				line = word
			else:
				line = next
		lines.append(line)
	for i in range(mini(max_lines, lines.size())):
		MineInk.text(self, lines[i].left(remaining), pos, size, color)
		remaining = maxi(0, remaining - lines[i].length() - 1)
		pos.y += size + 6

func fit_size(value: String, width: float, size: int) -> int:
	while size > 10 and MineInk.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	return size

func panel(rect: Rect2, start: float) -> bool:
	if age < start:
		return false
	MineInk.panel(self, rect)
	return true

func map_y(depth: float) -> float:
	return lerpf(144, 274, clampf((depth - map_from) / maxf(1, map_to - map_from), 0, 1))

func material_rect(slot: int) -> Rect2:
	return Rect2(190 + (slot % 8) * 32, 124 + (slot / 8) * 26, 24, 24)

func hovered_material() -> int:
	if age < STEP * 2:
		return -1
	for slot in range(game.discovered_materials.size()):
		if age >= material_reveal_at(game.discovered_materials[slot]) and material_rect(slot).has_point(game.cursor_position):
			return game.discovered_materials[slot]
	return -1

func draw_depth_map() -> void:
	typed("DEPTH", Vector2(34, 104), 118, 15, STEP * 2, MineInk.GOLD)
	MineInk.fitted_text(self, "+%d m" % maxi(0, roundi(depth_at() - map_from)), Vector2(34, 124), 118, 13, MineInk.GOLD)
	for step in range(10):
		var y := 144 + step * 13
		var color := MineWorld.region_color(roundi(lerpf(map_from, map_to, step / 9.0)), "rock")
		draw_rect(Rect2(32, y, 8, 10), color.darkened(0.2))
		draw_rect(Rect2(58, y + 3, 8, 10), color)
	draw_rect(Rect2(46, 144, 6, 130), MineInk.LINE.darkened(0.65))
	var current := depth_at()
	draw_rect(Rect2(46, 144, 6, maxf(2, map_y(current) - 144)), MineInk.GOLD)
	var best := int(report.previous_best) if record_at >= 0 and age < map_finish else int(report.best_depth)
	var best_y := map_y(best)
	var flash := record_at >= 0 and age >= record_at and age < record_at + 0.45
	for x in range(76, 150, 8):
		draw_rect(Rect2(x, best_y, 4, 2 if flash else 1), MineInk.TEXT if flash else MineInk.LINE)
	MineInk.fitted_text(self, "Best: %d" % best, Vector2(76, best_y - 5), 78, 10, MineInk.GOLD)
	MineInk.fitted_text(self, "%d m" % int(map_to), Vector2(34, 291), 118, 11, MineInk.MUTED)

func draw_materials() -> void:
	typed("Discovered Materials", Vector2(190, 104), 252, 15, STEP * 2, MineInk.GOLD)
	for slot in range(game.discovered_materials.size()):
		var ore: int = game.discovered_materials[slot]
		if age < material_reveal_at(ore):
			continue
		var rect := material_rect(slot)
		var fresh: bool = ore in report.get("new_materials", [])
		MineInk.panel(self, rect, MineInk.PANEL, MineInk.GOLD if fresh or rect.has_point(game.cursor_position) else MineInk.LINE.darkened(0.35))
	if game.discovered_materials.is_empty():
		typed("Collect materials to fill this journal.", Vector2(192, 176), 240, 13, STEP * 3, MineInk.MUTED)
	var next: int = game.next_material()
	var footer := "Next material at %d meters" % int(MineCatalog.ORES[next].depth) if next >= 0 else "All materials discovered"
	typed(footer, Vector2(190, 291), 252, 11, STEP * 4, MineInk.MUTED, false, 1)

func draw_material_tooltip(ore: int) -> void:
	var rect := MATERIAL_TOOLTIP
	MineInk.panel(self, rect, MineInk.PANEL, MineInk.GOLD)
	var material: Dictionary = MineCatalog.ORES[ore]
	var x := rect.position.x + 108
	MineInk.fitted_text(self, material.name, Vector2(x, rect.position.y + 33), 296, 20, MineCatalog.ore_color(ore))
	MineInk.text(self, "Value: %d coins" % int(material.value), Vector2(x, rect.position.y + 64), 14)
	MineInk.text(self, "Amount sold: %d" % int(game.materials_sold[ore]), Vector2(x, rect.position.y + 91), 14)
	MineInk.text(self, "Found at: %d meters" % int(material.depth), Vector2(x, rect.position.y + 118), 14, MineInk.MUTED)

func milestone_state() -> Dictionary:
	var milestone: Dictionary = report.next_milestone
	var active := -1
	if age >= REWARD_START and age < REWARD_END + 0.22 and not reward_beats.is_empty():
		active = mini(reward_beats.size() - 1, floori((age - REWARD_START) / (REWARD_END - REWARD_START) * reward_beats.size()))
	if active >= 0:
		milestone = reward_beats[active]
	var goal := int(milestone.depth)
	var previous := goal - MineCatalog.MILESTONE_STEP
	var depth := mini(goal, maxi(int(report.previous_best), roundi(depth_at())))
	if age >= map_finish:
		depth = mini(goal, int(report.best_depth))
	var complete := active >= 0 and age >= reward_beat_time(active)
	if active >= 0:
		previous = int(report.earned_milestones[0].depth) - MineCatalog.MILESTONE_STEP if active == 0 else int(reward_beats[active - 1].depth)
		var start := REWARD_START if active == 0 else REWARD_START + (REWARD_END - REWARD_START) * active / reward_beats.size()
		var t := clampf((age - start) / maxf(0.01, reward_beat_time(active) - start), 0, 1)
		depth = roundi(lerpf(previous, goal, smoothstep(0, 1, t)))
	var old_progress := clampf(float(int(report.previous_best) - previous) / maxi(1, goal - previous), 0, 1)
	var progress := maxf(old_progress, clampf(float(depth - previous) / maxi(1, goal - previous), 0, 1))
	var run_depth := int(report.get("end_depth", report.peak_depth))
	return {"goal": goal, "reward": int(milestone.reward), "active": active, "complete": complete, "depth": depth, "run_depth": run_depth, "remaining": maxi(0, goal - run_depth), "old_progress": old_progress, "progress": progress}

func draw_next_milestone() -> void:
	var state := milestone_state()
	var heading := "MILESTONE REACHED" if state.complete else "NEXT MILESTONE"
	MineInk.text(self, heading, Vector2(36, 500), 16, MineInk.GOLD)
	MineInk.text(self, "%d m" % int(state.goal), Vector2(36, 540), SUMMARY_SIZE)
	var reward := "Reward: +%d coins" % int(state.reward)
	MineInk.fitted_text(self, reward, Vector2(278, 538), 166, 13, MineInk.GOLD)
	var bar := Rect2(36, 556, 408, 8)
	draw_rect(bar, MineInk.LINE.darkened(0.65))
	# Previous achievement stays subdued; only progress earned this run shines.
	var old_width := floorf(bar.size.x * float(state.old_progress))
	var width := floorf(bar.size.x * float(state.progress))
	draw_rect(Rect2(bar.position, Vector2(old_width, bar.size.y)), MineInk.GOLD.darkened(0.5))
	if width > old_width:
		draw_rect(Rect2(bar.position + Vector2(old_width, 0), Vector2(width - old_width, bar.size.y)), MineInk.GOLD.lightened(0.15))
	MineInk.text(self, "%d / %d m" % [int(state.run_depth), int(state.goal)], Vector2(36, 581), 11, MineInk.MUTED)
	var remaining := "%d meters left" % int(state.remaining)
	var label_width := MineInk.FONT.get_string_size(remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	MineInk.text(self, remaining, Vector2(444 - label_width, 581), 11, MineInk.GOLD if state.complete else MineInk.MUTED)
	if not reward_beats.is_empty():
		draw_line(Vector2(36, 588), Vector2(444, 588), MineInk.LINE.darkened(0.35), 1)
		MineInk.text(self, "Earned this run: +%d coins" % displayed_bonus(), Vector2(36, 603), 11, MineInk.GOLD)
	for i in range(reward_beats.size()):
		var t := (age - reward_beat_time(i)) / 0.22
		if t >= 0 and t < 1:
			var pos := Vector2(355, 535).lerp(Vector2(330, 600), t) - Vector2(0, sin(t * PI) * 20)
			MineInk.text(self, "+%d" % int(reward_beats[i].reward), pos, 12, MineInk.TEXT)

func draw_run_stats() -> void:
	var lines := ["%d ores found" % stat_count(int(report.get("ores_found", report.get("ore_count", 0))), 0.4, 0.6), "%d blocks broken" % stat_count(int(report.get("blocks_broken", 0)), 0.65, 0.6), "%d meters" % stat_count(maxi(0, int(report.peak_depth) - int(report.start_depth)), 0.9, 0.6), "Value: %d coins" % stat_count(int(report.haul_value), VALUE_START, VALUE_END - VALUE_START)]
	for i in range(lines.size()):
		var y := 338 + i * 29 + (12 if i == 3 else 0)
		if age < 0.4 + i * 0.25:
			continue
		var bounce := -sin(clampf((age - VALUE_END) / 0.3, 0, 1) * PI) * 4 if i == 3 else 0.0
		MineInk.fitted_text(self, lines[i], Vector2(66, y + bounce), 378, SUMMARY_SIZE if i == 3 else 16, MineInk.GOLD if i == 3 else MineInk.TEXT)
		if i == 0:
			var lost := "(Lost: %d ores)" % int(report.get("ores_lost", 0))
			var lost_width := MineInk.FONT.get_string_size(lost, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			MineInk.text(self, lost, Vector2(444 - lost_width, y), 11, MineInk.MUTED)
	if age >= 1.15:
		draw_line(Vector2(36, 409), Vector2(444, 409), MineInk.LINE, 1)

func draw_pixel_graphics(canvas: CanvasItem) -> void:
	if report.is_empty():
		return
	if age >= STEP * 3 and hovered_material() < 0:
		MineInk.icon(canvas, "coin", Vector2(262, 532), MineInk.GOLD, 0.7)
		var state := milestone_state()
		if state.complete:
			var stamp_age := age - reward_beat_time(int(state.active))
			var pop := sin(clampf(stamp_age / 0.15, 0, 1) * PI) * 2
			var center := Vector2(430, 494 - pop)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, 0), center + Vector2(-2, 4), center + Vector2(6, -5)]), MineInk.GOLD, 2)
	for i in range(4):
		if age >= 0.4 + i * 0.25:
			MineInk.icon(canvas, ["bag", "pick", "depth", "coin"][i], Vector2(46, 332 + i * 29 + (10 if i == 3 else 0)), MineInk.GOLD, 0.8)
	if age >= STEP:
		PLAYER_ART.draw_equipment(canvas, Vector2(49, map_y(depth_at()) + 8), report.equipment_before, 1.5)
	if age >= STEP * 2:
		for slot in range(game.discovered_materials.size()):
			var ore: int = game.discovered_materials[slot]
			var since := age - material_reveal_at(ore)
			if since >= 0:
				var fresh: bool = ore in report.get("new_materials", [])
				var pop := 1 + sin(clampf(since / 0.35, 0, 1) * PI) * 0.35 if fresh else 1.0
				var center := material_rect(slot).get_center() + Vector2(0, 2 if fresh else 0)
				MineCatalog.ore_shape(canvas, center, ore, 2 * pop)
				if fresh and since < 0.65:
					for ray in range(4):
						var point := center + Vector2.from_angle(ray * PI * 0.5 + 0.4) * (8 + since * 12)
						canvas.draw_line(point - Vector2(2, 0), point + Vector2(2, 0), MineInk.GOLD, 1)
						canvas.draw_line(point - Vector2(0, 2), point + Vector2(0, 2), MineInk.GOLD, 1)
	var ore := hovered_material()
	if ore >= 0:
		MineCatalog.ore_shape(canvas, MATERIAL_TOOLTIP.position + Vector2(54, 78), ore, 6)

func _draw() -> void:
	if report.is_empty():
		return
	draw_rect(Rect2(0, 0, 480, 800), MineInk.BG)
	if panel(Rect2(20, 16, 440, 52), 0):
		var color := MineInk.GOLD if report.hero_kind != "progress" else MineInk.TEXT
		var record_badge := record_at >= 0 and age >= record_at
		# The title arrives quickly, leaving time for the earned celebration.
		var chars := clampi(floori(age / 0.018), 0, str(report.hero_title).length())
		MineInk.text(self, str(report.hero_title).left(chars), Vector2(36, 40 if record_badge else 45), fit_size(report.hero_title, 408, 23), color)
		if record_badge:
			MineInk.text(self, "NEW BEST! +%d m" % (int(report.peak_depth) - int(report.previous_best)), Vector2(36, 60), 10, MineInk.GOLD)
	if panel(Rect2(20, 312, 440, 152), STEP * 2):
		draw_run_stats()

	if panel(Rect2(20, 78, 146, 224), STEP):
		draw_depth_map()
	if panel(MATERIALS, STEP * 2):
		draw_materials()
	if panel(Rect2(20, 476, 440, 134), STEP * 3):
		draw_next_milestone()
	if panel(Rect2(20, 622, 440, 98), STEP * 4):
		var upgrades_ready: Array = report.get("affordable_upgrades", [])
		var badge := not upgrades_ready.is_empty() and age >= 2.6
		if badge:
			MineInk.fitted_text(self, "%s now affordable" % str(upgrades_ready[0]), Vector2(36, 644), 408, 12, MineInk.GOLD)
		# Reveal by words so flavor never prolongs the three-second sequence.
		var message := str(report.flavor)
		var revealed := clampi(roundi(message.length() * clampf((age - 0.8) / 1.6, 0, 1)), 0, message.length())
		var display := message.left(revealed)
		if revealed < message.length():
			display = display.left(maxi(0, display.rfind(" ")))
		# typed() performs wrapping; a start in the past displays the chosen words.
		typed(display, Vector2(36, 670 if badge else 650), 408, 14, -10, MineInk.TEXT, false, 2 if badge else 3)
	if age >= STEP * 6:
		var hover := CONTINUE.has_point(game.cursor_position)
		MineInk.panel(self, CONTINUE.grow(2 if hover else 0), MineInk.PANEL, MineInk.LINE.lightened(0.25) if hover else MineInk.LINE)
		typed("Continue", Vector2(196, 759), 120, 16, STEP * 7)
		MineInk.centered(self, "Click anywhere to finish reveals" if not is_revealed() else "Your next expedition awaits", 793, 10, MineInk.MUTED)
	var ore := hovered_material()
	if ore >= 0:
		draw_material_tooltip(ore)
	draw_texture_rect(graphics_viewport.get_texture(), Rect2(0, 0, 480, 800), false)
	# Keep the journal labels above the art, including its arrival bounce.
	for slot in range(game.discovered_materials.size()):
		var material: int = game.discovered_materials[slot]
		if material in report.get("new_materials", []) and age >= material_reveal_at(material):
			var rect := material_rect(slot)
			draw_rect(Rect2(rect.position + Vector2.ONE, Vector2(22, 8)), MineInk.PANEL)
			MineInk.text(self, "NEW", rect.position + Vector2(1, 7), 6, MineInk.GOLD)
