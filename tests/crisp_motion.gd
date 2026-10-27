extends SceneTree

class MovingSprite extends Node2D:
	var sprite: Texture2D
	var offset := Vector2(48.3, 48.7)
	var angle := 0.0
	func _draw() -> void:
		draw_set_transform(offset, angle, Vector2(2.3, 2.7))
		draw_texture(sprite, Vector2(-8, -8))

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

func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.015

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(480, 800)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 96)
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var palette := [Color("ee8b38"), Color("70bcb4"), Color("ffe1a0")]
	var source := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	# A hostile transparent fringe catches accidental interpolation of hidden RGB.
	source.fill(Color(1, 0, 1, 0))
	for y in range(3, 13):
		for x in range(3, 13):
			source.set_pixel(x, y, palette[(x + y) % 3])
	var probe := MovingSprite.new()
	probe.sprite = ImageTexture.create_from_image(source)
	# The shader must be hard-edged even if an inherited texture filter is linear.
	probe.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var crisp := ShaderMaterial.new()
	crisp.shader = load("res://shaders/crisp.gdshader")
	probe.material = crisp
	viewport.add_child(probe)
	var fractional := 0
	var mixed := 0
	var opaque := 0
	for pose in range(8):
		probe.offset = Vector2(46.13 + pose * 0.37, 47.61 + pose * 0.23)
		probe.angle = -0.3 + pose * 0.09
		probe.queue_redraw()
		await frames()
		var pixels := viewport.get_texture().get_image()
		for y in range(96):
			for x in range(96):
				var color := pixels.get_pixel(x, y)
				if color.a > 0.001 and color.a < 0.999:
					fractional += 1
				if color.a > 0.999:
					opaque += 1
					if not near(color, palette[0]) and not near(color, palette[1]) and not near(color, palette[2]):
						mixed += 1
	check(opaque > 1000, "Moving textured shapes are actually rendered")
	check(fractional == 0, "Moving and rotated sprites have no partially transparent edge pixels")
	check(mixed == 0, "Fractional motion and linear inherited filtering cannot mix shape colors")
	print("Motion raster: %d opaque pixels, %d fractional-alpha pixels, %d mixed colors across eight poses" % [opaque, fractional, mixed])
	viewport.queue_free()
	var game = load("res://scenes/game.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.synth.muted = true
	game.world.blocks.clear()
	game.world.lava.clear()
	game.world.floor_spikes.clear()
	game.enemies.clear()
	game.world.scroll = 0
	for row in game.terrain_rows.values():
		row.queue_redraw()
	game.player = Vector2(240, 180)
	var cell := Vector2i(11, 11)
	game.cursor_position = game.world.cell_position(cell) + Vector2(16, 16)
	await frames()
	check(game.placement_preview.target_rect().has_area(), "Valid placement cells show the preview")
	game.placement_preview.hide()
	await frames()
	var underlay: Image = root.get_texture().get_image()
	game.placement_preview.show()
	await frames()
	var overlay: Image = root.get_texture().get_image()
	var origin: Vector2 = game.world.cell_position(cell)
	var blend_errors := 0
	for y in range(int(origin.y) + 4, int(origin.y) + 28, 2):
		for x in range(int(origin.x) + 4, int(origin.x) + 28, 2):
			var expected := underlay.get_pixel(x, y).lerp(Color(0.5, 0.5, 0.5), 0.5)
			if not near(expected, overlay.get_pixel(x, y)):
				blend_errors += 1
	check(blend_errors == 0, "Valid preview blends neutral gray at exactly 50 percent")
	game.world.blocks[cell] = {"hp": 2, "ore": -1, "variant": 0}
	game.invalidate_terrain_row(cell.y)
	await frames()
	check(not game.placement_preview.target_rect().has_area(), "Occupied cells hide the preview entirely")
	var blocked: Image = root.get_texture().get_image()
	game.placement_preview.hide()
	await frames()
	check(blocked.get_data() == root.get_texture().get_image().get_data(), "Invalid cells draw no ghost, outline, pips, or rejection mark")
	game.world.blocks.erase(cell)
	game.blocks_left = 0
	check(not game.placement_preview.target_rect().has_area(), "An empty placement budget hides the preview")
	game.blocks_left = 3
	game.inventory_open = true
	check(not game.placement_preview.target_rect().has_area(), "Opening inventory hides the preview")
	print("Crisp motion/preview: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
