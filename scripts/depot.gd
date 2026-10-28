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
var primary_rect := Rect2(28, 730, 424, 46)
var dive_rect := Rect2(28, 730, 424, 46)
var reveal_time := 0.0
var entrance_time := 0.0
var coin_target := Vector2(348, 51)
var confirm_rect := Rect2(96, 424, 288, 42)
var haul_scroll := 0
var purchase_compare_time := 0.0
var purchase_compare_index := -1
var purchase_before: Dictionary = {}
var purchase_after: Dictionary = {}
var sold_haul: Array[int] = []
var sold_new_materials: Array = []
var receipt_value := 0
var receipt_age := -1.0
var sale_age := 0.0
var sale_row_delays: Dictionary = {}
var purchase_cost := 0
var purchase_anim := 0.0
var miner_viewport: SubViewport
var miner_art: Node2D
var walk_clock := 0.0
const PLAYER_ART := preload("res://scripts/player_render.gd")

func _ready() -> void:
	miner_viewport = SubViewport.new()
	miner_viewport.size = Vector2i(240, 400)
	miner_viewport.transparent_bg = true
	miner_viewport.msaa_2d = Viewport.MSAA_DISABLED
	miner_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	miner_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(miner_viewport)
	miner_art = Node2D.new()
	miner_art.set_script(preload("res://scripts/shop_art.gd"))
	miner_art.depot = self
	miner_art.scale = Vector2.ONE * 0.5
	var pixels := ShaderMaterial.new()
	pixels.shader = preload("res://shaders/crisp.gdshader")
	pixels.set_shader_parameter("dither_pixel_size", 1.0)
	miner_art.material = pixels
	miner_viewport.add_child(miner_art)

func local_mouse() -> Vector2:
	return game.cursor_position - position

func _process(delta: float) -> void:
	miner_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible and screen == "shop" else SubViewport.UPDATE_DISABLED
	if not visible or game == null:
		return
	walk_clock += delta * 8
	miner_art.queue_redraw()
	var previous_entrance := entrance_time
	entrance_time = maxf(0, entrance_time - delta)
	position.y = snappedf(-800 * pow(entrance_time / 0.4, 3), 2)
	reveal_time += maxf(0, delta - previous_entrance)
	advance_sale(delta)
	transition = maxf(0, transition - delta)
	feedback_time = maxf(0, feedback_time - delta)
	purchase_compare_time = maxf(0, purchase_compare_time - delta)
	purchase_anim = maxf(0, purchase_anim - delta)
	if receipt_age >= 0:
		receipt_age += delta
		if receipt_age > 2.0:
			sold_haul.clear()
	haul_scroll = clampi(haul_scroll, 0, maxi(0, haul_ores().size() - 10))
	wallet_visual = lerpf(wallet_visual, displayed_credits, 1.0 - exp(-delta * 18))
	if absf(wallet_visual - displayed_credits) < 0.2:
		wallet_visual = displayed_credits
	for key in press_amount.keys():
		press_amount[key] = maxf(0, press_amount[key] - delta * 12)
	var mouse := local_mouse()
	for key in ["primary", "nav", "dive"]:
		var rect: Rect2 = primary_rect if key == "primary" else (dive_rect if key == "dive" else nav_rect())
		hover_amount[key] = 1.0 if rect.has_point(mouse) else 0.0
	for i in MineCatalog.SHOP_UPGRADES:
		var key := "up%d" % i
		var hovered := upgrade_rect(i).has_point(mouse - Vector2(content_offset(), 0)) and screen == "shop" and not has_popup()
		hover_amount[key] = 1.0 if hovered else 0.0
	queue_redraw()

func show_depot(from_death: bool = false) -> void:
	haul_scroll = 0
	purchase_compare_time = 0
	purchase_anim = 0
	sold_haul.clear()
	sold_new_materials.clear()
	receipt_age = -1
	receipt_value = 0
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
	return false

func primary_label() -> String:
	return "Sell All · +%d coins" % game.haul_value() if game.inventory_count() > 0 else "Dig Deeper"

func activate_primary() -> void:
	if has_popup():
		return
	if game.inventory_count() > 0:
		sell_requested.emit()
	else:
		finish_sale()
		dive_requested.emit()

