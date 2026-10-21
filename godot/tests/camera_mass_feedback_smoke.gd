extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CAMERA MASS FEEDBACK FAIL: ", label)


func run() -> void:
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	var camera := FollowCamera.new()
	camera.target = vehicle
	camera.use_track_limits = false
	root.add_child(camera)
	vehicle.linear_velocity = Vector2(vehicle.config.max_speed, 0.0)
	for _frame in 45:
		camera._process(1.0 / 60.0)
	check(camera.zoom.x < camera.resting_zoom and camera.zoom.x >= camera.maximum_speed_zoom - 0.02, "camera widens smoothly at speed")
	check((camera.global_position - vehicle.global_position).dot(Vector2.RIGHT) > 45.0, "camera reveals road in the direction of travel")
	check(camera.offset.length() < 0.01, "high speed does not continuously vibrate the camera")
	check(Vehicle.VISUAL_SCALE > 1.6, "cars have increased on-screen presence")

	AccessibilitySettings.screen_shake = 1.0
	camera.shake(40.0, 0.5)
	camera._process(1.0 / 60.0)
	check(camera.offset.length() <= 2.0, "impact shake is comfort-capped")
	check(camera._shake_time <= 0.1, "impact shake is brief")
	camera.snap_to_target()
	camera.kick(Vector2.RIGHT, 30.0)
	camera._process(1.0 / 60.0)
	check(camera.offset.length() <= 3.01, "directional kick is comfort-capped")
	AccessibilitySettings.screen_shake = 0.0
	camera.snap_to_target()
	camera.shake(40.0, 0.5)
	camera.kick(Vector2.RIGHT, 30.0)
	camera._process(1.0 / 60.0)
	check(camera.offset.length() < 0.01, "zero shake setting disables all camera impulses")

	var impact_values := {"light": 0.0, "heavy": 0.0}
	vehicle.impacted.connect(func(value: float): impact_values.light = value)
	vehicle._emit_impact_feedback(120.0)
	var heavy := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	heavy.config = load("res://resources/vehicles/behemoth.tres")
	root.add_child(heavy)
	heavy.impacted.connect(func(value: float): impact_values.heavy = value)
	heavy._emit_impact_feedback(120.0)
	check(float(impact_values.heavy) > float(impact_values.light), "heavy chassis produces stronger impact feedback at equal speed")

	vehicle.free()
	heavy.free()
	camera.free()
	print("CAMERA MASS FEEDBACK: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
