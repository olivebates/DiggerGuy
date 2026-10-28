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

func click(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = pos
	game.cursor_position = pos
	game.depot._input(event)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.inventory[1] = 3
	game.inventory[8] = 2
	game.results.report = {"new_materials": [8]}
	game.credits = 50
	game.return_to_depot(false)
	var depot: Node = game.depot
	check(depot.primary_label() == "Sell All · +135 coins", "Sell button quotes the exact retained haul value")
	check(depot.haul_ores() == [1, 8] and depot.haul_amount(8) == 2, "Haul exposes sorted quantities without changing inventory")
	depot.activate_primary()
	check(game.credits == 185 and game.inventory_count() == 0, "Sale deposits coins exactly once")
	check(depot.haul_ores() == [1, 8] and depot.receipt_value == 135 and depot.sold_new_materials == [8], "Sale snapshots retain quantities, value, and discovery tags")
	check(depot.primary_label() == "Dig Deeper" and depot.is_selling(), "Diving remains immediately available")
	check(not depot.row_is_sold(8), "Rows remain pending while their ore is flying")
	depot.advance_sale(0.25)
	check(depot.haul_ores() == [8] and depot.visible_haul_value() == 120, "First row disappears at the end of its flash and subtracts only its subtotal")
	check(game.credits == 185 and depot.is_selling(), "Removing a row neither credits twice nor waits for the coin flights")
	game.synth.muted = false
	var voices: int = game.synth.voice_index
	depot.advance_sale(2)
	check(depot.row_is_sold(1) and depot.row_is_sold(8) and depot.displayed_credits == 185 and depot.visible_haul_value() == 0, "Sale settlement leaves an empty zero-value list and exact wallet")
	check(game.synth.voice_index >= voices + 1 and game.synth.sounds.has("sell_complete"), "Sale completion has a dedicated final chime")
	voices = game.synth.voice_index
	depot.advance_sale(1)
	check(game.synth.voice_index == voices, "Final chime cannot repeat after settlement")
	game.synth.muted = true
	depot._process(0.5)
	check(depot.haul_ores().is_empty() and depot.visible_haul_value() == 0, "Sold rows and their values disappear after their flashes")
	depot._process(2)
	check(depot.sold_haul.is_empty() and depot.receipt_value == 135 and game.credits == 185, "Clearing the sale snapshot preserves real coins")
	game.inventory[0] = 2
	depot.activate_primary()
	depot.activate_primary()
	check(game.mode == "playing" and game.credits == 191 and depot.sale_flights.is_empty() and depot.wallet_visual == 191, "Immediate dive settles outstanding sale without double payment")
	game.set_physics_process(false)
	game.return_to_depot(false)
	game.best_depth = 500
	depot.open_shop()
	depot.transition = 0
	var level: int = game.upgrades.power
	var cash: int = game.credits
	var tracked: String = game.tracked_upgrade
	click(depot.upgrade_rect(1).position + Vector2(190, 15))
	check(game.tracked_upgrade == tracked and game.upgrades.power == level and game.credits == cash, "Former pin area no longer changes tracking")
	game.credits = 0
	click(depot.upgrade_rect(2).get_center())
	check(game.tracked_upgrade == tracked and game.upgrades.capacity == 0, "Failed purchase cannot replace the pinned goal")
	game.cursor_position = depot.upgrade_rect(2).get_center()
	var preview: Dictionary = depot.preview_equipment()
	check(preview.capacity == 1 and game.upgrades.capacity == 0, "Hover previews upgraded equipment without buying")
	game.cursor_position = Vector2.ZERO
	check(depot.preview_equipment() == game.upgrades, "Leaving a card restores the real miner")
	game.credits = 1000
	var price := MineCatalog.price(2, 0)
	click(depot.upgrade_rect(2).get_center())
	check(game.upgrades.capacity == 1 and game.credits == 1000 - price and game.tracked_upgrade == tracked, "Successful purchase equips the upgrade and keeps the pinned goal")
	check(depot.purchase_cost == price and depot.purchase_anim == 0.7, "Purchase animation uses the price actually paid")
	check(depot.preview_equipment() == game.upgrades and depot.purchase_after.capacity == 1, "Purchase fitting shows the newly owned equipment")
	depot._process(0.8)
	check(depot.purchase_anim == 0 and absf(depot.wallet_visual - game.credits) < 0.2, "Purchase settles to the real wallet and retains actual upgrades")
	check(MineCatalog.price(2, game.upgrades.capacity) > price, "Next purchase uses the new price")
	game.best_depth = 0
	cash = game.credits
	game.buy_upgrade(1)
	check(game.credits == cash and game.upgrades.power == 0, "New card feedback cannot bypass milestone gating")
	game.inventory.fill(1)
	depot.screen = "depot"
	check(depot.ore_rect(9).end.y <= depot.content_bottom() - 54, "Ten material rows fit above the fixed total")
	for key in game.upgrades:
		game.upgrades[key] = 0
	game.best_depth = 0
	check(depot.upgrade_order() == [5, 0, 1, 2, 3, 7, 6], "Unlocked Speedup comes first, then locks ordered by required depth")
	check(depot.upgrade_rect(5) == depot.shop_card_rect(1), "Sorted card position also drives hover and click targets")
	game.best_depth = 30
	game.upgrades.power = 2
	check(depot.upgrade_order() == [0, 2, 3, 5, 7, 1, 6], "Upgrading and reaching depths automatically reorders the remaining locks")
	print("Haul and shop: %d checks, %d failures" % [checks, failures])
	for voice in game.synth.voices:
		voice.stop()
		voice.stream = null
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
