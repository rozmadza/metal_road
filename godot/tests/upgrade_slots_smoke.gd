extends SceneTree

var failures := 0
var profile_path := "/tmp/metal-road-upgrade-slots-%d.cfg" % OS.get_process_id()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	PlayerProfile.path_override = profile_path
	PlayerProfile.save({
		"credits": 30000,
		"vehicles": [&"raider", &"wasteland_gt"],
		"weapons": [&"machine_gun"],
		"weapon_upgrades": [],
		"vehicle_states": {},
	})
	check(not PlayerProfile.purchase_upgrade(&"engine_2", &"vehicle", &"raider"), "levels cannot be skipped")
	check(PlayerProfile.purchase_upgrade(&"engine_1", &"vehicle", &"raider"), "engine level one purchased")
	check(PlayerProfile.purchase_upgrade(&"engine_2", &"vehicle", &"raider"), "engine level two purchased")
	check(PlayerProfile.purchase_upgrade(&"engine_3", &"vehicle", &"raider"), "raider installs racing engine level three")
	check(not PlayerProfile.purchase_upgrade(&"engine_3", &"vehicle", &"wasteland_gt"), "assault racing engine level three blocked")
	check(PlayerProfile.purchase_upgrade(&"armor_1", &"vehicle", &"wasteland_gt"), "assault armor level one purchased")
	check(PlayerProfile.purchase_upgrade(&"armor_2", &"vehicle", &"wasteland_gt"), "assault armor level two purchased")
	check(PlayerProfile.purchase_upgrade(&"armor_3", &"vehicle", &"wasteland_gt"), "assault heavy armor level three purchased")
	check(PlayerProfile.vehicle_upgrade_level(&"raider", &"engine") == 3, "raider engine level saved")
	check(PlayerProfile.vehicle_upgrade_level(&"wasteland_gt", &"engine") == 0, "upgrades remain vehicle-specific")
	var raider := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(&"raider"), &"raider")
	var assault := PlayerProfile.apply_vehicle_upgrades(LoadoutProfile.vehicle_config(&"wasteland_gt"), &"wasteland_gt")
	check(raider.acceleration > LoadoutProfile.vehicle_config(&"raider").acceleration, "saved engine affects race config")
	check(assault.max_health > LoadoutProfile.vehicle_config(&"wasteland_gt").max_health, "saved armor affects race config")
	check(int(PlayerProfile.read().credits) < 30000, "module purchases spend credits")
	PlayerProfile.path_override = ""
	DirAccess.remove_absolute(profile_path)
	print("UPGRADE SLOTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("UPGRADE SLOTS FAIL: ", label)
