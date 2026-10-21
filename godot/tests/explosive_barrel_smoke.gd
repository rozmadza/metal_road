extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BARREL FAIL: ", label)

func run() -> void:
	var vehicle: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	vehicle.position = Vector2(0, 0)
	root.add_child(vehicle)
	vehicle.add_to_group("combatants")
	var barrel: ExplosiveBarrel = load("res://scenes/ExplosiveBarrel.tscn").instantiate()
	barrel.position = Vector2(0, 0)
	root.add_child(barrel)
	await process_frame
	barrel.take_damage(5.0, &"body", vehicle)
	check(not barrel.exploding, "first hit does not destroy barrel")
	barrel.take_damage(5.0, &"body", vehicle)
	check(not barrel.exploding and barrel.health == 20.0, "barrel uses health instead of hit count")
	barrel.take_damage(20.0, &"body", vehicle)
	check(barrel.exploding, "zero health explodes barrel")
	check(vehicle.health < vehicle.config.max_health, "radial damage reaches vehicle")
	barrel.take_damage(100.0, &"body", vehicle)
	check(barrel.destroyed, "destroyed guard prevents duplicate trigger")
	await create_timer(1.1).timeout
	check(not is_instance_valid(barrel), "barrel cleans itself after explosion")
	vehicle.free()
	var ram_vehicle: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(ram_vehicle)
	var ram_barrel: ExplosiveBarrel = load("res://scenes/ExplosiveBarrel.tscn").instantiate()
	ram_barrel.position = Vector2(100.0, 0.0)
	root.add_child(ram_barrel)
	await process_frame
	ram_vehicle._collision_cooldowns.clear()
	ram_vehicle._last_velocity = Vector2(420.0, 0.0)
	ram_vehicle._on_body_entered(ram_barrel.get_node("Collision"))
	check(ram_barrel.exploding, "single hard ram explodes barrel")
	ram_vehicle.free()
	ram_barrel.free()

	var shooter: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(shooter)
	var shot_barrel: ExplosiveBarrel = load("res://scenes/ExplosiveBarrel.tscn").instantiate()
	root.add_child(shot_barrel)
	await process_frame
	var bullet := Bullet.new()
	bullet.damage = shot_barrel.max_health
	bullet.shooter = shooter
	bullet.global_position = shot_barrel.global_position
	root.add_child(bullet)
	bullet._physics_process(0.0)
	check(shot_barrel.exploding, "bullet reaches destructible before static cover check")
	shooter.free()
	shot_barrel.free()
	print("EXPLOSIVE BARREL: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
