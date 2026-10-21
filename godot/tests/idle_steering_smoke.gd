extends SceneTree

var failures := 0
var vehicle: Vehicle


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("IDLE STEERING FAIL: ", label)


func run() -> void:
	vehicle = (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	await physics_frame
	vehicle.linear_velocity = Vector2.ZERO
	vehicle.angular_velocity = 0.0
	vehicle.apply_control(0.0, 0.0, 1.0)
	for _step in 20:
		await physics_frame
	check(absf(vehicle.angular_velocity) < 0.02, "steering without throttle does not spin the car")
	vehicle.apply_control(0.8, 0.0, 1.0)
	for _step in 25:
		await physics_frame
	check(absf(vehicle.angular_velocity) > 0.05, "steering turns the car once it is rolling")
	vehicle.queue_free()
	await process_frame
	print("IDLE STEERING: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
