extends Area2D
class_name OilSpot

const OIL_TEXTURE := preload("res://assets/environment/arena/oil_spill.png")

@export_range(0.1, 1.0, 0.01) var traction_multiplier := 0.38
@export_range(0.1, 1.0, 0.01) var steering_multiplier := 0.72
@export var radius := Vector2(66.0, 34.0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("oil_spots")
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	var vehicle := body as Vehicle
	if vehicle != null:
		vehicle.set_surface_modifier(traction_multiplier, steering_multiplier, self)

func _on_body_exited(body: Node) -> void:
	var vehicle := body as Vehicle
	if vehicle != null:
		vehicle.clear_surface_modifier(self)

func _draw() -> void:
	draw_texture_rect(OIL_TEXTURE, Rect2(-radius, radius * 2.0), false)
