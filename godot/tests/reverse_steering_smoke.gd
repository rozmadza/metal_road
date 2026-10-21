extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	await physics_frame
	vehicle.linear_velocity = Vector2(-70.0, 0.0)
	vehicle.apply_control(-0.6, 0.0, 1.0)
	for _frame in 20:
		await physics_frame
	check(vehicle.angular_velocity < -0.05, "right steering rotates counter-clockwise in reverse")
	vehicle.rotation = 0.0
	vehicle.angular_velocity = 0.0
	vehicle.linear_velocity = Vector2(-70.0, 0.0)
	vehicle.apply_control(-0.6, 0.0, -1.0)
	for _frame in 20:
		await physics_frame
	check(vehicle.angular_velocity > 0.05, "left steering rotates clockwise in reverse")
	vehicle.free()
	print("REVERSE STEERING: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("REVERSE STEERING FAIL: ", label)
