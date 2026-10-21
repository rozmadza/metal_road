extends SceneTree

var failures := 0
const PROFILE_PATH := "res://.profile_recovery_test.cfg"
const LOADOUT_PATH := "res://.loadout_recovery_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("PROFILE RECOVERY FAIL: ", label)


func run() -> void:
	PlayerProfile.path_override = PROFILE_PATH
	LoadoutProfile.path_override = LOADOUT_PATH
	_cleanup()

	var profile := PlayerProfile._default_profile()
	profile.credits = 1234
	check(PlayerProfile.save(profile), "initial profile is committed")
	profile.credits = 5678
	check(PlayerProfile.save(profile), "new profile revision is committed")
	FileAccess.open(PROFILE_PATH, FileAccess.WRITE).store_string("broken profile")
	var recovered := PlayerProfile.read()
	check(int(recovered.credits) == 1234, "corrupt primary profile recovers last known-good backup")

	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	LoadoutProfile.save_ids(&"nomad", &"heavy_machine_gun")
	FileAccess.open(LOADOUT_PATH, FileAccess.WRITE).store_string("broken loadout")
	var ids := LoadoutProfile.read_ids()
	check(ids.vehicle == &"raider" and ids.weapon == &"machine_gun", "corrupt loadout recovers backup")

	_cleanup()
	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	print("PROFILE RECOVERY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _cleanup() -> void:
	for path in [
		PROFILE_PATH, PROFILE_PATH + ".bak", PROFILE_PATH + ".tmp",
		LOADOUT_PATH, LOADOUT_PATH + ".bak", LOADOUT_PATH + ".tmp",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
