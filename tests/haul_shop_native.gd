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

func capture(path: String) -> Image:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.save_png("res://.test-data/" + path + ".png")
	return pixels

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 1600)
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.inventory[1] = 3
	game.inventory[8] = 2
	game.inventory[9] = 1
	game.credits = 90
	game.best_depth = 65
	game.upgrades.depth = 1
	game.selected_depth = 10
	game.results.report = {"new_materials": [8, 9]}
	game.return_to_depot(false)
	game.depot.reveal_time = 10
	game.cursor_position = Vector2.ZERO
	var haul := await capture("haul-polished")
	game.depot.activate_primary()
	var selling := await capture("haul-selling")
	check(haul.get_data() != selling.get_data() and game.depot.haul_ores().size() == 3, "Sale highlights keep the three material rows visible")
	game.depot.advance_sale(2)
	var sold := await capture("haul-receipt")
	check(sold.get_data() != haul.get_data() and game.depot.haul_ores().is_empty() and game.depot.visible_haul_value() == 0, "Sold rows disappear and leave a zero total")
	game.credits = 90
	game.depot.open_shop()
	game.depot.transition = 0
	game.cursor_position = Vector2.ZERO
	var shop := await capture("shop-polished")
	check(game.depot.miner_viewport.size == Vector2i(240, 400) and game.depot.miner_art.material.shader.resource_path == "res://shaders/crisp.gdshader", "Shop miners render through the native-resolution pixel shader")
	var red := 0
	var locked: Rect2 = game.depot.upgrade_rect(6)
	for y in range(int(locked.position.y * 2), int(locked.end.y * 2)):
		for x in range(int(locked.position.x * 2), int(locked.end.x * 2)):
			var color := shop.get_pixel(x, y)
			red += int(color.r > 0.8 and color.g < 0.5 and color.b < 0.5)
	check(red > 4, "Locked card's required depth renders in red")
	game.depot.set_process(false)
	game.depot.walk_clock = 0
	game.depot.miner_art.queue_redraw()
	await capture("shop-walk-a")
	var pose_a: Image = game.depot.miner_viewport.get_texture().get_image()
	game.depot.walk_clock = PI * 0.5
	game.depot.miner_art.queue_redraw()
	await capture("shop-walk-b")
	var pose_b: Image = game.depot.miner_viewport.get_texture().get_image()
	check(pose_a.get_data() != pose_b.get_data(), "Miner's walking pose changes on the pixel grid")
	var binary := true
	for y in range(pose_b.get_height()):
		for x in range(pose_b.get_width()):
			var alpha := pose_b.get_pixel(x, y).a
			binary = binary and (alpha == 0 or alpha == 1)
	check(binary, "Shop miner shader preserves binary pixel coverage")
	game.depot.set_process(true)
	game.cursor_position = game.depot.upgrade_rect(2).get_center()
	var preview := await capture("shop-equipment-preview")
	check(shop.get_data() != preview.get_data() and game.upgrades.capacity == 0, "Hover preview changes the rendered miner without changing ownership")
	game.buy_upgrade(2)
	var purchased := await capture("shop-purchase")
	check(purchased.get_data() != preview.get_data() and game.upgrades.capacity == 1 and game.credits == 70, "Purchase fitting and coin deduction render the newly owned upgrade")
	game.depot.purchase_anim = 0
	game.depot.purchase_compare_time = 0
	game.cursor_position = Vector2.ZERO
	game.inventory.fill(1)
	game.depot.show_depot(false)
	game.depot.reveal_time = 10
	await capture("haul-many-materials")
	check(game.depot.ore_rect(9).end.y < game.depot.content_bottom() - 34, "Dense material list stays above the fixed total and sliders")
	print("Haul and shop native: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
