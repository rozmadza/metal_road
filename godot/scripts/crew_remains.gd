extends Node2D
class_name CrewRemains
## Persistent, non-colliding aftermath marker for a crushed fleeing crew member.

const FALLEN_TEXTURE := preload("res://assets/characters/crew/fallen_crew.png")

var role: EscapingCrew.Role = EscapingCrew.Role.PILOT


func setup(value_role: EscapingCrew.Role) -> void:
	role = value_role


func _ready() -> void:
	add_to_group("crew_remains")
	# Stay above the arena floor, but below cars from the first rendered frame.
	z_index = -1
	var body := Sprite2D.new()
	body.name = "FallenCrew"
	body.texture = FALLEN_TEXTURE
	body.scale = Vector2.ONE * 0.029
	body.rotation = randf_range(-0.16, 0.16)
	body.modulate = Color.WHITE if role == EscapingCrew.Role.PILOT else Color(0.82, 0.88, 0.78)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(body)
	queue_redraw()


func _draw() -> void:
	# Layered uneven circles read as soaked ground rather than a clean vector UI
	# disk. The corpse sprite sits above this stain.
	draw_circle(Vector2(2, 3), 16.0, Color(0.29, 0.012, 0.012, 0.72))
	draw_circle(Vector2(-11, 7), 8.5, Color(0.38, 0.018, 0.012, 0.62))
	draw_circle(Vector2(13, -5), 7.0, Color(0.24, 0.008, 0.008, 0.58))
	draw_circle(Vector2(-18, -3), 3.5, Color(0.42, 0.02, 0.014, 0.5))
