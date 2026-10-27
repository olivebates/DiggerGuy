extends Node2D

const STEP := 0.2
const LETTER_TIME := 0.03
const MAJOR_LETTER_TIME := 0.045
const MAP_START := 0.6
const FUNDS_START := 1.2
const HAUL_DURATION := 0.9
const BONUS_START := 2.3
const BONUS_DURATION := 0.8
const CONTINUE := Rect2(28, 730, 424, 46)
const PLAYER_ART := preload("res://scripts/player_render.gd")

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

func show_report(data: Dictionary) -> void:
	report = data.duplicate(true)
	age = 0
	heard_events.clear()
	record_heard = false
	goal_heard = false
	goal_ready_at = -10
	selected_discovery = -1
	events.clear()
	for entry in report.get("events", []):
		events.append(entry.duplicate())
	build_timeline()
	visible = true
	queue_redraw()

func build_timeline() -> void:
	segments.clear()
	map_from = float(report.previous_best) if report.hero_kind == "record" else float(report.start_depth)
	map_from = minf(map_from, report.peak_depth)
	map_to = maxf(map_from + 1, maxf(report.previous_best, report.peak_depth))
	var distance := maxf(1, float(report.peak_depth) - map_from)
	var cursor := map_from
	var clock := MAP_START
	for event in events:
		var depth: float = event.depth
		if depth > cursor:
			var duration := maxf(0.12, (depth - cursor) / distance * 2.0)
			segments.append({"start": clock, "end": clock + duration, "from": cursor, "to": depth})
			clock += duration
		var hold := 1.1 if event.kind == "ore" else (1.55 if event.kind == "animal" else 1.85)
		event.reveal_at = clock
		segments.append({"start": clock, "end": clock + hold, "from": depth, "to": depth})
		clock += hold
		cursor = depth
	if float(report.peak_depth) > cursor:
		var duration := maxf(0.12, (float(report.peak_depth) - cursor) / distance * 2.0)
		segments.append({"start": clock, "end": clock + duration, "from": cursor, "to": float(report.peak_depth)})
		clock += duration
	map_finish = clock
	finish_time = maxf(map_finish + 0.65, BONUS_START + BONUS_DURATION + 0.8)
	finish_time = maxf(finish_time, STEP * 7 + str(report.next_goal).length() * LETTER_TIME)
	if not events.is_empty():
		finish_time = maxf(finish_time, float(events[-1].reveal_at) + 0.22 + str(events[-1].detail).length() * LETTER_TIME)

func _process(delta: float) -> void:
	if not visible or report.is_empty():
		return
	age += delta
	for i in range(events.size()):
		if age >= float(events[i].reveal_at) and not heard_events.has(i):
			heard_events[i] = true
			game.synth.play_sound("discovery_" + str(events[i].kind), -6)
	if age >= map_finish and not record_heard:
		record_heard = true
		if report.hero_kind in ["record", "treasure"]:
			game.synth.play_sound("depth_record", -5)
	if not goal_heard and int(report.funds_before) < int(report.target_price) and animated_funds() >= int(report.target_price):
		goal_heard = true
		goal_ready_at = age
		game.synth.play_sound("goal_ready", -7)
	queue_redraw()

func is_revealed() -> bool:
	return age >= finish_time

func complete_reveal() -> void:
	age = maxf(age, finish_time)
	for i in range(events.size()):
		heard_events[i] = true
	record_heard = true
	goal_heard = true
	# Skipping settles the animations without a burst of queued sounds.
	goal_ready_at = age - 1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or report.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and Rect2(176, 118, 284, 252).has_point(event.position) and not events.is_empty():
		complete_reveal()
		var current := current_event_index()
		selected_discovery = clampi(current + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, events.size() - 1)
		get_viewport().set_input_as_handled()
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
	var before: float = report.funds_before
	var haul: float = report.haul_change
	var bonus: float = report.bonus_earned
	var haul_t := smoothstep(0, 1, clampf((at - FUNDS_START) / HAUL_DURATION, 0, 1))
	var bonus_t := smoothstep(0, 1, clampf((at - BONUS_START) / BONUS_DURATION, 0, 1))
	return roundi(before + haul * haul_t + bonus * bonus_t)

