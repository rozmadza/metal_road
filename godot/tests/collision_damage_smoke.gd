extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("COLLISION DAMAGE FAIL: ", label)


func run() -> void:
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(vehicle)
	vehicle.add_to_group("combatants")
	await process_frame

	var front: Dictionary = vehicle._calculate_collision_damage(100.0, 1000.0, 1.0, 1.0, Vector2.RIGHT)
	var side: Dictionary = vehicle._calculate_collision_damage(100.0, 1000.0, 1.0, 1.0, Vector2.DOWN)
	var heavy: Dictionary = vehicle._calculate_collision_damage(100.0, 1550.0, 1.25, 1.0, Vector2.DOWN)
	var tire: Dictionary = vehicle._calculate_collision_damage(100.0, 1000.0, 1.0, 0.3, Vector2.DOWN)
	var harmless: Dictionary = vehicle._calculate_collision_damage(20.0, 1000.0, 1.0, 1.0, Vector2.DOWN)
	var catastrophic: Dictionary = vehicle._calculate_collision_damage(400.0, 2000.0, 2.0, 1.2, Vector2.DOWN)

	check(float(harmless.damage) == 0.0, "low-speed contact is harmless")
	check(float(front.damage) > 2.0, "medium collision deals visible damage")
	check(float(side.damage) > float(front.damage), "side impact is more dangerous than front")
	check(float(heavy.damage) > float(side.damage), "heavy rammer delivers more damage")
	check(float(tire.damage) < float(side.damage) * 0.4, "tire pile cushions impact")
	check(float(catastrophic.damage) <= vehicle.config.impact_damage_cap, "single-contact damage is capped")

	var before := vehicle.health
	var wheels_before := vehicle.damage.wheels
	vehicle._take_collision_damage(float(side.damage), &"wheels", null)
	check(vehicle.health < before, "collision reduces body health")
	check(vehicle.damage.wheels < wheels_before, "side impact damages wheels")

	vehicle.free()
	print("COLLISION DAMAGE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
