extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var readout: VehicleReadout = load("res://scenes/VehicleReadout.tscn").instantiate()
	root.add_child(readout)
	var vehicle: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(vehicle)
	await process_frame
	vehicle.linear_velocity = Vector2(128, 0)
	readout.update_vehicle(vehicle)
	check("128" in readout.speed.text, "digital speed follows vehicle")
	check(is_equal_approx(readout.speed.maximum_speed, vehicle.config.max_speed), "scale follows vehicle config")
	check(readout.speed.current_speed == 128.0, "needle receives runtime speed")
	check(readout.speed.custom_minimum_size.x >= 0.0, "speedometer control instantiated")
	print("SPEEDOMETER: ", "PASS" if failures == 0 else "FAIL")
	readout.free()
	vehicle.free()
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	if ok:
		print("SPEEDOMETER ok: ", label)
	else:
		failures += 1
		printerr("SPEEDOMETER FAIL: ", label)
