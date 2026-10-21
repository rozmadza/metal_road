extends Control
class_name SpeedFX

var player: Vehicle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.config == null:
		return
	var ratio := clampf(player.get_speed() / maxf(player.get_current_max_speed(), 1.0), 0.0, 1.0)
	var strength := smoothstep(0.55, 1.0, ratio)
	if strength <= 0.01:
		return
	var center := size * 0.5
	var radius := maxf(size.x, size.y) * 0.43
	for index in 28:
		var angle := TAU * float(index) / 28.0 + sin(float(index) * 7.13) * 0.08
		var direction := Vector2(cos(angle), sin(angle))
		var start := center + direction * radius
		var length := (12.0 + float(index % 5) * 5.0) * strength
		draw_line(start, start + direction * length, Color(0.92, 0.69, 0.31, 0.18 * strength), 1.2, true)
