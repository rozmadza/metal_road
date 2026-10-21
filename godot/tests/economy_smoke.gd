extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ECONOMY FAIL: ", label)

func run() -> void:
	var data := {"credits": 12000, "vehicles": [&"raider"], "weapons": [&"machine_gun"], "vehicle_upgrades": [], "weapon_upgrades": []}
	check(PlayerProfile.purchase_data(data, &"vehicle", &"crusher"), "vehicle purchase succeeds")
	check(PlayerProfile.purchase_data(data, &"weapon", &"shotgun"), "weapon purchase succeeds")
	check(&"crusher" in data.vehicles, "vehicle ownership updated")
	check(&"shotgun" in data.weapons, "weapon ownership updated")
	data.vehicle_upgrades.append(&"engine_1")
	data.weapon_upgrades.append(&"weapon_damage_1")
	var tuned_vehicle := PlayerProfile.apply_vehicle_upgrades_from(LoadoutProfile.vehicle_config(&"raider"), data.vehicle_upgrades)
	var tuned_weapon := PlayerProfile.apply_weapon_upgrades_from(LoadoutProfile.weapon_config(&"machine_gun"), data.weapon_upgrades)
	check(tuned_vehicle.max_speed > LoadoutProfile.vehicle_config(&"raider").max_speed, "engine modifies vehicle")
	check(tuned_weapon.bullet_damage > LoadoutProfile.weapon_config(&"machine_gun").bullet_damage, "upgrade modifies weapon")
	check(int(data.credits) < 12000, "credits are spent")
	var before_sale := int(data.credits)
	var refund := PlayerProfile.sell_vehicle_data(data, &"crusher")
	check(refund > 0 and int(data.credits) == before_sale + refund, "vehicle sale refunds credits")
	check(&"crusher" not in data.vehicles, "sold vehicle leaves ownership")
	print("ECONOMY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
