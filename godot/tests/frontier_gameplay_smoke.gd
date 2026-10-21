extends SceneTree

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FRONTIER GAMEPLAY FAIL: ", label)

func run() -> void:
	CareerSession.select_event(&"frontier_express")
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Game
	game._countdown_remaining = 0.0
	var starts := {}
	for bot in game._bots:
		starts[bot] = (bot.get_parent() as Vehicle).global_position
	for _frame in 360:
		await physics_frame
	var mobile := 0
	var valid_progress := 0
	for bot in game._bots:
		var car := bot.get_parent() as Vehicle
		if car.global_position.distance_to(starts[bot]) > 120.0: mobile += 1
		if game.progress.total_progress(car) > 80.0: valid_progress += 1
	check(game.track.config.biome_id == &"rust_frontier", "frontier track active")
	check(game.participants.size() == 6 and game.track.config.lane_count == 6, "one lane per racer")
	check(mobile >= 4, "bots navigate the long circuit")
	check(valid_progress >= 4, "bots accumulate race progress")
	check(Engine.get_frames_per_second() >= 55.0, "frontier keeps realtime performance")
	print("FRONTIER GAMEPLAY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
