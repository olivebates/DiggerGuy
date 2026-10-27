class_name MineInk
extends RefCounted

const FONT = preload("res://PixelifySans.ttf")
const PIXEL := 2.0
const ICONS := ["block", "heart", "shield", "depth", "lock", "speed", "coin", "bag", "freeze", "home", "pick", "close", "arrow"]
const ICON_VARIANTS := 9
static var icon_texture: Texture2D
static var ring_textures: Dictionary = {}

const BG := Color("160e0b")
const PANEL := Color("2b1b13")
const LINE := Color("a47750")
const TEXT := Color("eee0bd")
const MUTED := Color("a69a80")
const GOLD := Color("e5d1a0")
const MINT := Color("fff0cc")

static func snap(value: Vector2) -> Vector2:
	return value.snapped(Vector2.ONE * PIXEL)

static func grid_rect(rect: Rect2) -> Rect2:
	var start := snap(rect.position)
	return Rect2(start, (snap(rect.end) - start).max(Vector2.ONE * PIXEL))

static func text(canvas: CanvasItem, value: String, pos: Vector2, size: int = 14, color: Color = TEXT) -> void:
	canvas.draw_string(FONT, pos.round(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func ring_texture(radius: int) -> Texture2D:
	if ring_textures.has(radius):
		return ring_textures[radius]
	var pixels := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in range(radius * 2):
		for x in range(radius * 2):
			var distance := Vector2(x + 0.5 - radius, y + 0.5 - radius).length_squared()
			if distance <= radius * radius and distance > (radius - 1) * (radius - 1):
				pixels.set_pixel(x, y, Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	ring_textures[radius] = texture
	return texture

static func fitted_text(canvas: CanvasItem, value: String, pos: Vector2, width: float, size: int, color: Color = TEXT) -> void:
	while size > 8 and FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	text(canvas, value, pos, size, color)

static func centered(canvas: CanvasItem, value: String, y: float, size: int = 14, color: Color = TEXT, x: float = 240) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(canvas, value, Vector2(x - width * 0.5, y), size, color)

static func panel(canvas: CanvasItem, rect: Rect2, color: Color = PANEL, border: Color = LINE, _radius: int = 0) -> void:
	var aligned := grid_rect(rect)
	canvas.draw_rect(aligned, color)
	outline(canvas, aligned, border)

static func outline(canvas: CanvasItem, rect: Rect2, border: Color = LINE) -> void:
	var aligned := grid_rect(rect)
	# Filled strips give exactly one game pixel, without centered half-pixel lines.
	canvas.draw_rect(Rect2(aligned.position, Vector2(aligned.size.x, PIXEL)), border)
	canvas.draw_rect(Rect2(aligned.position + Vector2(0, aligned.size.y - PIXEL), Vector2(aligned.size.x, PIXEL)), border)
	canvas.draw_rect(Rect2(aligned.position, Vector2(PIXEL, aligned.size.y)), border)
	canvas.draw_rect(Rect2(aligned.position + Vector2(aligned.size.x - PIXEL, 0), Vector2(PIXEL, aligned.size.y)), border)

static func button(canvas: CanvasItem, rect: Rect2, label: String, primary: bool, hover: bool, enabled: bool = true) -> void:
	var border := LINE.lightened(0.25) if hover and enabled else LINE
	if not enabled:
		border = LINE.darkened(0.55)
	panel(canvas, rect.grow(PIXEL if hover else 0), PANEL, border)
	centered(canvas, label, rect.position.y + rect.size.y * 0.5 + 5, 16 if primary else 14, TEXT if enabled else MUTED.darkened(0.3), rect.get_center().x)

static func icon(canvas: CanvasItem, kind: String, center: Vector2, color: Color = TEXT, scale_value: float = 1.0) -> void:
	var index := ICONS.find(kind)
	if icon_texture == null or index < 0:
		return
	var variant := clampi(roundi(scale_value * 8) - 4, 0, ICON_VARIANTS - 1)
	var cell := index * ICON_VARIANTS + variant
	var source := Rect2((cell % 16) * 16, (cell / 16) * 16, 16, 16)
	canvas.draw_texture_rect_region(icon_texture, Rect2(snap(center) - Vector2(16, 16), Vector2(32, 32)), source, color)

static func ore_icon(canvas: CanvasItem, center: Vector2, index: int, scale_value: float = 1.0) -> void:
	if icon_texture == null:
		return
	var variant := clampi(roundi(scale_value * 8) - 4, 0, ICON_VARIANTS - 1)
	var cell := (ICONS.size() + index) * ICON_VARIANTS + variant
	var source := Rect2((cell % 16) * 16, (cell / 16) * 16, 16, 16)
	canvas.draw_texture_rect_region(icon_texture, Rect2(snap(center) - Vector2(16, 16), Vector2(32, 32)), source)

static func vector_icon(canvas: CanvasItem, kind: String, center: Vector2, color: Color = TEXT, scale_value: float = 1.0) -> void:
	var s := scale_value
	match kind:
		"arrow":
			canvas.draw_line(center + Vector2(-9, 0) * s, center + Vector2(9, 0) * s, color, maxf(1, s))
			canvas.draw_polyline(PackedVector2Array([center + Vector2(3, -6) * s, center + Vector2(9, 0) * s, center + Vector2(3, 6) * s]), color, maxf(1, s))
		"block":
			canvas.draw_rect(Rect2(center - Vector2.ONE * 6 * s, Vector2.ONE * 12 * s), color, false, maxf(1, s))
			canvas.draw_line(center + Vector2(-4, -4) * s, center + Vector2(4, -4) * s, color, maxf(1, s))
		"heart":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, 7) * s, center + Vector2(-7, 0) * s, center + Vector2(-7, -4) * s, center + Vector2(-3, -6) * s, center + Vector2(0, -3) * s, center + Vector2(3, -6) * s, center + Vector2(7, -4) * s, center + Vector2(7, 0) * s]), color)
		"shield":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(0, -8) * s, center + Vector2(7, -5) * s, center + Vector2(6, 3) * s, center + Vector2(0, 8) * s, center + Vector2(-6, 3) * s, center + Vector2(-7, -5) * s, center + Vector2(0, -8) * s]), color, maxf(1, s))
		"depth":
			canvas.draw_line(center + Vector2(0, -8) * s, center + Vector2(0, 7) * s, color, maxf(1, 1.5 * s))
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-5, 2) * s, center + Vector2(0, 7) * s, center + Vector2(5, 2) * s]), color, maxf(1, 1.5 * s))
		"lock":
			canvas.draw_rect(Rect2(center + Vector2(-4, -1) * s, Vector2(8, 7) * s), color, false, maxf(1, s))
			canvas.draw_arc(center + Vector2(0, -1) * s, 3 * s, PI, TAU, 12, color, maxf(1, s))
		"speed":
			for x in [-5.0, 2.0]:
				canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(x - 3, -6) * s, center + Vector2(x + 4, 0) * s, center + Vector2(x - 3, 6) * s]), color)
		"coin":
			canvas.draw_circle(center, 8 * s, color, false, maxf(1, s))
			canvas.draw_circle(center, 5.5 * s, color, false, maxf(1, s))
			canvas.draw_line(center + Vector2(0, -3.5) * s, center + Vector2(0, 3.5) * s, color, maxf(1, 1.5 * s))
		"bag":
			canvas.draw_rect(Rect2(center + Vector2(-7, -5) * s, Vector2(14, 13) * s), color, false, maxf(1, 1.5 * s))
			canvas.draw_arc(center + Vector2(0, -5) * s, 4 * s, PI, TAU, 12, color, maxf(1, 1.5 * s))
			canvas.draw_line(center + Vector2(-3, 2) * s, center + Vector2(3, 2) * s, color, maxf(1, s))
		"freeze":
			for i in range(3):
				var v := Vector2.from_angle(i * PI / 3) * 8 * s
				canvas.draw_line(center - v, center + v, color, maxf(1, 1.5 * s))
				for sign_value in [-1, 1]:
					var point: Vector2 = center + v * sign_value * 0.65
					canvas.draw_line(point, point - v.rotated(0.7) * sign_value * 0.35, color, maxf(1, s))
					canvas.draw_line(point, point - v.rotated(-0.7) * sign_value * 0.35, color, maxf(1, s))
		"home":
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-9, -1) * s, center + Vector2(0, -8) * s, center + Vector2(9, -1) * s]), color, maxf(1, 1.5 * s))
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, -2) * s, center + Vector2(-6, 8) * s, center + Vector2(6, 8) * s, center + Vector2(6, -2) * s]), color, maxf(1, 1.5 * s))
			canvas.draw_rect(Rect2(center + Vector2(-2, 2) * s, Vector2(4, 6) * s), color, false, maxf(1, s))
		"pick":
			canvas.draw_line(center + Vector2(-6, 8) * s, center + Vector2(5, -6) * s, color, maxf(1, 2 * s))
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-6, -5) * s, center + Vector2(1, -8) * s, center + Vector2(7, -5) * s, center + Vector2(9, 1) * s]), color, maxf(1, 2 * s))
		"close":
			canvas.draw_line(center + Vector2(-5, -5) * s, center + Vector2(5, 5) * s, color, maxf(1, 1.5 * s))
			canvas.draw_line(center + Vector2(5, -5) * s, center + Vector2(-5, 5) * s, color, maxf(1, 1.5 * s))
		"sound", "muted":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -3) * s, center + Vector2(-3, -3) * s, center + Vector2(2, -7) * s, center + Vector2(2, 7) * s, center + Vector2(-3, 3) * s, center + Vector2(-7, 3) * s]), color)
			if kind == "sound":
				canvas.draw_arc(center + Vector2(1, 0) * s, 7 * s, -0.8, 0.8, 10, color, maxf(1, 1.5 * s))
			else:
				canvas.draw_line(center + Vector2(4, -3) * s, center + Vector2(9, 3) * s, color, maxf(1, s))
				canvas.draw_line(center + Vector2(9, -3) * s, center + Vector2(4, 3) * s, color, maxf(1, s))