func finish_sale() -> void:
	if is_selling():
		receipt_age = 0
		for delay in sale_row_delays.values():
			sale_age = maxf(sale_age, float(delay) + 0.24)
	sale_flights.clear()
	displayed_credits = game.credits
	wallet_visual = game.credits
	coin_pulse = 0

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
	var height := minf(42, (content_bottom() - 242) / maxi(1, mini(10, haul_ores().size())))
	return Rect2(44, 184 + clampi(slot - haul_scroll, 0, 9) * height, 392, height)

func haul_ores() -> Array[int]:
	if game.inventory_count() > 0 or sold_haul.is_empty():
		return game.visible_ores()
	var ores: Array[int] = []
	for ore in range(sold_haul.size()):
		if sold_haul[ore] > 0 and sale_age < float(sale_row_delays.get(ore, 0)) + 0.24:
			ores.append(ore)
	ores.sort_custom(func(a: int, b: int) -> bool: return MineCatalog.ORES[a].depth < MineCatalog.ORES[b].depth if MineCatalog.ORES[a].depth != MineCatalog.ORES[b].depth else a < b)
	return ores

func haul_amount(ore: int) -> int:
	return game.inventory[ore] if game.inventory_count() > 0 else sold_haul[ore] if ore < sold_haul.size() else 0

func row_is_sold(ore: int) -> bool:
	if game.inventory_count() > 0 or sold_haul.is_empty():
		return false
	return sale_age >= float(sale_row_delays.get(ore, 0)) + 0.24

func visible_haul_value() -> int:
	var total := 0
	for ore in haul_ores():
		total += haul_amount(ore) * int(MineCatalog.ORES[ore].value)
	return total

func preview_equipment() -> Dictionary:
	var levels: Dictionary = game.upgrades.duplicate()
	if purchase_anim > 0:
		return levels
	var index := hovered_upgrade()
	if index >= 0 and not (purchase_compare_time > 0 and purchase_compare_index == index):
		levels[MineCatalog.UPGRADES[index].key] += 1
	return levels

func row_scale(slot: int) -> float:
	return 1.0 if reveal_time > slot * 0.2 else 0.0

func row_characters(slot: int) -> int:
	return maxi(0, floori((reveal_time - slot * 0.2) * 40))

func content_bottom() -> float:
	return 678.0 - slider_count() * 60

func haul_rect() -> Rect2:
	return Rect2(28, 116, 424, content_bottom() - 116)

func nav_rect() -> Rect2:
	return Rect2(28, 678, 424, 40)

func upgrade_rect(index: int) -> Rect2:
	return shop_card_rect(upgrade_order().find(index) + 1)

func upgrade_order() -> Array[int]:
	var order: Array[int] = []
	order.assign(MineCatalog.SHOP_UPGRADES)
	order.sort_custom(func(a: int, b: int) -> bool:
		var a_locked: bool = not game.upgrade_is_unlocked(a)
		var b_locked: bool = not game.upgrade_is_unlocked(b)
		if a_locked != b_locked:
			return not a_locked
		if a_locked:
			var a_key: String = MineCatalog.UPGRADES[a].key
			var b_key: String = MineCatalog.UPGRADES[b].key
			var a_depth := MineCatalog.upgrade_required_depth(a_key, game.upgrades[a_key])
			var b_depth := MineCatalog.upgrade_required_depth(b_key, game.upgrades[b_key])
			if a_depth != b_depth:
				return a_depth < b_depth
		return a < b
	)
	return order

func portrait_rect() -> Rect2:
	return shop_card_rect(0)

func shop_card_rect(slot: int) -> Rect2:
	var height := 104.5
	return Rect2(28 + (slot % 2) * 216, 116 + (slot / 2) * (height + 8), 208, height)

func slider_rect(kind: String) -> Rect2:
	var both: bool = game.upgrades.depth > 0
	return Rect2(28, content_bottom() + 8 + (60 if kind == "speed" and both else 0), 424, 44)

func set_slider(kind: String, mouse_x: float) -> void:
	var t := clampf((mouse_x - 188) / 246.0, 0, 1)
	if kind == "depth":
		game.selected_depth = MineCatalog.starting_depth(roundi(t * game.upgrades.depth))
	else:
		game.selected_speed = 2 + roundi(t * (game.max_speed() - 2))

