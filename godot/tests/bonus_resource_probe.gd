extends SceneTree
## Graphical resource-only probe. No gameplay scene is instantiated.
const WEAPON_PATH := "res://resources/weapons/rocket_launcher.tres"
const IMAGE_PATH := "res://assets/weapons/rocket_launcher/rocket_launcher_roof.png"

func _initialize() -> void:
	run.call_deferred()

func mark() -> Dictionary:
	var output: Array = []
	var rss := -1
	if OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], output) == 0 and not output.is_empty():
		for line in str(output[0]).split("\n"):
			if line.begins_with("VmRSS:"):
				rss = int(line.replace("VmRSS:", "").strip_edges().split(" ", false)[0])
	return {"rss_kb": rss, "godot_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"godot_video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"godot_texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}

func run() -> void:
	var mode := "cold"
	var id := "bonus-resource-cold"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mode="): mode = arg.substr(5)
		if arg.begins_with("id="): id = arg.substr(3)
	DirAccess.make_dir_recursive_absolute("res://perf-output/")
	var rows := [{"stage": "initial", "memory": mark(), "config_cached": ResourceLoader.has_cached(WEAPON_PATH),
		"texture_cached": ResourceLoader.has_cached(IMAGE_PATH)}]
	var retained: Array[Resource] = []
	if mode == "all_weapons":
		var paths := ["machine_gun", "heavy_machine_gun", "shotgun", "rocket_launcher",
			"mine_layer", "flamethrower", "emp_cannon"]
		var t_all := Time.get_ticks_usec()
		for name in paths:
			retained.append(load("res://resources/weapons/" + name + ".tres") as Resource)
		rows.append({"stage": "all_seven_retained", "us": Time.get_ticks_usec() - t_all,
			"memory": mark(), "retained": retained.size()})
	var image: Texture2D
	if mode == "image_first":
		var t := Time.get_ticks_usec()
		image = load(IMAGE_PATH) as Texture2D
		rows.append({"stage": "image_load", "us": Time.get_ticks_usec() - t, "memory": mark(),
			"image_size": image.get_size()})
	var config: WeaponConfig
	var t := Time.get_ticks_usec()
	config = load(WEAPON_PATH) as WeaponConfig
	rows.append({"stage": "config_load", "us": Time.get_ticks_usec() - t, "memory": mark(),
		"config_cached": ResourceLoader.has_cached(WEAPON_PATH),
		"texture_cached": ResourceLoader.has_cached(IMAGE_PATH)})
	t = Time.get_ticks_usec()
	var repeat: WeaponConfig = load(WEAPON_PATH) as WeaponConfig
	rows.append({"stage": "config_repeat", "us": Time.get_ticks_usec() - t, "same_instance": repeat == config, "memory": mark()})
	await RenderingServer.frame_post_draw
	rows.append({"stage": "after_render", "memory": mark()})
	if mode == "all_weapons":
		retained.clear()
		config = null
		repeat = null
		await process_frame
		rows.append({"stage": "after_release", "memory": mark(),
			"rocket_cached": ResourceLoader.has_cached(WEAPON_PATH)})
	var path := "res://perf-output/" + id + ".json"
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({
		"id": id, "mode": mode, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "rows": rows}))
	print("BONUS RESOURCE PROBE COMPLETE ", id)
	quit()
