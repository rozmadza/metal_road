extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE PROGRESSION FAIL: ", label)

func run() -> void:
	for id in LoadoutProfile.vehicle_ids():
		check(LoadoutProfile.vehicle_config(id).max_speed <= 200.0, "%s base speed capped" % id)
	var upgraded := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"viper"), [&"engine_1"])
	check(upgraded.max_speed <= 200.0, "engine upgrade respects 200 km/h cap")
	check(upgraded.acceleration > LoadoutProfile.vehicle_config(&"viper").acceleration, "engine improves dynamics")
	var wheel_upgrade := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"raider"), [&"wheels_1"])
	check(wheel_upgrade.wheels_repair_rate > LoadoutProfile.vehicle_config(&"raider").wheels_repair_rate, "wheel upgrade improves repair")
	var armor_upgrade := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"raider"), [&"armor_1"])
	check(armor_upgrade.damage_resistance > 0.0, "armor absorbs damage")
	var full_engine := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"raider"), [&"engine_1", &"engine_2", &"engine_3"])
	check(full_engine.acceleration > upgraded.acceleration, "three engine levels stack")
	var armed := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"wasteland_gt"), [&"armament_1", &"armament_2", &"armament_3"])
	check(armed.weapon_damage_multiplier > 1.3 and armed.weapon_fire_rate_multiplier > 1.2, "weapon slot improves damage and fire rate")
	var profile := {
		"credits": 20000,
		"vehicles": [&"raider", &"wasteland_gt"],
		"weapons": [&"machine_gun"],
		"weapon_upgrades": [],
		"vehicle_states": {
			"raider": {"upgrades": [], "races": 0, "wins": 0, "best_finish": 0, "best_time": 0.0, "kills": 0, "damage_dealt": 0.0, "survival_best_round": 0},
			"wasteland_gt": {"upgrades": [&"engine_1", &"engine_2", &"armor_1", &"armor_2"], "races": 0, "wins": 0, "best_finish": 0, "best_time": 0.0, "kills": 0, "damage_dealt": 0.0, "survival_best_round": 0},
		},
	}
	check(not bool(PlayerProfile.upgrade_availability(&"engine_2", &"raider", profile).allowed), "level two requires level one")
	check(not bool(PlayerProfile.upgrade_availability(&"engine_3", &"wasteland_gt", profile).allowed), "assault cannot install racing engine level three")
	check(bool(PlayerProfile.upgrade_availability(&"armor_3", &"wasteland_gt", profile).allowed), "assault can install heavy armor level three")
	var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	vehicle.config = wheel_upgrade
	root.add_child(vehicle)
	await process_frame
	vehicle.take_damage(20.0, &"wheels")
	var damaged_wheels := vehicle.damage.wheels
	vehicle._wheels_repair_cooldown = 0.0
	vehicle._physics_process(1.0)
	check(vehicle.damage.wheels > damaged_wheels, "damaged wheels repair over time")
	var strip := (load("res://scenes/SpikeStrip.tscn") as PackedScene).instantiate() as SpikeStrip
	root.add_child(strip)
	var before_spikes := vehicle.damage.wheels
	strip._on_body_entered(vehicle)
	check(vehicle.damage.wheels < before_spikes, "spike strip damages wheels")
	vehicle.free()

	var race := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Game
	root.add_child(race)
	await process_frame
	check(race.participants.size() == 6, "race has player and five bots")
	var strategies := {}
	for bot in get_nodes_in_group("bots"):
		strategies[(bot as BotController).strategy] = true
	check(strategies.size() == 5, "all five race bots use unique strategies")
	race.free()

	var survival := (load("res://scenes/ArenaBattle.tscn") as PackedScene).instantiate() as Survival
	root.add_child(survival)
	await process_frame
	check(survival._enemies.size() == 5, "survival has five bots")
	var arena_strategies := {}
	for bot in get_nodes_in_group("arena_bots"):
		arena_strategies[(bot as ArenaBot).strategy] = true
	check(arena_strategies.size() >= 4, "arena bots use distinct strategies")
	print("VEHICLE PROGRESSION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
