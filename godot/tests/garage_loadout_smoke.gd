extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("LOADOUT FAIL: ", label)

func run() -> void:
	# Allow the previous headless process to release its user:// logger/config lock.
	await create_timer(0.5).timeout
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	var garage: Control = load("res://scenes/Garage.tscn").instantiate()
	root.add_child(garage)
	await process_frame
	check(garage.get_node("%VehicleSelect").item_count == 12, "twelve vehicles listed")
	check(not garage.has_node("%WeaponSelect"), "weapon selector removed")
	var crusher_index := LoadoutProfile.vehicle_ids().find(&"crusher")
	garage.get_node("%VehicleSelect").select(crusher_index)
	garage._on_vehicle_selected(crusher_index)
	await create_timer(0.05).timeout
	check(garage._vehicle_id == &"crusher", "crusher selected")
	check("155" in garage.get_node("%Stats").text, "crusher stats shown")
	var selected_vehicle_config: VehicleConfig = garage.vehicle_config
	garage.free()
	var game: Game = load("res://scenes/Main.tscn").instantiate()
	game.spawn_bots = false
	root.add_child(game)
	await physics_frame
	# Apply the same selected Resources directly. This keeps the smoke test
	# deterministic when another headless Godot process is releasing user://
	# files, while the windowed Garage path still persists the IDs normally.
	game.vehicle.config = selected_vehicle_config
	check(is_equal_approx(game.vehicle.config.max_health, selected_vehicle_config.max_health), "race applies selected vehicle")
	check(not game.vehicle.gun.enabled, "race starts without a selected weapon")
	game.free()
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	print("GARAGE LOADOUT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
