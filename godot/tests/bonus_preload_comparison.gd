extends SceneTree
## Disposable graphical comparison of resource preparation before Start.
const PATHS := [
	"res://resources/weapons/machine_gun.tres",
	"res://resources/weapons/heavy_machine_gun.tres",
	"res://resources/weapons/shotgun.tres",
	"res://resources/weapons/rocket_launcher.tres",
	"res://resources/weapons/mine_layer.tres",
	"res://resources/weapons/flamethrower.tres",
	"res://resources/weapons/emp_cannon.tres",
]
var mode := "none"
var run_id := "preload-probe"
var retained: Array[WeaponConfig] = []
var frames: Array[float] = []
var last_us := 0
var collecting := false

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	if collecting:
		var now := Time.get_ticks_usec()
		frames.append((now - last_us) / 1000.0)
		last_us = now
	return false

func memory() -> Dictionary:
	var output: Array = []
	var rss := -1
	if OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], output) == 0 and not output.is_empty():
		for line in str(output[0]).split("\n"):
			if line.begins_with("VmRSS:"):
				rss = int(line.replace("VmRSS:", "").strip_edges().split(" ", false)[0])
	return {"rss_kb": rss, "static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}

func prepare_sync() -> Dictionary:
	var calls: Array[Dictionary] = []
	for path in PATHS:
		var cached := ResourceLoader.has_cached(path)
		var started := Time.get_ticks_usec()
		var config := load(path) as WeaponConfig
		calls.append({"path": path, "cached_before": cached, "usec": Time.get_ticks_usec() - started,
			"valid": config != null})
		retained.append(config)
	return {"calls": calls}

func prepare_threaded(use_sub_threads: bool = true) -> Dictionary:
	var request_results: Array[Dictionary] = []
	var main_request_us := 0
	for path in PATHS:
		var started := Time.get_ticks_usec()
		var code := ResourceLoader.load_threaded_request(path, "WeaponConfig", use_sub_threads)
		main_request_us += Time.get_ticks_usec() - started
		request_results.append({"path": path, "code": code, "cached_before": ResourceLoader.has_cached(path)})
	var polls := 0
	while true:
		var all_done := true
		for path in PATHS:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return {"request_results": request_results, "error_path": path}
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				all_done = false
		if all_done:
			break
		polls += 1
		await process_frame
	var get_calls: Array[Dictionary] = []
	for path in PATHS:
		var started := Time.get_ticks_usec()
		var config := ResourceLoader.load_threaded_get(path) as WeaponConfig
		get_calls.append({"path": path, "usec": Time.get_ticks_usec() - started, "valid": config != null})
		retained.append(config)
	return {"request_results": request_results, "request_usec": main_request_us,
		"polls": polls, "get_calls": get_calls}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="): mode = arg.substr(5)
		if arg.begins_with("id="): run_id = arg.substr(3)
	DirAccess.make_dir_recursive_absolute("res://bench-output/")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	PlayerProfile.path_override = "res://bench-output/" + run_id + "-profile.cfg"
	LoadoutProfile.path_override = "res://bench-output/" + run_id + "-loadout.cfg"
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection()
	SurvivalRunData.selected_arena_id = &"scrapyard"
	SurvivalRunData.daily_mode = false
	seed(4217)
	var first_entry_us := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	current_scene.get_node("%SurvivalButton").pressed.emit()
	while not current_scene is PreRaceSetup or SceneTransition.is_busy():
		await process_frame
	var menu_to_prerace_us := Time.get_ticks_usec() - first_entry_us
	# Avoid unrelated scene-warm workers when comparing the two preparation modes.
	var transition := root.get_node("Transition") as SceneTransition
	var wait_started := Time.get_ticks_usec()
	while not transition._cache.has("res://scenes/ArenaBattle.tscn") and Time.get_ticks_usec() - wait_started < 5000000:
		await process_frame
	var warm_wait_us := Time.get_ticks_usec() - wait_started
	var before := memory()
	var cached_before: Array[bool] = []
	for path in PATHS: cached_before.append(ResourceLoader.has_cached(path))
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.024, 0.028, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shade)
	await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	last_us = started
	collecting = true
	var prep: Dictionary = {}
	if mode == "sync":
		prep = prepare_sync()
	elif mode == "threaded":
		prep = await prepare_threaded(true)
	elif mode == "threaded_simple":
		prep = await prepare_threaded(false)
	var prep_us := Time.get_ticks_usec() - started
	var after_prep := memory()
	shade.queue_free()
	current_scene.get_node("%StartButton").pressed.emit()
	while not current_scene is Survival or SceneTransition.is_busy():
		await process_frame
	await RenderingServer.frame_post_draw
	collecting = false
	var visible_us := Time.get_ticks_usec() - started
	var data := {"id": run_id, "mode": mode, "engine": Engine.get_version_info(),
		"display": DisplayServer.get_name(), "menu_to_prerace_us": menu_to_prerace_us,
		"warm_wait_us": warm_wait_us, "cached_before": cached_before,
		"prep_us": prep_us, "visible_us": visible_us, "prep": prep,
		"before": before, "after_prep": after_prep, "after_game": memory(), "frames_ms": frames}
	FileAccess.open("res://bench-output/" + run_id + ".json", FileAccess.WRITE).store_string(JSON.stringify(data))
	print("BONUS PRELOAD COMPARISON COMPLETE ", run_id, " mode=", mode, " prep_us=", prep_us, " visible_us=", visible_us)
	quit()
