extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var results: Control = load("res://scenes/SurvivalResults.tscn").instantiate()
	root.add_child(results)
	check(not results.visible, "results hidden initially")
	results.show_result({"status": &"DEFEAT", "round": 3, "kills": 4, "damage": 321.5, "time": 65.2, "credits": 650})
	check(results.visible, "results shown")
	check(results.get_node("Center/Panel/Layout/ResultTitle").text == "ПОРАЖЕНИЕ", "defeat title")
	check("РАУНД  3" in results.get_node("Center/Panel/Layout/Summary").text, "summary has round")
	results.get_node("Center/Panel/Layout/Actions/RetryButton").pressed.emit()
	check(results.visible, "retry signal leaves screen available")
	print("SURVIVAL RESULTS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	if ok:
		print("SURVIVAL RESULTS ok: ", label)
	else:
		failures += 1
		printerr("SURVIVAL RESULTS FAIL: ", label)
