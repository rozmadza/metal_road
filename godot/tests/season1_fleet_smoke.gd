extends SceneTree

var failures := 0
var test_path := "user://season1_fleet_test.cfg"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("SEASON 1 FLEET FAIL: ", label)

func run() -> void:
	PlayerProfile.path_override = test_path
	var absolute := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	var catalog := LoadoutProfile.vehicle_catalog()
	var season_ids := [&"dustfox", &"needle", &"warhound", &"bastion"]
	var classes := {}
	for id in season_ids:
		var config := catalog.get_vehicle(id)
		check(config != null, "%s exists" % id)
		check(config.texture != null, "%s has raster art" % id)
		check(config.career_unlock_event != &"", "%s has a career gate" % id)
		check(config.engine_pitch_base != 0.8 or config.engine_pitch_range != 0.7, "%s has an engine profile" % id)
		classes[config.vehicle_class] = true
	check(classes.size() == 4, "one new vehicle exists for every class")

	var data := PlayerProfile.read()
	data.credits = 50000
	data.vehicles.append(&"dustfox")
	data.vehicle_states["dustfox"] = PlayerProfile.default_vehicle_state()
	PlayerProfile.save(data)
	var options := PlayerProfile.specialization_options(&"dustfox")
	check(options.size() == 2, "Dust Fox has two final branches")
	check(PlayerProfile.purchase_upgrade(options[0].id, &"vehicle", &"dustfox"), "first branch can be installed")
	check(not bool(PlayerProfile.upgrade_availability(options[1].id, &"dustfox").allowed), "alternative branch is locked")
	check(PlayerProfile.installed_specialization(&"dustfox").id == options[0].id, "branch persists per vehicle")
	check(PlayerProfile.installed_specialization(&"needle") == null, "branch does not leak to another vehicle")

	var veteran := CareerDifficulty.apply_bot_vehicle(LoadoutProfile.vehicle_config(&"needle"), 8, 1)
	check(veteran.max_speed >= LoadoutProfile.vehicle_config(&"needle").max_speed, "veteran bot receives upgrades")
	check(CareerDifficulty.upgrade_ids(8, 1, &"needle").any(func(id): return id in PlayerProfile.VEHICLE_SPECIALIZATION_IDS[&"needle"]), "veteran bot receives a specialization")
	check(CareerSession.event_by_id(&"frontier_express").unlock_vehicle == &"dustfox", "frontier race unlocks Dust Fox")
	check(CareerSession.event_by_id(&"oil_cauldron").unlock_vehicle == &"bastion", "frontier arena unlocks Bastion")
	check(CareerSession.event_by_id(&"copper_ravine").objective_unlock_vehicle == &"warhound", "frontier finale objective unlocks Warhound")
	var migrated := PlayerProfile.read()
	migrated.career.completed_events = [&"frontier_express", &"oil_cauldron", &"copper_ravine"]
	migrated.career.completed_objectives = [&"copper_ravine"]
	for id in season_ids: migrated.vehicles.erase(id)
	PlayerProfile.save(migrated)
	var reconciled := PlayerProfile.read()
	for id in season_ids: check(id in reconciled.vehicles, "%s is restored for an existing completed career" % id)

	PlayerProfile.path_override = ""
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("SEASON 1 FLEET: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
