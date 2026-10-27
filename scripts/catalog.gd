class_name MineCatalog
extends RefCounted

const ORES = [
	{"name": "Iron", "color": "a7b4c4", "value": 3, "depth": 0},
	{"name": "Copper", "color": "e89a68", "value": 5, "depth": 0},
	{"name": "Tin", "color": "c4d8d6", "value": 9, "depth": 60},
	{"name": "Silver", "color": "dae7f5", "value": 15, "depth": 130},
	{"name": "Gold", "color": "ffd36b", "value": 25, "depth": 220},
	{"name": "Cobalt", "color": "618cfa", "value": 40, "depth": 330},
	{"name": "Nickel", "color": "b5ce88", "value": 60, "depth": 450},
	{"name": "Titanium", "color": "a9a2d5", "value": 90, "depth": 580},
	{"name": "Emerald", "color": "4ae5a2", "value": 135, "depth": 730},
	{"name": "Ruby", "color": "ff6685", "value": 200, "depth": 900},
	{"name": "Sapphire", "color": "61d0ff", "value": 300, "depth": 1090},
	{"name": "Diamond", "color": "c5ffff", "value": 450, "depth": 1300},
	{"name": "Obsidian", "color": "bd83e8", "value": 650, "depth": 1530},
	{"name": "Mythril", "color": "76f5d2", "value": 950, "depth": 1790},
	{"name": "Eternium", "color": "ffabef", "value": 1500, "depth": 2080},
]

const ENEMIES = [
	{"name": "Pebble slime", "color": "8cc78c", "depth": 0, "speed": 10.0, "kind": "slime"},
	{"name": "Cave beetle", "color": "d1a477", "depth": 0, "speed": 15.0, "kind": "beetle"},
	{"name": "Dust bat", "color": "b99cda", "depth": 80, "speed": 22.0, "kind": "bat"},
	{"name": "Rock hopper", "color": "c8c17c", "depth": 180, "speed": 21.0, "kind": "hopper"},
	{"name": "Tunnel spider", "color": "d68e91", "depth": 320, "speed": 28.0, "kind": "spider"},
	{"name": "Ember wisp", "color": "ffa86a", "depth": 480, "speed": 25.0, "kind": "wisp"},
	{"name": "Crystal crab", "color": "77d3e5", "depth": 680, "speed": 25.0, "kind": "crab"},
	{"name": "Deep burrower", "color": "b99374", "depth": 920, "speed": 34.0, "kind": "worm"},
	{"name": "Void watcher", "color": "cc8cff", "depth": 1240, "speed": 31.0, "kind": "eye"},
	{"name": "Eternium sentinel", "color": "ff82cf", "depth": 1640, "speed": 39.0, "kind": "sentinel"},
]

const UPGRADES = [
	{"key": "depth", "name": "Starting Depth", "base": 60, "max": -1, "icon": "depth"},
	{"key": "power", "name": "Mining Power", "base": 200, "max": -1, "icon": "pick"},
	{"key": "capacity", "name": "Inventory Size", "base": 30, "max": -1, "icon": "bag"},
	{"key": "insurance", "name": "Ore Insurance", "base": 500, "max": -1, "icon": "shield"},
	{"key": "freeze", "name": "Freeze", "base": 1000, "max": 1, "icon": "freeze"},
	{"key": "speed", "name": "Speedup", "base": 200, "max": 3, "icon": "speed"},
	{"key": "lives", "name": "Extra Lives", "base": 1200, "max": -1, "icon": "heart"},
	{"key": "blocks", "name": "Place Blocks", "base": 100, "max": -1, "icon": "block"},
]

static func ore_color(index: int) -> Color:
	return Color(ORES[index].color)

static func price(index: int, level: int) -> int:
	var key: String = UPGRADES[index].key
	if key == "speed":
		return [200, 500, 1200][clampi(level, 0, 2)]
	var amount: int = UPGRADES[index].base
	for step in range(level):
		if key == "lives":
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
		"depth": return "%d → %d m" % [level * 100, (level + 1) * 100]
		"power": return "%d → %d damage" % [level + 1, level + 2]
		"capacity": return "%d → %d spaces" % [7 + level, 8 + level]
		"insurance": return "Keep %d → %d ores" % [3 + level, 4 + level]
		"freeze": return "Hold Space · click to toggle"
		"speed": return "%dx → %dx · hold W" % [1 + level, 2 + level]
		"lives": return "%d → %d lives / dive" % [1 + level, 2 + level]
		"blocks": return "%d → %d blocks / dive" % [3 + level, 4 + level]
	return ""
static func ore_shape(canvas: CanvasItem, center: Vector2, index: int, scale_value: float = 1.0, rotation: float = 0.0) -> void:
	var color := ore_color(index)
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
