extends Node2D
class_name TireTracks
## A bounded, arena-local trail canvas shared by every combat vehicle.

@export_range(1.0, 30.0, 0.5) var lifetime := 3.0
@export_range(100, 5000, 50) var max_segments := 1800
@export_range(0.02, 0.25, 0.01) var sample_interval := 0.065
@export var min_speed := 10.0

var _segments: Array[Dictionary] = []
var _vehicle_state: Dictionary = {}
var _sample_elapsed := 0.0
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	_sample_elapsed += delta
	if _sample_elapsed >= sample_interval:
		_sample_elapsed = fmod(_sample_elapsed, sample_interval)
		_sample_vehicles()
	_prune_expired()
	queue_redraw()


func clear_tracks() -> void:
	_segments.clear()
	_vehicle_state.clear()
	queue_redraw()


func _sample_vehicles() -> void:
	var active_ids := {}
	for node in get_tree().get_nodes_in_group("combatants"):
		var vehicle := node as Vehicle
		if vehicle == null or not vehicle.alive or vehicle.config == null:
			continue
		var id := vehicle.get_instance_id()
		active_ids[id] = true
		if vehicle.get_speed() < min_speed:
			_vehicle_state.erase(id)
			continue

		var forward := Vector2.RIGHT.rotated(vehicle.global_rotation)
		var axle := vehicle.global_position - forward * vehicle.config.length * Vehicle.VISUAL_SCALE * 0.32
		var across := forward.rotated(PI * 0.5) * vehicle.config.width * Vehicle.VISUAL_SCALE * 0.42
		var left := to_local(axle + across)
		var right := to_local(axle - across)
		var previous: Dictionary = _vehicle_state.get(id, {})
		if not previous.is_empty():
			var travel: float = (left + right).distance_to(previous.left + previous.right) * 0.5
			if travel >= 1.5 and travel <= 28.0:
				var slip := clampf(absf(vehicle.get_lateral_speed()) / 70.0, 0.0, 1.0)
				var speed_factor := clampf(vehicle.get_speed() / 150.0, 0.0, 1.0)
				_segments.append({
					"left_from": previous.left,
					"left_to": left,
					"right_from": previous.right,
					"right_to": right,
					"born": _clock,
					"strength": 0.52 + speed_factor * 0.18 + slip * 0.24,
					"width": 2.5 + slip * 1.8,
				})
				while _segments.size() > max_segments:
					_segments.pop_front()
		_vehicle_state[id] = {"left": left, "right": right}

	for id in _vehicle_state.keys():
		if not active_ids.has(id):
			_vehicle_state.erase(id)


func _prune_expired() -> void:
	while not _segments.is_empty() and _clock - float(_segments[0].born) >= lifetime:
		_segments.pop_front()


func _draw() -> void:
	for segment in _segments:
		var age: float = _clock - float(segment.born)
		var fade := 1.0 - smoothstep(lifetime * 0.5, lifetime, age)
		var alpha: float = float(segment.strength) * fade
		var width: float = float(segment.width)
		var dark := Color(0.012, 0.009, 0.006, alpha)
		var wet_edge := Color(0.17, 0.105, 0.052, alpha * 0.3)
		draw_line(segment.left_from, segment.left_to, wet_edge, width + 1.4, true)
		draw_line(segment.right_from, segment.right_to, wet_edge, width + 1.4, true)
		draw_line(segment.left_from, segment.left_to, dark, width, true)
		draw_line(segment.right_from, segment.right_to, dark, width, true)
