extends Node2D

signal dive_requested
signal sell_requested
signal upgrade_requested(index: int)
signal depth_requested

var game: Node
var screen := "depot"
var sale_flights: Array[Dictionary] = []
var displayed_credits := 0
var wallet_visual := 0.0
var coin_pulse := 0.0
var sale_chime_cooldown := 0.0
var sale_total := 0
var transition := 0.0
var transition_direction := 1
var hover_amount: Dictionary = {}
var press_amount: Dictionary = {}
var feedback_index := -1
var feedback_time := 0.0
var feedback_success := true
var dragging := ""
var previous_screen := "depot"
var primary_rect := Rect2(28, 626, 424, 46)
var dive_rect := Rect2(28, 730, 424, 46)
var reveal_time := 0.0
var entrance_time := 0.0
var coin_target := Vector2(348, 51)
var confirm_rect := Rect2(96, 424, 288, 42)

func local_mouse() -> Vector2:
	return game.cursor_position - position

func _process(delta: float) -> void:
	if not visible or game == null:
		return
	var previous_entrance := entrance_time
	entrance_time = maxf(0, entrance_time - delta)
	position.y = snappedf(-800 * pow(entrance_time / 0.4, 3), 2)
	reveal_time += maxf(0, delta - previous_entrance)
	advance_sale(delta)
	transition = maxf(0, transition - delta)
	feedback_time = maxf(0, feedback_time - delta)
	wallet_visual = lerpf(wallet_visual, displayed_credits, 1.0 - exp(-delta * 18))
	if absf(wallet_visual - displayed_credits) < 0.2:
		wallet_visual = displayed_credits
	for key in press_amount.keys():
		press_amount[key] = maxf(0, press_amount[key] - delta * 12)
	var mouse := local_mouse()
	for key in ["primary", "nav", "dive"]:
		var rect: Rect2 = primary_rect if key == "primary" else (dive_rect if key == "dive" else nav_rect())
		hover_amount[key] = 1.0 if rect.has_point(mouse) else 0.0
	for i in range(MineCatalog.UPGRADES.size()):
		var key := "up%d" % i
		var hovered := upgrade_rect(i).has_point(mouse - Vector2(content_offset(), 0)) and screen == "shop" and not has_popup()
		hover_amount[key] = 1.0 if hovered else 0.0
	queue_redraw()

func show_depot(from_death: bool = false) -> void:
	reveal_time = 0
	entrance_time = 0.4 if from_death else 0.0
	position.y = -800 if from_death else 0.0
	screen = "depot"
	sale_flights.clear()
	displayed_credits = game.credits
	wallet_visual = game.credits
	coin_pulse = 0
	transition = 0
	dragging = ""

func is_selling() -> bool:
	return not sale_flights.is_empty()

func has_popup() -> bool:
	return not game.pending_shortcuts.is_empty()

func primary_label() -> String:
	return "Sell All"

func activate_primary() -> void:
	if is_selling() or has_popup():
		return
	if game.inventory_count() > 0:
		sell_requested.emit()
	else:
		dive_requested.emit()

func change_screen(next: String) -> void:
	if has_popup():
		return
	previous_screen = screen
	transition_direction = 1 if next == "shop" else -1
	screen = next
	if next == "depot":
		reveal_time = 0
	transition = 0.4
	game.synth.play_sound("ui", -10)

func open_shop() -> void:
	change_screen("shop")

func content_offset() -> float:
	return snappedf(transition_direction * 480.0 * (1 - smoothstep(0, 1, 1 - transition / 0.4)), 2)

func slider_count() -> int:
	return int(game.upgrades.depth > 0) + int(game.upgrades.speed > 0)

func ore_rect(slot: int) -> Rect2:
	var height := minf(42, (haul_rect().size.y - 52) / maxi(1, game.visible_ores().size()))
	return Rect2(44, 160 + slot * height, 392, height)

