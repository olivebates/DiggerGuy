extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func run() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	check(not game.is_frozen() and not game.shortcut_popup and not game.inventory_open, "Launch starts without an invisible pause")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	key.echo = true
	game._input(key)
	check(not game.space_held, "A launch-time key repeat cannot initiate freeze")
	key.echo = false
	game._input(key)
	check(game.space_held, "A fresh space press still freezes")
	game.shortcut_popup = true
	key.pressed = false
	game._input(key)
	check(not game.space_held, "Space release is handled while a popup owns input")
	game.shortcut_popup = false
	game.tutorial_cell = Vector2i(2, 3)
	game.space_held = true
	game._input(key)
	check(not game.space_held, "Placement lesson cannot swallow a space release")
	game.tutorial_cell = Vector2i(-999, -999)
	game.space_held = true
	game.speed_held = true
	game.sync_held_controls()
	check(not game.is_frozen() and not game.speed_held, "Missing key-up events recover on the next rendered frame")
	game.frozen_toggle = true
	game.sync_held_controls()
	check(game.is_frozen(), "Reconciliation preserves intentional button freeze")
	game.frozen_toggle = false
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	game.sync_held_controls()
	check(game.space_held, "Real held space survives reconciliation")
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	Input.flush_buffered_events()
	game.sync_held_controls()
	game.start_run()
	game.set_physics_process(false)
	var scroll_before: float = game.world.scroll
	for frame in range(60):
		game._physics_process(1.0 / 60)
	check(game.run_time > 0.9 and game.world.scroll > scroll_before, "A new round immediately advances simulation and terrain")
	print("Startup controls: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
