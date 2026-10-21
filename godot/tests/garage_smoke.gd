extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("GARAGE FAIL: ", label)

func run() -> void:
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	current_scene.get_node("%GarageButton").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == "res://scenes/Garage.tscn", "menu opens garage")
	check(current_scene.get_node("%VehiclePreview").texture == current_scene.vehicle_config.texture, "preview uses current config")
	check(str(int(current_scene.vehicle_config.max_health)) in current_scene.get_node("%Stats").text, "stats use actual vehicle")
	check(not current_scene.has_node("%WeaponSelect"), "weapons are no longer selected in garage")
	check(current_scene.has_node("%SellButton"), "vehicle sale is available")
	check("НА ТРАССЕ" in current_scene.get_node("Margin/Layout/Body/StatsPanel/Info/BonusInfo").text, "pickup rules shown")
	current_scene.get_node("%BackButton").pressed.emit()
	await scene_changed
	check(current_scene.scene_file_path == "res://scenes/MainMenu.tscn", "return to menu")
	current_scene.get_node("%GarageButton").pressed.emit()
	await scene_changed
	current_scene.get_node("%SurvivalButton").pressed.emit()
	await scene_changed
	check(current_scene is PreRaceSetup, "garage opens pre-race selection")
	check(current_scene.mode == &"survival", "garage keeps the selected survival mode")
	current_scene.free()
	await create_timer(0.4).timeout
	print("GARAGE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
