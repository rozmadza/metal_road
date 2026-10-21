extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("HANDLING FAIL: ", label)
	else:
		print("HANDLING ok: ", label)

func run() -> void:
	var scene := load("res://scenes/Vehicle.tscn") as PackedScene
	var light := scene.instantiate() as Vehicle
	var heavy := scene.instantiate() as Vehicle
	root.add_child(light)
	root.add_child(heavy)
	light.global_position = Vector2(-55, 0)
	heavy.global_position = Vector2(55, 0)
	var heavy_config := heavy.config.duplicate() as VehicleConfig
	heavy_config.mass = light.mass * 3.0
	heavy.reconfigure(heavy_config)
	light.linear_velocity = Vector2(165, 0)
	heavy.linear_velocity = Vector2(-45, 0)
	light.apply_control(0, 0, 0)
	heavy.apply_control(0, 0, 0)
	var closest := INF
	for frame in 55:
		await physics_frame
		closest = minf(closest, light.global_position.distance_to(heavy.global_position))
	check(closest < light.config.length * Vehicle.COLLISION_SCALE.x + 10.0, "vehicles make contact at the visible bumpers")
	check(closest > light.config.length * Vehicle.COLLISION_SCALE.x * 0.82, "vehicles do not interpenetrate half a chassis")
	print("HANDLING velocities: light=%.1f heavy=%.1f distance=%.1f" % [light.linear_velocity.x, heavy.linear_velocity.x, light.global_position.distance_to(heavy.global_position)])
	check(light.global_position.distance_to(heavy.global_position) > 35.0, "vehicles separate after impact")
	check(light.linear_velocity.x < heavy.linear_velocity.x + 70.0, "impulse changes their relative travel")
	check(light.physics_material_override.friction < 0.3, "body friction permits sliding contact")
	light.free()
	heavy.free()

	var pause := PauseOverlay.new()
	root.add_child(pause)
	pause.toggle()
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	InputBindings.ensure_controller_defaults()
	pause._unhandled_input(back)
	check(not paused and not pause.visible, "gamepad B closes the paused menu")
	pause.free()
	print("HANDLING: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
