extends Area2D
class_name SpikeStrip

const SPIKE_TEXTURE := preload("res://assets/environment/arena/spike_strip.png")

@export var wheel_damage: float = 28.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("spike_strips")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	var vehicle := body as Vehicle
	if vehicle != null and vehicle.alive:
		vehicle.take_damage(wheel_damage, &"wheels", self)

func _draw() -> void:
	draw_texture_rect(SPIKE_TEXTURE, Rect2(-42, -14, 84, 28), false)
