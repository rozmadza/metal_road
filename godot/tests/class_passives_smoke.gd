extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CLASS PASSIVES FAIL: ", label)


func make_vehicle(id: StringName) -> Vehicle:
	var car := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	car.config = LoadoutProfile.vehicle_config(id)
	root.add_child(car)
	return car


func run() -> void:
	var bullets := Node2D.new()
	bullets.add_to_group("bullets")
	root.add_child(bullets)

	var raider := make_vehicle(&"raider")
	await process_frame
	raider.activate_boost(10.0)
	check(is_equal_approx(raider.boost_time_remaining, 13.5), "Raider extends temporary bonuses")
	check("×1.35" in raider.get_hud_state().passive_state, "Raider passive is visible in HUD state")

	var viper := make_vehicle(&"viper")
	await process_frame
	viper.linear_velocity = Vector2(viper.config.max_speed * 0.7, 0.0)
	viper._time_since_impact = 2.0
	check(viper.notify_clean_corner(), "Viper earns boost for a clean fast checkpoint")
	check(viper.is_apex_boost_active(), "Viper apex boost becomes active")
	check("ИДЕАЛЬНАЯ ДУГА" in viper.get_hud_state().passive_state, "Viper passive is visible in HUD state")

	var assault := make_vehicle(&"wasteland_gt")
	await process_frame
	assault.activate_temporary_weapon(assault.gun.config, 5.0)
	assault.gun._shoot()
	var shot := bullets.get_child(bullets.get_child_count() - 1) as Bullet
	check(is_equal_approx(shot.damage, assault.gun.config.bullet_damage * 1.25), "Assault projectile receives overdrive damage")
	check("+25%" in assault.get_hud_state().passive_state, "Assault passive is visible in HUD state")

	var crusher := make_vehicle(&"crusher")
	await process_frame
	var base_impact := crusher._calculate_collision_damage(110.0, crusher.config.mass, 1.0, 1.0, Vector2.RIGHT)
	var ram_impact := crusher._calculate_collision_damage(110.0, crusher.config.mass, crusher.config.ram_power, 1.0, Vector2.RIGHT)
	check(float(ram_impact.damage) > float(base_impact.damage), "Juggernaut frontal ram increases delivered damage")
	crusher._trigger_passive_feedback(1.0)
	check("УДАР" in crusher.get_hud_state().passive_state, "Juggernaut ram feedback is visible")

	var race := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	var bot_classes := {}
	for bot in get_nodes_in_group("bots"):
		bot_classes[(bot as BotController).vehicle.config.vehicle_class] = true
	check(bot_classes.size() == 4, "race grid includes all four vehicle classes")
	var topdown := LoadoutProfile.vehicle_config(&"wasteland_gt").texture.resource_path
	check(topdown.ends_with("wasteland_gt_topdown.png"), "Wasteland GT uses unified top-down artwork")

	print("CLASS PASSIVES: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
