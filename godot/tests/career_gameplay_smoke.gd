extends SceneTree

var failures := 0
var profile_path := "user://career_gameplay_profile_test.cfg"
var loadout_path := "user://career_gameplay_loadout_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CAREER GAMEPLAY FAIL: ", label)


func run() -> void:
	PlayerProfile.path_override = profile_path
	LoadoutProfile.path_override = loadout_path
	PlayerProfile.save({"credits": 0, "vehicles": [&"raider"], "weapons": [&"machine_gun"], "vehicle_states": {}, "weapon_upgrades": []})
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	CareerSession.select_event(&"dust_elimination")
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	var game := current_scene as Game
	await process_frame
	game.set_physics_process(false)
	for bot in game._bots: bot.set_physics_process(false)
	check(game.event_type == &"elimination", "elimination rules reach gameplay")
	check(game.track.config.laps == 3 and game.track.config.centerline.size() == 15, "event track config is applied")
	var before_alive := game.participants.filter(func(car): return car.alive).size()
	game._eliminate_last_racer()
	var after_alive := game.participants.filter(func(car): return car.alive).size()
	check(after_alive == before_alive - 1, "elimination removes the last racer")

	current_scene.free()
	await process_frame
	CareerSession.select_event(&"crown_supply_rush")
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	game = current_scene as Game
	await process_frame
	game.set_physics_process(false)
	for bot in game._bots: bot.set_physics_process(false)
	check(game.event_type == &"bonus_hunt" and game.track.config.laps == 99, "bonus hunt rules reach gameplay")
	for _pickup in 3:
		game._on_bonus_collected(game.vehicle, BonusPickup.Kind.SPEED_BOOST)
	check(game.race_over and int(game.result.pickups) == 3, "third pickup completes bonus hunt")
	check(bool(game.result.get("career_event", false)) and game.results.visible, "career result is shown")
	check(game.results.get_node("%CareerButton").visible, "result offers return to career")

	current_scene.free()
	await process_frame
	CareerSession.select_event(&"scrapyard_contract")
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	var survival := current_scene as Survival
	await process_frame
	survival.set_process(false)
	survival.set_physics_process(false)
	survival._round = 2
	survival._end_round(true)
	check(survival._round_over and survival.results.visible, "arena contract ends after target round")
	check("ПОБЕДА" in survival.results.get_node("%ResultTitle").text, "arena contract reports victory")
	check(survival.results.get_node("%CareerButton").visible, "arena result returns to career")

	CareerSession.clear_selection()
	current_scene.free()
	await process_frame
	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	for path in [profile_path, loadout_path]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("CAREER GAMEPLAY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
