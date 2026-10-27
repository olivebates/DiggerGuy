extends SceneTree

class ButtonProbe extends Node2D:
	var hovered := false
	func _draw() -> void:
		MineInk.button(self, Rect2(12, 12, 100, 50), "Go", true, hovered)

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

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(480, 800)
	game.return_to_depot(false)
	game.credits = 1000
	game.buy_upgrade(0)
	check(game.selected_depth == 20, "The first depth upgrade unlocks 20 meters")
	game.buy_upgrade(0)
	check(game.selected_depth == 40, "Each additional depth upgrade adds another 20 meters")
	game.depot.set_slider("depth", 311)
	check(game.selected_depth == 20, "Depth slider chooses purchased depths in 20-meter steps")
	game.cycle_depth()
	check(game.selected_depth == 40, "Depth selection advances by one 20-meter level")
	game.cycle_depth()
	check(game.selected_depth == 0, "Depth selection wraps to the surface at its purchased maximum")
	check(MineCatalog.price(4, 0) == 200 and MineCatalog.price(5, 0) == 50, "Freeze costs 200 and the first speed tier costs 50")
	var file := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "upgrades": {"depth": 3}, "depth": 200, "credits": 2000}))
	file.close()
	game.test_mode = false
	game.load_progress()
	check(game.upgrades.depth == 3 and game.selected_depth == 40, "Legacy saves retain purchased levels and their relative depth selection")
	game.save_progress()
	game.selected_depth = 0
	game.load_progress()
	check(game.selected_depth == 40, "Migrated depth settings survive a new-format save and reload")
	game.test_mode = true
	for i in range(4):
		check(game.indicator_center(i + 1).x - game.indicator_center(i).x == 88, "HUD indicator %d has the same spacing as its neighbor" % i)
	check(game.pickup_position({"start": Vector2(80, 400), "t": 1.0}) == game.indicator_center(2), "Ore pickup flights finish exactly at the Ores counter")
	game.cursor_position = Vector2(201.1, 411.2)
	check(game.cursor_center() == Vector2(202, 412), "The cursor center snaps to whole game pixels")
	var ring := MineInk.ring_texture(12).get_image()
	check(ring.get_pixel(0, 12).a == 1 and ring.get_pixel(1, 12).a == 0 and ring.get_pixel(23, 12).a == 1, "The mouse circle is one native pixel thick")
	game.pending_shortcuts.clear()
	game.selected_depth = 0
	game.start_run()
	game.world.blocks.clear()
	game.world.floor_spikes.clear()
	game.world.lava.clear()
	game.world.spawn_queue.clear()
	game.enemies.clear()
	for row in game.terrain_rows.values():
		row.queue_redraw()
	game.cursor_position = Vector2(-10, -10)
	game.time = 1.2
	game.enemies.append({"pos": Vector2(320, 400), "type": 2, "clock": 0.02})
	await frames()
	var pose_a := root.get_texture().get_image().get_region(Rect2i(296, 376, 48, 48))
	game.enemies[0].clock = 0.12
	await frames()
	check(pose_a.get_data() == root.get_texture().get_image().get_region(Rect2i(296, 376, 48, 48)).get_data(), "Enemy wings hold their target pose between animation frames")
	game.enemies[0].clock = 0.18
	await frames()
	check(pose_a.get_data() != root.get_texture().get_image().get_region(Rect2i(296, 376, 48, 48)).get_data(), "Enemy wings switch directly to the next pose at a frame boundary")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 96)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := ButtonProbe.new()
	viewport.add_child(probe)
	await frames()
	var base := viewport.get_texture().get_image().get_used_rect()
	probe.hovered = true
	probe.queue_redraw()
	await frames()
	check(viewport.get_texture().get_image().get_used_rect() == base.grow(2), "Button hover grows exactly one game pixel in all four directions")
	viewport.queue_free()
	game.return_to_depot(false)
	game.depot.open_shop()
	game.depot._process(0.4)
	var motion := InputEventMouseMotion.new()
	motion.position = game.depot.upgrade_rect(0).get_center()
	game._input(motion)
	await frames(4)
	check(game.depot.hovered_upgrade() == 0, "Hovering an upgrade opens its description")
	var tooltip: Rect2 = game.depot.tooltip_rect()
	check(tooltip.has_point(game.depot.nav_rect().get_center()) and tooltip.has_point(game.depot.dive_rect.get_center()), "The description popup overlays the bottom navigation and dive controls")
	var with_tooltip := root.get_texture().get_image()
	with_tooltip.save_png("res://.test-data/upgrade-tooltip.png")
	check(with_tooltip.get_pixel(240, 754) == MineInk.PANEL, "The popup covers the underlying bottom button label")
	motion.position = Vector2(8, 200)
	game._input(motion)
	await frames()
	check(game.depot.hovered_upgrade() == -1, "The description disappears as soon as the pointer leaves the card")
	check(with_tooltip.get_region(Rect2i(28, 626, 424, 150)).get_data() != root.get_texture().get_image().get_region(Rect2i(28, 626, 424, 150)).get_data(), "Leaving the upgrade restores the original bottom controls")
	var all_described := true
	for i in range(MineCatalog.UPGRADES.size()):
		all_described = all_described and MineCatalog.upgrade_description(i).length() > 50
	check(all_described, "Every upgrade has an explanatory hover description")
	print("Brown GUI: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