func row_scale(slot: int) -> float:
	return 1.0 if reveal_time > slot * 0.2 else 0.0

func row_characters(slot: int) -> int:
	return maxi(0, floori((reveal_time - slot * 0.2) * 40))

func content_bottom() -> float:
	return 610.0 - slider_count() * 60

func haul_rect() -> Rect2:
	return Rect2(28, 116, 424, content_bottom() - 116)

func nav_rect() -> Rect2:
	return Rect2(28, 678, 424, 40)

func upgrade_rect(index: int) -> Rect2:
	var height := (content_bottom() - 116 - 24) / 4
	return Rect2(28 + (index % 2) * 216, 116 + (index / 2) * (height + 8), 208, height)

func slider_rect(kind: String) -> Rect2:
	var both: bool = game.upgrades.depth > 0 and game.upgrades.speed > 0
	return Rect2(28, content_bottom() + 8 + (60 if kind == "speed" and both else 0), 424, 44)

func set_slider(kind: String, mouse_x: float) -> void:
	var t := clampf((mouse_x - 188) / 246.0, 0, 1)
	if kind == "depth":
		game.selected_depth = roundi(t * game.upgrades.depth) * MineCatalog.DEPTH_STEP
	else:
		game.selected_speed = 1 + roundi(t * game.upgrades.speed)

func purchase_feedback(index: int, success: bool) -> void:
	feedback_index = index
	feedback_success = success
	feedback_time = 0.45
	press_amount["up%d" % index] = 1.0
	if not success:
		game.synth.play_sound("hit", -15, 1.4)
	displayed_credits = maxi(0, game.credits - remaining_sale_value())

func confirm_shortcut() -> void:
	if has_popup():
		game.pending_shortcuts.pop_front()
		game.save_progress()
		game.synth.play_sound("ui", -6)

func begin_sale(haul: Array[int], starting_credits: int) -> void:
	displayed_credits = starting_credits
	wallet_visual = starting_credits
	sale_flights.clear()
	sale_total = 0
	var slot := 0
	for ore in range(haul.size()):
		if haul[ore] <= 0:
			continue
		var source := ore_rect(slot).position + Vector2(20, ore_rect(slot).size.y * 0.5)
		if screen == "shop":
			source = Vector2(180 + slot * 9, 480)
		for piece in range(haul[ore]):
			sale_total += 1
			sale_flights.append({"ore": ore, "start": source + Vector2(game.rng.randf_range(-4, 4), 0), "control": source + Vector2(game.rng.randf_range(-60, 60), -100), "time": 0.0, "delay": slot * 0.01 + (piece % 8) * 0.01, "duration": game.rng.randf_range(0.45, 0.65)})
		slot += 1

func remaining_sale_value() -> int:
	var value := 0
	for flight in sale_flights:
		value += MineCatalog.ORES[flight.ore].value
	return value

func advance_sale(delta: float) -> void:
	coin_pulse = maxf(0, coin_pulse - delta * 3)
	sale_chime_cooldown = maxf(0, sale_chime_cooldown - delta)
	var arrived := false
	for i in range(sale_flights.size() - 1, -1, -1):
		var flight := sale_flights[i]
		flight.time += delta
		if flight.time >= flight.delay + flight.duration:
			coin_pulse = 0.3
			arrived = true
			sale_flights.remove_at(i)
	displayed_credits = maxi(0, game.credits - remaining_sale_value())
	if arrived and sale_chime_cooldown <= 0:
		var fraction := 1.0 - float(sale_flights.size()) / maxi(1, sale_total)
		game.synth.play_sound("coin", -12, 0.9 + fraction * 0.6)
		sale_chime_cooldown = 0.06

