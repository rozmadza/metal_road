extends SceneTree
## End-to-end navigation checks for post-race and post-survival actions.

const MENU := "res://scenes/MainMenu.tscn"
const GARAGE := "res://scenes/Garage.tscn"
const ARENA := "res://scenes/ArenaBattle.tscn"
const PROFILE_PATH := "res://.results_navigation_profile.cfg"
const LOADOUT_PATH := "res://.results_navigation_loadout.cfg"

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	PlayerProfile.path_override = PROFILE_PATH
	LoadoutProfile.path_override = LOADOUT_PATH
	await _check_survival_retry()
	await _check_survival_menu()
	await _check_survival_garage()
	await _check_race_results_routes()
	await _check_pause_routes()
	_cleanup()
	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	print("RESULTS NAVIGATION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _check_survival_retry() -> void:
	await _open(ARENA)
	var survival := current_scene as Survival
	survival._end_round(false)
	var results := survival.results
	check(results.visible, "survival results are visible after defeat")
	results.get_node("%RetryButton").pressed.emit()
	await process_frame
	check(current_scene == survival, "Retry remains in Survival")
	check(not results.visible and survival._round == 1 and not survival._round_over, "Retry starts a clean first wave")


func _check_survival_menu() -> void:
	await _open(ARENA)
	var survival := current_scene as Survival
	survival._end_round(false)
	paused = true
	survival.results.get_node("%MenuButton").pressed.emit()
	check(not paused, "Survival results clear a stale pause")
	check(await _wait_for_scene(MENU), "Survival results open Main Menu")


func _check_survival_garage() -> void:
	await _open(ARENA)
	var survival := current_scene as Survival
	survival._end_round(false)
	survival.results.get_node("%GarageButton").pressed.emit()
	check(await _wait_for_scene(GARAGE), "Survival results open Garage")
	current_scene.get_node("%BackButton").pressed.emit()
	check(await _wait_for_scene(MENU), "Garage Back returns to Main Menu")


func _check_race_results_routes() -> void:
	await _open(GARAGE)
	var results := (load("res://scenes/RaceResults.tscn") as PackedScene).instantiate()
	current_scene.add_child(results)
	var result := {
		"status": &"FINISHED", "position": 1, "participants": 4,
		"time": 75.0, "laps": 3, "target_laps": 3,
		"kills": 1, "weapon_kills": 1, "damage": 100.0, "credits": 200,
	}
	results.show_result(result)
	results.get_node("%MenuButton").pressed.emit()
	check(await _wait_for_scene(MENU), "Race results open Main Menu")
	results = (load("res://scenes/RaceResults.tscn") as PackedScene).instantiate()
	current_scene.add_child(results)
	results.show_result(result)
	results.get_node("%GarageButton").pressed.emit()
	check(await _wait_for_scene(GARAGE), "Race results open Garage")


func _check_pause_routes() -> void:
	await _open(ARENA)
	var survival := current_scene as Survival
	var pause := survival.hud.pause_overlay
	pause.toggle()
	check(paused and pause.visible, "pause menu stops gameplay")
	pause.resume()
	check(not paused and not pause.visible, "Continue resumes gameplay")
	pause.toggle()
	pause._restart()
	await process_frame
	check(not paused and survival._round == 1 and not survival._round_over, "pause Restart resumes and restarts")
	pause.toggle()
	pause._menu()
	check(await _wait_for_scene(MENU), "pause Main Menu resumes and leaves arena")


func _open(path: String) -> void:
	paused = false
	var error := change_scene_to_file(path)
	check(error == OK, "scene request accepted: %s" % path)
	await scene_changed
	await process_frame


func _wait_for_scene(path: String, max_frames: int = 600) -> bool:
	for _frame in max_frames:
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
			return true
		await process_frame
	return false


func check(ok: bool, label: String) -> void:
	if ok:
		print("RESULTS NAVIGATION ok: ", label)
	else:
		failures += 1
		printerr("RESULTS NAVIGATION FAIL: ", label)


func _cleanup() -> void:
	for path in [PROFILE_PATH, PROFILE_PATH + ".bak", PROFILE_PATH + ".tmp", LOADOUT_PATH, LOADOUT_PATH + ".bak", LOADOUT_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
