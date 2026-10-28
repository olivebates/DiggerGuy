extends SceneTree

var game: Node
var frames := 0

func _initialize() -> void:
	call_deferred("begin")

func begin() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.synth.muted = true
	print("STARTUP_READY: mode=%s frozen=%s popup=%s inventory=%s" % [game.mode, game.is_frozen(), game.shortcut_popup, game.inventory_open])
	process_frame.connect(observe)

func observe() -> void:
	frames += 1
	if frames < 90:
		return
	var moving: bool = game.run_time > 0.1 and game.world.scroll > 0
	print("STARTUP_LIVE: frames=%d simulation=%.3f scroll=%.1f moving=%s" % [frames, game.run_time, game.world.scroll, moving])
	quit(0 if moving else 1)
