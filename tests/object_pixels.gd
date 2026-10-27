extends SceneTree

class Probe extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(4.3, 6.8, 20.4, 20.4), Color(0.23, 0.41, 0.67, 0.4))
		draw_circle(Vector2(44, 38), 13.4, Color(0.71, 0.19, 0.33, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(3, 55), "Aa", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.36, 0.72, 0.13, 1))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := Probe.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/crisp.gdshader")
	probe.material = material
	viewport.add_child(probe)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	var fractional := 0
	var opaque := 0
	var wrong_rgb := 0
	var originals := [Color(0.23, 0.41, 0.67), Color(0.71, 0.19, 0.33), Color(0.36, 0.72, 0.13)]
	for y in range(64):
		for x in range(64):
			var color := pixels.get_pixel(x, y)
			if color.a > 0.001 and color.a < 0.999:
				fractional += 1
			if color.a > 0.999:
				opaque += 1
				var matches := false
				for original in originals:
					if absf(color.r - original.r) + absf(color.g - original.g) + absf(color.b - original.b) < 0.02:
						matches = true
				if not matches:
					wrong_rgb += 1
	print("Object raster: %d opaque pixels, %d fractional-alpha pixels, %d changed RGB pixels" % [opaque, fractional, wrong_rgb])
	viewport.queue_free()
	var game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.player_lean = 0.31
	game.landing_squash = 0.2
	game.time = 1.2
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var sprite: Image = game.player_viewport.get_texture().get_image()
	var sprite_fractional := 0
	var sprite_opaque := 0
	for y in range(sprite.get_height()):
		for x in range(sprite.get_width()):
			var alpha := sprite.get_pixel(x, y).a
			if alpha > 0.001 and alpha < 0.999:
				sprite_fractional += 1
			if alpha > 0.999:
				sprite_opaque += 1
	print("Rotated miner raster: %d opaque pixels, %d fractional-alpha pixels" % [sprite_opaque, sprite_fractional])
	if sprite_fractional > 0 or sprite_opaque < 50:
		fractional += 1
	game.queue_free()
	await process_frame
	quit(1 if fractional > 0 or opaque < 100 or wrong_rgb > 0 else 0)
