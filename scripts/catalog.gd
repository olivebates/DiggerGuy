class_name MineCatalog
extends RefCounted

const DEPTH_STEP := 10
const SHOP_UPGRADES := [0, 1, 2, 3, 5, 6, 7]
const MILESTONE_STEP := 10

static func milestone_reward(depth: int) -> int:
	return maxi(1, depth / MILESTONE_STEP) * 5

static func milestone_at(depth: int) -> Dictionary:
	for feature in MILESTONES:
		if feature.depth == depth:
			var result: Dictionary = feature.duplicate()
			result.reward = milestone_reward(depth)
			return result
	return {"depth": depth, "name": "Depth milestone", "reward": milestone_reward(depth), "detail": "A new depth reached. A one-time reward earned."}

static func next_milestone(depth: int) -> Dictionary:
	return milestone_at((maxi(0, depth) / MILESTONE_STEP + 1) * MILESTONE_STEP)

static func upgrade_required_depth(key: String, level: int) -> int:
	match key:
		"depth": return starting_depth(level + 1)
		"power": return 10 + level * 30
		"capacity": return 20 + level * 30
		"insurance": return 30 + level * 30
		"speed": return 0 if level == 0 else 30 + level * 90
		"blocks": return 60 + level * 90
		"lives": return 90 + level * 90
	return 0
const MILESTONES := [
	{"depth": 100, "name": "Glow gardens", "reward": 50, "detail": "Luminous roots mark sheltered pockets."},
	{"depth": 300, "name": "Lost vaults", "reward": 150, "detail": "Treasure rooms hide gilded caches."},
	{"depth": 360, "name": "Molten crossings", "reward": 180, "detail": "Lava basins reshape your route."},
	{"depth": 580, "name": "Crystal groves", "reward": 290, "detail": "Crystal formations fill the caverns."},
	{"depth": 920, "name": "Herd trails", "reward": 460, "detail": "Herds patrol the deeper cave floors."},
	{"depth": 1640, "name": "Ancient spires", "reward": 820, "detail": "Tall stone formations mark the ancient mine."},
	{"depth": 2600, "name": "Prismatic caverns", "reward": 1300, "detail": "Prismatic ore cuts and deep wildlife await."},
	{"depth": 4000, "name": "Deep sanctuaries", "reward": 2000, "detail": "Treasure caches grow richer in the deep."},
]

static func ore_id(ore_name: String) -> int:
	for i in range(ORES.size()):
		if ORES[i].name == ore_name:
			return i
	return -1

static func discovery_events(from_depth: int, to_depth: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(ORES.size()):
		var ore: Dictionary = ORES[i]
		if ore.depth > from_depth and ore.depth <= to_depth:
			events.append({"kind": "ore", "id": i, "name": ore.name, "depth": ore.depth, "detail": "Worth %d coins each." % ore.value, "value": ore.value})
	for i in range(ENEMIES.size()):
		var animal: Dictionary = ENEMIES[i]
		if animal.depth > from_depth and animal.depth <= to_depth:
			var behavior: String = animal.get("behavior", animal.kind)
			var details := {"graze": "Grazes, then wanders across the cave.", "shy": "Runs away when you get close.", "charge": "Pauses before charging toward you.", "bound": "Bounds between cave ledges.", "herd": "Patrols a small herd territory.", "glide": "Glides through the open caverns.", "slime": "Wanders with small, gentle hops.", "beetle": "Turns around at the edge of a ledge.", "bat": "Flutters through the cave air.", "hopper": "Leaps toward nearby movement.", "spider": "Alternates slow steps and quick bursts.", "wisp": "Drifts closer when you approach.", "crab": "Rushes across nearby cave floors.", "worm": "Shuffles and hops along the ground.", "eye": "Swoops toward nearby movement.", "sentinel": "Charges and jumps when you approach."}
			events.append({"kind": "animal", "id": i, "name": animal.name, "depth": animal.depth, "detail": details.get(behavior, "A new animal inhabits these caves.")})
	for i in range(MILESTONES.size()):
		var milestone: Dictionary = MILESTONES[i]
		if milestone.depth > from_depth and milestone.depth <= to_depth:
			events.append({"kind": "milestone", "id": i, "name": milestone.name, "depth": milestone.depth, "detail": milestone.detail, "value": milestone_reward(milestone.depth)})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.depth != b.depth:
			return a.depth < b.depth
		return ["ore", "milestone", "animal"].find(a.kind) < ["ore", "milestone", "animal"].find(b.kind))
	return events