func current_event_index() -> int:
	if selected_discovery >= 0:
		return selected_discovery
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
	return lerpf(172, 318, clampf((depth - map_from) / maxf(1, map_to - map_from), 0, 1))

func draw_burst(center: Vector2, since: float, color: Color) -> void:
	if since < 0 or since >= 0.6:
		return
	for i in range(8):
		var direction := Vector2.from_angle(i * TAU / 8)
		var point := MineInk.snap(center + direction * (10 + since * 45))
		draw_rect(Rect2(point, Vector2.ONE * (4 if since < 0.3 else 2)), color)

func draw_depth_map() -> void:
	typed("DEPTH", Vector2(34, 144), 118, 15, STEP * 2, MineInk.GOLD)
	for step in range(11):
		var y := 170 + step * 14
		var color := MineWorld.region_color(roundi(lerpf(map_from, map_to, step / 10.0)), "rock")
		draw_rect(Rect2(32, y, 8, 10), color.darkened(0.2))
		draw_rect(Rect2(58, y + 3, 8, 10), color)
	draw_rect(Rect2(46, 172, 6, 146), MineInk.LINE.darkened(0.65))
	var current := depth_at()
	draw_rect(Rect2(46, 172, 6, maxf(2, map_y(current) - 172)), MineInk.GOLD)
	for event in events:
		var color := MineInk.LINE
		if age >= float(event.reveal_at):
			color = MineCatalog.ore_color(event.id) if event.kind == "ore" else MineInk.GOLD
		draw_rect(Rect2(68, map_y(event.depth) - 1, 6, 2), color)
	MineInk.text(self, "%d m" % roundi(map_from), Vector2(80, 178), 11, MineInk.MUTED)
	if int(report.previous_best) > map_from and int(report.previous_best) <= map_to:
		var y := map_y(report.previous_best)
		for x in range(76, 150, 8):
			draw_rect(Rect2(x, y, 4, 1), MineInk.LINE)
	PLAYER_ART.draw_equipment(self, Vector2(49, map_y(current) + 8), report.equipment_before, 1)
	MineInk.fitted_text(self, "%d m" % roundi(current), Vector2(34, 343), 116, 23, MineInk.GOLD)
	MineInk.fitted_text(self, "Old best: %d m" % int(report.previous_best), Vector2(34, 359), 118, 10, MineInk.MUTED)

func draw_milestone_art(event: Dictionary, center: Vector2) -> void:
	var depth: int = event.depth
	if depth == 100:
		for side in [-1, 1]:
			draw_line(center + Vector2(0, 34), center + Vector2(side * 22, -28), Color("83bd79"), 4)
			draw_rect(Rect2(center + Vector2(side * 24 - 7, -30), Vector2(14, 10)), Color("c3e69b"))
	elif depth == 300 or event.get("context", "") == "TREASURE":
		draw_rect(Rect2(center + Vector2(-38, -18), Vector2(76, 52)), Color("946c4d"))
		draw_rect(Rect2(center + Vector2(-38, -22), Vector2(76, 16)), MineInk.GOLD)
		for x in [-24, 20]:
			draw_rect(Rect2(center + Vector2(x, -18), Vector2(6, 52)), Color("e1b95e"))
		draw_rect(Rect2(center + Vector2(-5, -5), Vector2(10, 16)), Color("ffe5a0"))
	elif depth == 360:
		draw_rect(Rect2(center + Vector2(-46, 14), Vector2(92, 24)), Color("dc623b"))
		for i in range(4):
			draw_rect(Rect2(center + Vector2(-40 + i * 24, 10 + (i % 2) * 4), Vector2(16, 6)), Color("f4b254"))
	elif depth == 920:
		for i in range(3):
			game.draw_enemy({"pos": center + Vector2((i - 1) * 36, 8), "type": 7, "dir": 1, "clock": age + i, "ground": true, "vel": Vector2.ZERO}, self, true, 2)
			draw_set_transform(Vector2.ZERO)
	else:
		for i in range(4):
			var root := center + Vector2((i - 1.5) * 22, 34)
			var tint := Color.from_hsv(0.46 + i * 0.1, 0.38, 0.85) if depth >= 2600 else Color("b69bda")
			draw_colored_polygon(PackedVector2Array([root - Vector2(10, 0), root + Vector2(0, -40 - i * 8), root + Vector2(10, 0)]), tint)

