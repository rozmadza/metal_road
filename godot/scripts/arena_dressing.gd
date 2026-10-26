extends Node2D
## Cached ground paint and wear: no collision or navigation cost.
var config: ArenaConfig

class SignalLamps extends Node2D:
	var arena_size := Vector2.ZERO
	var clock := 0.0
	var phase := false
	func _process(delta: float) -> void:
		clock += delta
		if clock >= 0.4:
			clock = 0.0
			phase = not phase
			queue_redraw()
	func _draw() -> void:
		for side in 2:
			for index in 9:
				var p := Vector2(35 + index * (arena_size.x - 70) / 8.0, -9 if side == 0 else arena_size.y + 9)
				draw_circle(p, 6, Color(0.9, 0.45, 0.08, 0.08))
				draw_circle(p, 2.2, Color(1, 0.63, 0.2, 0.9 if phase == bool(index % 2) else 0.35))

func _ready() -> void:
	z_index = -12
	modulate.a = config.dressing_opacity
	var lamps := SignalLamps.new()
	lamps.name = "PerimeterSignals"
	lamps.arena_size = config.size
	lamps.z_index = 13
	add_child(lamps)

func _draw() -> void:
	var paint := Color(0.71, 0.61, 0.39, 0.32)
	var dark := Color(0.035, 0.028, 0.02, 0.2)
	var center := config.obstacles[0].get_center() if not config.obstacles.is_empty() else config.size * 0.5
	var container_pad := config.obstacles[1].merge(config.obstacles[2]).grow(15) if config.obstacles.size() >= 3 else Rect2()
	for point in config.crates: container_pad = container_pad.merge(Rect2(point-Vector2(20,20),Vector2(40,40)))
	var danger_pad := config.obstacles[3] if config.obstacles.size() >= 4 else Rect2()
	for point in config.explosive_barrels: danger_pad = danger_pad.merge(Rect2(point-Vector2(18,18),Vector2(36,36)))
	# Match the authored OilSpot ellipse (66x34 radii), not a square placeholder.
	for point in config.oil_spots: danger_pad = danger_pad.merge(Rect2(point-Vector2(66,34),Vector2(132,68)))
	danger_pad = danger_pad.grow(15)
	# The center ring and cluster pads visually connect cover to the floor.
	draw_arc(center, 112, 0, TAU, 64, Color(paint, 0.16), 14, true)
	for quadrant in 4:
		var angle := quadrant * PI * 0.5 + 0.12
		draw_arc(center, 122, angle, angle + 0.65, 12, paint, 2, true)
	_pad(container_pad, paint)
	_pad(danger_pad, Color(0.9, 0.47, 0.15, 0.35))
	for index in int(danger_pad.size.x / 18):
		var x := danger_pad.position.x + 4 + index * 18
		draw_line(Vector2(x, danger_pad.end.y), Vector2(x + 10, danger_pad.end.y + 12), Color(0.88, 0.53, 0.14, 0.3), 5, true)
	# Open maneuver lane: quiet broken paint, no new physical objects.
	for index in int((config.size.x - 200) / 68):
		var x := 100.0 + index * 68
		draw_line(Vector2(x, config.maneuver_lane_y), Vector2(x + 28, config.maneuver_lane_y), Color(paint, 0.2), 2, true)
	for point in config.spike_strip_positions:
		_pad(Rect2(point-Vector2(52,24),Vector2(104,48)),Color(0.85,0.49,0.17,0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4217
	for index in int(config.size.x * config.size.y / 25000):
		var stain_center := Vector2(rng.randf_range(60, config.size.x-60), rng.randf_range(100, config.size.y-80))
		var size := Vector2(rng.randf_range(10, 30), rng.randf_range(3, 9))
		var points := PackedVector2Array()
		for vertex in 12:
			var angle := TAU * vertex / 12.0
			points.append(stain_center + Vector2(cos(angle), sin(angle)) * size * rng.randf_range(0.7, 1.0))
		draw_colored_polygon(points, dark)
	# Paired skid arcs around the anchor and across the lower approach.
	for radius in [145.0, 154.0, 240.0, 249.0]:
		draw_arc(center-Vector2(0,10), radius, 0.2, 2.75, 42, Color(0.025, 0.023, 0.02, 0.2), 3, true)
	for index in config.supply_hotspots.size():
		var p := config.supply_hotspots[index]
		draw_circle(p, 28, Color(0.04, 0.10, 0.11, 0.24))
		draw_arc(p, 32, 0.15, TAU - 0.15, 32, Color(0.4, 0.68, 0.68, 0.45), 2, true)
		for side in [-1, 1]:
			draw_line(p + Vector2(side * 38, -12), p + Vector2(side * 38, 12), paint, 3, true)
	# Reinforced wall segments occupy the existing boundary, never the driving lane.
	for index in 20:
		var x := index * config.size.x / 20.0
		for y in [-18.0, config.size.y + 2]:
			draw_rect(Rect2(x + 2, y, config.size.x / 20.0 - 4, 16), Color(0.24, 0.25, 0.24, 0.9))
			draw_line(Vector2(x + 12, y + 3), Vector2(x + 20, y + 13), paint, 3)
	for index in 16:
		var y := index * config.size.y / 16.0
		for x in [-18.0, config.size.x + 2]:
			draw_rect(Rect2(x, y + 2, 16, config.size.y / 16.0 - 4), Color(0.24, 0.25, 0.24, 0.9))

func _pad(rect: Rect2, paint: Color) -> void:
	draw_rect(rect, Color(0.035, 0.03, 0.025, 0.13))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction: Vector2 = (rect.get_center() - corner).sign()
		draw_line(corner, corner + Vector2(direction.x * 22, 0), paint, 2, true)
		draw_line(corner, corner + Vector2(0, direction.y * 22), paint, 2, true)