static func upgrade_benefit(key: String, level: int) -> String:
	match key:
		"power": return "%d -> %d damage per hit" % [level + 1, level + 2]
		"capacity": return "%d -> %d ores carried" % [level + 7, level + 8]
		"depth": return "%d -> %d m starting depth" % [starting_depth(level), starting_depth(level + 1)]
		"insurance": return "%d -> %d ores saved on death" % [level + 3, level + 4]
		"speed": return "x%d -> x%d game speed" % [level + 2, level + 3]
		"lives": return "%d -> %d extra lives" % [level, level + 1]
		"blocks": return "%d -> %d blocks to place" % [level + 3, level + 4]
	return ""

static func starting_depth(level: int) -> int:
	return 5 * level * (level + 1)

const ORES = [
	{"name": "Iron", "color": "a7b4c4", "value": 3, "depth": 0},
	{"name": "Copper", "color": "e89a68", "value": 5, "depth": 0},
	{"name": "Tin", "color": "c4d8d6", "value": 9, "depth": 60},
	{"name": "Silver", "color": "dae7f5", "value": 15, "depth": 130},
	{"name": "Gold", "color": "ffd36b", "value": 25, "depth": 400},
	{"name": "Cobalt", "color": "618cfa", "value": 40, "depth": 800},
	{"name": "Nickel", "color": "b5ce88", "value": 60, "depth": 1200},
	{"name": "Titanium", "color": "a9a2d5", "value": 90, "depth": 1600},
	{"name": "Emerald", "color": "4ae5a2", "value": 60, "depth": 50},
	{"name": "Ruby", "color": "ff6685", "value": 70, "depth": 70},
	{"name": "Sapphire", "color": "61d0ff", "value": 300, "depth": 2800},
	{"name": "Diamond", "color": "c5ffff", "value": 450, "depth": 3400},
	{"name": "Obsidian", "color": "bd83e8", "value": 650, "depth": 4000},
	{"name": "Mythril", "color": "76f5d2", "value": 950, "depth": 4600},
	{"name": "Eternium", "color": "ffabef", "value": 1500, "depth": 5200},
	{"name": "Quartzite", "color": "dbc4a2", "value": 13, "depth": 100},
	{"name": "Sunstone", "color": "efb65b", "value": 21, "depth": 180},
	{"name": "Verdigris", "color": "65c897", "value": 32, "depth": 260},
	{"name": "Amberite", "color": "d7a448", "value": 47, "depth": 320},
	{"name": "Azurite", "color": "62b8d9", "value": 65, "depth": 460},
	{"name": "Moonstone", "color": "cad9f2", "value": 87, "depth": 560},
	{"name": "Frostsalt", "color": "a2dfe9", "value": 111, "depth": 680},
	{"name": "Malachite", "color": "48af7e", "value": 139, "depth": 900},
	{"name": "Dawnsteel", "color": "f3d787", "value": 169, "depth": 1000},
	{"name": "Roseglass", "color": "dc9cbb", "value": 202, "depth": 1100},
	{"name": "Stormite", "color": "818fca", "value": 238, "depth": 1300},
	{"name": "Jadestone", "color": "b0cf75", "value": 277, "depth": 1400},
	{"name": "Glowstone", "color": "d6e86e", "value": 319, "depth": 1500},
	{"name": "Lumenite", "color": "83e4bf", "value": 363, "depth": 1750},
	{"name": "Duskgold", "color": "bf9656", "value": 409, "depth": 1900},
	{"name": "Starshard", "color": "d8b8ff", "value": 458, "depth": 2050},
	{"name": "Aetherite", "color": "8ce9e7", "value": 510, "depth": 2200},
	{"name": "Dreamglass", "color": "c58fdb", "value": 564, "depth": 2350},
	{"name": "Novalite", "color": "ffb27d", "value": 621, "depth": 2500},
	{"name": "Voidopal", "color": "9a7ae0", "value": 680, "depth": 2650},
	{"name": "Sunfire", "color": "ff9d58", "value": 741, "depth": 2950},
	{"name": "Cryonium", "color": "8bbffc", "value": 805, "depth": 3100},
	{"name": "Nebulite", "color": "b898ef", "value": 872, "depth": 3250},
	{"name": "Soulquartz", "color": "e1c6de", "value": 940, "depth": 3550},
	{"name": "Astralite", "color": "7fddd2", "value": 1011, "depth": 3700},
	{"name": "Nightsteel", "color": "6e7da8", "value": 1084, "depth": 3850},
	{"name": "Chronite", "color": "d0b46a", "value": 1160, "depth": 4150},
	{"name": "Celestium", "color": "a6def3", "value": 1238, "depth": 4300},
	{"name": "Worldstone", "color": "bc91a4", "value": 1318, "depth": 4450},
	{"name": "Originite", "color": "f7d7a7", "value": 1400, "depth": 4900},
]

