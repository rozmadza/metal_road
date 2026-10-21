extends Control
class_name CinematicFX
## Lightweight full-screen post effect used by both race and arena HUDs.
## It deliberately uses draw calls instead of a full-screen shader so it stays
## inexpensive on integrated GPUs and remains resolution independent.

var player: Vehicle
var damage_flash := 0.0
var explosion_flash := 0.0
var pickup_flash := 0.0
var emp_flash := 0.0
var finish_amount := 0.0
var pickup_color := Color(0.35, 0.9, 1.0)
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	damage_flash = maxf(0.0, damage_flash - delta * 2.8)
	explosion_flash = maxf(0.0, explosion_flash - delta * 4.2)
	pickup_flash = maxf(0.0, pickup_flash - delta * 2.4)
	emp_flash = maxf(0.0, emp_flash - delta * 1.7)
	queue_redraw()


func flash_damage(amount: float = 1.0) -> void:
	var reduction := 0.35 if AccessibilitySettings.reduced_flashes else 1.0
	damage_flash = maxf(damage_flash, clampf(0.24 + amount * 0.018, 0.3, 1.0) * reduction)


func flash_explosion() -> void:
	explosion_flash = 0.3 if AccessibilitySettings.reduced_flashes else 1.0


func flash_pickup(color: Color = Color(0.35, 0.9, 1.0)) -> void:
	pickup_color = color
	pickup_flash = 1.0


func pulse_emp() -> void:
	emp_flash = 0.22 if AccessibilitySettings.reduced_flashes else 1.0


func set_finish_cinematic(enabled: bool) -> void:
	var tween := create_tween()
	tween.tween_property(self, "finish_amount", 1.0 if enabled else 0.0, 0.38).set_trans(Tween.TRANS_QUAD)


func reset() -> void:
	damage_flash = 0.0
	explosion_flash = 0.0
	pickup_flash = 0.0
	emp_flash = 0.0
	finish_amount = 0.0
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	if bounds.size.x <= 1.0:
		return
	var speed_ratio := 0.0
	var health_ratio := 1.0
	if is_instance_valid(player) and player.config != null:
		speed_ratio = clampf(player.get_speed() / maxf(player.get_current_max_speed(), 1.0), 0.0, 1.0)
		health_ratio = clampf(player.health / maxf(player.config.max_health, 1.0), 0.0, 1.0)
	var vignette := (0.1 if AccessibilitySettings.high_contrast else 0.06) + maxf(0.0, speed_ratio - 0.55) * 0.16 + pow(1.0 - health_ratio, 2.0) * 0.38
	_draw_vignette(bounds, vignette, Color(0.02, 0.025, 0.03))
	if damage_flash > 0.0:
		_draw_vignette(bounds, damage_flash * 0.48, Color(0.72, 0.04, 0.02))
	if pickup_flash > 0.0:
		_draw_vignette(bounds, pickup_flash * 0.32, pickup_color)
	if explosion_flash > 0.0:
		draw_rect(bounds, Color(1.0, 0.62, 0.23, explosion_flash * 0.22), true)
	var emp_amount := emp_flash
	if is_instance_valid(player) and player.is_emp_disabled():
		emp_amount = maxf(emp_amount, 0.34)
	if emp_amount > 0.0:
		var alpha := emp_amount * (0.09 + absf(sin(_time * 46.0)) * 0.12)
		for line_index in 9:
			var y := fmod(float(line_index) * 83.0 + _time * 210.0, size.y)
			draw_rect(Rect2(0.0, y, size.x, 2.0 + float(line_index % 3)), Color(0.1, 0.9, 1.0, alpha), true)
	if finish_amount > 0.001:
		var bar_height := size.y * 0.085 * finish_amount
		draw_rect(Rect2(0, 0, size.x, bar_height), Color(0.01, 0.01, 0.012, 0.94), true)
		draw_rect(Rect2(0, size.y - bar_height, size.x, bar_height), Color(0.01, 0.01, 0.012, 0.94), true)


func _draw_vignette(bounds: Rect2, strength: float, color: Color) -> void:
	var thickness := minf(bounds.size.x, bounds.size.y) * 0.12
	for layer in 4:
		var inset := float(layer) * thickness * 0.25
		var alpha := strength * (0.34 - float(layer) * 0.065)
		var c := Color(color.r, color.g, color.b, maxf(alpha, 0.0))
		draw_rect(Rect2(inset, inset, bounds.size.x - inset * 2.0, thickness * 0.3), c, true)
		draw_rect(Rect2(inset, bounds.size.y - inset - thickness * 0.3, bounds.size.x - inset * 2.0, thickness * 0.3), c, true)
		draw_rect(Rect2(inset, inset, thickness * 0.3, bounds.size.y - inset * 2.0), c, true)
		draw_rect(Rect2(bounds.size.x - inset - thickness * 0.3, inset, thickness * 0.3, bounds.size.y - inset * 2.0), c, true)
