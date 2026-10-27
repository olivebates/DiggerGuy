class_name MineWorld
extends RefCounted

const TILE := 32
const PIXEL := 2.0
const COLS := 15
const ORE_CHANCE := 0.06
const TOP := 128.0
const START_Y := 272.0
const BOTTOM := 800.0
const GENERATION_MARGIN := 50
const MAX_OPEN_DROP := 5
const COLOR_SEED := 438771
const FLOOR_SPIKE_CHANCE := 0.07
static var color_anchors: Dictionary = {}
const REGIONS = [
	{"depth": 0, "rock": "65624b", "back": "14292c", "accent": "91af78", "kind": "roots"},
	{"depth": 220, "rock": "505e69", "back": "14212e", "accent": "8cbbcf", "kind": "slate"},
	{"depth": 580, "rock": "61536e", "back": "241c35", "accent": "c89bee", "kind": "crystal"},
	{"depth": 1100, "rock": "705044", "back": "301c24", "accent": "f5a26c", "kind": "ember"},
	{"depth": 1640, "rock": "454c68", "back": "151b31", "accent": "85e2d2", "kind": "crystal"},
]

var blocks: Dictionary = {}
var lava: Dictionary = {}
var floor_spikes: Dictionary = {}
var spawn_queue: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var sections: Array[Dictionary] = []
var veins: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var scroll := 0.0
var scroll_remainder := 0.0
var base_depth := 0
var last_row := -1
var rng := RandomNumberGenerator.new()
var flow_clock := 0.0
var generated_cave_cells := 0
var exit_column := 7
var vertical_runs: Array[int] = []
var vein_sequence := 0
var culled_row := -2147483648

static func region_index(depth: int) -> int:
	var index := 0
	for i in range(REGIONS.size()):
		if depth >= REGIONS[i].depth:
			index = i
	return index

static func region_color(depth: int, key: String) -> Color:
	var index := region_index(depth)
	var start_depth: int = REGIONS[index].depth
	var end_depth: int
	if index == REGIONS.size() - 1:
		var extra := maxi(0, floori((depth - start_depth) / 400.0))
		start_depth += extra * 400
		index += extra
		end_depth = start_depth + 400
	else:
		end_depth = REGIONS[index + 1].depth
	var blend := smoothstep(0, 1, clampf(float(depth - start_depth) / (end_depth - start_depth), 0, 1))
	return color_anchor(index, key).lerp(color_anchor(index + 1, key), blend)

static func color_anchor(index: int, key: String) -> Color:
	var cache_key := "%s:%d" % [key, index]
	if color_anchors.has(cache_key):
		return color_anchors[cache_key]
	var color_rng := RandomNumberGenerator.new()
	var salt := 11 if key == "rock" else (23 if key == "back" else 37)
	color_rng.seed = COLOR_SEED + index * 7919 + salt
	var color: Color
	if index < REGIONS.size():
		color = Color(REGIONS[index][key]).lightened(color_rng.randf_range(-0.025, 0.025))
	else:
		var hue := fposmod(0.58 + (index - REGIONS.size() + 1) * 0.087 + color_rng.randf_range(-0.025, 0.025), 1)
		var saturation := color_rng.randf_range(0.22, 0.4)
		var brightness := color_rng.randf_range(0.32, 0.43)
		if key == "back":
			saturation += 0.22
			brightness *= 0.28
		elif key == "accent":
			brightness = 0.78
		color = Color.from_hsv(hue, saturation, brightness)
	color_anchors[cache_key] = color
	return color

static func block_color(cell: Vector2i, starting_depth: int) -> Color:
	var variation := posmod((cell.x * 73856093) ^ COLOR_SEED, 7) - 3
	return region_color(starting_depth + cell.y, "rock").lightened(variation * 0.012)

static func block_health(depth: int) -> int:
	return 2 + maxi(0, depth) / 100

