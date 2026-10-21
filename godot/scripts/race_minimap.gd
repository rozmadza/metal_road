extends Control
class_name RaceMinimap

var track: Track
var participants: Array[Vehicle] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func setup(value: Track, racers: Array[Vehicle]) -> void:
	track = value
	participants = racers
	queue_redraw()


func _process(_delta: float) -> void:
	if track != null:
		queue_redraw()


func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), panel)
	if track == null or track.config == null:
		return
	var bounds := track.get_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var inset := Rect2(12, 18, size.x - 24, size.y - 30)
	var scale_factor := minf(inset.size.x / bounds.size.x, inset.size.y / bounds.size.y)
	var drawn_size := bounds.size * scale_factor
	var origin := inset.position + (inset.size - drawn_size) * 0.5
	var route := PackedVector2Array()
	for point in track.config.centerline:
		route.append(origin + (point - bounds.position) * scale_factor)
	if route.size() > 1:
		draw_polyline(route + PackedVector2Array([route[0]]), Color(0.08, 0.07, 0.055, 0.95), 5.0, true)
		draw_polyline(route + PackedVector2Array([route[0]]), Color(0.73, 0.55, 0.24, 0.95), 1.5, true)
	for index in participants.size():
		var racer := participants[index]
		if not is_instance_valid(racer):
			continue
		var marker := origin + (racer.global_position - bounds.position) * scale_factor
		var color := Color("49d5e8") if index == 0 else Color("f2a63b")
		draw_circle(marker, 3.5 if index == 0 else 2.5, Color(0.02, 0.025, 0.028, 0.95))
		draw_circle(marker, 2.4 if index == 0 else 1.7, color)
	var font := get_theme_default_font()
	draw_string(font, Vector2(12, 14), "КАРТА ТРАССЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("b9b2a3"))


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.052, 0.88)
	style.border_color = Color(0.72, 0.53, 0.22, 0.9)
	style.border_width_left = 3
	style.border_width_bottom = 1
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	return style
