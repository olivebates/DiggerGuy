extends Node2D

var results: Node

func _draw() -> void:
	if is_instance_valid(results) and results.visible and not results.report.is_empty():
		results.draw_pixel_graphics(self)
