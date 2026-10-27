extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func shot(label: String, wait: float = 0.08) -> void:
	game.queue_redraw()
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-data/%s.png" % label)

func run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(720, 1200)
	game.credits = 8000
	game.upgrades.freeze = 1
	game.upgrades.speed = 1
	game.upgrades.depth = 1
	game.selected_speed = 2
	game.inventory[0] = 3
	game.inventory[1] = 2
	game.inventory[14] = 2
	game.return_to_depot(false)
	await shot("haul-reveal-early", 0.12)
	await shot("haul-list", 0.95)
	game.depot.open_shop()
	await shot("shop-transition", 0.2)
	await shot("shop-placement", 0.3)
	game.inventory.fill(0)
	game.start_run()
	game.frozen_toggle = true
	game.enemies.clear()
	var placed := 0
	for cell_y in range(3, 16):
		for x in range(1, 14):
			var pos: Vector2 = game.world.cell_position(Vector2i(x, cell_y)) + Vector2(16, 16)
			if placed < 3 and game.place_block(pos):
				placed += 1
	game.place_block(Vector2(240, 430))
	game.floating_texts[0].age = 0.2
	game._physics_process(0.13)
	await shot("placement-exhausted")
	game.landing_squash = 0.35
	await shot("ears-landing")
	game.landing_squash = 0
	game.inventory[0] = 2
	game.die("Preview")
	game.advance_death(game.death_transition_start() + game.DEATH_IRIS_DURATION + 0.6)
	await shot("iris-hold")
	game.advance_death(game.death_duration() - game.death_time + 0.01)
	await shot("depot-entrance", 0.12)
	await shot("depot-after-death", 0.75)
	game.start_run()
	game.time = 1
	game.begin_departure()
	game._physics_process(0.25)
	await shot("departure-beam")
	game._physics_process(1.95)
	await shot("departure-lift")
	game._physics_process(1.25)
	await shot("departure-iris")
	quit()