const ENEMIES = [
	{"name": "Rabbit", "color": "8cc78c", "depth": 0, "speed": 10.0, "kind": "slime"},
	{"name": "Capybara", "color": "d1a477", "depth": 0, "speed": 15.0, "kind": "beetle"},
	{"name": "Fruit bat", "color": "b99cda", "depth": 80, "speed": 22.0, "kind": "bat"},
	{"name": "Kangaroo", "color": "c8c17c", "depth": 180, "speed": 21.0, "kind": "hopper"},
	{"name": "Deer", "color": "d68e91", "depth": 320, "speed": 28.0, "kind": "spider"},
	{"name": "Butterfly", "color": "ffa86a", "depth": 480, "speed": 25.0, "kind": "wisp"},
	{"name": "Tortoise", "color": "77d3e5", "depth": 680, "speed": 25.0, "kind": "crab"},
	{"name": "Elephant", "color": "b99374", "depth": 920, "speed": 34.0, "kind": "worm", "behavior": "herd"},
	{"name": "Goose", "color": "cc8cff", "depth": 1240, "speed": 31.0, "kind": "eye"},
	{"name": "Bison", "color": "ff82cf", "depth": 1640, "speed": 39.0, "kind": "sentinel"},
	{"name": "Tapir", "color": "dbc4a2", "depth": 1800, "speed": 18, "kind": "beetle", "art": 1, "behavior": "shy"},
	{"name": "Moose", "color": "efb65b", "depth": 1960, "speed": 18.65, "kind": "spider", "art": 4, "behavior": "charge"},
	{"name": "Ibex", "color": "65c897", "depth": 2120, "speed": 19.3, "kind": "hopper", "art": 4, "behavior": "bound"},
	{"name": "Alpaca", "color": "d7a448", "depth": 2280, "speed": 19.95, "kind": "slime", "art": 3, "behavior": "graze"},
	{"name": "Dugong", "color": "62b8d9", "depth": 2440, "speed": 20.6, "kind": "wisp", "art": 1, "behavior": "glide"},
	{"name": "Okapi", "color": "cad9f2", "depth": 2600, "speed": 21.25, "kind": "spider", "art": 4, "behavior": "shy"},
	{"name": "Zebra", "color": "a2dfe9", "depth": 2760, "speed": 21.9, "kind": "sentinel", "art": 9, "behavior": "herd"},
	{"name": "Giraffe", "color": "48af7e", "depth": 2920, "speed": 22.55, "kind": "spider", "art": 4, "behavior": "graze"},
	{"name": "Rhinoceros", "color": "f3d787", "depth": 3080, "speed": 23.2, "kind": "sentinel", "art": 9, "behavior": "charge"},
	{"name": "Hippopotamus", "color": "dc9cbb", "depth": 3240, "speed": 23.85, "kind": "crab", "art": 1, "behavior": "charge"},
	{"name": "Porcupine", "color": "818fca", "depth": 3400, "speed": 24.5, "kind": "slime", "art": 0, "behavior": "graze"},
	{"name": "Beaver", "color": "b0cf75", "depth": 3560, "speed": 25.15, "kind": "beetle", "art": 1, "behavior": "herd"},
	{"name": "Marmot", "color": "d6e86e", "depth": 3720, "speed": 25.8, "kind": "hopper", "art": 0, "behavior": "shy"},
	{"name": "Guinea pig", "color": "83e4bf", "depth": 3880, "speed": 26.450000000000003, "kind": "slime", "art": 0, "behavior": "shy"},
	{"name": "Chinchilla", "color": "bf9656", "depth": 4040, "speed": 27.1, "kind": "hopper", "art": 0, "behavior": "bound"},
	{"name": "Agouti", "color": "d8b8ff", "depth": 4200, "speed": 27.75, "kind": "slime", "art": 0, "behavior": "shy"},
	{"name": "Gazelle", "color": "8ce9e7", "depth": 4360, "speed": 28.4, "kind": "hopper", "art": 3, "behavior": "bound"},
	{"name": "Antelope", "color": "c58fdb", "depth": 4520, "speed": 29.05, "kind": "sentinel", "art": 4, "behavior": "herd"},
	{"name": "Reindeer", "color": "ffb27d", "depth": 4680, "speed": 29.700000000000003, "kind": "spider", "art": 4, "behavior": "herd"},
	{"name": "Musk ox", "color": "9a7ae0", "depth": 4840, "speed": 30.35, "kind": "sentinel", "art": 9, "behavior": "charge"},
	{"name": "Wombat", "color": "ff9d58", "depth": 5000, "speed": 31, "kind": "beetle", "art": 1, "behavior": "graze"},
	{"name": "Koala", "color": "8bbffc", "depth": 5160, "speed": 31.65, "kind": "slime", "art": 0, "behavior": "graze"},
	{"name": "Giant panda", "color": "b898ef", "depth": 5320, "speed": 32.3, "kind": "sentinel", "art": 9, "behavior": "charge"},
	{"name": "Pika", "color": "e1c6de", "depth": 5480, "speed": 32.95, "kind": "hopper", "art": 0, "behavior": "bound"},
	{"name": "Sloth", "color": "7fddd2", "depth": 5640, "speed": 33.6, "kind": "worm", "art": 7, "behavior": "graze"},
	{"name": "Woolly mammoth", "color": "6e7da8", "depth": 5800, "speed": 34.25, "kind": "worm", "art": 7, "behavior": "charge"},
	{"name": "Glyptodon", "color": "d0b46a", "depth": 5960, "speed": 34.900000000000006, "kind": "crab", "art": 6, "behavior": "graze"},
	{"name": "Megatherium", "color": "a6def3", "depth": 6120, "speed": 35.55, "kind": "worm", "art": 7, "behavior": "herd"},
	{"name": "Parakeet", "color": "bc91a4", "depth": 6280, "speed": 36.2, "kind": "bat", "art": 8, "behavior": "glide"},
	{"name": "Toucan", "color": "f7d7a7", "depth": 6440, "speed": 36.85, "kind": "eye", "art": 8, "behavior": "glide"},
]