func _input(event: InputEvent) -> void:
	if not visible or game == null or entrance_time > 0 or transition > 0:
		return
	if has_popup():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and confirm_rect.has_point(event.position):
			confirm_shortcut()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			confirm_shortcut()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and screen == "shop":
			change_screen("depot")
		elif event.keycode == KEY_ENTER:
			activate_primary()
	if event is InputEventMouseMotion and not dragging.is_empty():
		set_slider(dragging, event.position.x)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if not dragging.is_empty():
				game.save_progress()
			dragging = ""
			return
		var mouse: Vector2 = event.position
		for kind in ["depth", "speed"]:
			if game.upgrades[kind] > 0 and slider_rect(kind).has_point(mouse):
				dragging = kind
				set_slider(kind, mouse.x)
				return
		if dive_rect.has_point(mouse) and game.inventory_count() == 0 and not is_selling():
			dive_requested.emit()
		elif primary_rect.has_point(mouse) and game.inventory_count() > 0:
			press_amount.primary = 1.0
			activate_primary()
		elif nav_rect().has_point(mouse):
			press_amount.nav = 1.0
			change_screen("depot" if screen == "shop" else "shop")
		elif screen == "shop":
			for i in range(MineCatalog.UPGRADES.size()):
				if upgrade_rect(i).has_point(mouse):
					upgrade_requested.emit(i)
		game.synth.play_sound("ui", -18)

func animated_button(rect: Rect2, label: String, key: String, primary: bool, enabled: bool = true) -> void:
	var hover: float = hover_amount.get(key, 0)
	var press: float = press_amount.get(key, 0)
	var visual := rect
	visual.position.y += 2 if press > 0 else 0
	MineInk.button(self, visual, label, primary, hover > 0.05, enabled)

