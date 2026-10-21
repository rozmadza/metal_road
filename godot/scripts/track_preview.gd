extends Control
class_name TrackPreview

var config: TrackConfig


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_track(value: TrackConfig) -> void:
	config = value
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("11171a"), true)
	if config == null or config.centerline.size() < 3:
		return
	if config.background_texture != null:
		draw_texture_rect(config.background_texture, Rect2(Vector2.ZERO, size), true, config.background_modulate.lightened(0.18))
	var bounds := Rect2(config.centerline[0], Vector2.ZERO)
	for point in config.centerline: bounds = bounds.expand(point)
	var scale_factor := minf((size.x - 18.0) / maxf(bounds.size.x, 1.0), (size.y - 14.0) / maxf(bounds.size.y, 1.0))
	var offset := (size - bounds.size * scale_factor) * 0.5 - bounds.position * scale_factor
	var points := PackedVector2Array()
	for point in config.centerline: points.append(point * scale_factor + offset)
	points.append(points[0])
	draw_polyline(points, Color(0.035, 0.04, 0.042, 0.95), maxf(5.0, config.track_width * scale_factor + 4.0), true)
	draw_polyline(points, config.surface_tint, maxf(3.0, config.track_width * scale_factor), true)
	draw_circle(points[0], 3.5, config.finish_line_color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.63, 0.2, 0.65), false, 2.0)
