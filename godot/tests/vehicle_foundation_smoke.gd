extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE FOUNDATION FAIL: ", label)

func run() -> void:
	var catalog := LoadoutProfile.vehicle_catalog()
	check(catalog != null, "catalog loads")
	check(catalog.ids().size() == 12, "catalog contains twelve vehicles")
	check(catalog.validation_errors().is_empty(), "catalog data is valid")
	var classes := {}
	var class_counts := {}
	for id in catalog.ids():
		var config := catalog.get_vehicle(id)
		classes[config.vehicle_class] = true
		class_counts[config.vehicle_class] = int(class_counts.get(config.vehicle_class, 0)) + 1
		check(config.vehicle_id == id, "%s has a stable id" % id)
		check(not config.display_name.is_empty(), "%s has a display name" % id)
		check(not config.passive_name.is_empty(), "%s has a passive" % id)
		check(config.texture != null, "%s has vehicle artwork" % id)
		check(PlayerProfile.price(&"vehicle", id) > 0 or id == &"raider", "%s has an economy price" % id)
	check(classes.size() == 4, "all four explicit classes are represented")
	for vehicle_class in class_counts:
		check(int(class_counts[vehicle_class]) == 3, "class %s has three vehicles" % vehicle_class)

	var original_loadout := LoadoutProfile.read_ids()
	LoadoutProfile.save_ids(&"raider", original_loadout.weapon)
	var test_path := "user://vehicle_foundation_test.cfg"
	var absolute_path := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	PlayerProfile.path_override = test_path
	var legacy := ConfigFile.new()
	legacy.set_value("profile", "save_version", 1)
	legacy.set_value("profile", "credits", 5000)
	legacy.set_value("profile", "owned_vehicles", PackedStringArray(["raider", "viper"]))
	legacy.set_value("profile", "owned_weapons", PackedStringArray(["machine_gun"]))
	legacy.set_value("profile", "vehicle_upgrades", PackedStringArray(["engine_1"]))
	legacy.set_value("profile", "weapon_upgrades", PackedStringArray())
	legacy.save(test_path)

	var migrated := PlayerProfile.read()
	check(&"engine_1" in PlayerProfile.vehicle_upgrade_ids(&"raider", migrated), "legacy upgrade migrates to selected vehicle")
	check(PlayerProfile.vehicle_upgrade_ids(&"viper", migrated).is_empty(), "other vehicle starts with independent upgrades")
	check(PlayerProfile.purchase_upgrade(&"handling_1", &"vehicle", &"viper"), "upgrade can be bought for a specific vehicle")
	check(&"handling_1" in PlayerProfile.vehicle_upgrade_ids(&"viper"), "specific vehicle keeps its upgrade")
	check(&"handling_1" not in PlayerProfile.vehicle_upgrade_ids(&"raider"), "upgrade does not leak between vehicles")

	PlayerProfile.record_vehicle_result(&"viper", &"race", {
		"status": &"FINISHED", "position": 1, "time": 72.5, "kills": 2, "damage": 140.0,
	})
	var saved := PlayerProfile.read()
	var viper_state: Dictionary = saved.vehicle_states["viper"]
	check(int(viper_state.races) == 1 and int(viper_state.wins) == 1, "per-vehicle race history persists")
	check(int(viper_state.kills) == 2 and is_equal_approx(float(viper_state.damage_dealt), 140.0), "per-vehicle combat stats persist")

	PlayerProfile.path_override = ""
	LoadoutProfile.save_ids(original_loadout.vehicle, original_loadout.weapon)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	print("VEHICLE FOUNDATION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