func purchase_feedback(index: int, success: bool) -> void:
	feedback_index = index
	feedback_success = success
	feedback_time = 0.45
	press_amount["up%d" % index] = 1.0
	if not success:
		game.synth.play_sound("hit", -15, 1.4)
	displayed_credits = maxi(0, game.credits - remaining_sale_value())

func show_purchase_comparison(index: int, before: Dictionary) -> void:
	purchase_compare_index = index
	purchase_before = before.duplicate()
	purchase_after = game.upgrades.duplicate()
	purchase_compare_time = 2.5
	purchase_cost = MineCatalog.price(index, int(before[MineCatalog.UPGRADES[index].key]))
	purchase_anim = 0.7

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
	sold_haul = haul.duplicate()
	sold_new_materials = game.results.report.get("new_materials", []).duplicate()
	receipt_value = 0
	for ore in range(haul.size()):
		receipt_value += haul[ore] * int(MineCatalog.ORES[ore].value)
	receipt_age = -1
	sale_age = 0
	sale_row_delays.clear()
	var slot := 0
	for ore in haul_ores():
		sale_row_delays[ore] = slot * 0.055
		var source := ore_rect(slot).position + Vector2(20, ore_rect(slot).size.y * 0.5)
		if screen == "shop":
			source = Vector2(180 + slot * 9, 480)
		for piece in range(haul[ore]):
			sale_total += 1
			sale_flights.append({"ore": ore, "start": source + Vector2(game.rng.randf_range(-4, 4), 0), "control": source + Vector2(game.rng.randf_range(-60, 60), -100), "time": 0.0, "delay": slot * 0.055 + (piece % 8) * 0.01, "duration": game.rng.randf_range(0.45, 0.65)})
		slot += 1

func remaining_sale_value() -> int:
	var value := 0
	for flight in sale_flights:
		value += MineCatalog.ORES[flight.ore].value
	return value

func advance_sale(delta: float) -> void:
	var was_selling := is_selling()
	if was_selling:
		sale_age += delta
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
	if was_selling and not is_selling():
		receipt_age = 0
		game.synth.play_sound("sell_complete", -5)

func _input(event: InputEvent) -> void:
	if not visible or game == null or entrance_time > 0 or transition > 0:
		return
	if screen == "depot" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		haul_scroll = clampi(haul_scroll + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, haul_ores().size() - 10))
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
			if (game.upgrades[kind] > 0) and slider_rect(kind).has_point(mouse):
				dragging = kind
				set_slider(kind, mouse.x)
				return
		if primary_rect.has_point(mouse):
			press_amount.primary = 1.0
			activate_primary()
		elif nav_rect().has_point(mouse):
			press_amount.nav = 1.0
			change_screen("depot" if screen == "shop" else "shop")
		elif screen == "shop":
			for i in MineCatalog.SHOP_UPGRADES:
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
	animated_button(primary_rect, primary_label(), "primary", true)
	animated_button(nav_rect(), "Back" if screen == "shop" else "Shop", "nav", false)
	draw_sale_flights()
	var preview_index := hovered_upgrade()
	if preview_index < 0 and screen == "shop" and purchase_compare_time > 0:
		preview_index = purchase_compare_index
	if preview_index >= 0 and game.upgrade_is_unlocked(preview_index):
		draw_upgrade_tooltip(preview_index)
	if screen == "shop":
		draw_texture_rect(miner_viewport.get_texture(), Rect2(0, 0, 480, 800), false)
	draw_purchase_flight()
	if has_popup():
		draw_popup()

func draw_content(page: String, offset: float) -> void:
	draw_set_transform(Vector2(offset, 0))
	if page == "shop":
		draw_shop(offset)
	else:
		draw_haul()
	draw_set_transform(Vector2.ZERO)

func right_text(value: String, x: float, y: float, size: int, color: Color = MineInk.TEXT) -> void:
	var width := MineInk.FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	MineInk.text(self, value, Vector2(x - width, y), size, color)

