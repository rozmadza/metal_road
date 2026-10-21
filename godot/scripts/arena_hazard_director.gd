extends Node2D
class_name ArenaHazardDirector

signal hazard_announced(text: String)
signal hazard_triggered(text: String)

var config: ArenaConfig
var _clock := 8.0
var _warning := false
var _active_time := 0.0
var _hazard_center := Vector2.ZERO
var _hazard_rect := Rect2()
var _rng := RandomNumberGenerator.new()

func setup(value: ArenaConfig, seed_value: int = 0) -> void:
	config = value
	_rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	_clock = maxf(5.0, config.hazard_interval * 0.55)
	queue_redraw()

func _process(delta: float) -> void:
	if config == null or config.mechanic_id == &"": return
	if _active_time > 0.0:
		_active_time -= delta
		queue_redraw()
	_clock -= delta
	if _clock > 0.0: return
	if not _warning:
		_warning = true
		_clock = 2.2
		_pick_hazard()
		hazard_announced.emit(config.mechanic_label)
	else:
		_warning = false
		_clock = config.hazard_interval
		_active_time = 1.4
		_trigger_hazard()
		hazard_triggered.emit(config.mechanic_label)
	queue_redraw()

func apply_surface_to(vehicle: Vehicle) -> void:
	if vehicle == null or config == null: return
	var grip := 1.0
	if config.mechanic_id == &"flood" and (_warning or _active_time > 0.0):
		grip = 0.68 if _active_time > 0.0 else 0.84
	vehicle.set_surface_modifier(grip, grip, self)

func _pick_hazard() -> void:
	match config.mechanic_id:
		&"press":
			var vertical := _rng.randf() > 0.5
			if vertical:
				var x := _rng.randf_range(180.0, config.size.x - 180.0)
				_hazard_rect = Rect2(x - 70.0, 0.0, 140.0, config.size.y)
			else:
				var y := _rng.randf_range(150.0, config.size.y - 150.0)
				_hazard_rect = Rect2(0.0, y - 65.0, config.size.x, 130.0)
		&"rockfall":
			_hazard_center = Vector2(_rng.randf_range(150.0, config.size.x - 150.0), _rng.randf_range(140.0, config.size.y - 140.0))
		&"flood":
			_hazard_rect = Rect2(0, 0, config.size.x, config.size.y)

func _trigger_hazard() -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or not vehicle.alive: continue
		match config.mechanic_id:
			&"press":
				if _hazard_rect.has_point(vehicle.global_position): vehicle.take_damage(28.0, &"body")
			&"rockfall":
				if vehicle.global_position.distance_to(_hazard_center) <= 125.0: vehicle.take_damage(34.0, &"body")

func _draw() -> void:
	if config == null or (not _warning and _active_time <= 0.0): return
	var pulse := 0.35 + sin(Time.get_ticks_msec() * 0.012) * 0.12
	var color := Color(1.0, 0.22, 0.06, 0.48 if _active_time > 0.0 else pulse)
	match config.mechanic_id:
		&"press", &"flood":
			draw_rect(_hazard_rect, Color(color, color.a * 0.28), true)
			draw_rect(_hazard_rect, color, false, 5.0)
		&"rockfall":
			draw_circle(_hazard_center, 125.0, Color(color, color.a * 0.22))
			draw_arc(_hazard_center, 125.0, 0, TAU, 48, color, 5.0, true)
			for i in 8:
				var angle := TAU * float(i) / 8.0
				draw_line(_hazard_center + Vector2.RIGHT.rotated(angle) * 35.0, _hazard_center + Vector2.RIGHT.rotated(angle) * 105.0, color, 3.0)