func reset(start_depth: int, world_seed: int = 0) -> void:
	blocks.clear()
	lava.clear()
	floor_spikes.clear()
	spawn_queue.clear()
	rooms.clear()
	sections.clear()
	veins.clear()
	decorations.clear()
	scroll = 0
	scroll_remainder = 0
	base_depth = start_depth
	last_row = -1
	culled_row = -2147483648
	generated_cave_cells = 0
	flow_clock = 0
	vein_sequence = 0
	vertical_runs.resize(COLS)
	vertical_runs.fill(0)
	if world_seed == 0:
		rng.randomize()
	else:
		rng.seed = world_seed
	exit_column = rng.randi_range(5, 9)
	ensure_rows()

func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori((pos.y - START_Y + scroll) / TILE))

func cell_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE, START_Y + cell.y * TILE - scroll)

func solid(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.x >= COLS or blocks.has(cell)

func collides(rect: Rect2) -> bool:
	var first := cell_at(rect.position + Vector2(0.01, 0.01))
	var last := cell_at(rect.end - Vector2(0.01, 0.01))
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if solid(Vector2i(x, y)):
				return true
	return false

func ensure_rows() -> void:
	var target := ceili((800 - START_Y + scroll) / TILE) + GENERATION_MARGIN
	while last_row < target:
		var start := last_row + 1
		var height := rng.randi_range(18, 24)
		generate_section(start, height)
		last_row = start + height - 1
	var oldest := floori((TOP - START_Y + scroll) / TILE) - 5
	if oldest == culled_row:
		return
	culled_row = oldest
	for cell in blocks.keys():
		if cell.y < oldest:
			blocks.erase(cell)
	for cell in lava.keys():
		if cell.y < oldest:
			lava.erase(cell)
	for cell in floor_spikes.keys():
		if cell.y < oldest or not blocks.has(cell):
			floor_spikes.erase(cell)
	rooms = rooms.filter(func(room: Dictionary) -> bool: return room.center.y + room.radius.y >= oldest)
	sections = sections.filter(func(section: Dictionary) -> bool: return section.end >= oldest)
	veins = veins.filter(func(vein: Dictionary) -> bool: return vein.row >= oldest - 5)
	decorations = decorations.filter(func(prop: Dictionary) -> bool: return prop.cell.y >= oldest)
	spawn_queue = spawn_queue.filter(func(spawn: Dictionary) -> bool: return spawn.cell.y >= oldest)

func carve_disc(mask: Dictionary, center: Vector2, radius: Vector2, height: int, angular: bool = false) -> void:
	for y in range(maxi(0, floori(center.y - radius.y)), mini(height, ceili(center.y + radius.y) + 1)):
		for x in range(maxi(1, floori(center.x - radius.x)), mini(COLS - 1, ceili(center.x + radius.x) + 1)):
			var offset := (Vector2(x + 0.5, y + 0.5) - center) / radius
			var inside := absf(offset.x) + absf(offset.y) < 1.35 if angular else offset.length_squared() <= 1.0
			if inside:
				mask[Vector2i(x, y)] = true

func carve_tunnel(mask: Dictionary, from: Vector2, to: Vector2, radius: float, height: int, curved: bool = true) -> void:
	var control := (from + to) * 0.5
	if curved:
		control.x = clampf(control.x + rng.randf_range(-1.7, 1.7), 2, COLS - 2)
	var end_radius := radius * rng.randf_range(0.95, 1.25)
	var widening := rng.randf_range(0, 0.18)
	var samples := maxi(4, ceili(from.distance_to(to) * 5))
	for i in range(samples + 1):
		var t := float(i) / samples
		var center := from.lerp(control, t).lerp(control.lerp(to, t), t)
		var width := lerpf(radius, end_radius, smoothstep(0, 1, t)) + sin(t * PI) * widening
		carve_disc(mask, center, Vector2.ONE * width, height)

func add_room(mask: Dictionary, center: Vector2, radius: Vector2, kind: String, start: int, height: int, angular: bool = false) -> void:
	carve_disc(mask, center, radius, height, angular)
	rooms.append({"center": center + Vector2(0, start), "radius": radius, "kind": kind})

func generate_section(start: int, height: int) -> void:
	var initial_runs := vertical_runs.duplicate()
	var depth := base_depth + start
	var region := region_index(depth)
	var mask: Dictionary = {}
	var shelves: Dictionary = {}
	var safer_left := rng.randf() < 0.5
	var safe_x := 3.5 if safer_left else 11.5
	var risk_x := 11.0 if safer_left else 4.0
	var treasure_cell := Vector2i(-1, -1)
	var style := rng.randi_range(0, 4)
	# Slate favors shafts, crystals favor angular branches, embers favor broad basins.
	if region == 1 and rng.randf() < 0.55:
		style = 0
	elif region == 2 and rng.randf() < 0.55:
		style = 2
	elif region == 3 and rng.randf() < 0.6:
		style = 1
	var entry := Vector2(exit_column + 0.5, 0.5 if start > 0 else 2.5)
	var fork := Vector2(7.5 + rng.randf_range(-1, 1), 4)
	carve_tunnel(mask, entry, fork, 1.05, height)
	var previous := fork
	var safe_nodes: Array[Vector2] = []
	for y in range(5, height - 2, 3):
		var node := Vector2(clampf(safe_x + rng.randf_range(-1.4, 1.4), 2.5, 12.5), y + 0.5)
		var elbow := Vector2(node.x, previous.y)
		carve_tunnel(mask, previous, elbow, 1.05, height, false)
		carve_tunnel(mask, elbow, node, 1.05, height, false)
		carve_disc(mask, node, Vector2(1.65, 1.05), height)
		safe_nodes.append(node)
		previous = node
	var chamber := Vector2(risk_x, rng.randf_range(8, 10))
	var radius := Vector2(3.1, 2.65)
	match style:
		0: radius = Vector2(1.8, 4.0)
		1: radius = Vector2(3.7, 2.7)
		2: radius = Vector2(3.2, 3.2)
		3: radius = Vector2(2.7, 2.1)
		4: radius = Vector2(2.35, 2.8)
	add_room(mask, chamber, radius, ["shaft", "chamber", "branch", "terrace", "pocketed"][style], start, height, region == 2)
	carve_tunnel(mask, fork, chamber - Vector2(0, radius.y - 0.5), 1.0, height)
	var lower := Vector2(7.5 + rng.randf_range(-1, 1), height - 5.0)
	add_room(mask, lower, Vector2(rng.randf_range(2.1, 3.1), 1.6), "landing", start, height, region == 2)
	carve_tunnel(mask, chamber + Vector2(0, radius.y - 0.5), lower, 1.05, height)
	carve_tunnel(mask, previous, lower, 1.05, height)
	if style == 2:
		var branch := Vector2(7.5, 8)
		add_room(mask, branch, Vector2(1.7, 1.5), "branch", start, height, true)
		carve_tunnel(mask, branch, chamber, 0.95, height)
	if style == 3:
		for step in range(3):
			var terrace := chamber + Vector2((step - 1) * (1 if safer_left else -1), (step - 1) * 2)
			carve_disc(mask, terrace, Vector2(2.2, 1.1), height)
			var ledge := Vector2i(terrace) + Vector2i(0, 1)
			mask.erase(ledge)
			shelves[ledge] = true
	# Small enclosed pockets reward selective digging beside the main routes.
	var pockets_left := 3 if style == 4 else 1
	for attempt in range(30):
		var pocket := Vector2(rng.randi_range(2, 12) + 0.5, rng.randi_range(6, height - 4) + 0.5)
		if not mask.has(Vector2i(pocket)) and not mask.has(Vector2i(pocket) + Vector2i.LEFT) and not mask.has(Vector2i(pocket) + Vector2i.RIGHT):
			add_room(mask, pocket, Vector2(1.25, 1.25), "pocket", start, height)
			pockets_left -= 1
			if pockets_left <= 0:
				break
	exit_column = rng.randi_range(4, 10)
	var exit_point := Vector2(exit_column + 0.5, height - 0.5)
	carve_tunnel(mask, lower, exit_point, 1.05, height)
	if depth >= 300 and rng.randf() < (0.28 if depth >= 4000 else 0.18):
		var vault := Vector2(2.5 if safer_left else 12.5, height - 8.5)
		add_room(mask, vault, Vector2(1.65, 1.45), "treasure", start, height)
		carve_tunnel(mask, lower, vault, 0.8, height, false)
		treasure_cell = Vector2i(floori(vault.x), floori(vault.y) + 1)
		mask.erase(treasure_cell)
		shelves[treasure_cell] = true
	# Alternate supported steps along the safer route, leaving a side gap to dig around.
	for node in safe_nodes:
		var shelf := Vector2i(floori(node.x), floori(node.y) + 1)
		mask.erase(shelf)
		shelves[shelf] = true
		var neighbor := shelf + Vector2i(-1 if safer_left else 1, 0)
		mask.erase(neighbor)
		shelves[neighbor] = true
	# Catch shelves interrupt every long vertical opening, including section boundaries.
	for y in range(height):
		for x in range(COLS):
			var local := Vector2i(x, y)
			if start == 0 and y < 2:
				mask.erase(local)
			if mask.has(local):
				vertical_runs[x] += 1
				if vertical_runs[x] > MAX_OPEN_DROP:
					mask.erase(local)
					shelves[local] = true
					vertical_runs[x] = 0
			else:
				vertical_runs[x] = 0
	var basin: Array[Vector2i] = []
	if depth >= 360 and (start == 0 or rng.randf() < 0.45 + region * 0.08):
		var basin_y := mini(height - 5, floori(chamber.y + radius.y) - 1)
		var basin_x := clampi(floori(chamber.x) - 1, 2, COLS - 5)
		for x in range(basin_x, basin_x + 3):
			mask[Vector2i(x, basin_y)] = true
			mask[Vector2i(x, basin_y - 1)] = true
			mask.erase(Vector2i(x, basin_y + 1))
			shelves[Vector2i(x, basin_y + 1)] = true
			basin.append(Vector2i(x, start + basin_y))
		for x in [basin_x - 1, basin_x + 3]:
			mask.erase(Vector2i(x, basin_y))
			mask.erase(Vector2i(x, basin_y + 1))
	# Basin construction can open an old shelf; revalidate drop lengths afterward.
	vertical_runs = initial_runs
	for y in range(height):
		for x in range(COLS):
			var local := Vector2i(x, y)
			if not mask.has(local):
				vertical_runs[x] = 0
				continue
			vertical_runs[x] += 1
			if vertical_runs[x] > MAX_OPEN_DROP:
				if Vector2i(x, start + y) in basin:
					var catch_cell := local + Vector2i(0, -2)
					mask.erase(catch_cell)
					shelves[catch_cell] = true
					vertical_runs[x] = 2
				else:
					mask.erase(local)
					shelves[local] = true
					vertical_runs[x] = 0
	# Materialize a complete section before placing veins, props, or enemies.
	var section_rocks: Array[Vector2i] = []
	for y in range(height):
		for x in range(COLS):
			var cell := Vector2i(x, start + y)
			var local := Vector2i(x, y)
			if mask.has(local):
				generated_cave_cells += 1
			else:
				var health := block_health(base_depth + cell.y)
				blocks[cell] = {"hp": health, "max_hp": health, "ore": -1, "variant": rng.randi_range(0, 6), "shelf": shelves.has(local)}
				section_rocks.append(cell)
	for cell in basin:
		lava[cell] = rng.randf_range(0.7, 0.95)
	place_veins(section_rocks, chamber + Vector2(0, start), depth)
	var cache_cell := treasure_cell + Vector2i(0, start)
	if treasure_cell.x >= 0 and blocks.has(cache_cell):
		blocks[cache_cell].treasure = true
		blocks[cache_cell].treasure_coins = (20 + (base_depth + cache_cell.y) / 8) * (2 if depth >= 4000 else 1)
		if blocks[cache_cell].ore < 0:
			blocks[cache_cell].ore = choose_ore(base_depth + cache_cell.y)
	place_decorations(start, height, region)
	place_floor_spikes(start, height)
	place_emeralds(section_rocks)
	place_enemies(start, height, chamber + Vector2(0, start), radius)
	sections.append({"start": start, "end": start + height - 1, "style": style, "safe_left": safer_left, "entry": entry + Vector2(0, start), "exit": exit_point + Vector2(0, start), "basin": basin})

func place_veins(rocks: Array[Vector2i], risk_center: Vector2, depth: int) -> void:
	var remaining := maxi(2, roundi(rocks.size() * ORE_CHANCE))
	var candidates := rocks.duplicate()
	# Fisher-Yates uses the world's seeded RNG; Array.shuffle would break reproducibility.
	for i in range(candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var swap: Vector2i = candidates[i]
		candidates[i] = candidates[other]
		candidates[other] = swap
	var single_candidates := candidates.duplicate()
	while remaining >= 2 and not candidates.is_empty():
		var size := mini(5, remaining)
		if remaining > 5:
			size = rng.randi_range(2, mini(5, remaining - 2))
		var seed_cell: Vector2i = candidates.pop_back()
		if blocks[seed_cell].ore >= 0:
			continue
		# Prefer the chamber side for the first vein, creating a visible risk/reward choice.
		if remaining == maxi(2, roundi(rocks.size() * ORE_CHANCE)):
			var distance := Vector2(seed_cell).distance_squared_to(risk_center)
			for cell in candidates:
				var next_distance := Vector2(cell).distance_squared_to(risk_center)
				if next_distance < distance and blocks[cell].ore < 0:
					seed_cell = cell
					distance = next_distance
		var cluster: Array[Vector2i] = [seed_cell]
		var frontier: Array[Vector2i] = [seed_cell]
		while cluster.size() < size and not frontier.is_empty():
			var current: Vector2i = frontier.pop_back()
			var neighbors: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
			var rotation := rng.randi_range(0, 3)
			for i in range(4):
				var cell := current + neighbors[(i + rotation) % 4]
				if cluster.size() >= size:
					break
				if blocks.has(cell) and cell in rocks and blocks[cell].ore < 0 and cell not in cluster:
					cluster.append(cell)
					frontier.append(cell)
		if cluster.size() < mini(2, size):
			continue
		var ore := choose_ore(depth)
		if Vector2(seed_cell).distance_to(risk_center) < 5:
			ore = maxi(ore, choose_ore(depth))
		vein_sequence += 1
		for cell in cluster:
			blocks[cell].ore = ore
			blocks[cell].vein = vein_sequence
		veins.append({"id": vein_sequence, "cells": cluster, "ore": ore, "row": seed_cell.y})
		remaining -= cluster.size()
	# Three isolated ore deposits for every vein, in addition to vein ore.
	var single_count := 0
	# Count only veins seeded in this section's rock set.
	for vein in veins:
		if vein.cells[0] in rocks:
			single_count += 3
	for cell in single_candidates:
		if single_count <= 0:
			break
		if blocks[cell].ore >= 0:
			continue
		var isolated := true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if blocks.get(cell + offset, {}).get("ore", -1) >= 0:
				isolated = false
		if isolated:
			blocks[cell].ore = choose_ore(depth)
			blocks[cell].single = true
			single_count -= 1

func place_decorations(start: int, height: int, region: int) -> void:
	var section_depth := base_depth + start
	if REGIONS[region].kind == "roots" and section_depth < 100:
		return
	for y in range(start + 1, start + height - 1):
		for x in range(1, COLS - 1):
			var cell := Vector2i(x, y)
			if not solid(cell) and not lava.has(cell) and rng.randf() < 0.12:
				var kind: String = REGIONS[region].kind
				if section_depth >= 2600:
					kind = "prism"
				elif section_depth >= 1640:
					kind = "spire"
				elif section_depth < 220:
					kind = "garden"
				if solid(cell + Vector2i.UP):
					decorations.append({"cell": cell, "kind": kind, "ceiling": true, "variant": rng.randf()})
				elif solid(cell + Vector2i.DOWN):
					decorations.append({"cell": cell, "kind": kind, "ceiling": false, "variant": rng.randf()})

func place_floor_spikes(start: int, height: int) -> void:
	for y in range(maxi(4, start + 1), start + height - 1):
		for x in range(1, COLS - 1):
			var cell := Vector2i(x, y)
			var above := cell + Vector2i.UP
			if solid(cell) and blocks[cell].ore < 0 and not blocks[cell].get("treasure", false) and not solid(above) and not lava.has(above) and rng.randf() < FLOOR_SPIKE_CHANCE:
				floor_spikes[cell] = {"height": rng.randf_range(8, 11)}
				blocks[cell].indestructible = true
				blocks[cell].ore = -1

func spike_triangles(cell: Vector2i) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not floor_spikes.has(cell) or not solid(cell) or solid(cell + Vector2i.UP):
		return result
	var pos := cell_position(cell)
	var height: float = floor_spikes[cell].height
	for i in range(3):
		var base := pos + Vector2(3 + i * 9, 0)
		result.append(PackedVector2Array([base, base + Vector2(9, 0), base + Vector2(4.5, -height)]))
	return result

func touches_floor_spikes(rect: Rect2) -> bool:
	for cell: Vector2i in floor_spikes:
		var pos := cell_position(cell)
		var height: float = floor_spikes[cell].height
		if not rect.intersects(Rect2(pos + Vector2(3, -height), Vector2(27, height))):
			continue
		var body := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
		for triangle in spike_triangles(cell):
			if not Geometry2D.intersect_polygons(triangle, body).is_empty():
				return true
	return false

func place_enemies(start: int, height: int, chamber: Vector2, radius: Vector2) -> void:
	var floors: Array[Vector2i] = []
	var open_air: Array[Vector2i] = []
	for y in range(maxi(7, start + 3), start + height - 2):
		for x in range(1, COLS - 1):
			var cell := Vector2i(x, y)
			if solid(cell) or lava.has(cell) or lava.has(cell + Vector2i.DOWN) or floor_spikes.has(cell + Vector2i.DOWN):
				continue
			if solid(cell + Vector2i.DOWN) and not lava.has(cell + Vector2i.LEFT) and not lava.has(cell + Vector2i.RIGHT):
				floors.append(cell)
			elif not solid(cell + Vector2i.LEFT) and not solid(cell + Vector2i.RIGHT) and not solid(cell + Vector2i.UP) and not solid(cell + Vector2i.DOWN) and Vector2(cell).distance_to(chamber) < radius.length():
				open_air.append(cell)
	var attempts := 2 if base_depth + start > 320 else 1
	for attempt in range(attempts):
		var available: Array[int] = []
		for i in range(MineCatalog.ENEMIES.size()):
			if base_depth + start < MineCatalog.ENEMIES[i].depth:
				continue
			var flying: bool = MineCatalog.ENEMIES[i].kind in ["bat", "wisp", "eye"]
			if (flying and not open_air.is_empty()) or (not flying and not floors.is_empty()):
				available.append(i)
		if available.is_empty():
			return
		var index := rng.randi_range(0, available.size() - 1)
		if available.size() > 2 and rng.randf() < 0.55:
			index = rng.randi_range(available.size() / 2, available.size() - 1)
		var enemy_type := available[index]
		var flying: bool = MineCatalog.ENEMIES[enemy_type].kind in ["bat", "wisp", "eye"]
		var spots: Array[Vector2i] = open_air if flying else floors
		var cell := spots[rng.randi_range(0, spots.size() - 1)]
		spawn_queue.append({"cell": cell, "type": enemy_type})
		spots.erase(cell)
func choose_ore(depth: int) -> int:
	var eligible: Array[int] = []
	for i in range(MineCatalog.ORES.size()):
		# Emeralds have their own one-percent roll, outside veins and singles.
		if i != 8 and depth >= MineCatalog.ORES[i].depth:
			eligible.append(i)
	eligible.sort_custom(func(a: int, b: int) -> bool: return MineCatalog.ORES[a].depth < MineCatalog.ORES[b].depth)
	# Keep early ores present, but weight the newest unlocked ores more heavily.
	if eligible.size() > 2 and rng.randf() < 0.60:
		return eligible[rng.randi_range(maxi(0, eligible.size() - 4), eligible.size() - 1)]
	return eligible[rng.randi_range(0, eligible.size() - 1)]

func place_emeralds(rocks: Array[Vector2i]) -> void:
	for cell in rocks:
		if base_depth + cell.y < 50 or blocks[cell].ore >= 0 or blocks[cell].get("indestructible", false):
			continue
		if rng.randf() < 0.01:
			blocks[cell].ore = 8

func hit(cell: Vector2i, damage: int) -> Dictionary:
	if not blocks.has(cell):
		return {}
	if blocks[cell].get("indestructible", false) or floor_spikes.has(cell):
		return {"damaged": true, "indestructible": true}
	blocks[cell].hp -= damage
	if blocks[cell].hp <= 0:
		var destroyed: Dictionary = blocks[cell].duplicate()
		blocks.erase(cell)
		floor_spikes.erase(cell)
		return destroyed
	return {"damaged": true}

func advance(delta: float, speed: float) -> float:
	# Accumulate time without losing slow movement; expose only whole game pixels.
	scroll_remainder += speed * delta
	var movement := floorf((scroll_remainder + 0.0000001) / PIXEL) * PIXEL
	scroll_remainder = maxf(0, scroll_remainder - movement)
	scroll += movement
	ensure_rows()
	flow_clock += delta
	if flow_clock >= 0.07:
		flow_clock = 0
		flow_lava()
	return movement

func flow_lava() -> void:
	# Finite-volume cellular liquid: fall first, then equalize neighboring cells.
	# Transfers immediately update both cells, conserving volume even in waterfalls.
	var cells := lava.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	for cell: Vector2i in cells:
		if cell_position(cell).y > 800 + TILE * 4:
			continue
		if solid(cell):
			lava.erase(cell)
			continue
		var amount: float = lava.get(cell, 0.0)
		if amount < 0.002:
			continue
		var below := cell + Vector2i.DOWN
		if below.y <= last_row and not solid(below):
			var moved := minf(amount, 1.0 - float(lava.get(below, 0.0)))
			if moved > 0:
				lava[below] = float(lava.get(below, 0.0)) + moved
				amount -= moved
		var direction := -1 if (cell.x + cell.y) % 2 == 0 else 1
		for side in [direction, -direction]:
			var neighbor := cell + Vector2i(side, 0)
			if not solid(neighbor):
				var other: float = lava.get(neighbor, 0.0)
				var moved := maxf(0, (amount - other) * 0.45)
				if moved > 0.002:
					lava[neighbor] = other + moved
					amount -= moved
		if amount <= 0.0001:
			lava.erase(cell)
		else:
			lava[cell] = amount

func clear_spike_contact(rect: Rect2) -> void:
	for cell in floor_spikes.keys():
		for triangle in spike_triangles(cell):
			var body := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
			if not Geometry2D.intersect_polygons(triangle, body).is_empty():
				floor_spikes.erase(cell)
				break

func clear_lava_contact(rect: Rect2) -> void:
	var frontier: Array[Vector2i] = []
	var visited: Dictionary = {}
	for cell: Vector2i in lava:
		if Rect2(cell_position(cell), Vector2.ONE * TILE).intersects(rect):
			frontier.append(cell)
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if visited.has(cell) or not lava.has(cell):
			continue
		visited[cell] = true
		lava.erase(cell)
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if lava.has(cell + step):
				frontier.append(cell + step)

func touches_lava(rect: Rect2) -> bool:
	var first := cell_at(rect.position)
	var last := cell_at(rect.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var amount: float = lava.get(cell, 0.0)
			if amount > 0.06:
				var pos := cell_position(cell) + Vector2(0, TILE * (1 - amount))
				if rect.intersects(Rect2(pos, Vector2(TILE, TILE * amount))):
					return true
	return false
