extends SceneTree

var failures := 0
var profile_path := "res://.pre_race_profile_test.cfg"
var loadout_path := "res://.pre_race_loadout_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("PRE-RACE FAIL: ", label)


func run() -> void:
	for test_path in [profile_path, loadout_path]:
		var absolute_path := ProjectSettings.globalize_path(test_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	PlayerProfile.path_override = profile_path
	LoadoutProfile.path_override = loadout_path
	PlayerProfile.save({
		"credits": 1000,
		"vehicles": [&"raider", &"viper"],
		"weapons": [&"machine_gun"],
		"vehicle_states": {},
		"weapon_upgrades": [],
	})
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	LoadoutProfile.save_mode_vehicle(&"race", &"viper")
	LoadoutProfile.save_mode_vehicle(&"survival", &"raider")

	PreRaceSetup.request_mode(&"race")
	var selection := (load("res://scenes/PreRace.tscn") as PackedScene).instantiate() as PreRaceSetup
	root.add_child(selection)
	await process_frame
	check(selection.mode == &"race", "race mode is shown")
	check(selection.selected_vehicle_id == &"viper", "race remembers its own vehicle")
	check(selection.get_node("%VehicleGrid").get_child_count() == 12, "all catalog vehicles have cards")
	check(not selection.get_node("%StartButton").disabled, "owned vehicle can start")
	check("ИДЕАЛЬНАЯ ДУГА" in selection.get_node("%Passive").text, "class passive is explained")
	check(selection.get_node("%TrackPreview").config != null, "race preparation shows track map")
	check(selection.get_node("%TrackPreview").config.biome_id == &"industrial", "default race shows its biome")

	var crusher := selection.get_node("%VehicleGrid/Card_crusher") as Button
	crusher.pressed.emit()
	check(selection.selected_vehicle_id == &"crusher", "locked card can be inspected")
	check(selection.get_node("%StartButton").disabled, "locked vehicle cannot start")
	check("ПОКУПКИ" in selection.get_node("%Ownership").text, "locked state is explicit")
	var assault_filter := selection.get_node("Margin/Layout/Body/CatalogPanel/Catalog/ClassFilters/AssaultFilter") as Button
	assault_filter.pressed.emit()
	check(selection.get_node("%VehicleGrid/Card_wasteland_gt").visible, "class filter shows matching vehicle")
	check(not selection.get_node("%VehicleGrid/Card_raider").visible, "class filter hides other classes")
	selection.free()
	await process_frame

	PreRaceSetup.request_mode(&"survival")
	selection = (load("res://scenes/PreRace.tscn") as PackedScene).instantiate() as PreRaceSetup
	root.add_child(selection)
	await process_frame
	check(selection.mode == &"survival", "survival mode is shown")
	check(selection.selected_vehicle_id == &"raider", "survival remembers a separate vehicle")
	check("ВЫЖИВАНИЮ" in selection.get_node("%Title").text, "mode copy matches survival")
	selection.free()

	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	for test_path in [profile_path, loadout_path]:
		var absolute_path := ProjectSettings.globalize_path(test_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	print("PRE-RACE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
