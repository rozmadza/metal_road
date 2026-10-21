extends SceneTree

var failures := 0
var deaths := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("CONTRACT FAIL: ", label)

func run() -> void:
	var v: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
	root.add_child(v)
	v.died.connect(func(_vehicle: Vehicle): deaths += 1)
	v.add_to_group("combatants")
	v.take_damage(-10)
	check(v.health == v.config.max_health, "negative damage ignored")
	v.take_damage(25)
	check(v.health == v.config.max_health - 25, "legacy health tracks damage")
	v.take_damage(1000)
	v.take_damage(1000)
	check(not v.alive and v.health == 0 and deaths == 1, "death once")
	check(not v.is_in_group("combatants"), "death leaves combat group")
	await process_frame
	check(v.freeze and v.collision_layer == 0, "death disables physics")
	v.reset_to(Vector2(80, 80), 0)
	check(v.alive and v.health == v.config.max_health, "reset restores life")
	check(not v.freeze and v.collision_layer == 1, "reset restores physics")
	v.free()
	print("DAMAGE CONTRACT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
