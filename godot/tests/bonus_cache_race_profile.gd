extends SceneTree
## Graphical Race entry, supplies, restart and memory; works on both source versions.
const Timing = preload("res://tests/survival_perf_stats.gd")
const PATHS := [
	"res://resources/weapons/machine_gun.tres",
	"res://resources/weapons/heavy_machine_gun.tres",
	"res://resources/weapons/shotgun.tres",
	"res://resources/weapons/rocket_launcher.tres",
	"res://resources/weapons/mine_layer.tres",
	"res://resources/weapons/flamethrower.tres",
	"res://resources/weapons/emp_cannon.tres",
]
var run_id := "race-profile"
var game: Game
var active := false
var last_us := 0
var frames: Array = []
var windows: Array = []
var events: Array = []

func _initialize() -> void:
	run.call_deferred()

func _process(_delta: float) -> bool:
	if active:
		var now := Time.get_ticks_usec()
		frames.append([now, (now - last_us) / 1000.0])
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
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}

func sample(label: String, seconds: float) -> void:
	Timing.phase = label
	frames = []
	last_us = Time.get_ticks_usec()
	active = true
	var started := last_us
	while Time.get_ticks_usec() - started < int(seconds * 1000000.0):
		await process_frame
	active = false
	windows.append({"name": label, "duration_s": (Time.get_ticks_usec() - started) / 1000000.0,
		"frames": frames.duplicate(), "memory": memory(), "race_over": game.race_over,
		"pickup_count": game.bonus_spawner._active_pickups.size(),
		"cached_weapons": PATHS.filter(func(path): return ResourceLoader.has_cached(path)).size()})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("id="): run_id = arg.substr(3)
	DirAccess.make_dir_recursive_absolute("res://perf-output/")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	PlayerProfile.path_override = "res://perf-output/" + run_id + "-profile.cfg"
	LoadoutProfile.path_override = "res://perf-output/" + run_id + "-loadout.cfg"
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	PlayerProfile.save(PlayerProfile.read())
	CareerSession.clear_selection()
	PreRaceSetup.request_mode(&"race")
	Timing.enabled = true
	Timing.phase = "race_entry"
	var started := Time.get_ticks_usec()
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	current_scene.get_node("%RaceButton").pressed.emit()
	while not current_scene is PreRaceSetup or SceneTransition.is_busy():
		await process_frame
	var prerace_us := Time.get_ticks_usec() - started
	current_scene.get_node("%StartButton").pressed.emit()
	while not current_scene is Game or SceneTransition.is_busy():
		await process_frame
	await RenderingServer.frame_post_draw
	game = current_scene as Game
	var entry_us := Time.get_ticks_usec() - started
	game.bonus_spawner._rng.seed = 4217
	game.bonus_spawner.bonus_spawned.connect(func(pickup: BonusPickup):
		events.append({"event": "spawn", "at_us": Time.get_ticks_usec(), "kind": pickup.kind,
			"weapon": str(pickup.weapon_config.weapon_id) if pickup.weapon_config != null else ""}))
	var after_entry := memory()
	await sample("race_first", 13.0)
	Timing.phase = "race_restart"
	var restart_started := Time.get_ticks_usec()
	game._reset_race()
	await RenderingServer.frame_post_draw
	var restart_us := Time.get_ticks_usec() - restart_started
	await sample("race_after_restart", 6.0)
	var payload := {"id": run_id, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"prerace_us": prerace_us, "entry_us": entry_us, "restart_us": restart_us,
		"after_entry": after_entry, "windows": windows, "events": events,
		"function_times_us": Timing.calls, "slow_events": Timing.events}
	FileAccess.open("res://perf-output/" + run_id + ".json", FileAccess.WRITE).store_string(JSON.stringify(payload))
	print("BONUS CACHE RACE PROFILE COMPLETE ", run_id, " pickups=", events.size())
	quit()
