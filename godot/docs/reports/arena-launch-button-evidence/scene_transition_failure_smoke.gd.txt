extends "res://tests/arena_launch_gui_smoke.gd"
## Deliberate missing scene: loader errors in this negative test are expected.
func run() -> void:
	output="/tmp/arena-launch-failure/"
	DirAccess.make_dir_recursive_absolute(output)
	PlayerProfile.path_override=output+"profile.cfg";LoadoutProfile.path_override=output+"loadout.cfg"
	MainMenu.settings_path_override=output+"settings.cfg"
	PlayerProfile.save({"credits":0,"vehicles":[&"raider"],"weapons":[&"machine_gun"],"vehicle_states":{},"weapon_upgrades":[]})
	LoadoutProfile.save_ids(&"raider",&"machine_gun")
	var settings:=ConfigFile.new();settings.set_value("settings","fullscreen",false);settings.set_value("settings","resolution_index",0);settings.save(MainMenu.settings_path_override)
	AudioServer.set_bus_mute(0,true)
	scene_changed.connect(func():transitions+=1)
	change_scene_to_file("res://scenes/MainMenu.tscn")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	print("EXPECTED LOAD ERROR: intentionally missing regression scene")
	SceneTransition.go("res://scenes/__missing_launch_regression__.tscn")
	var until:=Time.get_ticks_msec()+10000
	while SceneTransition.is_busy() and Time.get_ticks_msec()<until:await process_frame
	var transition:=root.get_node("Transition") as SceneTransition
	check(not transition._loading and not transition._overlay.visible,"failed load releases busy flag/overlay")
	check(transition._error_dialog!=null and transition._error_dialog.visible,"failure has visible user message")
	check(current_scene!=null and current_scene.scene_file_path=="res://scenes/MainMenu.tscn","failed load preserves current screen")
	if transition._error_dialog!=null:
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			shots.append({"name":"load-error-dialog","image":transition._error_dialog.get_texture().get_image()})
		await click(transition._error_dialog.get_ok_button())
		check(not transition._error_dialog.visible,"error dismissed by GUI OK click")
	if not await launch("SurvivalButton"):finish();return
	check(current_scene.player.alive,"valid launch succeeds after error")
	finish()
