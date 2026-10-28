extends Node2D

var depot: Node

func _draw() -> void:
	if is_instance_valid(depot) and depot.visible:
		depot.draw_miner_graphics(self)
