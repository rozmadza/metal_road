extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("MODULES FAIL: ", label)

func run() -> void:
	var scene: PackedScene = load("res://scenes/Vehicle.tscn")
	var v: Vehicle = scene.instantiate()
	var other: Vehicle = scene.instantiate()
	root.add_child(v)
	root.add_child(other)
	check(v.damage.engine_factor() == 1 and v.damage.traction_factor() == 1, "healthy physics unchanged")
	v.take_damage(1000, &"engine")
	check(is_equal_approx(v.damage.engine_factor(), 0.85), "engine damage is capped at fifteen percent")
	check(v.health == v.config.max_health and v.alive, "engine does not kill body")
	v.take_damage(1000, &"wheels")
	check(v.damage.traction_factor() < 1 and v.damage.steering_factor() < 1, "wheels degrade grip and steering")
	check(other.damage.engine_factor() == 1, "shared config does not share damage")
	v.reset_to(Vector2.ZERO, 0)
	for stage in range(1, 5):
		v.take_damage(25)
		check(v.damage.visual_stage() == stage, "visual stage %d" % stage)
	v.apply_control(1, 0, 1, true)
	check(not v.alive and v.throttle == 0 and not v.fire, "dead input blocked")
	await process_frame
	check(not v.gun.is_physics_processing(), "dead weapon disabled")
	v.reset_to(Vector2.ZERO, 0)
	check(v.damage.visual_stage() == 0 and v.damage.engine_factor() == 1 and v.damage.traction_factor() == 1, "reset all modules")
	check(v.gun.is_physics_processing(), "reset weapon")
	v.take_damage(NAN)
	check(v.health == v.config.max_health, "invalid damage rejected")
	v.position = Vector2(0, -1000)
	other.position = Vector2(0, 1000)
	v.take_damage(1000, &"engine")
	v.apply_control(1, 0, 0)
	other.apply_control(1, 0, 0)
	for i in 120:
		await physics_frame
	check(other.get_speed() > v.get_speed() * 1.08, "damaged engine modestly reduces actual acceleration/speed")
	v.apply_control(0, 0, 0)
	other.apply_control(0, 0, 0)
	v.take_damage(1000, &"wheels")
	v.linear_velocity = Vector2(0, 80)
	other.linear_velocity = Vector2(0, 80)
	for i in 10:
		await physics_frame
	check(absf(v.get_lateral_speed()) > absf(other.get_lateral_speed()) + 5, "damaged wheels increase actual drift")
	v.free()
	other.free()
	print("DAMAGE MODULES: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
