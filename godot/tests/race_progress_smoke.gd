extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RACE PROGRESS FAIL: ", label)

func point_at(track: Track, distance: float) -> Vector2:
	var remaining := fposmod(distance, track.get_total_length())
	for i in track.segment_lengths.size():
		if remaining <= track.segment_lengths[i]:
			return track.segments[i] + track.segment_tangents[i] * remaining
		remaining -= track.segment_lengths[i]
	return track.finish_point

func run() -> void:
	var track: Track = load("res://scenes/Track.tscn").instantiate()
	root.add_child(track)
	var car: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(car)
	car.freeze = true
	car.position = track.finish_point
	var tracker := RaceProgress.new()
	var racers: Array[Vehicle] = [car]
	tracker.reset(track, racers)
	var length := track.get_total_length()
	# Reverse full lap and repeatedly oscillate across the start.
	for i in range(1, 201):
		car.position = point_at(track, -length * i / 200.0)
		tracker.advance(car, 1.0 / 60)
	check(tracker.laps(car) == 0, "reverse lap ignored")
	car.position = track.finish_point
	tracker.reset(track, racers)
	for i in range(20):
		car.position = point_at(track, -5)
		tracker.advance(car, 1.0 / 60)
		car.position = point_at(track, 5)
		tracker.advance(car, 1.0 / 60)
	check(tracker.laps(car) == 0, "finish oscillation ignored")
	check(tracker.total_progress(car) < 20, "reverse wrap does not inflate rank")
	car.position = track.finish_point
	tracker.reset(track, racers)
	var finished := false
	for lap in range(3):
		for i in range(1, 201):
			car.position = point_at(track, length * i / 200.0 + 0.1)
			finished = tracker.advance(car, 1.0 / 60) or finished
		check(tracker.laps(car) == lap + 1, "lap %d increments" % (lap + 1))
		check(finished == (lap == 2), "finish only after final lap")
	car.position = track.finish_point
	tracker.reset(track, racers)
	# Teleport directly to the far end then cross forward: invalid partial lap.
	car.position = point_at(track, length - 5)
	tracker.advance(car, 1.0 / 60)
	car.position = point_at(track, 5)
	tracker.advance(car, 1.0 / 60)
	check(tracker.laps(car) == 0, "shortcut ignored")
	car.free()
	track.free()
	print("RACE PROGRESS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
