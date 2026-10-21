extends SceneTree

var failures := 0
var profile_path := "user://driver_progression_profile_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("DRIVER PROGRESSION FAIL: ", label)


func run() -> void:
	PlayerProfile.path_override = profile_path
	PlayerProfile.save({"credits": 0, "vehicles": [&"raider"], "weapons": [&"machine_gun"], "vehicle_states": {}, "career": {}})
	var selection := (load("res://scenes/DriverSelect.tscn") as PackedScene).instantiate() as DriverSelect
	root.add_child(selection)
	await process_frame
	check(selection.get_node("%DriverList").get_child_count() == 3, "three career drivers are available")
	check(selection.get_node("%Portrait").texture != null, "driver portrait is loaded")
	selection.get_node("%DriverList").get_child(1).pressed.emit()
	check("ЖЕЛЕЗНАЯ ВОЛЯ" in selection.get_node("%Passive").text, "selection changes the specialization")
	var data := PlayerProfile.read()
	data.career.driver_id = &"rook"
	PlayerProfile.save(data)
	check(PlayerProfile.career_state().driver_id == &"rook", "selected driver persists")

	var base := LoadoutProfile.vehicle_config(&"raider")
	var rook_car := DriverRoster.apply_passive(base, &"rook")
	var flint_car := DriverRoster.apply_passive(base, &"flint")
	var mara_car := DriverRoster.apply_passive(base, &"mara")
	check(rook_car.max_health > base.max_health and rook_car.damage_resistance > base.damage_resistance, "mechanic improves durability")
	check(flint_car.acceleration > base.acceleration and flint_car.steer_rate > base.steer_rate, "pilot improves handling")
	check(mara_car.weapon_damage_multiplier > base.weapon_damage_multiplier and mara_car.passive_bonus_duration_multiplier > base.passive_bonus_duration_multiplier, "navigator improves combat bonuses")

	var rookie := CareerDifficulty.apply_bot_vehicle(base, 1)
	var veteran := CareerDifficulty.apply_bot_vehicle(base, 6)
	check(CareerDifficulty.upgrade_ids(1).is_empty(), "first-level rivals use stock cars")
	check(CareerDifficulty.upgrade_ids(6).size() >= 5, "veteran rivals accumulate modules")
	check(veteran.acceleration > rookie.acceleration and veteran.max_health > rookie.max_health, "rival car stats grow with career level")

	var state := PlayerProfile.career_state()
	check(int(state.career_level) == 1, "career starts at level one")
	CareerSession.select_event(&"iron_open")
	CareerSession.record_result({"status": &"FINISHED", "position": 1})
	check(int(PlayerProfile.career_state().career_level) == 2, "first career victory raises rival level")

	selection.free()
	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	var absolute := ProjectSettings.globalize_path(profile_path)
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("DRIVER PROGRESSION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