const UPGRADES = [
	{"key": "depth", "name": "Starting Depth", "base": 60, "max": -1, "icon": "depth"},
	{"key": "power", "name": "Mining Power", "base": 200, "max": -1, "icon": "pick"},
	{"key": "capacity", "name": "Inventory Size", "base": 20, "max": -1, "icon": "bag"},
	{"key": "insurance", "name": "Ore Insurance", "base": 500, "max": -1, "icon": "shield"},
	{"key": "freeze", "name": "Freeze", "base": 200, "max": 1, "icon": "freeze"},
	{"key": "speed", "name": "Speedup", "base": 200, "max": -1, "icon": "speed"},
	{"key": "lives", "name": "Extra Lives", "base": 1200, "max": -1, "icon": "heart"},
	{"key": "blocks", "name": "Place Blocks", "base": 100, "max": -1, "icon": "block"},
]

static func ore_color(index: int) -> Color:
	return Color(ORES[index].color)

static func price(index: int, level: int) -> int:
	var key: String = UPGRADES[index].key
	if key == "speed" and level == 0:
		return 50
	var amount: int = UPGRADES[index].base
	for step in range(level):
		if key in ["lives", "speed"]:
			if amount > 3074457345618258602:
				return 9223372036854775807
			amount *= 3
		else:
			var increase := amount / 4
			if amount > 9223372036854775807 - increase:
				return 9223372036854775807
			amount += increase
	return amount

