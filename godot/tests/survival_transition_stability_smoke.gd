extends SceneTree

var failures := 0
const PROFILE_PATH := "res://.survival_transition_profile.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("SURVIVAL TRANSITION FAIL: ", label)


func run() -> void:
	PlayerProfile.path_override = PROFILE_PATH
	_cleanup()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	var survival := current_scene as Survival

	check(survival.arena.get_spawn_points(9).size() == 9, "late waves have player plus eight distinct spawn slots")
	var credits_before := int(PlayerProfile.read().credits)
	survival._end_round(true)
	var credits_after_first := int(PlayerProfile.read().credits)
	survival._end_round(true)
	var credits_after_second := int(PlayerProfile.read().credits)
	check(credits_after_first > credits_before, "victory reward is paid")
	check(credits_after_second == credits_after_first, "duplicate finalization cannot pay twice")

	survival.start_round(14)
	check(survival._enemies.size() == 8, "eight-opponent late wave starts without truncated spawn array")
	_cleanup()
	PlayerProfile.path_override = ""
	print("SURVIVAL TRANSITION: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _cleanup() -> void:
	for path in [PROFILE_PATH, PROFILE_PATH + ".bak", PROFILE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