func draw_discovery() -> void:
	var index := current_event_index()
	var event: Dictionary = events[index] if index >= 0 else report.fallback
	var start := float(event.get("reveal_at", STEP * 2))
	var context: String = event.get("context", "NEW " + str(event.kind).to_upper())
	if index < 0 and not events.is_empty():
		event = events[0]
		start = event.reveal_at
		context = "NEXT STOP BELOW"
	elif index >= 0:
		context = "NEW " + str(event.kind).to_upper() + " | %d / %d" % [index + 1, events.size()]
	typed(context, Vector2(192, 143), 252, 12, STEP * 2, MineInk.GOLD)
	if age < start:
		MineInk.centered(self, "?", 260, 54, MineInk.LINE, 318)
		return
	var name_size := fit_size(event.name, 252, 20)
	typed(event.name, Vector2(192, 171), 252, name_size, start, MineInk.TEXT, event.kind == "milestone", 1)
	var center := Vector2(318, 246)
	if event.kind == "ore":
		MineCatalog.ore_shape(self, center, event.id, 8, sin(age * 0.8) * 0.12)
	elif event.kind == "animal":
		game.draw_enemy({"pos": center, "type": event.id, "dir": 1, "clock": age, "ground": true, "vel": Vector2.ZERO}, self, true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_milestone_art(event, center)
	draw_burst(center, age - start, MineInk.GOLD)
	typed(event.detail, Vector2(192, 313), 252, 12, start + STEP, MineInk.TEXT, false, 2)
	var caption := "From %d m" % int(event.depth)
	if event.kind == "milestone" and event.has("value"):
		caption = "%d m | +%d coins" % [event.depth, event.value]
	if not events.is_empty():
		caption += " | Wheel: discoveries"
	MineInk.fitted_text(self, caption, Vector2(192, 356), 252, 10, MineInk.MUTED)

func draw_coin_transfer() -> void:
	var amount := 0
	var progress := -1.0
	var source := Vector2(92, 480)
	if age >= FUNDS_START and age < FUNDS_START + HAUL_DURATION:
		progress = (age - FUNDS_START) / HAUL_DURATION
		amount = int(report.haul_change)
	elif age >= BONUS_START and age < BONUS_START + BONUS_DURATION:
		progress = (age - BONUS_START) / BONUS_DURATION
		amount = int(report.bonus_earned)
		source.x = 300
	if amount == 0 or progress < 0:
		return
	for i in range(5):
		var t := clampf(progress * 1.5 - i * 0.1, 0, 1)
		if t <= 0 or t >= 1:
			continue
		if amount < 0:
			t = 1 - t
		var end := Vector2(240, 448)
		var control := Vector2(source.x, 416)
		var point := source.lerp(control, t).lerp(control.lerp(end, t), t)
		MineInk.icon(self, "coin", point, MineInk.GOLD if amount > 0 else Color("ff8585"), 0.65)

func draw_upgrade_progress() -> void:
	typed(report.target_name.to_upper(), Vector2(36, 404), 408, 16, STEP * 4, MineInk.GOLD)
	var funds := animated_funds()
	var price: int = report.target_price
	var tally := "After selling: %d -> %d / %d coins" % [report.funds_before, funds, price]
	typed(tally, Vector2(36, 428), 408, fit_size(tally, 408, 13), STEP * 5, MineInk.TEXT, false, 1)
	var bar := Rect2(36, 442, 408, 10)
	draw_rect(bar, MineInk.LINE.darkened(0.65))
	draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * clampf(float(funds) / maxf(1, price), 0, 1)), 10)), MineInk.GOLD)
	if funds >= price:
		MineInk.outline(self, bar.grow(2), Color("83d990"))
	typed("Haul: %+d   Bonus: %+d" % [report.haul_change, report.bonus_earned], Vector2(36, 478), 408, 13, STEP * 6)
	var remaining := maxi(0, price - funds)
	var status := "%d coins to go." % remaining if remaining > 0 else "Ready to buy at the depot!"
	MineInk.text(self, status, Vector2(36, 500), 14, MineInk.MUTED if remaining > 0 else Color("83d990"))
	typed(report.affordable if str(report.affordable).begins_with("Newly affordable") else report.outcome, Vector2(36, 525), 408, 11, STEP * 7, MineInk.MUTED, false, 1)
	draw_coin_transfer()
	draw_burst(Vector2(430, 448), age - goal_ready_at, Color("83d990"))