func draw_haul() -> void:
	MineInk.panel(self, haul_rect())
	MineInk.text(self, "Your Haul", Vector2(44, 146), 20)
	var ores := haul_ores()
	MineInk.text(self, "Material", Vector2(44, 174), 10, MineInk.MUTED)
	right_text("Qty", 246, 174, 10, MineInk.MUTED)
	right_text("Each", 326, 174, 10, MineInk.MUTED)
	right_text("Total", 432, 174, 10, MineInk.MUTED)
	for slot in range(haul_scroll, mini(haul_scroll + 10, ores.size())):
		var characters := row_characters(slot - haul_scroll) if sold_haul.is_empty() else 999
		if characters <= 0:
			continue
		var ore := ores[slot]
		var rect := ore_rect(slot)
		var ink := MineInk.TEXT
		var departing := sale_age - float(sale_row_delays.get(ore, -10))
		if is_selling() and departing >= 0 and departing < 0.24:
			draw_rect(rect, Color(MineInk.GOLD, (1 - departing / 0.24) * 0.18))
		var y := rect.get_center().y
		var size := clampi(roundi(rect.size.y * 0.4), 10, 14)
		MineInk.ore_icon(self, Vector2(57, y), ore, 0.85)
		var fresh: bool = ore in (sold_new_materials if not sold_haul.is_empty() else game.results.report.get("new_materials", []))
		var label: String = MineCatalog.ORES[ore].name
		MineInk.fitted_text(self, label.left(characters), Vector2(76, y + size * 0.35 - (4 if fresh else 0)), 130, size, ink)
		if fresh:
			MineInk.text(self, "NEW", Vector2(76, y + 10), 7, MineInk.GOLD)
		var count := haul_amount(ore)
		right_text(str(count), 246, y + size * 0.35, size, ink)
		right_text(str(MineCatalog.ORES[ore].value), 326, y + size * 0.35, size, ink)
		right_text(str(count * int(MineCatalog.ORES[ore].value)), 432, y + size * 0.35, size, ink)
	if ores.size() > 10:
		MineInk.text(self, "Mouse wheel: more ores", Vector2(44, content_bottom() - 43), 10, MineInk.MUTED)
	draw_line(Vector2(44, content_bottom() - 34), Vector2(436, content_bottom() - 34), MineInk.LINE, 1)
	var total := visible_haul_value()
	MineInk.text(self, "Total value", Vector2(44, content_bottom() - 13), 14, MineInk.GOLD)
	right_text("%d coins" % total, 432, content_bottom() - 13, 16, MineInk.GOLD)

