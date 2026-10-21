extends RefCounted
class_name RaceProgress
## Per-racer progress along existing Track geometry. No independent track shape.
var track: Track
var entries: Dictionary = {}

func reset(track_ref: Track, racers: Array[Vehicle]) -> void:
	track = track_ref
	entries.clear()
	for car in racers:
		var p := track.get_progress_along_track(car.global_position)
		entries[car] = {"laps": 0, "progress": p, "projection": p,
			"position": car.global_position, "travelled": 0.0, "checkpoint": 1}

func advance(car: Vehicle, delta: float) -> bool:
	var e: Dictionary = entries[car]
	var point := car.global_position
	var previous: Vector2 = e.position
	var p := track.get_progress_along_track(point)
	var length := track.get_total_length()
	var step := wrapf(p - float(e.projection), -length * 0.5, length * 0.5)
	var motion := point - previous
	var allowed := maxf(track.config.progress_step_tolerance, car.config.max_speed * delta * 2.0)
	var on_track: bool = track.get_closest_segment(point).distance <= track.half_width + track.config.progress_edge_margin
	var was_on_track: bool = track.get_closest_segment(previous).distance <= track.half_width + track.config.progress_edge_margin
	e.position = point
	if not on_track or not was_on_track or motion.length() > allowed or absf(step) > allowed:
		# Invalidate the partial lap after a discontinuity/off-track shortcut.
		e.travelled = 0.0
		e.checkpoint = 1
		return false
	e.projection = p
	e.progress = p
	e.travelled += step
	if step > 0:
		while int(e.checkpoint) <= 3:
			var checkpoint := length * float(e.checkpoint) / 4.0
			if p < checkpoint or p - step > checkpoint: break
			e.checkpoint += 1
			car.notify_clean_corner()
	var before_side := (previous - track.finish_point).dot(track.finish_tangent)
	var after_side := (point - track.finish_point).dot(track.finish_tangent)
	var forward_cross := before_side < 0 and after_side >= 0 and motion.dot(track.finish_tangent) > 0
	if forward_cross and e.checkpoint == 4 and e.travelled >= length * track.config.minimum_lap_fraction:
		var intersection: Variant = Geometry2D.segment_intersects_segment(previous, point, track.finish_line_start, track.finish_line_end)
		if intersection != null:
			e.laps += 1
			e.progress = p
			e.travelled = p
			e.checkpoint = 1
			return int(e.laps) >= track.config.laps
	return false

func laps(car: Vehicle) -> int:
	return int(entries[car].laps)

func total_progress(car: Vehicle) -> float:
	var e: Dictionary = entries[car]
	return float(e.laps) * track.get_total_length() + float(e.progress)