func _draw() -> void:
	if report.is_empty():
		return
	draw_rect(Rect2(0, 0, 480, 800), MineInk.BG)
	if panel(Rect2(20, 16, 440, 92), 0):
		var color := MineInk.GOLD if report.hero_kind != "progress" else MineInk.TEXT
		typed(report.hero_title, Vector2(36, 45), 408, fit_size(report.hero_title, 408, 23), 0, color, true, 1)
		var number := "%d m" % roundi(depth_at())
		MineInk.text(self, number, Vector2(36, 85), fit_size(number, 145, 26), color)
		typed(report.hero_detail, Vector2(190, 70), 254, 12, STEP, MineInk.TEXT, false, 2)
		if report.hero_kind in ["record", "treasure"]:
			draw_burst(Vector2(430, 45), age - map_finish, MineInk.GOLD)
	if panel(Rect2(20, 118, 146, 252), STEP):
		draw_depth_map()
	if panel(Rect2(176, 118, 284, 252), STEP * 2):
		draw_discovery()
	if panel(Rect2(20, 380, 440, 160), STEP * 3):
		draw_upgrade_progress()
	if panel(Rect2(20, 550, 440, 106), STEP * 4):
		typed("NOW", Vector2(44, 574), 70, 11, STEP * 5, MineInk.MUTED)
		typed("NEXT", Vector2(116, 574), 70, 11, STEP * 6, MineInk.GOLD)
		if age >= STEP * 5:
			PLAYER_ART.draw_equipment(self, Vector2(62, 638), report.equipment_before, 2)
		if age >= STEP * 6:
			PLAYER_ART.draw_equipment(self, Vector2(134, 638), report.equipment_after, 2)
			MineInk.icon(self, "arrow", Vector2(98, 614), MineInk.GOLD, 0.7)
		typed("YOUR NEXT UPGRADE", Vector2(202, 576), 238, 12, STEP * 6, MineInk.GOLD)
		typed(report.benefit, Vector2(202, 600), 238, 13, STEP * 7, MineInk.TEXT, false, 2)
	if panel(Rect2(20, 666, 440, 54), STEP * 5):
		typed(report.next_goal, Vector2(36, 688), 408, 12, STEP * 7, MineInk.TEXT, false, 2)
	if age >= STEP * 6:
		MineInk.panel(self, CONTINUE)
		typed("Continue", Vector2(196, 759), 120, 16, STEP * 7)
		MineInk.centered(self, "Click anywhere to finish reveals" if not is_revealed() else "Your next expedition awaits", 793, 10, MineInk.MUTED)
