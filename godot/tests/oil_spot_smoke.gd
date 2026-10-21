extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("OIL FAIL: ", label)

func run() -> void:
	var vehicle: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(vehicle)
	var oil: OilSpot = load("res://scenes/OilSpot.tscn").instantiate()
	root.add_child(oil)
	await process_frame
	vehicle.global_position = oil.global_position
	await create_timer(0.35).timeout
	check(vehicle.get_surface_traction_factor() < 0.8, "traction is reduced on oil")
	check(vehicle.get_surface_steering_factor() < 0.9, "steering stability is reduced on oil")
	vehicle.global_position = Vector2(300, 300)
	await create_timer(0.8).timeout
	check(vehicle.get_surface_traction_factor() > 0.95, "traction recovers smoothly")
	check(vehicle.get_surface_steering_factor() > 0.95, "steering recovers smoothly")
	var second_oil: OilSpot = load("res://scenes/OilSpot.tscn").instantiate()
	root.add_child(second_oil)
	await process_frame
	oil._on_body_entered(vehicle)
	second_oil._on_body_entered(vehicle)
	oil._on_body_exited(vehicle)
	await create_timer(0.35).timeout
	check(vehicle.get_surface_traction_factor() < 0.8, "second oil source remains active")
	second_oil._on_body_exited(vehicle)
	await create_timer(0.8).timeout
	check(vehicle.get_surface_traction_factor() > 0.95, "all oil sources clear")
	vehicle.free()
	oil.free()
	second_oil.free()
	print("OIL SPOT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
