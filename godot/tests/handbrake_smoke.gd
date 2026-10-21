extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	if condition:
		print("HANDBRAKE ok: ", label)
	else:
		failures += 1
		printerr("HANDBRAKE FAIL: ", label)


func run() -> void:
	var scene := load("res://scenes/Vehicle.tscn") as PackedScene
	var normal := scene.instantiate() as Vehicle
	var drifting := scene.instantiate() as Vehicle
	root.add_child(normal)
	root.add_child(drifting)
	normal.global_position = Vector2(0, -500)
	drifting.global_position = Vector2(0, 500)
	normal.linear_velocity = Vector2(150, 0)
	drifting.linear_velocity = Vector2(150, 0)
	normal.apply_control(0.0, 0.0, 0.82)
	drifting.apply_control(0.0, 1.0, 0.82)
	var peak_strength := 0.0
	var peak_slip_advantage := 0.0
	var peak_yaw_advantage := 0.0
	for frame in 18:
		await physics_frame
		peak_strength = maxf(peak_strength, drifting.get_handbrake_strength())
		peak_slip_advantage = maxf(peak_slip_advantage, absf(drifting.get_lateral_speed()) - absf(normal.get_lateral_speed()))
		peak_yaw_advantage = maxf(peak_yaw_advantage, absf(drifting.angular_velocity) - absf(normal.angular_velocity))
	check(peak_strength > 0.90, "brake engages handbrake above the speed threshold")
	print("HANDBRAKE measurements: grip slip delta=%.2f yaw delta=%.2f" % [peak_slip_advantage, peak_yaw_advantage])
	check(peak_slip_advantage > 4.0, "rear grip release creates additional lateral slip")
	check(peak_yaw_advantage > 0.08, "handbrake increases yaw response")

	var straight := scene.instantiate() as Vehicle
	root.add_child(straight)
	straight.global_position = Vector2(0, 1000)
	straight.linear_velocity = Vector2(130, 0)
	straight.apply_control(0.0, 1.0, 0.0)
	for frame in 18:
		await physics_frame
	check(absf(straight.angular_velocity) < 0.03, "straight-line braking does not create an artificial spin")
	check(straight.get_forward_speed() < 130.0, "handbrake still decelerates the car")

	for vehicle in [normal, drifting, straight]:
		vehicle.free()
	print("HANDBRAKE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
