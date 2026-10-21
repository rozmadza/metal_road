extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE VISUALS FAIL: ", label)

func run() -> void:
	var vehicle_ids := LoadoutProfile.vehicle_ids()
	var texture_paths: Array[String] = []
	var unique_textures := {}
	for vehicle_id in vehicle_ids:
		var config := LoadoutProfile.vehicle_config(vehicle_id)
		check(config != null, "%s config loads" % vehicle_id)
		check(config.texture != null, "%s has preview texture" % vehicle_id)
		if config.texture != null:
			texture_paths.append(config.texture.resource_path)
			unique_textures[config.texture.resource_path] = true
	check(texture_paths.size() == 12, "all vehicle textures are present")
	check(unique_textures.size() == 12, "vehicle silhouettes use distinct textures")
	for path in texture_paths:
		check(path.get_file().contains("_clean") or path.get_file().contains("_topdown"), "selectable vehicle uses weaponless top-down art")
	check(load("res://resources/default_vehicle.tres").texture.resource_path.get_file().contains("_clean"), "default vehicle uses weaponless base art")

	var weapon_ids := [&"machine_gun", &"heavy_machine_gun", &"shotgun"]
	var weapon_names: Array[String] = []
	for weapon_id in weapon_ids:
		var config := LoadoutProfile.weapon_config(weapon_id)
		check(config != null, "%s config loads" % weapon_id)
		if config != null:
			weapon_names.append(config.display_name)
			check(config.texture != null, "%s has integrated roof asset" % weapon_id)
	check(weapon_names.size() == 3, "all weapon configs are present")
	check(weapon_names.size() == weapon_names.duplicate().size(), "weapon selections are visually distinguishable")

	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	check(garage.get_node("%VehiclePreview").texture != null, "garage shows selected vehicle")
	check(garage.get_node("%VehiclePreview").weapon == null, "garage preview has a clean roof")
	check(not garage.has_node("%WeaponPreview"), "separate weapon preview removed")
	var viper_index := LoadoutProfile.vehicle_ids().find(&"viper")
	garage.get_node("%VehicleSelect").select(viper_index)
	garage._on_vehicle_selected(viper_index)
	await process_frame
	check(garage.get_node("%VehiclePreview").texture.resource_path.ends_with("viper_clean.png"), "vehicle preview changes on selection")
	check(garage.get_node("%VehiclePreview").weapon == null, "vehicle selection keeps roof clean")
	garage.free()
	print("VEHICLE VISUALS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