func draw_shop(offset: float = 0) -> void:
	var mouse := local_mouse() - Vector2(offset, 0)
	var portrait := portrait_rect()
	var fitting := purchase_anim > 0
	MineInk.panel(self, portrait, MineInk.PANEL, MineInk.TEXT if fitting else MineInk.LINE)
	draw_set_transform(Vector2(offset, 0))
	for i in MineCatalog.SHOP_UPGRADES:
		var upgrade: Dictionary = MineCatalog.UPGRADES[i]
		var level: int = game.upgrades[upgrade.key]
		var maxed: bool = upgrade.max >= 0 and level >= upgrade.max
		var price := MineCatalog.price(i, level)
		var locked: bool = not game.upgrade_is_unlocked(i)
		var opacity := 0.35 if locked else 1.0
		var affordable: bool = not locked and not maxed and game.credits >= price
		var rect := upgrade_rect(i).grow(2 if float(hover_amount.get("up%d" % i, 0)) > 0 else 0)
		rect.position.y += 2 if float(press_amount.get("up%d" % i, 0)) > 0 else 0
		var border := MineInk.GOLD if affordable else MineInk.LINE.lightened(0.2) if rect.has_point(mouse) else MineInk.LINE
		if feedback_index == i and feedback_time > 0:
			if feedback_success:
				border = border.lerp(MineInk.TEXT, feedback_time / 0.45)
			else:
				rect.position.x += snappedf(sin(feedback_time * 70) * feedback_time * 5, 2)
		MineInk.panel(self, rect, Color(MineInk.PANEL, opacity), Color(border, opacity))
		if locked:
			draw_depth_requirement(rect, MineCatalog.upgrade_required_depth(upgrade.key, level))
			continue
		MineInk.fitted_text(self, upgrade.name, rect.position + Vector2(12, 27), 184, 16, MineInk.TEXT)
		var values := upgrade_values(upgrade.key, level)
		if purchase_anim > 0 and purchase_compare_index == i:
			var old_values := upgrade_values(upgrade.key, int(purchase_before[upgrade.key]))
			values.x = roundi(lerpf(old_values.x, values.x, smoothstep(0, 1, 1 - purchase_anim / 0.7)))
		var detail_y := rect.position.y + rect.size.y * 0.56 + 2
		if maxed:
			MineInk.text(self, "Unlocked" if upgrade.key == "freeze" else "%dx" % (level + 1), Vector2(rect.position.x + 16, detail_y), 19, Color("83d990"))
		else:
			MineInk.fitted_text(self, ("x" if upgrade.key == "speed" else "") + str(values.x), Vector2(rect.position.x + 16, detail_y), 60, 22, Color(MineInk.TEXT, opacity))
			MineInk.icon(self, "arrow", Vector2(rect.position.x + 80, detail_y - 8), Color(MineInk.TEXT, opacity), 1.5)
			MineInk.fitted_text(self, ("x" if upgrade.key == "speed" else "") + str(values.y), Vector2(rect.position.x + 110, detail_y), 80, 22, Color(Color("83d990"), opacity))
		var price_y := rect.end.y - 12
		if maxed:
			MineInk.text(self, "Owned", Vector2(rect.position.x + 16, price_y), 15, MineInk.MUTED)
		else:
			var color := Color("83d990") if affordable else Color("ff6565")
			MineInk.icon(self, "coin", Vector2(rect.position.x + 23, price_y - 5), Color(MineInk.TEXT, opacity), 0.8)
			var price_text := str(price)
			var price_size := 16
			var price_width := 155
			if price_width == 62 and price >= 1000000:
				price_text = "%.1e" % float(price)
			while MineInk.FONT.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, price_size).x > price_width and price_size > 8:
				price_size -= 1
			MineInk.text(self, price_text, Vector2(rect.position.x + 38, price_y), price_size, Color(color, opacity))

