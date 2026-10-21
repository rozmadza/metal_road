extends SceneTree
## Headless smoke test for Track geometry and queries.

var _track: Track
var _frames := 0


func _initialize() -> void:
	_track = Track.new()
	_track.config = load("res://resources/iron_circuit.tres")
	root.add_child(_track)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false

	var failures := 0
	failures += _check(_track.outer_boundary.size() >= _track.config.centerline.size(), "outer boundary count")
	failures += _check(_track.inner_boundary.size() >= _track.config.centerline.size(), "inner boundary count")
	failures += _check(_track.total_length > 0.0, "total length")
	failures += _check(_track.get_total_length() == _track.total_length, "total length accessor")
	failures += _check(_track.waypoints.size() == _track.config.centerline.size(), "waypoints")
	failures += _check(_track.finish_tangent.length() > 0.99, "finish tangent")
	failures += _check(_track.is_point_on_track(_track.get_start_position()), "start on track")
	var start_grid := _track.get_start_grid(6)
	failures += _check(start_grid.size() == 6, "six safe start slots")
	for index in start_grid.size():
		var start_distance: float = _track.get_closest_segment(start_grid[index])["distance"]
		failures += _check(start_distance <= _track.half_width - 24.0, "start slot %d has edge clearance" % index)

	var info := _track.get_closest_segment(_track.get_start_position())
	failures += _check(info["distance"] < 0.001, "start projects onto centerline")
	var progress := _track.get_progress_along_track(_track.get_start_position())
	failures += _check(progress < 1.0, "start progress ~0")

	var max_err := 0.0
	for boundary in [_track.inner_boundary, _track.outer_boundary]:
		for p in boundary:
			var d: float = _track.get_closest_segment(p)["distance"]
			max_err = maxf(max_err, absf(d - _track.half_width))
	failures += _check(max_err < 8.0, "smoothed boundaries follow half width (err=%.3f)" % max_err)
	failures += _check(_track.inner_boundary.size() >= _track.config.centerline.size(), "inner boundary has corner arcs")
	failures += _check(_track.outer_boundary.size() >= _track.config.centerline.size(), "outer boundary has corner arcs")

	print("TRACK: %d failures" % failures)
	print("TRACK: %s" % ("PASS" if failures == 0 else "FAIL"))
	_track.free()
	quit(0 if failures == 0 else 1)
	return true


func _check(condition: bool, label: String) -> int:
	if not condition:
		print("TRACK FAIL: ", label)
		return 1
	return 0
