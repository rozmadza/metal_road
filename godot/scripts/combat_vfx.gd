extends Node2D
class_name CombatVFX
## Shared transient world-space effects for all weapons and destructibles.

var events: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("combat_vfx")
	set_process(false)


func _process(delta: float) -> void:
	for event in events:
		event.time = float(event.time) - delta
	events = events.filter(func(event: Dictionary): return float(event.time) > 0.0)
	queue_redraw()
	if events.is_empty(): set_process(false)


func spawn_explosion(world_position: Vector2, color: Color = Color(1.0, 0.4, 0.08), radius: float = 80.0) -> void:
	_trim_events()
	events.append({"kind": &"explosion", "position": world_position, "color": color, "radius": radius, "time": 0.48, "duration": 0.48})
	set_process(true)


func spawn_impact(world_position: Vector2, color: Color = Color(1.0, 0.78, 0.25)) -> void:
	_trim_events()
	events.append({"kind": &"impact", "position": world_position, "color": color, "radius": 28.0, "time": 0.24, "duration": 0.24})
	set_process(true)


func spawn_pickup(world_position: Vector2, color: Color = Color(0.25, 0.92, 1.0)) -> void:
	_trim_events()
	events.append({"kind": &"pickup", "position": world_position, "color": color, "radius": 54.0, "time": 0.55, "duration": 0.55})
	set_process(true)

func _trim_events() -> void:
	if events.size() >= 48:
		events.pop_front()


func _draw() -> void:
	for event in events:
		var life := clampf(float(event.time) / float(event.duration), 0.0, 1.0)
		var progress := 1.0 - life
		var center: Vector2 = event.position
		var color: Color = event.color
		var radius: float = event.radius
		match event.kind:
			&"explosion":
				draw_circle(center, radius * (0.12 + progress * 0.62), Color(0.16, 0.08, 0.035, life * 0.42))
				draw_circle(center + Vector2(-radius * 0.12, radius * 0.05), radius * (0.14 + progress * 0.25), Color(color, life * 0.3))
				draw_circle(center + Vector2(radius * 0.1, -radius * 0.08), radius * (0.1 + progress * 0.18), Color(1.0, 0.76, 0.23, life * 0.42))
				draw_arc(center, radius * (0.22 + progress * 0.78), 0, TAU, 30, Color(1.0, 0.76, 0.28, life * 0.85), 4.0 * life + 1.0, true)
				for spark_index in 11:
					var angle := float(spark_index) * 2.399 + sin(float(spark_index) * 4.17) * 0.24
					var direction := Vector2.RIGHT.rotated(angle)
					var spark_length := radius * (0.35 + fmod(float(spark_index) * 0.37, 0.45))
					var start := center + direction * radius * progress * 0.18
					draw_line(start, center + direction * spark_length * (0.35 + progress * 0.65), Color(color, life), 2.2 * life + 0.8, true)
			&"impact":
				for spark_index in 7:
					var direction := Vector2.RIGHT.rotated(float(spark_index) * 2.17)
					draw_line(center + direction * 3.0, center + direction * radius * progress, Color(color, life), 2.0, true)
			&"pickup":
				draw_arc(center, radius * (0.4 + progress * 0.8), 0, TAU, 28, Color(color, life * 0.9), 3.0, true)
				draw_arc(center, radius * (0.25 + progress * 0.48), _process_angle(progress), _process_angle(progress) + PI * 1.35, 20, Color(1, 1, 1, life), 2.0, true)


func _process_angle(progress: float) -> float:
	return progress * TAU * 1.7
