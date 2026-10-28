extends SceneTree
## Graphical lifecycle probe with no per-frame or per-pickup event retention.
var game: Survival
var rows: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func mark(label: String) -> void:
	var output: Array = []
	var rss := -1
	if OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], output) == 0 and not output.is_empty():
		for line in str(output[0]).split("\n"):
			if line.begins_with("VmRSS:"):
				rss = int(line.replace("VmRSS:", "").strip_edges().split(" ", false)[0])
	rows.append({"phase": label, "rss_kb": rss,
		"godot_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"godot_video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})

func observe_supply() -> void:
	await create_timer(2.5).timeout

func menu_entry() -> void:
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	current_scene.get_node("%SurvivalButton").pressed.emit()
	while not current_scene is PreRaceSetup or SceneTransition.is_busy():
		await process_frame
	current_scene.get_node("%StartButton").pressed.emit()
	while not current_scene is Survival or SceneTransition.is_busy():
		await process_frame
	game = current_scene as Survival
	game.bonus_spawner._rng.seed = 4217

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://perf-output/")
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	PlayerProfile.path_override = "res://perf-output/bonus-memory-soak-profile.cfg"
	LoadoutProfile.path_override = "res://perf-output/bonus-memory-soak-loadout.cfg"
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection()
	SurvivalRunData.selected_arena_id = &"scrapyard"
	SurvivalRunData.daily_mode = false
	seed(4217)
	mark("before_entry")
	game = load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	game.bonus_spawner._rng.seed = 4217
	await observe_supply()
	mark("first_supply")
	for index in 10:
		var old_arena := game.arena.get_instance_id()
		game._on_retry_requested()
		while game._round_start_pending >= 0 or game.arena.get_instance_id() == old_arena:
			await process_frame
		game.bonus_spawner._rng.seed = 4217
		await observe_supply()
		mark("restart_%02d" % index)
	game.free()
	game = null
	await process_frame
	for index in 5:
		await menu_entry()
		await observe_supply()
		mark("menu_%02d" % index)
	FileAccess.open("res://perf-output/bonus-memory-soak.json", FileAccess.WRITE).store_string(JSON.stringify({
		"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "rows": rows}))
	print("BONUS MEMORY SOAK COMPLETE")
	quit()
