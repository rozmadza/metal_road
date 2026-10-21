extends Control
class_name WeaponPreview

var weapon: WeaponConfig

func set_weapon(value: WeaponConfig) -> void:
	weapon = value
	queue_redraw()

func _draw() -> void:
	if weapon == null: return
	var center := size * 0.5
	var color := Color("#f2b84b")
	var dark := Color("#20262c")
	draw_line(center - Vector2(95, 0), center + Vector2(95, 0), Color(0.18, 0.2, 0.22, 0.8), 2)
	if weapon.display_name == "ДРОБОВИК":
		draw_rect(Rect2(center - Vector2(28, 12), Vector2(36, 24)), dark, true)
		draw_line(center + Vector2(8, -6), center + Vector2(72, -6), color, 5)
		draw_line(center + Vector2(8, 6), center + Vector2(72, 6), color, 5)
	elif weapon.display_name == "ТЯЖЁЛЫЙ ПУЛЕМЁТ":
		draw_rect(Rect2(center - Vector2(24, 16), Vector2(32, 32)), dark, true)
		draw_rect(Rect2(center + Vector2(8, -9), Vector2(68, 18)), color, true)
		draw_circle(center + Vector2(76, 0), 6, Color("#e85c3c"))
	else:
		draw_rect(Rect2(center - Vector2(24, 11), Vector2(30, 22)), dark, true)
		draw_rect(Rect2(center + Vector2(5, -4), Vector2(78, 8)), color, true)
		draw_circle(center + Vector2(88, 0), 4, Color("#5fe3e8"))
