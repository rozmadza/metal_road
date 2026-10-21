extends Area2D
class_name SandDrift

const TEXTURE := preload("res://assets/environment/frontier/frontier_ground.png")
@export var radius := Vector2(78, 34)
@export_range(0.1, 1.0, 0.01) var traction := 0.52
@export_range(0.1, 1.0, 0.01) var steering := 0.64

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var ellipse := CapsuleShape2D.new()
	ellipse.radius = radius.y
	ellipse.height = radius.x * 2.0
	shape.shape = ellipse
	shape.rotation = PI * 0.5
	add_child(shape)
	body_entered.connect(func(body):
		if body is Vehicle: body.set_surface_modifier(traction, steering, self))
	body_exited.connect(func(body):
		if body is Vehicle: body.clear_surface_modifier(self))
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-radius, radius * 2.0)
	draw_texture_rect(TEXTURE, rect, false, Color(0.82, 0.63, 0.38, 0.9))
	draw_arc(Vector2.ZERO, radius.x * 0.72, 0, TAU, 48, Color(0.9,0.66,0.31,0.5), 2.0)
