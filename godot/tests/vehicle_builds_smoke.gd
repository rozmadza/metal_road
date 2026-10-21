extends SceneTree

var failures := 0
var profile_path := "/tmp/metal-road-builds-%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	PlayerProfile.path_override = profile_path
	PlayerProfile.save({
		"credits": 20000,
		"vehicles": [&"raider"],
		"weapons": [&"machine_gun"],
		"weapon_upgrades": [],
		"vehicle_states": {
			"raider": {
				"upgrades": [&"engine_1", &"armor_1"], "build": &"factory",
				"races": 0, "wins": 0, "best_finish": 0, "best_time": 0.0,
				"kills": 0, "damage_dealt": 0.0, "survival_best_round": 0,
			},
		},
	})
	var options := PlayerProfile.vehicle_build_options(&"raider")
	check(options.size() == 3, "every class offers stock and two tactical builds")
	check(bool(PlayerProfile.vehicle_build_availability(&"raider", &"raider_scavenger").allowed), "first build unlocks from module progress")
	check(not bool(PlayerProfile.vehicle_build_availability(&"raider", &"raider_runner").allowed), "advanced build remains progression-gated")
	check(PlayerProfile.set_vehicle_build(&"raider", &"raider_scavenger"), "available build can be equipped")
	check(StringName(PlayerProfile.vehicle_state(&"raider").build) == &"raider_scavenger", "selected build persists per vehicle")
	var stock := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"raider"), [&"engine_1", &"armor_1"])
	var tuned := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(&"raider"), &"raider")
	check(tuned.wheels_repair_rate > stock.wheels_repair_rate, "scavenger build improves field repair")
	check(tuned.max_speed < stock.max_speed, "build trade-off is applied")
	check(PlayerProfile.set_vehicle_build(&"raider", &"factory"), "builds are reversible")

	var raider_damage := VehicleDamage.new()
	var interceptor_damage := VehicleDamage.new()
	raider_damage.reset(LoadoutProfile.vehicle_config(&"raider"))
	interceptor_damage.reset(LoadoutProfile.vehicle_config(&"viper"))
	raider_damage.apply(20.0, &"engine")
	interceptor_damage.apply(20.0, &"engine")
	check(raider_damage.ratio(&"engine") > interceptor_damage.ratio(&"engine"), "class damage profiles affect module resilience")

	var breach := VehicleDamage.new()
	breach.reset(LoadoutProfile.vehicle_config(&"raider"))
	var engine_start := breach.engine
	breach.apply(30.0, &"body")
	var first_loss := engine_start - breach.engine
	var before_second := breach.engine
	breach.apply(30.0, &"body")
	check(before_second - breach.engine > first_loss, "breached body exposes internal modules")
	breach.apply(1000.0, &"wheels")
	check(breach.critical_module() != &"", "critical module state is exposed to HUD")

	PlayerProfile.path_override = ""
	DirAccess.remove_absolute(profile_path)
	print("VEHICLE BUILDS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE BUILDS FAIL: ", label)
