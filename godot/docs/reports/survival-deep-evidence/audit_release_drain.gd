extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RELEASE FAIL: ", label)

func run() -> void:
	check(String(ProjectSettings.get_setting("application/config/version")) == "1.0.0", "release version")
	AccessibilitySettings.difficulty = 0
	check(is_equal_approx(AccessibilitySettings.player_damage_multiplier(), 0.72), "assisted damage")
	AccessibilitySettings.difficulty = 2
	check(AccessibilitySettings.reward_multiplier() > 1.0, "hardcore reward")
	AccessibilitySettings.screen_shake = 0.0
	var camera := FollowCamera.new()
	root.add_child(camera)
	camera.shake(12.0, 0.4)
	check(camera._shake_time == 0.0, "camera shake can be disabled")
	camera.free()
	AccessibilitySettings.screen_shake = 1.0
	AccessibilitySettings.difficulty = 1
	var pause := PauseOverlay.new()
	root.add_child(pause)
	pause.toggle()
	check(pause.visible and paused, "pause stops gameplay")
	pause.resume()
	check(not pause.visible and not paused, "pause resumes gameplay")
	pause.free()
	var menu := (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	for path in ["%DifficultyOption", "%ShakeSlider", "%ReducedFlashesCheck", "%HighContrastCheck", "%TutorialCheck"]:
		check(menu.get_node(path) != null, "accessibility control " + path)
	menu.free()
	var hud := (load("res://scenes/HUD.tscn") as PackedScene).instantiate() as DebugHUD
	root.add_child(hud)
	await process_frame
	check(hud.tutorial != null and hud.pause_overlay != null, "race onboarding and pause")
	hud.free()
	var vfx := CombatVFX.new()
	root.add_child(vfx)
	for index in 70: vfx.spawn_impact(Vector2(index, 0))
	check(vfx.events.size() <= 48, "VFX budget cap")
	vfx.free()
	await create_timer(0.5).timeout
	print("RELEASE CANDIDATE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
