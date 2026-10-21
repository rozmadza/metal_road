extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("TIRE TRACKS FAIL: ", label)


func run() -> void:
	var canvas := TireTracks.new()
	root.add_child(canvas)
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	vehicle.add_to_group("combatants")
	vehicle.global_position = Vector2(100, 100)
	vehicle.linear_velocity = Vector2(90, 0)
	canvas._sample_vehicles()
	vehicle.global_position = Vector2(110, 100)
	canvas._clock += canvas.sample_interval
	canvas._sample_vehicles()
	check(canvas._segments.size() == 1, "moving vehicle leaves one paired segment")
	canvas._clock += canvas.lifetime + 0.1
	canvas._prune_expired()
	check(canvas._segments.is_empty(), "expired segments are removed")
	canvas.clear_tracks()
	check(canvas._vehicle_state.is_empty(), "clear resets vehicle sampling state")
	vehicle.free()
	canvas.free()
	print("TIRE TRACKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