static func upgrade_detail(index: int, level: int) -> String:
	match UPGRADES[index].key:
		"depth": return "%d → %d m" % [starting_depth(level), starting_depth(level + 1)]
		"power": return "%d → %d damage" % [level + 1, level + 2]
		"capacity": return "%d → %d spaces" % [7 + level, 8 + level]
		"insurance": return "Keep %d → %d ores" % [3 + level, 4 + level]
		"freeze": return "Hold Space · click to toggle"
		"speed": return "x%d → x%d · hold W" % [2 + level, 3 + level]
		"lives": return "%d → %d extra lives / dive" % [level, level + 1]
		"blocks": return "%d → %d blocks / dive" % [3 + level, 4 + level]
	return ""

static func upgrade_description(index: int) -> String:
	match UPGRADES[index].key:
		"depth": return "Increases the depth at which you start. Deeper depths have more dangers but also better ores."
		"power": return "Increases the amount of damage you do to blocks with the mouse."
		"capacity": return "Increases the amount of ores you can hold at one time."
		"insurance": return "Increases the amount of ores you keep when colliding with a hazard."
		"freeze": return "Hold space to freeze the game, allowing you to break blocks and think about what to do next."
		"speed": return "Hold W to speed up the game."
		"lives": return "Increases the amount of hazards you can hit"
		"blocks": return "Increases the amount of blocks you can place with Right Click."
	return ""

static func ore_shape(canvas: CanvasItem, center: Vector2, index: int, scale_value: float = 1.0, rotation: float = 0.0) -> void:
	var color := ore_color(index)
	if index >= 15:
		var sides := 4 + index % 4
		var gem := PackedVector2Array()
		for side in range(sides):
			gem.append(center + Vector2.from_angle(rotation + TAU * side / sides) * (5.5 if side % 2 == 0 else 4.5) * scale_value)
		canvas.draw_colored_polygon(gem, color)
		canvas.draw_colored_polygon(PackedVector2Array([gem[0], gem[1], center]), color.lightened(0.35))
		canvas.draw_line(center, gem[sides / 2], color.darkened(0.35), maxf(1, scale_value))
		return
	var points := PackedVector2Array([
		center + Vector2(-5, -1) * scale_value, center + Vector2(-2, -5) * scale_value,
		center + Vector2(3, -4) * scale_value, center + Vector2(5, 1) * scale_value,
		center + Vector2(1, 5) * scale_value, center + Vector2(-4, 3) * scale_value])
	for i in range(points.size()):
		points[i] = center + (points[i] - center).rotated(rotation)
	canvas.draw_colored_polygon(points, color.darkened(0.3))
	canvas.draw_colored_polygon(PackedVector2Array([points[0], points[1], center, points[5]]), color.lightened(0.2))
	canvas.draw_colored_polygon(PackedVector2Array([points[1], points[2], points[3], center]), color)
	canvas.draw_line(points[1], center, color.lightened(0.5), 1.0)
