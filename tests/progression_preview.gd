extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func shot(label: String) -> void:
	game.queue_redraw()
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/%s.png" % label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-data"))
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(720, 1200)
	game.credits = 8000
	game.return_to_depot(false)
	game.depot.open_shop()
	game.buy_upgrade(4)
	await shot("unlock-freeze")
	game.depot.confirm_shortcut()
	game.buy_upgrade(5)
	await shot("unlock-speed")
	game.depot.confirm_shortcut()
	game.buy_upgrade(0)
	game.buy_upgrade(6)
	await shot("shop-controls")
	game.inventory[0] = 3
	game.inventory[1] = 2
	game.inventory[14] = 1
	game.depot.change_screen("depot")
	await shot("depot-controls")
	game.inventory.fill(0)
	game.start_run()
	game.inventory[0] = 7
	game.frozen_toggle = true
	game._physics_process(0)
	await shot("inventory-full")
	print("Progression preview rendered with object-local coverage and original colors.")
	quit()
