extends SceneTree

const Bindings = preload("res://scripts/input_bindings.gd")
const TEST_PROFILE := "res://.release_v1_profile.cfg"

func _init() -> void:
	var failures: Array[String] = []
	Bindings.ensure_controller_defaults()
	for action in Bindings.ACTIONS:
		if InputMap.action_get_events(action).is_empty(): failures.append("missing input: %s" % action)
	var dpad_drive := {
		&"steer_left": JOY_BUTTON_DPAD_LEFT,
		&"steer_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action in dpad_drive:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == dpad_drive[action]:
				found = true
		if not found: failures.append("missing D-pad driving input: %s" % action)
	for action in [&"accelerate", &"brake"]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
				failures.append("D-pad vertical direction must not drive: %s" % action)
	for action in [&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var has_pad_event := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad_event = true
		if not has_pad_event: failures.append("missing gamepad UI input: %s" % action)
	Input.action_press(&"accelerate", 0.42)
	Input.action_press(&"steer_right", 0.36)
	var analogue := InputHandler.new().get_commands()
	if not is_equal_approx(float(analogue.throttle), 0.42): failures.append("analogue trigger strength lost")
	if not is_equal_approx(float(analogue.steer), 0.36): failures.append("analogue steering strength lost")
	Input.action_release(&"accelerate")
	Input.action_release(&"steer_right")
	for scene_path in ["res://scenes/MainMenu.tscn", "res://scenes/Controls.tscn", "res://scenes/Progress.tscn"]:
		if load(scene_path) == null: failures.append("scene failed: %s" % scene_path)
	PlayerProfile.path_override = TEST_PROFILE
	var data := PlayerProfile.read()
	data.credits = 4242
	PlayerProfile.save(data)
	data.credits = 5252
	PlayerProfile.save(data)
	if not FileAccess.file_exists(TEST_PROFILE + ".bak"): failures.append("profile backup missing")
	if int(PlayerProfile.read().credits) != 5252: failures.append("profile round-trip failed")
	PlayerProfile.path_override = ""
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PROFILE + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE + suffix))
	if ProjectSettings.get_setting("application/config/version") != "1.0.0": failures.append("version is not 1.0.0")
	if failures.is_empty():
		print("RELEASE_V1_SMOKE: PASS")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("RELEASE_V1_SMOKE: FAIL")
		quit(1)