func draw_depth_requirement(rect: Rect2, depth: int) -> void:
	var parts := ["Reach ", str(depth), " meters"]
	var width := MineInk.FONT.get_string_size("".join(parts), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var pos := Vector2(rect.get_center().x - width * 0.5, rect.get_center().y - 3)
	for i in range(parts.size()):
		MineInk.text(self, parts[i], pos, 13, Color("ff6565") if i == 1 else MineInk.TEXT)
		pos.x += MineInk.FONT.get_string_size(parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	MineInk.centered(self, "to unlock", rect.get_center().y + 19, 13, MineInk.TEXT, rect.get_center().x)

func draw_miner_graphics(canvas: CanvasItem) -> void:
	if screen != "shop":
		return
	var offset := content_offset() if screen == "shop" else snappedf(-transition_direction * 480 * smoothstep(0, 1, 1 - transition / 0.4), 2)
	var portrait := portrait_rect()
	var lift := sin((1 - purchase_anim / 0.7) * PI) * 3 if purchase_anim > 0 else 0.0
	PLAYER_ART.draw_equipment(canvas, Vector2(portrait.get_center().x + offset, portrait.get_center().y + 22 - lift), preview_equipment(), 2, sin(walk_clock))
	var index := hovered_upgrade()
	if index < 0 and screen == "shop" and purchase_compare_time > 0:
		index = purchase_compare_index
	if index < 0 or not game.upgrade_is_unlocked(index):
		return
	var purchased := purchase_compare_time > 0 and purchase_compare_index == index
	var upgrade: Dictionary = MineCatalog.UPGRADES[index]
	var before: Dictionary = purchase_before if purchased else game.upgrades
	var after: Dictionary = purchase_after.duplicate() if purchased else game.upgrades.duplicate()
	if not purchased:
		after[upgrade.key] += 1
	var rect := tooltip_rect()
	PLAYER_ART.draw_equipment(canvas, rect.position + Vector2(44, 114), before, 2, sin(walk_clock))
	PLAYER_ART.draw_equipment(canvas, rect.position + Vector2(116, 114), after, 2, sin(walk_clock))

func upgrade_values(key: String, level: int) -> Vector2i:
	match key:
		"depth": return Vector2i(MineCatalog.starting_depth(level), MineCatalog.starting_depth(level + 1))
		"power": return Vector2i(level + 1, level + 2)
		"speed": return Vector2i(level + 2, level + 3)
		"lives": return Vector2i(level, level + 1)
		"capacity": return Vector2i(level + 7, level + 8)
		"insurance", "blocks": return Vector2i(level + 3, level + 4)
	return Vector2i(level, level + 1)

func hovered_upgrade() -> int:
	if screen != "shop" or transition > 0 or entrance_time > 0 or has_popup() or not dragging.is_empty():
		return -1
	var mouse := local_mouse()
	for index in MineCatalog.SHOP_UPGRADES:
		if upgrade_rect(index).has_point(mouse):
			return index
	return -1

func tooltip_rect() -> Rect2:
	return Rect2(28, 566, 424, 210)

func draw_upgrade_tooltip(index: int) -> void:
	var rect := tooltip_rect()
	MineInk.panel(self, rect)
	var upgrade: Dictionary = MineCatalog.UPGRADES[index]
	var purchased := purchase_compare_time > 0 and purchase_compare_index == index
	var before: Dictionary = purchase_before if purchased else game.upgrades
	var after: Dictionary = purchase_after.duplicate() if purchased else game.upgrades.duplicate()
	if not purchased:
		after[upgrade.key] += 1
	MineInk.text(self, upgrade.name + (" upgraded!" if purchased else ""), rect.position + Vector2(16, 30), 17)
	MineInk.text(self, "Before" if purchased else "Now", rect.position + Vector2(24, 58), 12, MineInk.MUTED)
	MineInk.text(self, "After" if purchased else "Next", rect.position + Vector2(96, 58), 12, MineInk.GOLD)
	MineInk.icon(self, "arrow", rect.position + Vector2(80, 88), MineInk.GOLD, 0.7)
	var benefit := MineCatalog.upgrade_benefit(upgrade.key, int(before[upgrade.key]))
	MineInk.fitted_text(self, benefit, rect.position + Vector2(166, 82), 240, 13, MineInk.GOLD)
	if purchased:
		MineInk.text(self, "Equipped", rect.position + Vector2(166, 104), 12, MineInk.MUTED)
	var line := ""
	var y := rect.position.y + 143
	for word in MineCatalog.upgrade_description(index).split(" "):
		var next := word if line.is_empty() else line + " " + word
		if MineInk.FONT.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > 392:
			MineInk.text(self, line, Vector2(rect.position.x + 16, y), 12)
			y += 18
			line = word
		else:
			line = next
	if not line.is_empty():
		MineInk.text(self, line, Vector2(rect.position.x + 16, y), 12)
	var price := MineCatalog.price(index, int(game.upgrades[upgrade.key]))
	MineInk.fitted_text(self, "Costs: %d coins" % price, Vector2(48, rect.end.y - 12), 384, 12, MineInk.GOLD)

func draw_purchase_flight() -> void:
	if purchase_anim <= 0 or purchase_compare_index < 0:
		return
	var t := 1 - purchase_anim / 0.7
	var target := upgrade_rect(purchase_compare_index).get_center()
	var pos := coin_target.lerp(target, smoothstep(0, 1, t)) - Vector2(0, sin(t * PI) * 35)
	MineInk.icon(self, "coin", MineInk.snap(pos), MineInk.GOLD, 0.85)
	MineInk.fitted_text(self, "-%d" % purchase_cost, pos + Vector2(12, -8), 130, 12, MineInk.GOLD)

func draw_slider(kind: String) -> void:
	var rect := slider_rect(kind)
	MineInk.panel(self, rect)
	var value: int = game.selected_depth if kind == "depth" else game.selected_speed
	var label := "Depth: %d m" % value if kind == "depth" else "W Speed up: %dx" % value
	MineInk.text(self, label, rect.position + Vector2(14, 31), 14)
	var center_y := snappedf(rect.get_center().y, 2)
	draw_rect(Rect2(188, center_y, 246, 2), MineInk.LINE.darkened(0.5))
	var fraction: float = float(sqrt(0.25 + float(value) / 5.0) - 0.5) / game.upgrades.depth if kind == "depth" else float(value - 2) / maxi(1, game.max_speed() - 2)
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