func _draw() -> void:
	if game == null:
		return
	draw_rect(Rect2(0, 0, 480, 800), MineInk.BG)
	if transition > 0:
		var progress := smoothstep(0, 1, 1 - transition / 0.4)
		draw_content(previous_screen, snappedf(-transition_direction * 480 * progress, 2))
	draw_content(screen, content_offset())
	draw_set_transform(Vector2.ZERO)
	# Fixed chrome masks moving content at the top and bottom.
	draw_rect(Rect2(0, 0, 480, 104), MineInk.BG)
	draw_rect(Rect2(0, content_bottom() + 1, 480, 800 - content_bottom()), MineInk.BG)
	MineInk.panel(self, Rect2(16, 16, 448, 72))
	MineInk.text(self, "Shop" if screen == "shop" else "Depot", Vector2(32, 61), 28)
	var wallet_text := str(roundi(wallet_visual))
	var size := 22
	while MineInk.FONT.get_string_size(wallet_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 220 and size > 8:
		size -= 1
	var width := MineInk.FONT.get_string_size(wallet_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	coin_target = Vector2(442 - width - 16, 51)
	MineInk.icon(self, "coin", coin_target, MineInk.GOLD, 1 + coin_pulse * 0.45)
	MineInk.text(self, wallet_text, Vector2(442 - width, 58), size)
	for kind in ["depth", "speed"]:
		if game.upgrades[kind] > 0:
			draw_slider(kind)
	if game.inventory_count() > 0 or is_selling():
		animated_button(primary_rect, "Sell All", "primary", true, not is_selling())
	animated_button(nav_rect(), "Back" if screen == "shop" else "Shop", "nav", false)
	if game.inventory_count() == 0 and not is_selling():
		animated_button(dive_rect, "Dig Deeper", "dive", true)
	draw_sale_flights()
	if hovered_upgrade() >= 0:
		draw_upgrade_tooltip(hovered_upgrade())
	if has_popup():
		draw_popup()

func draw_content(page: String, offset: float) -> void:
	draw_set_transform(Vector2(offset, 0))
	if page == "shop":
		draw_shop()
	else:
		MineInk.panel(self, haul_rect())
		MineInk.text(self, "Your Haul", Vector2(44, 150), 20)
		var ores: Array[int] = game.visible_ores()
		for slot in range(ores.size()):
			var characters := row_characters(slot)
			if characters <= 0:
				continue
			var ore := ores[slot]
			var rect := ore_rect(slot)
			if slot > 0:
				draw_rect(Rect2(MineInk.snap(rect.position), Vector2(392, 2)), MineInk.LINE)
			var y := rect.get_center().y
			var font_size := clampi(roundi(rect.size.y * 0.48), 11, 20)
			MineInk.ore_icon(self, Vector2(62, y), ore, 1.15)
			var label := "%s ×%d" % [MineCatalog.ORES[ore].name, game.inventory[ore]]
			MineInk.text(self, label.left(characters), Vector2(86, y + font_size * 0.35), font_size)
			var value := str(game.inventory[ore] * MineCatalog.ORES[ore].value)
			var count := maxi(0, characters - label.length())
			if count > 0:
				var width := MineInk.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				MineInk.icon(self, "coin", Vector2(432 - width - 12, y), MineInk.TEXT, 0.7)
				MineInk.text(self, value.left(count), Vector2(432 - width, y + font_size * 0.35), font_size)
	draw_set_transform(Vector2.ZERO)

func draw_shop() -> void:
	var mouse := local_mouse() - Vector2(content_offset(), 0)
	for i in range(MineCatalog.UPGRADES.size()):
		var upgrade: Dictionary = MineCatalog.UPGRADES[i]
		var level: int = game.upgrades[upgrade.key]
		var maxed: bool = upgrade.max >= 0 and level >= upgrade.max
		var price := MineCatalog.price(i, level)
		var affordable: bool = not maxed and game.credits >= price
		var rect := upgrade_rect(i).grow(2 if float(hover_amount.get("up%d" % i, 0)) > 0 else 0)
		rect.position.y += 2 if float(press_amount.get("up%d" % i, 0)) > 0 else 0
		var border := MineInk.LINE.lightened(0.2) if rect.has_point(mouse) else MineInk.LINE
		if feedback_index == i and feedback_time > 0:
			if feedback_success:
				border = border.lerp(MineInk.TEXT, feedback_time / 0.45)
			else:
				rect.position.x += snappedf(sin(feedback_time * 70) * feedback_time * 5, 2)
		MineInk.panel(self, rect, MineInk.PANEL, border)
		MineInk.icon(self, upgrade.icon, rect.position + Vector2(23, 24), MineInk.TEXT, 1.15)
		MineInk.text(self, upgrade.name, rect.position + Vector2(43, 29), 16)
		var values := upgrade_values(upgrade.key, level)
		var detail_y := rect.position.y + rect.size.y * 0.56
		if maxed:
			MineInk.text(self, "Unlocked" if upgrade.key == "freeze" else "%dx" % (level + 1), Vector2(rect.position.x + 16, detail_y), 19, Color("83d990"))
		else:
			MineInk.text(self, str(values.x), Vector2(rect.position.x + 16, detail_y), 22)
			MineInk.icon(self, "arrow", Vector2(rect.position.x + 80, detail_y - 8), MineInk.TEXT, 1.5)
			MineInk.text(self, str(values.y), Vector2(rect.position.x + 110, detail_y), 22, Color("83d990"))
		var price_y := rect.end.y - 14
		if maxed:
			MineInk.text(self, "Owned", Vector2(rect.position.x + 16, price_y), 15, MineInk.MUTED)
		else:
			var color := Color("83d990") if affordable else Color("ff6565")
			MineInk.icon(self, "coin", Vector2(rect.position.x + 23, price_y - 5), MineInk.TEXT, 0.8)
			var price_text := str(price)
			var price_size := 16
			while MineInk.FONT.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_size).x > 155 and price_size > 8:
				price_size -= 1
			MineInk.text(self, price_text, Vector2(rect.position.x + 38, price_y), price_size, color)

func upgrade_values(key: String, level: int) -> Vector2i:
	match key:
		"depth": return Vector2i(level * MineCatalog.DEPTH_STEP, (level + 1) * MineCatalog.DEPTH_STEP)
		"power", "speed", "lives": return Vector2i(level + 1, level + 2)
		"capacity": return Vector2i(level + 7, level + 8)
		"insurance", "blocks": return Vector2i(level + 3, level + 4)
	return Vector2i(level, level + 1)

func hovered_upgrade() -> int:
	if screen != "shop" or transition > 0 or entrance_time > 0 or has_popup() or not dragging.is_empty():
		return -1
	var mouse := local_mouse()
	for index in range(MineCatalog.UPGRADES.size()):
		if upgrade_rect(index).has_point(mouse):
			return index
	return -1

func tooltip_rect() -> Rect2:
	return Rect2(28, content_bottom() + 8, 424, 776 - content_bottom() - 8)

func draw_upgrade_tooltip(index: int) -> void:
	var rect := tooltip_rect()
	MineInk.panel(self, rect)
	var upgrade: Dictionary = MineCatalog.UPGRADES[index]
	MineInk.icon(self, upgrade.icon, rect.position + Vector2(24, 30), MineInk.TEXT, 1.2)
	MineInk.text(self, upgrade.name, rect.position + Vector2(48, 36), 20)
	var line := ""
	var y := rect.position.y + 70
	for word in MineCatalog.upgrade_description(index).split(" "):
		var next := word if line.is_empty() else line + " " + word
		if MineInk.FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > 376:
			MineInk.text(self, line, Vector2(48, y), 16)
			y += 24
			line = word
		else:
			line = next
	if not line.is_empty():
		MineInk.text(self, line, Vector2(48, y), 16)

func draw_slider(kind: String) -> void:
	var rect := slider_rect(kind)
	MineInk.panel(self, rect)
	var value: int = game.selected_depth if kind == "depth" else game.selected_speed
	var label := "Depth: %d m" % value if kind == "depth" else "Speed: %dx" % value
	MineInk.text(self, label, rect.position + Vector2(14, 31), 14)
	var center_y := snappedf(rect.get_center().y, 2)
	draw_rect(Rect2(188, center_y, 246, 2), MineInk.LINE.darkened(0.5))
	var fraction: float = float(value / MineCatalog.DEPTH_STEP) / game.upgrades.depth if kind == "depth" else float(value - 1) / game.upgrades.speed
	var x := snappedf(lerpf(188, 434, fraction), 2)
	draw_rect(Rect2(188, center_y, x - 188, 2), MineInk.TEXT)
	draw_rect(Rect2(x - 4, center_y - 6, 8, 14), MineInk.TEXT)

func draw_popup() -> void:
	draw_rect(Rect2(0, 0, 480, 800), Color(MineInk.BG, 0.9))
	MineInk.panel(self, Rect2(36, 248, 408, 240))
	var freeze: bool = game.pending_shortcuts[0] == "freeze"
	MineInk.centered(self, "Freeze Unlocked" if freeze else "Speedup Unlocked", 292, 24)
	MineInk.centered(self, "Hold Space to freeze the mine." if freeze else "Hold W to use your selected speed.", 339, 15)
	MineInk.centered(self, "Or toggle the snowflake button." if freeze else "Adjust the speed slider before diving.", 367, 13, MineInk.MUTED)
	MineInk.button(self, confirm_rect, "Confirm", true, confirm_rect.has_point(local_mouse()))

func draw_sale_flights() -> void:
	for flight in sale_flights:
		var t: float = clampf((flight.time - flight.delay) / flight.duration, 0, 1)
		var eased := smoothstep(0, 1, t)
		var source: Vector2 = flight.start
		var control: Vector2 = flight.control
		var pos := source.lerp(control, eased).lerp(control.lerp(coin_target, eased), eased)
		MineInk.ore_icon(self, MineInk.snap(pos), flight.ore, lerpf(1.1, 0.6, t))
