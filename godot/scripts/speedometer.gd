extends Control
class_name Speedometer

const START_ANGLE := 2.36
const END_ANGLE := 7.07
const TICK_COUNT := 10

var current_speed := 0.0
var numeric_mode := false
var maximum_speed := 300.0
var text := "СКОРОСТЬ\n000"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_speed(value: float, maximum: float) -> void:
	current_speed = maxf(value, 0.0)
	maximum_speed = maxf(maximum, 1.0)
	text = "СКОРОСТЬ\n%03d" % roundi(current_speed)
	queue_redraw()

func _draw() -> void:
	if numeric_mode:
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, 11), "СКОРОСТЬ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#aeb9bd"))
		draw_string(font, Vector2(0, 38), "%03d" % roundi(current_speed), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color("#f1f4f4"))
		draw_string(font, Vector2(0, 51), "КМ/Ч", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#65d8e6"))
		return
	var gauge_size := minf(size.x, size.y * 1.48)
	var radius := clampf(gauge_size * 0.34, 24.0, 42.0)
	var center := Vector2(size.x * 0.5, size.y * 0.59)
	var ratio := clampf(current_speed / maximum_speed, 0.0, 1.0)
	var needle_angle := lerpf(START_ANGLE, END_ANGLE, ratio)

	draw_arc(center, radius + 5.0, START_ANGLE, END_ANGLE, 40, Color("#283039"), 7.0, true)
	if ratio > 0.001:
		var arc_color := Color("#49d5e8") if ratio < 0.72 else Color("#ffb52e")
		draw_arc(center, radius + 5.0, START_ANGLE, needle_angle, 32, arc_color, 7.0, true)

	for index in range(TICK_COUNT + 1):
		var tick_ratio := float(index) / TICK_COUNT
		var angle := lerpf(START_ANGLE, END_ANGLE, tick_ratio)
		var direction := Vector2(cos(angle), sin(angle))
		var length := 7.0 if index % 2 == 0 else 4.0
		var color := Color("#f3b33e") if tick_ratio >= 0.8 else Color("#9ca7ad")
		draw_line(center + direction * (radius - length), center + direction * radius, color, 2.0, true)

	var needle := Vector2(cos(needle_angle), sin(needle_angle))
	draw_line(center - needle * 5.0, center + needle * (radius - 10.0), Color("#ffb52e"), 3.0, true)
	draw_circle(center, 5.0, Color("#151a1e"))
	draw_circle(center, 2.5, Color("#f6c65a"))

	var font := get_theme_default_font()
	draw_string(font, Vector2(0, 13), "СКОРОСТЬ", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color("#aeb9bd"))
	draw_string(font, Vector2(0, center.y + 8), "%03d" % roundi(current_speed), HORIZONTAL_ALIGNMENT_CENTER, size.x, 19, Color("#f1f4f4"))
	draw_string(font, Vector2(0, size.y - 3), "КМ/Ч", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, Color("#65d8e6"))
