extends Node2D

func _draw() -> void:
	for index in range(MineInk.ICONS.size()):
		for variant in range(MineInk.ICON_VARIANTS):
			var cell := index * MineInk.ICON_VARIANTS + variant
			var center := Vector2((cell % 16) * 16 + 8, (cell / 16) * 16 + 8)
			# Rasterize vectors once at native resolution, then display each texel as 2x2.
			MineInk.vector_icon(self, MineInk.ICONS[index], center, Color.WHITE, (variant + 4) / 16.0)
