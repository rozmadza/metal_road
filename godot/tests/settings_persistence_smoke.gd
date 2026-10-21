extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("SETTINGS FAIL: ", label)

func run() -> void:
	MainMenu.settings_path_override = "res://.settings_test.cfg"
	var menu: MainMenu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(AudioServer.get_bus_index(&"Master") >= 0, "Master bus")
	check(AudioServer.get_bus_index(&"Music") >= 0, "Music bus")
	check(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus")
	check(AudioServer.get_bus_index(&"Engine") >= 0, "Engine bus")
	check(AudioServer.get_bus_index(&"UI") >= 0, "UI bus")
	menu.get_node("%SettingsButton").pressed.emit()
	menu.get_node("%VolumeSlider").value = 0.63
	menu.get_node("%MusicSlider").value = 0.42
	menu.get_node("%SfxSlider").value = 0.77
	menu.get_node("%EngineSlider").value = 0.31
	menu.get_node("%FullscreenCheck").button_pressed = false
	await process_frame
	menu.get_node("%DifficultyOption").select(2)
	menu.get_node("%DifficultyOption").item_selected.emit(2)
	menu.get_node("%ReducedFlashesCheck").button_pressed = true
	var cfg := ConfigFile.new()
	check(cfg.load("res://.settings_test.cfg") == OK, "settings file written")
	check(int(cfg.get_value("settings", "settings_version", 0)) == 2, "settings version")
	check(is_equal_approx(float(cfg.get_value("settings", "music_volume", 0)), 0.42), "music persisted")
	check(is_equal_approx(float(cfg.get_value("settings", "sfx_volume", 0)), 0.77), "sfx persisted")
	menu.free()
	var second: MainMenu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(second)
	await process_frame
	check(is_equal_approx(second.get_node("%VolumeSlider").value, 0.63), "master restored")
	check(is_equal_approx(second.get_node("%MusicSlider").value, 0.42), "music restored")
	check(is_equal_approx(second.get_node("%SfxSlider").value, 0.77), "sfx restored")
	check(is_equal_approx(second.get_node("%EngineSlider").value, 0.31), "engine restored")
	check(not second.get_node("%FullscreenCheck").button_pressed, "fullscreen restored")
	check(second.get_node("%DifficultyOption").selected == 2, "difficulty restored")
	check(second.get_node("%ReducedFlashesCheck").button_pressed, "reduced flashes restored")
	second.free()
	MainMenu.settings_path_override = ""
	var absolute := ProjectSettings.globalize_path("res://.settings_test.cfg")
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("SETTINGS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
