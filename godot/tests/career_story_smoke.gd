extends SceneTree

const PROFILE_PATH := "user://career_story_profile_test.cfg"
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	PlayerProfile.path_override = PROFILE_PATH
	var profile := PlayerProfile.read()
	profile.career.driver_id = &"mara"
	PlayerProfile.save(profile)
	CareerSession.select_event(&"iron_open")
	_check(CareerStory.prepare_intro(&"iron_open", "res://scenes/Main.tscn"), "intro is available for first event")
	_check(CareerStory.pending.driver.id == &"mara", "intro uses selected hero")
	var dialogue := (load(CareerStory.SCENE) as PackedScene).instantiate()
	root.add_child(dialogue)
	await process_frame
	_check(dialogue.get("_speech").text.contains("Новичкам"), "intro shows rival's line")
	dialogue.call("_next")
	_check(dialogue.get("_speech").text.contains("поворот"), "hero answers with selected voice")
	dialogue.free()
	await process_frame
	CareerStory.clear()
	var result := {"career_event": true, "status": &"FINISHED", "position": 2, "rival_positions": {"razor": 4}}
	_check(CareerStory.prepare_outro(result), "outro is available after finish")
	_check(String(CareerStory.pending.lines[0].text).contains("впереди"), "rival reacts to being beaten")
	dialogue = (load(CareerStory.SCENE) as PackedScene).instantiate()
	root.add_child(dialogue)
	await process_frame
	_check(dialogue.get("_speech").text.contains("впереди"), "outro screen shows actual result")
	dialogue.free()
	await process_frame
	CareerStory.clear()
	result.position = 5
	result.rival_positions.razor = 2
	_check(CareerStory.prepare_outro(result), "outro handles a loss")
	_check(String(CareerStory.pending.lines[0].text).contains("зеркале"), "loss has distinct reaction")
	CareerStory.clear()
	result.status = &"DNF"
	_check(CareerStory.prepare_outro(result), "outro handles DNF")
	_check(String(CareerStory.pending.lines[0].text).contains("оставил машину"), "DNF has distinct reaction")
	CareerStory.clear()
	PreRaceSetup.request_mode(&"race")
	change_scene_to_file("res://scenes/PreRace.tscn")
	await scene_changed
	current_scene.get_node("%StartButton").pressed.emit()
	_check(await _wait_for_scene(CareerStory.SCENE), "Start opens story before first race")
	_check(CareerStory.pending.destination == "res://scenes/Main.tscn", "intro continues into race")
	CareerStory.clear()
	change_scene_to_file("res://scenes/RaceResults.tscn")
	await scene_changed
	var results := current_scene
	results.show_result({"career_event": true, "status": &"FINISHED", "position": 2, "participants": 6,
		"time": 88.0, "laps": 3, "target_laps": 3, "kills": 0, "damage": 0.0,
		"credits": 400, "rival_positions": {"razor": 4}})
	results.get_node("%CareerButton").pressed.emit()
	_check(await _wait_for_scene(CareerStory.SCENE), "Career button opens post-race dialogue")
	CareerStory.clear()
	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	var path := ProjectSettings.globalize_path(PROFILE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	print("CAREER STORY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CAREER STORY FAIL: ", label)


func _wait_for_scene(path: String) -> bool:
	for _frame in 180:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return true
	return false
