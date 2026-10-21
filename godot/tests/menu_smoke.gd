extends SceneTree
## Headless smoke test for the main menu: buttons, settings panel, pre-race flow.

var _menu: Control
var _frames := 0
var _phase := 0
var _failures := 0


func _initialize() -> void:
	_menu = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(_menu)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	match _phase:
		0:
			_check_menu()
			_phase = 1
			return false
		1:
			_check_settings()
			# Reproduce the interactive case: the main menu has already warmed the
			# shared pre-race screen before Survival is pressed.
			var transition := root.get_node("Transition") as SceneTransition
			transition._cache["res://scenes/PreRace.tscn"] = load("res://scenes/PreRace.tscn")
			_menu.get_node("%SurvivalButton").pressed.emit()
			_check(SceneTransition.is_busy(), "Survival transition acknowledges input immediately")
			var overlay := root.get_node_or_null("Transition/LoadingOverlay") as Control
			_check(overlay != null and overlay.visible, "loading overlay is visible immediately")
			_check(overlay != null and overlay.size.x >= 1200.0 and overlay.size.y >= 700.0, "loading overlay covers the viewport")
			_phase = 2
			return false

	var changed := (
		current_scene != null
		and current_scene.scene_file_path == "res://scenes/PreRace.tscn"
	)
	if not changed and _frames < 600:
		return false
	_check(changed, "Survival opens pre-race vehicle selection")

	print("MENU: %d failures" % _failures)
	print("MENU: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_menu.free()
	if current_scene != null:
		current_scene.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check_menu() -> void:
	_check(_menu.get_node_or_null("%RaceButton") != null, "Race button exists")
	_check(_menu.get_node_or_null("%CareerButton") != null, "Career button exists")
	_check(_menu.get_node_or_null("%SurvivalButton") != null, "Survival button exists")
	_check(_menu.get_node_or_null("%SettingsButton") != null, "Settings button exists")
	_check(_menu.get_node("%MenuBox").visible, "menu shown initially")
	_check(not _menu.get_node("%SettingsPanel").visible, "settings hidden initially")


func _check_settings() -> void:
	_menu.get_node("%SettingsButton").pressed.emit()
	_check(not _menu.get_node("%MenuBox").visible, "menu hidden in settings")
	_check(_menu.get_node("%SettingsPanel").visible, "settings shown")
	_menu.get_node("%BackButton").pressed.emit()
	_check(_menu.get_node("%MenuBox").visible, "menu restored after Back")
	_check(not _menu.get_node("%SettingsPanel").visible, "settings hidden after Back")


func _check(condition: bool, label: String) -> void:
	if not condition:
		print("MENU FAIL: ", label)
		_failures += 1
